// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FlutterErrorEvent {

/// The JSON data associated with the error event.
@JsonKey(includeToJson: false) Map<String, dynamic> get json;/// The unique identifier for the error event.
 String get nodeId;/// The type of error (e.g., 'Flutter Error', 'VM Error').
 String get type;/// The error message.
 String get message;/// When the error occurred.
 DateTime get timestamp;/// Diagnostic information about the error.
@JsonKey(includeToJson: false) Instance? get diagnostics;/// The stack trace of the error, if available.
@JsonKey(includeToJson: false) StackTrace? get stackTrace;/// The severity level of the error.
 ErrorSeverity get severity;
/// Create a copy of FlutterErrorEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlutterErrorEventCopyWith<FlutterErrorEvent> get copyWith => _$FlutterErrorEventCopyWithImpl<FlutterErrorEvent>(this as FlutterErrorEvent, _$identity);

  /// Serializes this FlutterErrorEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FlutterErrorEvent&&super == other&&const DeepCollectionEquality().equals(other.json, json)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.type, type) || other.type == type)&&(identical(other.message, message) || other.message == message)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.diagnostics, diagnostics) || other.diagnostics == diagnostics)&&(identical(other.stackTrace, stackTrace) || other.stackTrace == stackTrace)&&(identical(other.severity, severity) || other.severity == severity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,super.hashCode,const DeepCollectionEquality().hash(json),nodeId,type,message,timestamp,diagnostics,stackTrace,severity);



}

/// @nodoc
abstract mixin class $FlutterErrorEventCopyWith<$Res>  {
  factory $FlutterErrorEventCopyWith(FlutterErrorEvent value, $Res Function(FlutterErrorEvent) _then) = _$FlutterErrorEventCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeToJson: false) Map<String, dynamic> json, String nodeId, String type, String message, DateTime timestamp,@JsonKey(includeToJson: false) Instance? diagnostics,@JsonKey(includeToJson: false) StackTrace? stackTrace, ErrorSeverity severity
});




}
/// @nodoc
class _$FlutterErrorEventCopyWithImpl<$Res>
    implements $FlutterErrorEventCopyWith<$Res> {
  _$FlutterErrorEventCopyWithImpl(this._self, this._then);

  final FlutterErrorEvent _self;
  final $Res Function(FlutterErrorEvent) _then;

/// Create a copy of FlutterErrorEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? json = null,Object? nodeId = null,Object? type = null,Object? message = null,Object? timestamp = null,Object? diagnostics = freezed,Object? stackTrace = freezed,Object? severity = null,}) {
  return _then(_self.copyWith(
json: null == json ? _self.json : json // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,diagnostics: freezed == diagnostics ? _self.diagnostics : diagnostics // ignore: cast_nullable_to_non_nullable
as Instance?,stackTrace: freezed == stackTrace ? _self.stackTrace : stackTrace // ignore: cast_nullable_to_non_nullable
as StackTrace?,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as ErrorSeverity,
  ));
}

}


/// @nodoc
@JsonSerializable(createFactory: false)

class _FlutterErrorEvent extends FlutterErrorEvent {
  const _FlutterErrorEvent({@JsonKey(includeToJson: false) required final  Map<String, dynamic> json, required this.nodeId, required this.type, required this.message, required this.timestamp, @JsonKey(includeToJson: false) this.diagnostics, @JsonKey(includeToJson: false) this.stackTrace, this.severity = ErrorSeverity.error}): _json = json,super._();
  

/// The JSON data associated with the error event.
 final  Map<String, dynamic> _json;
/// The JSON data associated with the error event.
@override@JsonKey(includeToJson: false) Map<String, dynamic> get json {
  if (_json is EqualUnmodifiableMapView) return _json;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_json);
}

/// The unique identifier for the error event.
@override final  String nodeId;
/// The type of error (e.g., 'Flutter Error', 'VM Error').
@override final  String type;
/// The error message.
@override final  String message;
/// When the error occurred.
@override final  DateTime timestamp;
/// Diagnostic information about the error.
@override@JsonKey(includeToJson: false) final  Instance? diagnostics;
/// The stack trace of the error, if available.
@override@JsonKey(includeToJson: false) final  StackTrace? stackTrace;
/// The severity level of the error.
@override@JsonKey() final  ErrorSeverity severity;

/// Create a copy of FlutterErrorEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlutterErrorEventCopyWith<_FlutterErrorEvent> get copyWith => __$FlutterErrorEventCopyWithImpl<_FlutterErrorEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FlutterErrorEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FlutterErrorEvent&&super == other&&const DeepCollectionEquality().equals(other._json, _json)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.type, type) || other.type == type)&&(identical(other.message, message) || other.message == message)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.diagnostics, diagnostics) || other.diagnostics == diagnostics)&&(identical(other.stackTrace, stackTrace) || other.stackTrace == stackTrace)&&(identical(other.severity, severity) || other.severity == severity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,super.hashCode,const DeepCollectionEquality().hash(_json),nodeId,type,message,timestamp,diagnostics,stackTrace,severity);



}

/// @nodoc
abstract mixin class _$FlutterErrorEventCopyWith<$Res> implements $FlutterErrorEventCopyWith<$Res> {
  factory _$FlutterErrorEventCopyWith(_FlutterErrorEvent value, $Res Function(_FlutterErrorEvent) _then) = __$FlutterErrorEventCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeToJson: false) Map<String, dynamic> json, String nodeId, String type, String message, DateTime timestamp,@JsonKey(includeToJson: false) Instance? diagnostics,@JsonKey(includeToJson: false) StackTrace? stackTrace, ErrorSeverity severity
});




}
/// @nodoc
class __$FlutterErrorEventCopyWithImpl<$Res>
    implements _$FlutterErrorEventCopyWith<$Res> {
  __$FlutterErrorEventCopyWithImpl(this._self, this._then);

  final _FlutterErrorEvent _self;
  final $Res Function(_FlutterErrorEvent) _then;

/// Create a copy of FlutterErrorEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? json = null,Object? nodeId = null,Object? type = null,Object? message = null,Object? timestamp = null,Object? diagnostics = freezed,Object? stackTrace = freezed,Object? severity = null,}) {
  return _then(_FlutterErrorEvent(
json: null == json ? _self._json : json // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,diagnostics: freezed == diagnostics ? _self.diagnostics : diagnostics // ignore: cast_nullable_to_non_nullable
as Instance?,stackTrace: freezed == stackTrace ? _self.stackTrace : stackTrace // ignore: cast_nullable_to_non_nullable
as StackTrace?,severity: null == severity ? _self.severity : severity // ignore: cast_nullable_to_non_nullable
as ErrorSeverity,
  ));
}


}

// dart format on
