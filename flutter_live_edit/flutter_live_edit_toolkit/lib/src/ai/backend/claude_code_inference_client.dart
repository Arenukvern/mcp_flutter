import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xsoulspace_inference_core/xsoulspace_inference_core.dart';

/// Non-interactive wrapper around the Anthropic `claude` CLI (Claude Code),
/// shaped to match the `InferenceClient` contract used by
/// `LiveEditAgentRegistry`. Option-A backend: one-shot invocation, structured
/// JSON output validated against `request.outputSchema`.
///
/// Invocation shape:
///   claude -p
///     --output-format json
///     --json-schema '<schema json>'
///     --permission-mode acceptEdits
///     --add-dir <workingDirectory>
///     [--model <model>] [--effort <low|medium|high|max>]
/// The prompt is passed on stdin (mirrors the Codex client pattern so large
/// prompts don't run into ARG_MAX).
class ClaudeCodeInferenceClient
    implements InferenceClient, StructuredTextStreamingInferenceClient {
  ClaudeCodeInferenceClient({
    this.binaryName = 'claude',
    this.environment,
    this.permissionMode = 'acceptEdits',
    this.extraArgs = const <String>[],
    this.defaultModel,
    this.defaultReasoningEffort,
    this.executionTimeout = const Duration(minutes: 6),
    this.maxOutputBytes = 4 * 1024 * 1024,
    this.maxAttempts = 3,
    this.maxTimeoutRetries = 0,
    this.maxTransientRetries = 1,
    this.killGracePeriod = const Duration(milliseconds: 300),
    this.enableSessionPersistence = false,
  }) : assert(maxOutputBytes > 0),
       assert(maxAttempts > 0),
       assert(maxTimeoutRetries >= 0),
       assert(maxTransientRetries >= 0);

  final String binaryName;
  final Map<String, String>? environment;

  /// One of `acceptEdits`, `auto`, `bypassPermissions`, `default`, `dontAsk`,
  /// `plan`. Option-A default `acceptEdits` allows Claude to write files
  /// without prompting (non-interactive CLI can't prompt anyway).
  final String permissionMode;
  final List<String> extraArgs;

  /// Default model alias (`sonnet`, `opus`, `haiku`) or full id
  /// (e.g. `claude-sonnet-4-6`).
  final String? defaultModel;

  /// Default effort: `low`, `medium`, `high`, `max`.
  final String? defaultReasoningEffort;
  final Duration executionTimeout;
  final int maxOutputBytes;
  final int maxAttempts;
  final int maxTimeoutRetries;
  final int maxTransientRetries;
  final Duration killGracePeriod;

  /// When `false` (Option-A default) each invocation passes
  /// `--no-session-persistence` so Claude Code doesn't write a session file
  /// per run. Option B flips this on and threads `--session-id`/`--resume`
  /// so bubbles become stateful conversations.
  final bool enableSessionPersistence;

  @override
  String get id => 'claude_code';

  @override
  bool get isAvailable => _resolveBinaryPath() != null;

  @override
  Set<InferenceTask> get supportedTasks => const <InferenceTask>{
    InferenceTask.structuredText,
  };

  @override
  Future<bool> refreshAvailability() async => isAvailable;

  @override
  void resetAvailabilityCache() {
    // No availability cache for claude binary resolution.
  }

  @override
  Future<InferenceResult<InferenceResponse>> infer(
    final InferenceRequest request,
  ) => _runInference(request);

  @override
  Future<InferenceStructuredTextStreamSession> streamStructuredText(
    final InferenceRequest request,
  ) async {
    final session = _ClaudeCodeStructuredTextStreamSession();
    session.start(
      () => _runInference(
        request,
        onEvent: session.emit,
        executionControl: session.executionControl,
      ),
    );
    return session;
  }

  Future<InferenceResult<InferenceResponse>> _runInference(
    final InferenceRequest request, {
    final void Function(InferenceStructuredTextStreamEvent event)? onEvent,
    final _ClaudeExecutionControl? executionControl,
  }) async {
    final preflightFailure = _validateRequest(request);
    if (preflightFailure != null) {
      _emitFailure(
        onEvent,
        preflightFailure,
        attempt: 1,
        lifecycleState: InferenceStructuredTextLifecycleState.failed,
      );
      return preflightFailure;
    }

    final binaryPath = _resolveBinaryPath()!;
    _emitLifecycle(
      onEvent,
      InferenceStructuredTextLifecycleState.started,
      message: 'Starting claude exec.',
      attempt: 1,
      metadata: <String, dynamic>{'binary_path': binaryPath},
    );

    final warnings = <String>[];
    final attempts = <_ClaudeRunResult>[];
    var timeoutRetriesLeft = maxTimeoutRetries;
    var transientRetriesLeft = maxTransientRetries;

    while (attempts.length < maxAttempts) {
      final attemptIndex = attempts.length + 1;
      if (executionControl?.canceled == true) {
        final canceledResult = InferenceResult<InferenceResponse>.fail(
          code: 'claude_code_cancelled',
          message: 'claude exec stream was cancelled',
          meta: <String, dynamic>{'attempt_count': attempts.length},
        );
        _emitFailure(
          onEvent,
          canceledResult,
          attempt: attemptIndex,
          lifecycleState: InferenceStructuredTextLifecycleState.failed,
        );
        return canceledResult;
      }

      _emitLifecycle(
        onEvent,
        InferenceStructuredTextLifecycleState.running,
        message: 'Running claude exec.',
        attempt: attemptIndex,
      );

      final result = await _runExec(
        binaryPath: binaryPath,
        request: request,
        attempt: attemptIndex,
        onEvent: onEvent,
        executionControl: executionControl,
      );
      attempts.add(result);

      if (result.exitCode == 0 && !result.timedOut) {
        break;
      }

      if (result.timedOut && timeoutRetriesLeft > 0) {
        timeoutRetriesLeft--;
        const warning = 'Retrying claude exec after timeout.';
        warnings.add(warning);
        _emitWarning(
          onEvent,
          warning,
          attempt: attemptIndex,
          isTransient: true,
        );
        _emitLifecycle(
          onEvent,
          InferenceStructuredTextLifecycleState.retrying,
          message: warning,
          attempt: attemptIndex + 1,
        );
        continue;
      }

      if (_isTransientFailure(result) && transientRetriesLeft > 0) {
        transientRetriesLeft--;
        const warning = 'Retrying claude exec after transient failure.';
        warnings.add(warning);
        _emitWarning(
          onEvent,
          warning,
          attempt: attemptIndex,
          isTransient: true,
        );
        _emitLifecycle(
          onEvent,
          InferenceStructuredTextLifecycleState.retrying,
          message: warning,
          attempt: attemptIndex + 1,
        );
        continue;
      }

      break;
    }

    if (attempts.isEmpty) {
      final result = InferenceResult<InferenceResponse>.fail(
        code: 'claude_code_failed',
        message: 'claude exec was not attempted',
      );
      _emitFailure(
        onEvent,
        result,
        attempt: 1,
        lifecycleState: InferenceStructuredTextLifecycleState.failed,
      );
      return result;
    }

    final runResult = attempts.last;
    if (runResult.exitCode != 0) {
      final result = _buildExecFailureResult(
        result: runResult,
        attempts: attempts,
        warnings: warnings,
      );
      _emitFailure(
        onEvent,
        result,
        attempt: attempts.length,
        lifecycleState: runResult.timedOut
            ? InferenceStructuredTextLifecycleState.timedOut
            : InferenceStructuredTextLifecycleState.failed,
      );
      return result;
    }

    final stdoutBytes = utf8.encode(runResult.stdout).length;
    if (stdoutBytes > maxOutputBytes) {
      final result = InferenceResult<InferenceResponse>.fail(
        code: 'claude_code_output_too_large',
        message: 'claude exec stdout exceeded maxOutputBytes limit',
        details: <String, dynamic>{
          'output_bytes': stdoutBytes,
          'max_output_bytes': maxOutputBytes,
        },
        warnings: warnings,
        meta: <String, dynamic>{'attempt_count': attempts.length},
      );
      _emitFailure(
        onEvent,
        result,
        attempt: attempts.length,
        lifecycleState: InferenceStructuredTextLifecycleState.failed,
      );
      return result;
    }

    final envelopeParse = parseStrictJsonObject(runResult.stdout);
    if (!envelopeParse.success || envelopeParse.data == null) {
      final result = InferenceResult<InferenceResponse>.fail(
        code: envelopeParse.error?.code ?? 'claude_code_envelope_parse_failed',
        message:
            envelopeParse.error?.message ??
            'Failed to parse claude exec JSON envelope',
        details: envelopeParse.error?.details ?? _truncate(runResult.stdout),
        warnings: warnings,
        meta: <String, dynamic>{'attempt_count': attempts.length},
      );
      _emitFailure(
        onEvent,
        result,
        attempt: attempts.length,
        lifecycleState: InferenceStructuredTextLifecycleState.failed,
      );
      return result;
    }

    final envelope = envelopeParse.data!;
    final rawResult = envelope['result'];
    if (rawResult is! String || rawResult.trim().isEmpty) {
      final result = InferenceResult<InferenceResponse>.fail(
        code: 'claude_code_result_missing',
        message: 'claude exec JSON envelope missing string "result" field',
        details: <String, dynamic>{
          'envelope_keys': envelope.keys.toList(),
          if (envelope['subtype'] != null) 'subtype': envelope['subtype'],
          if (envelope['is_error'] != null) 'is_error': envelope['is_error'],
        },
        warnings: warnings,
        meta: <String, dynamic>{'attempt_count': attempts.length},
      );
      _emitFailure(
        onEvent,
        result,
        attempt: attempts.length,
        lifecycleState: InferenceStructuredTextLifecycleState.failed,
      );
      return result;
    }

    final parsed = parseStrictJsonObject(rawResult);
    if (!parsed.success || parsed.data == null) {
      final result = InferenceResult<InferenceResponse>.fail(
        code: parsed.error?.code ?? 'claude_code_parse_failed',
        message:
            parsed.error?.message ??
            'Failed to parse structured output from claude',
        details: parsed.error?.details ?? _truncate(rawResult),
        warnings: warnings,
        meta: <String, dynamic>{'attempt_count': attempts.length},
      );
      _emitFailure(
        onEvent,
        result,
        attempt: attempts.length,
        lifecycleState: InferenceStructuredTextLifecycleState.failed,
      );
      return result;
    }

    final schemaValidation = validateJsonAgainstSchema(
      value: parsed.data,
      schema: request.outputSchema,
    );
    if (!schemaValidation.success) {
      final result = InferenceResult<InferenceResponse>.fail(
        code: schemaValidation.error?.code ?? 'schema_validation_failed',
        message:
            schemaValidation.error?.message ??
            'Inference output does not match schema',
        details: schemaValidation.error?.details,
        warnings: warnings,
        meta: <String, dynamic>{'attempt_count': attempts.length},
      );
      _emitFailure(
        onEvent,
        result,
        attempt: attempts.length,
        lifecycleState: InferenceStructuredTextLifecycleState.failed,
      );
      return result;
    }

    final model = _resolveModel(request);
    final reasoningEffort = _resolveReasoningEffort(request);
    final meta = <String, dynamic>{
      'provider': id,
      'binary_path': binaryPath,
      'attempt_count': attempts.length,
      'execution_timeout_ms': executionTimeout.inMilliseconds,
      'permission_mode': _resolvePermissionMode(request) ?? permissionMode,
      'attempts': attempts.map((final run) => run.toSummary()).toList(),
      if (_hasText(model)) 'model': model,
      if (_hasText(reasoningEffort)) 'reasoning_effort': reasoningEffort,
      if (envelope['session_id'] is String)
        'claude_session_id': envelope['session_id'],
      if (envelope['total_cost_usd'] is num)
        'claude_total_cost_usd': envelope['total_cost_usd'],
      if (envelope['num_turns'] is num)
        'claude_num_turns': envelope['num_turns'],
      if (envelope['duration_ms'] is num)
        'claude_duration_ms': envelope['duration_ms'],
    };
    if (request.metadata.isNotEmpty) {
      meta['request_metadata'] = request.metadata;
    }

    final result = InferenceResult<InferenceResponse>.ok(
      InferenceResponse(
        output: parsed.data!,
        rawOutput: rawResult,
        warnings: warnings,
        meta: meta,
      ),
      warnings: warnings,
      meta: meta,
    );
    _emitLifecycle(
      onEvent,
      InferenceStructuredTextLifecycleState.completed,
      message: 'claude exec completed successfully.',
      attempt: attempts.length,
    );
    _emitCompletion(onEvent, result, attempt: attempts.length);
    return result;
  }

  InferenceResult<InferenceResponse>? _validateRequest(
    final InferenceRequest request,
  ) {
    if (!supportedTasks.contains(request.task)) {
      return InferenceResult<InferenceResponse>.fail(
        code: errorCodeTaskUnsupported,
        message: 'Task ${request.task.name} is not supported by $id',
        details: <String, dynamic>{
          'supported_tasks': supportedTasks
              .map((final task) => task.name)
              .toList(),
          'requested_task': request.task.name,
        },
      );
    }

    final requestValidation = validateInferenceRequest(request);
    if (!requestValidation.success) {
      return InferenceResult<InferenceResponse>.fail(
        code: requestValidation.error?.code ?? 'request_invalid',
        message:
            requestValidation.error?.message ??
            'Inference request validation failed',
        details: requestValidation.error?.details,
      );
    }

    final workingDirectory = Directory(request.workingDirectory);
    if (!workingDirectory.existsSync()) {
      return InferenceResult<InferenceResponse>.fail(
        code: 'working_directory_not_found',
        message: 'Inference working directory does not exist',
        details: request.workingDirectory,
      );
    }

    if (_resolveBinaryPath() == null) {
      return InferenceResult<InferenceResponse>.fail(
        code: 'engine_unavailable',
        message: 'claude binary not found in PATH',
      );
    }
    return null;
  }

  Future<_ClaudeRunResult> _runExec({
    required final String binaryPath,
    required final InferenceRequest request,
    required final int attempt,
    final void Function(InferenceStructuredTextStreamEvent event)? onEvent,
    final _ClaudeExecutionControl? executionControl,
  }) async {
    final model = _resolveModel(request);
    final reasoningEffort = _resolveReasoningEffort(request);
    final schemaJson = jsonEncode(request.outputSchema);

    final mcpConfigPath = _metadataString(request, 'claudeMcpConfigPath');
    final newSessionId = _metadataString(request, 'claudeSessionId');
    final resumeSessionId = _metadataString(request, 'claudeResumeSessionId');
    if (newSessionId != null && resumeSessionId != null) {
      throw ArgumentError(
        'claudeSessionId and claudeResumeSessionId are mutually exclusive.',
      );
    }
    if (newSessionId != null && !_isValidUuidV4(newSessionId)) {
      throw ArgumentError(
        'claudeSessionId must be a v4 UUID string, got "$newSessionId".',
      );
    }
    if (resumeSessionId != null && !_isValidUuidV4(resumeSessionId)) {
      throw ArgumentError(
        'claudeResumeSessionId must be a v4 UUID string, '
        'got "$resumeSessionId".',
      );
    }
    final permissionOverride = _resolvePermissionMode(request);
    final effectivePermissionMode = permissionOverride ?? permissionMode;
    final sessionPersistence =
        enableSessionPersistence ||
        mcpConfigPath != null ||
        newSessionId != null ||
        resumeSessionId != null;

    final args = <String>[
      '-p',
      if (!sessionPersistence) '--no-session-persistence',
      '--output-format',
      'json',
      '--json-schema',
      schemaJson,
      '--permission-mode',
      effectivePermissionMode,
      '--add-dir',
      request.workingDirectory,
      if (mcpConfigPath != null) ...<String>[
        '--mcp-config',
        mcpConfigPath,
        '--strict-mcp-config',
      ],
      if (newSessionId != null) ...<String>['--session-id', newSessionId],
      if (resumeSessionId != null) ...<String>['--resume', resumeSessionId],
      if (_hasText(model)) ...<String>['--model', model!],
      if (_hasText(reasoningEffort)) ...<String>['--effort', reasoningEffort!],
      ...extraArgs,
    ];

    final startedAt = DateTime.now();
    final process = await Process.start(
      binaryPath,
      args,
      workingDirectory: request.workingDirectory,
      environment: environment,
    );
    executionControl?.attach(process);

    unawaited(() async {
      try {
        process.stdin.write(request.prompt);
        await process.stdin.flush();
      } on SocketException {
        // The child process can exit before consuming stdin.
      } finally {
        try {
          await process.stdin.close();
        } on SocketException {
          // best-effort close
        }
      }
    }());

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    late final StreamSubscription<String> stdoutSub;
    late final StreamSubscription<String> stderrSub;

    void handleChunk(
      final InferenceStructuredTextRawChannel channel,
      final String chunk,
    ) {
      if (chunk.isEmpty) return;
      if (channel == InferenceStructuredTextRawChannel.stdout) {
        stdoutBuffer.write(chunk);
      } else {
        stderrBuffer.write(chunk);
      }
      _emitRaw(onEvent, channel, chunk, attempt: attempt);
      final trimmed = chunk.trim();
      if (trimmed.isNotEmpty) {
        if (channel == InferenceStructuredTextRawChannel.stdout) {
          _emitPartialOutput(onEvent, trimmed, attempt: attempt);
        } else {
          _emitProgress(
            onEvent,
            trimmed,
            attempt: attempt,
            metadata: const <String, dynamic>{'source': 'stderr'},
          );
        }
      }
    }

    stdoutSub = process.stdout
        .transform(utf8.decoder)
        .listen(
          (final chunk) =>
              handleChunk(InferenceStructuredTextRawChannel.stdout, chunk),
          onDone: stdoutDone.complete,
          onError: (final Object error, final StackTrace stackTrace) {
            stdoutBuffer.write('$error');
            if (!stdoutDone.isCompleted) stdoutDone.complete();
          },
          cancelOnError: false,
        );
    stderrSub = process.stderr
        .transform(utf8.decoder)
        .listen(
          (final chunk) =>
              handleChunk(InferenceStructuredTextRawChannel.stderr, chunk),
          onDone: stderrDone.complete,
          onError: (final Object error, final StackTrace stackTrace) {
            stderrBuffer.write('$error');
            if (!stderrDone.isCompleted) stderrDone.complete();
          },
          cancelOnError: false,
        );

    try {
      final exitCode = await process.exitCode.timeout(executionTimeout);
      await Future.wait(<Future<void>>[stdoutDone.future, stderrDone.future]);
      await stdoutSub.cancel();
      await stderrSub.cancel();
      return _ClaudeRunResult(
        exitCode: exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
        duration: DateTime.now().difference(startedAt),
      );
    } on TimeoutException {
      _emitLifecycle(
        onEvent,
        InferenceStructuredTextLifecycleState.timedOut,
        message: 'claude exec timed out.',
        attempt: attempt,
      );
      await executionControl?.cancel();
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 1),
        onTimeout: () => -1,
      );
      await Future.wait(<Future<void>>[
        stdoutDone.future.timeout(const Duration(seconds: 1), onTimeout: () {}),
        stderrDone.future.timeout(const Duration(seconds: 1), onTimeout: () {}),
      ]);
      await stdoutSub.cancel();
      await stderrSub.cancel();
      return _ClaudeRunResult(
        exitCode: exitCode == 0 ? -1 : exitCode,
        stdout: stdoutBuffer.toString(),
        stderr: stderrBuffer.toString(),
        duration: DateTime.now().difference(startedAt),
        timedOut: true,
      );
    } finally {
      executionControl?.detach(process);
    }
  }

  InferenceResult<InferenceResponse> _buildExecFailureResult({
    required final _ClaudeRunResult result,
    required final List<_ClaudeRunResult> attempts,
    required final List<String> warnings,
  }) {
    final authFailure = _isAuthFailure(result);
    final code = result.timedOut
        ? 'claude_code_timeout'
        : authFailure
        ? 'claude_code_auth_failed'
        : 'claude_code_failed';
    final message = result.timedOut
        ? 'claude exec timed out after ${executionTimeout.inMilliseconds}ms'
        : authFailure
        ? 'claude exec authentication failed; run `claude auth` or set ANTHROPIC_API_KEY'
        : 'claude exec failed with exit code ${result.exitCode}';
    return InferenceResult<InferenceResponse>.fail(
      code: code,
      message: message,
      details: _buildFailureDetails(
        result: result,
        attempts: attempts,
        authFailure: authFailure,
      ),
      warnings: warnings,
      meta: <String, dynamic>{'attempt_count': attempts.length},
    );
  }

  String? _resolveModel(final InferenceRequest request) {
    final metadataValue =
        request.metadata['inferenceModel'] ??
        request.metadata['claudeCodeModel'];
    final normalized = _normalizeConfigValue(
      metadataValue == null ? null : '$metadataValue',
    );
    return normalized ?? _normalizeConfigValue(defaultModel);
  }

  String? _resolveReasoningEffort(final InferenceRequest request) {
    final metadataValue =
        request.metadata['inferenceReasoningEffort'] ??
        request.metadata['claudeCodeEffort'];
    final normalized = _normalizeReasoningEffort(
      metadataValue == null ? null : '$metadataValue',
    );
    return normalized ?? _normalizeReasoningEffort(defaultReasoningEffort);
  }

  bool _hasText(final String? value) =>
      value != null && value.trim().isNotEmpty;

  String? _normalizeConfigValue(final String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String? _normalizeReasoningEffort(final String? value) {
    final trimmed = _normalizeConfigValue(value)?.toLowerCase();
    return switch (trimmed) {
      null => null,
      'middle' => 'medium',
      _ => trimmed,
    };
  }

  static const Set<String> _validPermissionModes = <String>{
    'acceptEdits',
    'plan',
    'bypassPermissions',
    'default',
    'dontAsk',
    'auto',
  };

  static final RegExp _uuidV4Pattern = RegExp(
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-'
    r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  bool _isValidUuidV4(final String value) => _uuidV4Pattern.hasMatch(value);

  String? _metadataString(final InferenceRequest request, final String key) {
    final raw = request.metadata[key];
    if (raw == null) return null;
    final value = '$raw'.trim();
    return value.isEmpty ? null : value;
  }

  String? _resolvePermissionMode(final InferenceRequest request) {
    final override = _metadataString(request, 'claudePermissionMode');
    if (override == null) return null;
    if (!_validPermissionModes.contains(override)) {
      throw ArgumentError(
        'Invalid claudePermissionMode "$override"; '
        'expected one of ${_validPermissionModes.toList()..sort()}.',
      );
    }
    return override;
  }

  bool _isTransientFailure(final _ClaudeRunResult result) {
    if (result.timedOut) return true;
    final normalized = '${result.stderr}\n${result.stdout}'.toLowerCase();
    return normalized.contains('temporary failure') ||
        normalized.contains('temporarily unavailable') ||
        normalized.contains('connection reset') ||
        normalized.contains('network is unreachable') ||
        normalized.contains('rate limit') ||
        normalized.contains('overloaded') ||
        normalized.contains('resource busy');
  }

  bool _isAuthFailure(final _ClaudeRunResult result) {
    final normalized = '${result.stderr}\n${result.stdout}'.toLowerCase();
    return normalized.contains('401 unauthorized') ||
        normalized.contains('status: 401') ||
        normalized.contains('status 401') ||
        normalized.contains('invalid_api_key') ||
        normalized.contains('invalid api key') ||
        normalized.contains('authentication failed') ||
        normalized.contains('not authenticated') ||
        normalized.contains('not logged in') ||
        normalized.contains('no credentials');
  }

  Map<String, dynamic> _buildFailureDetails({
    required final _ClaudeRunResult result,
    required final List<_ClaudeRunResult> attempts,
    required final bool authFailure,
  }) {
    final stderr = result.stderr.trim();
    final stdout = result.stdout.trim();
    return <String, dynamic>{
      'timed_out': result.timedOut,
      'exit_code': result.exitCode,
      'auth_failure': authFailure,
      if (stderr.isNotEmpty) 'stderr': _truncate(stderr),
      if (stdout.isNotEmpty) 'stdout': _truncate(stdout),
      if (authFailure)
        'remediation': const <String>[
          'Run `claude auth login` or `claude setup-token`.',
          'Or set ANTHROPIC_API_KEY before running inference.',
        ],
      'attempts': attempts.map((final run) => run.toSummary()).toList(),
    };
  }

  String _truncate(final String value, {final int max = 2000}) {
    if (value.length <= max) return value;
    final headLength = max ~/ 2;
    final tailLength = max - headLength;
    final head = value.substring(0, headLength);
    final tail = value.substring(value.length - tailLength);
    return '$head...[truncated ${value.length - max} chars]...$tail';
  }

  String? _resolveBinaryPath() {
    if (binaryName.contains(Platform.pathSeparator)) {
      return File(binaryName).existsSync() ? binaryName : null;
    }
    final activeEnvironment = environment ?? Platform.environment;
    final pathEnv = activeEnvironment['PATH'];
    if (pathEnv == null || pathEnv.isEmpty) return null;

    final pathSegments = pathEnv
        .split(Platform.isWindows ? ';' : ':')
        .where((final segment) => segment.isNotEmpty);
    for (final segment in pathSegments) {
      final candidate = p.join(segment, binaryName);
      final file = File(candidate);
      if (file.existsSync()) return file.path;
      if (Platform.isWindows) {
        for (final suffix in const <String>['.exe', '.cmd']) {
          final withSuffix = File('$candidate$suffix');
          if (withSuffix.existsSync()) return withSuffix.path;
        }
      }
    }
    return null;
  }

  // --- Event emitters (parity with Codex client shape) -----------------------

  void _emitLifecycle(
    final void Function(InferenceStructuredTextStreamEvent event)? onEvent,
    final InferenceStructuredTextLifecycleState state, {
    required final String message,
    required final int attempt,
    final Map<String, dynamic> metadata = const <String, dynamic>{},
  }) => _emitEvent(
    onEvent,
    InferenceStructuredTextStreamEvent(
      type: InferenceStructuredTextStreamEventType.lifecycle,
      timestamp: DateTime.now().toUtc(),
      lifecycleState: state,
      message: message,
      attempt: attempt,
      metadata: metadata,
    ),
  );

  void _emitProgress(
    final void Function(InferenceStructuredTextStreamEvent event)? onEvent,
    final String message, {
    required final int attempt,
    final Map<String, dynamic> metadata = const <String, dynamic>{},
  }) => _emitEvent(
    onEvent,
    InferenceStructuredTextStreamEvent(
      type: InferenceStructuredTextStreamEventType.progress,
      timestamp: DateTime.now().toUtc(),
      message: message,
      attempt: attempt,
      metadata: metadata,
    ),
  );

  void _emitPartialOutput(
    final void Function(InferenceStructuredTextStreamEvent event)? onEvent,
    final String textDelta, {
    required final int attempt,
  }) => _emitEvent(
    onEvent,
    InferenceStructuredTextStreamEvent(
      type: InferenceStructuredTextStreamEventType.partialOutput,
      timestamp: DateTime.now().toUtc(),
      textDelta: textDelta,
      attempt: attempt,
    ),
  );

  void _emitRaw(
    final void Function(InferenceStructuredTextStreamEvent event)? onEvent,
    final InferenceStructuredTextRawChannel channel,
    final String rawText, {
    required final int attempt,
  }) => _emitEvent(
    onEvent,
    InferenceStructuredTextStreamEvent(
      type: InferenceStructuredTextStreamEventType.raw,
      timestamp: DateTime.now().toUtc(),
      rawChannel: channel,
      rawText: rawText,
      attempt: attempt,
    ),
  );

  void _emitWarning(
    final void Function(InferenceStructuredTextStreamEvent event)? onEvent,
    final String message, {
    required final int attempt,
    final bool isTransient = false,
  }) => _emitEvent(
    onEvent,
    InferenceStructuredTextStreamEvent(
      type: InferenceStructuredTextStreamEventType.warning,
      timestamp: DateTime.now().toUtc(),
      message: message,
      attempt: attempt,
      isTransient: isTransient,
    ),
  );

  void _emitFailure(
    final void Function(InferenceStructuredTextStreamEvent event)? onEvent,
    final InferenceResult<InferenceResponse> result, {
    required final int attempt,
    required final InferenceStructuredTextLifecycleState lifecycleState,
  }) {
    _emitLifecycle(
      onEvent,
      lifecycleState,
      message: result.error?.message ?? 'claude exec failed.',
      attempt: attempt,
    );
    _emitEvent(
      onEvent,
      InferenceStructuredTextStreamEvent(
        type: InferenceStructuredTextStreamEventType.error,
        timestamp: DateTime.now().toUtc(),
        message: result.error?.message,
        attempt: attempt,
        error: result.error,
        metadata: result.meta,
      ),
    );
    _emitCompletion(onEvent, result, attempt: attempt);
  }

  void _emitCompletion(
    final void Function(InferenceStructuredTextStreamEvent event)? onEvent,
    final InferenceResult<InferenceResponse> result, {
    required final int attempt,
  }) => _emitEvent(
    onEvent,
    InferenceStructuredTextStreamEvent(
      type: InferenceStructuredTextStreamEventType.completion,
      timestamp: DateTime.now().toUtc(),
      attempt: attempt,
      completion: InferenceStructuredTextCompletion(
        result: result,
        attemptCount: (result.meta['attempt_count'] as num?)?.toInt(),
      ),
      metadata: result.meta,
    ),
  );

  void _emitEvent(
    final void Function(InferenceStructuredTextStreamEvent event)? onEvent,
    final InferenceStructuredTextStreamEvent event,
  ) {
    if (onEvent == null) return;
    onEvent(event);
  }
}

final class _ClaudeExecutionControl {
  Process? _process;
  bool _canceled = false;

  bool get canceled => _canceled;

  void attach(final Process process) {
    _process = process;
    if (_canceled) _kill(process);
  }

  void detach(final Process process) {
    if (identical(_process, process)) _process = null;
  }

  Future<void> cancel() async {
    _canceled = true;
    final process = _process;
    if (process == null) return;
    _kill(process);
  }

  void _kill(final Process process) {
    process.kill();
    try {
      process.kill(ProcessSignal.sigkill);
    } catch (_) {
      // best-effort forced termination
    }
  }
}

final class _ClaudeCodeStructuredTextStreamSession
    implements InferenceStructuredTextStreamSession {
  final StreamController<InferenceStructuredTextStreamEvent> _controller =
      StreamController<InferenceStructuredTextStreamEvent>.broadcast(
        sync: true,
      );
  final Completer<InferenceResult<InferenceResponse>> _resultCompleter =
      Completer<InferenceResult<InferenceResponse>>();
  final _ClaudeExecutionControl executionControl = _ClaudeExecutionControl();
  bool _disposed = false;

  @override
  Stream<InferenceStructuredTextStreamEvent> get events => _controller.stream;

  @override
  Future<InferenceResult<InferenceResponse>> get result =>
      _resultCompleter.future;

  void emit(final InferenceStructuredTextStreamEvent event) {
    if (_disposed || _controller.isClosed) return;
    _controller.add(event);
  }

  void start(final Future<InferenceResult<InferenceResponse>> Function() run) {
    unawaited(() async {
      try {
        final resolved = await run();
        if (!_resultCompleter.isCompleted) _resultCompleter.complete(resolved);
      } catch (error) {
        if (!_resultCompleter.isCompleted) {
          _resultCompleter.complete(
            InferenceResult<InferenceResponse>.fail(
              code: 'claude_code_failed',
              message: 'Failed to execute claude',
              details: '$error',
            ),
          );
        }
      } finally {
        await dispose();
      }
    }());
  }

  @override
  Future<void> cancel() => executionControl.cancel();

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (!_resultCompleter.isCompleted) {
      _resultCompleter.complete(
        InferenceResult<InferenceResponse>.fail(
          code: 'claude_code_cancelled',
          message: 'claude exec stream was cancelled',
        ),
      );
    }
    await _controller.close();
  }
}

final class _ClaudeRunResult {
  const _ClaudeRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    this.timedOut = false,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final bool timedOut;

  Map<String, dynamic> toSummary() => <String, dynamic>{
    'exit_code': exitCode,
    'timed_out': timedOut,
    'duration_ms': duration.inMilliseconds,
  };
}
