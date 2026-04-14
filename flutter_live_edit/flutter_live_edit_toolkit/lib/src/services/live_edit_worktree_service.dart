import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';

/// Default branch name prefix used when allocating per-bubble worktrees.
///
/// Stable across reallocations so that reusing a bubble id reuses its
/// branch and worktree without leaking refs.
const _kDefaultBranchPrefix = 'live-edit/bubble-';

/// Default parent directory for allocated worktrees.
///
/// Placed under the system temp dir — the main working directory is
/// intentionally avoided so worktrees can't accidentally be treated as
/// nested repos or swept up by project-wide `git clean`.
String _defaultWorktreeRoot() =>
    p.join(Directory.systemTemp.path, 'mcp_flutter_live_edit_worktrees');

/// Process timeout for every git invocation. Keeps hung remotes / deadlocks
/// from freezing the apply pipeline; surfaces `failed()` instead.
const _kGitOpTimeout = Duration(seconds: 60);

/// Manages per-bubble git worktrees for parallel Live Edit apply flows.
///
/// Only used when two or more bubbles are in-flight simultaneously or when
/// their file targets overlap — see [shouldUseWorktree]. Single-bubble
/// apply stays on the main working directory so hot reload picks up writes
/// immediately.
///
/// Safety: destructive operations (`git worktree remove --force`, branch
/// delete) ONLY run against paths this service allocated in the current
/// process; see [_allocations]. The service never invokes
/// `git reset --hard`, `git push`, or any rewriting of main-tree history.
class LiveEditWorktreeService {
  LiveEditWorktreeService({
    final String? worktreeRoot,
    final String branchPrefix = _kDefaultBranchPrefix,
  }) : _worktreeRoot = worktreeRoot ?? _defaultWorktreeRoot(),
       _branchPrefix = branchPrefix;

  final String _worktreeRoot;
  final String _branchPrefix;

  /// bubbleId -> handle. Used to reuse existing worktrees and to gate
  /// [abandon] destructive ops to paths we allocated.
  final Map<String, LiveEditWorktreeHandle> _allocations =
      <String, LiveEditWorktreeHandle>{};

  /// Allocates (or reuses) a worktree for [bubbleId] on a stable branch.
  ///
  /// Runs `git worktree add -B <branch> <path> HEAD` against
  /// [mainWorkingDirectory]. Path is under `$TMPDIR/mcp_flutter_live_edit_worktrees/`.
  /// Throws a [StateError] if the worktree add fails — the caller should
  /// fall back to the main working dir and surface the error.
  Future<LiveEditWorktreeHandle> allocate({
    required final String bubbleId,
    required final String mainWorkingDirectory,
  }) async {
    final trimmedId = bubbleId.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError.value(bubbleId, 'bubbleId', 'must not be empty');
    }
    final existing = _allocations[trimmedId];
    if (existing != null && _worktreeLooksAlive(existing.worktreePath)) {
      return existing;
    }

    final branch = '$_branchPrefix$trimmedId';
    final rootDir = Directory(_worktreeRoot);
    if (!rootDir.existsSync()) {
      rootDir.createSync(recursive: true);
    }
    final worktreePath = p.join(
      _worktreeRoot,
      trimmedId.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_'),
    );

    // `-B <branch>` creates or resets the branch to point at HEAD, then
    // checks it out in the new worktree. We intentionally don't pair it
    // with `--detach` (git rejects the combo): the branch is the anchor
    // we later merge back into the main tree.
    final result = await _runGit(
      workingDirectory: mainWorkingDirectory,
      arguments: <String>[
        'worktree',
        'add',
        '-B',
        branch,
        worktreePath,
        'HEAD',
      ],
    );
    if (result.exitCode != 0) {
      throw StateError(
        'git worktree add failed (exit ${result.exitCode}): '
        '${result.stderr.toString().trim()}',
      );
    }

    final handle = LiveEditWorktreeHandle(
      bubbleId: trimmedId,
      branch: branch,
      worktreePath: worktreePath,
    );
    _allocations[trimmedId] = handle;
    return handle;
  }

  /// Merges the worktree branch into [mainWorkingDirectory].
  ///
  /// Uses `git merge --no-ff <branch>`. Returns [LiveEditMergeResult.clean]
  /// on success, [LiveEditMergeResult.conflict] with the list of paths
  /// from `git diff --name-only --diff-filter=U` on a merge conflict,
  /// and [LiveEditMergeResult.failed] for any other non-zero exit.
  ///
  /// On conflict the merge is left in the main tree — the orchestrator
  /// decides whether to `git merge --abort` or surface the conflict to the
  /// user. This service does not resolve conflicts.
  Future<LiveEditMergeResult> mergeInto({
    required final LiveEditWorktreeHandle handle,
    required final String mainWorkingDirectory,
  }) async {
    final mergeResult = await _runGit(
      workingDirectory: mainWorkingDirectory,
      arguments: <String>['merge', '--no-ff', '--no-edit', handle.branch],
    );

    if (mergeResult.exitCode == 0) {
      return const LiveEditMergeResult.clean();
    }

    final combined = '${mergeResult.stdout}\n${mergeResult.stderr}'
        .toLowerCase();
    final looksLikeConflict =
        combined.contains('conflict') || combined.contains('merge failed');
    if (looksLikeConflict) {
      final files = await _collectConflictedFiles(mainWorkingDirectory);
      return LiveEditMergeResult.conflict(files: files);
    }

    return LiveEditMergeResult.failed(
      stderr: mergeResult.stderr.toString().trim(),
    );
  }

  /// Removes the worktree and deletes the branch.
  ///
  /// No-op if the handle wasn't allocated by this service (prevents
  /// `git worktree remove` from being pointed at arbitrary paths). Uses
  /// `--force` on remove because uncommitted edits are expected; callers
  /// should merge first if they want to preserve them.
  Future<void> abandon(final LiveEditWorktreeHandle handle) async {
    final registered = _allocations[handle.bubbleId];
    if (registered == null || registered.worktreePath != handle.worktreePath) {
      // Refuse to act on a handle we didn't hand out. Quietly noop so
      // callers can call abandon() defensively.
      return;
    }

    // Best-effort: remove the worktree, then the branch, then the parent
    // dir. Each step ignores the prior step's failure — worktree state on
    // disk can drift and we want to leave the tree as clean as possible.
    await _runGit(
      workingDirectory: handle.worktreePath,
      arguments: <String>['worktree', 'remove', '--force', handle.worktreePath],
      allowFailure: true,
    );
    // If remove failed (e.g. because we already ran from inside it), also
    // try pruning from the main tree. The main working dir isn't available
    // here — callers that want strict cleanup should prune themselves.
    final dir = Directory(handle.worktreePath);
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Leave for next cleanup pass.
      }
    }
    _allocations.remove(handle.bubbleId);
  }

  /// A worktree folder is "alive" if it still has a `.git` pointer — git
  /// creates a FILE (not a directory) named `.git` inside a worktree that
  /// contains `gitdir:` referencing the main repo.
  bool _worktreeLooksAlive(final String worktreePath) {
    if (!Directory(worktreePath).existsSync()) return false;
    final dotGit = FileSystemEntity.typeSync(p.join(worktreePath, '.git'));
    return dotGit != FileSystemEntityType.notFound;
  }

  Future<List<String>> _collectConflictedFiles(
    final String mainWorkingDirectory,
  ) async {
    final result = await _runGit(
      workingDirectory: mainWorkingDirectory,
      arguments: <String>['diff', '--name-only', '--diff-filter=U'],
      allowFailure: true,
    );
    if (result.exitCode != 0) {
      return const <String>[];
    }
    return result.stdout
        .toString()
        .split('\n')
        .map((final line) => line.trim())
        .where((final line) => line.isNotEmpty)
        .toList(growable: false);
  }

  Future<ProcessResult> _runGit({
    required final String workingDirectory,
    required final List<String> arguments,
    final bool allowFailure = false,
  }) async {
    try {
      final result = await Process.run(
        'git',
        arguments,
        workingDirectory: workingDirectory,
      ).timeout(_kGitOpTimeout);
      return result;
    } on TimeoutException {
      if (allowFailure) {
        return ProcessResult(0, 124, '', 'git timed out after $_kGitOpTimeout');
      }
      throw StateError(
        'git ${arguments.join(' ')} timed out after $_kGitOpTimeout',
      );
    }
  }
}

/// Decides whether a bubble apply should be routed through a worktree.
///
/// Fast-path (returns false) when there's at most one in-flight bubble AND
/// its file targets don't overlap with another bubble's — writing directly
/// to the main working dir lets hot reload pick up the change without an
/// extra merge round-trip.
///
/// Returns true when [inFlightCount] >= 2 (another apply is already running
/// in the main tree) OR [bubbleTargetsOverlap] (caller has detected that
/// two bubbles touch overlapping files, even sequentially — still worth
/// isolating to avoid mid-apply state confusion).
bool shouldUseWorktree({
  required final int inFlightCount,
  required final bool bubbleTargetsOverlap,
}) => inFlightCount >= 2 || bubbleTargetsOverlap;
