// ignore_for_file: invalid_annotation_target

import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vm_service/vm_service.dart';

part 'error_event.freezed.dart';
part 'error_event.g.dart';

/// Represents the severity level of an error.
enum ErrorSeverity {
  /// A warning that doesn't affect functionality but should be addressed.
  warning,

  /// An error that affects functionality but doesn't crash the app.
  error,

  /// A severe error that crashes or severely impacts the app.
  fatal,
}

/// Represents a Flutter error event with diagnostic information.
@Freezed(toJson: true)
abstract class FlutterErrorEvent with _$FlutterErrorEvent, EquatableMixin {
  /// Creates a new [FlutterErrorEvent] instance.
  const factory FlutterErrorEvent({
    /// The JSON data associated with the error event.
    @JsonKey(includeToJson: false) required final Map<String, dynamic> json,

    /// The unique identifier for the error event.
    required final String nodeId,

    /// The type of error (e.g., 'Flutter Error', 'VM Error').
    required final String type,

    /// The error message.
    required final String message,

    /// When the error occurred.
    required final DateTime timestamp,

    /// Diagnostic information about the error.
    @JsonKey(includeToJson: false) final Instance? diagnostics,

    /// The stack trace of the error, if available.
    @JsonKey(includeToJson: false) final StackTrace? stackTrace,

    /// The severity level of the error.
    @Default(ErrorSeverity.error) final ErrorSeverity severity,
  }) = _FlutterErrorEvent;
  const FlutterErrorEvent._();

  /// The ID of the RenderFlex widget that caused the error.
  String get renderFlexId {
    final renderedErrorText = json['renderedErrorText'];
    final idMatch = RegExp(
      'RenderFlex#([a-f0-9]+)',
    ).firstMatch(renderedErrorText ?? '');

    final id = idMatch?.group(1);

    return id ?? '';
  }

  String get renderedErrorText => json['renderedErrorText'] ?? '';

  @override
  @JsonKey(includeToJson: false)
  List<Object?> get props => [type, message, renderFlexId];

  @override
  @JsonKey(includeToJson: false)
  bool? get stringify => true;
}
