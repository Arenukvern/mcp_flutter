// ignore_for_file: public_member_api_docs, prefer_asserts_with_message

import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Severity level of an error.
enum ErrorSeverity { warning, error, fatal }

/// Represents a Flutter error event.
class FlutterErrorEvent with EquatableMixin {
  /// The type of the error.
  FlutterErrorEvent({
    required this.type,
    required this.message,
    this.stackTrace,
    final DateTime? timestamp,
    this.severity = ErrorSeverity.error,
  }) : timestamp = timestamp ?? DateTime.now();

  final String type;
  final String message;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final ErrorSeverity severity;

  Map<String, dynamic> toJson() => {
    'type': type,
    'message': message,
    'stackTrace': stackTrace?.toString(),
    'timestamp': timestamp.toIso8601String(),
    'severity': severity.name,
  };

  @override
  List<Object?> get props => [type, message, stackTrace, severity];
}

/// Default maximum number of errors to store in [ErrorMonitor]
const kDefaultMaxErrors = 10;

/// A mixin that provides error monitoring capabilities.
/// Can be used with any class to add error monitoring functionality.
mixin ErrorMonitor {
  int get maxErrors => _maxErrors;

  /// Maximum number of errors to store
  int _maxErrors = kDefaultMaxErrors;

  /// List of errors, recorded by [attachToFlutterError] and [handleZoneError]
  ///
  /// Add limitation with configurable latest [maxErrors] errors
  ///
  /// Set uses [LinkedHashSet] to store errors
  final errors = <FlutterErrorEvent>{};

  /// Initialize error monitoring
  void attachToFlutterError({final int maxErrors = kDefaultMaxErrors}) {
    _maxErrors = maxErrors;
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (final details) {
      originalOnError?.call(details);
      final error = FlutterErrorEvent(
        type: 'FlutterError',
        stackTrace: details.stack,
        message: details.toDiagnosticsNode().toStringDeep(
          minLevel: DiagnosticLevel.info,
        ),
      );
      _handleError(error);
    };
  }

  /// Handle uncaught error
  /// ```dart
  /// // Can be used with external error handling zones
  /// runZonedGuarded(
  ///   () => runApp(this),
  ///   (error, stack) {
  ///     // External error handling (e.g. Crashlytics)
  ///     FirebaseCrashlytics.instance.recordError(error, stack);
  ///     // Monitor errors in this app
  ///     MCPToolkit.instance.handleUncaughtError(error, stack);
  ///   },
  /// );
  /// ```
  void handleZoneError(final Object error, final StackTrace stack) {
    _handleError(
      FlutterErrorEvent(
        type: 'UncaughtException',
        message: error.toString(),
        stackTrace: stack,
        severity: ErrorSeverity.fatal,
      ),
    );
  }

  void _handleError(final FlutterErrorEvent event) {
    // TODO(arenukvern): add security for sensitive data
    errors.add(event);
    if (errors.isNotEmpty && errors.length > maxErrors) {
      errors.remove(errors.first);
    }
  }
}
