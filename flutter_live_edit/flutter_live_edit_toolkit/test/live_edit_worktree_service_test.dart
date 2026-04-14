import 'dart:io';

import 'package:flutter_live_edit_toolkit/src/models/live_edit_models.dart';
import 'package:flutter_live_edit_toolkit/src/services/live_edit_worktree_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Checks whether a `git` binary is available on PATH. Tests are skipped
/// when absent so CI without git still passes.
bool _gitAvailable() {
  try {
    final result = Process.runSync('git', <String>['--version']);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Runs `git` in [cwd], asserting a zero exit code for setup helpers.
void _git(final String cwd, final List<String> args) {
  final r = Process.runSync('git', args, workingDirectory: cwd);
  if (r.exitCode != 0) {
    throw StateError(
      'git ${args.join(' ')} failed (exit ${r.exitCode}):\n'
      '${r.stderr}',
    );
  }
}

void main() {
  final gitAvailable = _gitAvailable();

  group('shouldUseWorktree', () {
    test('single in-flight bubble without overlap stays on main tree', () {
      expect(
        shouldUseWorktree(inFlightCount: 1, bubbleTargetsOverlap: false),
        isFalse,
      );
      expect(
        shouldUseWorktree(inFlightCount: 0, bubbleTargetsOverlap: false),
        isFalse,
      );
    });

    test('two or more in-flight bubbles route through worktree', () {
      expect(
        shouldUseWorktree(inFlightCount: 2, bubbleTargetsOverlap: false),
        isTrue,
      );
      expect(
        shouldUseWorktree(inFlightCount: 5, bubbleTargetsOverlap: false),
        isTrue,
      );
    });

    test('overlapping targets route through worktree even at count=1', () {
      expect(
        shouldUseWorktree(inFlightCount: 1, bubbleTargetsOverlap: true),
        isTrue,
      );
    });
  });

  group(
    'LiveEditWorktreeService',
    skip: gitAvailable ? null : 'git not available on PATH',
    () {
      late Directory tempRoot;
      late String mainRepo;
      late String worktreeRoot;
      late LiveEditWorktreeService service;

      setUp(() {
        tempRoot = Directory.systemTemp.createTempSync(
          'live_edit_worktree_test_',
        );
        mainRepo = p.join(tempRoot.path, 'main');
        worktreeRoot = p.join(tempRoot.path, 'worktrees');
        Directory(mainRepo).createSync(recursive: true);

        _git(mainRepo, <String>['init', '--initial-branch=main']);
        _git(mainRepo, <String>['config', 'user.email', 'test@test']);
        _git(mainRepo, <String>['config', 'user.name', 'Test']);
        _git(mainRepo, <String>['config', 'commit.gpgsign', 'false']);

        File(p.join(mainRepo, 'a.txt')).writeAsStringSync('seed\n');
        _git(mainRepo, <String>['add', '.']);
        _git(mainRepo, <String>['commit', '-m', 'seed']);

        File(p.join(mainRepo, 'b.txt')).writeAsStringSync('second\n');
        _git(mainRepo, <String>['add', '.']);
        _git(mainRepo, <String>['commit', '-m', 'second']);

        service = LiveEditWorktreeService(worktreeRoot: worktreeRoot);
      });

      tearDown(() {
        try {
          tempRoot.deleteSync(recursive: true);
        } on FileSystemException {
          // Ignore — worktree files can be stubborn on macOS.
        }
      });

      test('allocate creates a worktree at a stable branch', () async {
        final handle = await service.allocate(
          bubbleId: 'b1',
          mainWorkingDirectory: mainRepo,
        );
        expect(handle.bubbleId, 'b1');
        expect(handle.branch, 'live-edit/bubble-b1');
        expect(Directory(handle.worktreePath).existsSync(), isTrue);
        expect(File(p.join(handle.worktreePath, 'a.txt')).existsSync(), isTrue);
        expect(File(p.join(handle.worktreePath, 'b.txt')).existsSync(), isTrue);
      });

      test('allocate returns the same handle for the same bubble', () async {
        final first = await service.allocate(
          bubbleId: 'b1',
          mainWorkingDirectory: mainRepo,
        );
        final second = await service.allocate(
          bubbleId: 'b1',
          mainWorkingDirectory: mainRepo,
        );
        expect(identical(first, second) || first == second, isTrue);
        expect(first.worktreePath, second.worktreePath);
      });

      test(
        'mergeInto brings a worktree commit back into main tree cleanly',
        () async {
          final handle = await service.allocate(
            bubbleId: 'bubble-A',
            mainWorkingDirectory: mainRepo,
          );

          // Write + commit inside the worktree.
          File(
            p.join(handle.worktreePath, 'c.txt'),
          ).writeAsStringSync('from worktree\n');
          _git(handle.worktreePath, <String>['add', '.']);
          _git(handle.worktreePath, <String>[
            'commit',
            '-m',
            'add c.txt in worktree',
          ]);

          final result = await service.mergeInto(
            handle: handle,
            mainWorkingDirectory: mainRepo,
          );

          expect(result, isA<LiveEditMergeResultClean>());
          expect(File(p.join(mainRepo, 'c.txt')).existsSync(), isTrue);
          expect(
            File(p.join(mainRepo, 'c.txt')).readAsStringSync(),
            'from worktree\n',
          );
        },
      );

      test('mergeInto reports conflicting files on a merge conflict', () async {
        final handle = await service.allocate(
          bubbleId: 'bubble-conflict',
          mainWorkingDirectory: mainRepo,
        );

        // Divergent edits to the same file.
        File(
          p.join(handle.worktreePath, 'a.txt'),
        ).writeAsStringSync('from worktree side\n');
        _git(handle.worktreePath, <String>['commit', '-am', 'worktree edit']);

        File(p.join(mainRepo, 'a.txt')).writeAsStringSync('from main side\n');
        _git(mainRepo, <String>['commit', '-am', 'main edit']);

        final result = await service.mergeInto(
          handle: handle,
          mainWorkingDirectory: mainRepo,
        );

        expect(result, isA<LiveEditMergeResultConflict>());
        final conflict = result as LiveEditMergeResultConflict;
        expect(conflict.files, contains('a.txt'));

        // Clean up the left-over merge state so tearDown can delete the tree.
        Process.runSync('git', <String>[
          'merge',
          '--abort',
        ], workingDirectory: mainRepo);
      });

      test('abandon removes the worktree directory', () async {
        final handle = await service.allocate(
          bubbleId: 'bubble-abandon',
          mainWorkingDirectory: mainRepo,
        );
        expect(Directory(handle.worktreePath).existsSync(), isTrue);
        await service.abandon(handle);
        expect(Directory(handle.worktreePath).existsSync(), isFalse);
      });

      test('abandon refuses handles it did not allocate', () async {
        final fake = LiveEditWorktreeHandle(
          bubbleId: 'never-allocated',
          branch: 'live-edit/bubble-never-allocated',
          worktreePath: p.join(tempRoot.path, 'not-a-worktree'),
        );
        Directory(fake.worktreePath).createSync(recursive: true);
        await service.abandon(fake);
        // Should not have been touched.
        expect(Directory(fake.worktreePath).existsSync(), isTrue);
      });
    },
  );
}
