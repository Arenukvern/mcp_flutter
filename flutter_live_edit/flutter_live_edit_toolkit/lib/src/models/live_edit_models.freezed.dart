// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_edit_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveEditAgentBackend {

 String get id; String get label; String get description; bool get available; bool get isDefault; Map<String, Object?> get meta;
/// Create a copy of LiveEditAgentBackend
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditAgentBackendCopyWith<LiveEditAgentBackend> get copyWith => _$LiveEditAgentBackendCopyWithImpl<LiveEditAgentBackend>(this as LiveEditAgentBackend, _$identity);

  /// Serializes this LiveEditAgentBackend to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditAgentBackend&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description)&&(identical(other.available, available) || other.available == available)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&const DeepCollectionEquality().equals(other.meta, meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,description,available,isDefault,const DeepCollectionEquality().hash(meta));

@override
String toString() {
  return 'LiveEditAgentBackend(id: $id, label: $label, description: $description, available: $available, isDefault: $isDefault, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $LiveEditAgentBackendCopyWith<$Res>  {
  factory $LiveEditAgentBackendCopyWith(LiveEditAgentBackend value, $Res Function(LiveEditAgentBackend) _then) = _$LiveEditAgentBackendCopyWithImpl;
@useResult
$Res call({
 String id, String label, String description, bool available, bool isDefault, Map<String, Object?> meta
});




}
/// @nodoc
class _$LiveEditAgentBackendCopyWithImpl<$Res>
    implements $LiveEditAgentBackendCopyWith<$Res> {
  _$LiveEditAgentBackendCopyWithImpl(this._self, this._then);

  final LiveEditAgentBackend _self;
  final $Res Function(LiveEditAgentBackend) _then;

/// Create a copy of LiveEditAgentBackend
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? description = null,Object? available = null,Object? isDefault = null,Object? meta = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveEditAgentBackend].
extension LiveEditAgentBackendPatterns on LiveEditAgentBackend {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditAgentBackend value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditAgentBackend() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditAgentBackend value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditAgentBackend():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditAgentBackend value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditAgentBackend() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  String description,  bool available,  bool isDefault,  Map<String, Object?> meta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditAgentBackend() when $default != null:
return $default(_that.id,_that.label,_that.description,_that.available,_that.isDefault,_that.meta);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  String description,  bool available,  bool isDefault,  Map<String, Object?> meta)  $default,) {final _that = this;
switch (_that) {
case _LiveEditAgentBackend():
return $default(_that.id,_that.label,_that.description,_that.available,_that.isDefault,_that.meta);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  String description,  bool available,  bool isDefault,  Map<String, Object?> meta)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditAgentBackend() when $default != null:
return $default(_that.id,_that.label,_that.description,_that.available,_that.isDefault,_that.meta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEditAgentBackend implements LiveEditAgentBackend {
  const _LiveEditAgentBackend({required this.id, required this.label, required this.description, required this.available, this.isDefault = false, final  Map<String, Object?> meta = const <String, Object?>{}}): _meta = meta;
  factory _LiveEditAgentBackend.fromJson(Map<String, dynamic> json) => _$LiveEditAgentBackendFromJson(json);

@override final  String id;
@override final  String label;
@override final  String description;
@override final  bool available;
@override@JsonKey() final  bool isDefault;
 final  Map<String, Object?> _meta;
@override@JsonKey() Map<String, Object?> get meta {
  if (_meta is EqualUnmodifiableMapView) return _meta;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_meta);
}


/// Create a copy of LiveEditAgentBackend
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditAgentBackendCopyWith<_LiveEditAgentBackend> get copyWith => __$LiveEditAgentBackendCopyWithImpl<_LiveEditAgentBackend>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEditAgentBackendToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditAgentBackend&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.description, description) || other.description == description)&&(identical(other.available, available) || other.available == available)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&const DeepCollectionEquality().equals(other._meta, _meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,description,available,isDefault,const DeepCollectionEquality().hash(_meta));

@override
String toString() {
  return 'LiveEditAgentBackend(id: $id, label: $label, description: $description, available: $available, isDefault: $isDefault, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$LiveEditAgentBackendCopyWith<$Res> implements $LiveEditAgentBackendCopyWith<$Res> {
  factory _$LiveEditAgentBackendCopyWith(_LiveEditAgentBackend value, $Res Function(_LiveEditAgentBackend) _then) = __$LiveEditAgentBackendCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, String description, bool available, bool isDefault, Map<String, Object?> meta
});




}
/// @nodoc
class __$LiveEditAgentBackendCopyWithImpl<$Res>
    implements _$LiveEditAgentBackendCopyWith<$Res> {
  __$LiveEditAgentBackendCopyWithImpl(this._self, this._then);

  final _LiveEditAgentBackend _self;
  final $Res Function(_LiveEditAgentBackend) _then;

/// Create a copy of LiveEditAgentBackend
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? description = null,Object? available = null,Object? isDefault = null,Object? meta = null,}) {
  return _then(_LiveEditAgentBackend(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,meta: null == meta ? _self._meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}


/// @nodoc
mixin _$LiveEditCodexModelOption {

 String get id; String get label;
/// Create a copy of LiveEditCodexModelOption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditCodexModelOptionCopyWith<LiveEditCodexModelOption> get copyWith => _$LiveEditCodexModelOptionCopyWithImpl<LiveEditCodexModelOption>(this as LiveEditCodexModelOption, _$identity);

  /// Serializes this LiveEditCodexModelOption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditCodexModelOption&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label);

@override
String toString() {
  return 'LiveEditCodexModelOption(id: $id, label: $label)';
}


}

/// @nodoc
abstract mixin class $LiveEditCodexModelOptionCopyWith<$Res>  {
  factory $LiveEditCodexModelOptionCopyWith(LiveEditCodexModelOption value, $Res Function(LiveEditCodexModelOption) _then) = _$LiveEditCodexModelOptionCopyWithImpl;
@useResult
$Res call({
 String id, String label
});




}
/// @nodoc
class _$LiveEditCodexModelOptionCopyWithImpl<$Res>
    implements $LiveEditCodexModelOptionCopyWith<$Res> {
  _$LiveEditCodexModelOptionCopyWithImpl(this._self, this._then);

  final LiveEditCodexModelOption _self;
  final $Res Function(LiveEditCodexModelOption) _then;

/// Create a copy of LiveEditCodexModelOption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveEditCodexModelOption].
extension LiveEditCodexModelOptionPatterns on LiveEditCodexModelOption {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditCodexModelOption value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditCodexModelOption() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditCodexModelOption value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditCodexModelOption():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditCodexModelOption value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditCodexModelOption() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditCodexModelOption() when $default != null:
return $default(_that.id,_that.label);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label)  $default,) {final _that = this;
switch (_that) {
case _LiveEditCodexModelOption():
return $default(_that.id,_that.label);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditCodexModelOption() when $default != null:
return $default(_that.id,_that.label);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEditCodexModelOption implements LiveEditCodexModelOption {
  const _LiveEditCodexModelOption({required this.id, required this.label});
  factory _LiveEditCodexModelOption.fromJson(Map<String, dynamic> json) => _$LiveEditCodexModelOptionFromJson(json);

@override final  String id;
@override final  String label;

/// Create a copy of LiveEditCodexModelOption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditCodexModelOptionCopyWith<_LiveEditCodexModelOption> get copyWith => __$LiveEditCodexModelOptionCopyWithImpl<_LiveEditCodexModelOption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEditCodexModelOptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditCodexModelOption&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label);

@override
String toString() {
  return 'LiveEditCodexModelOption(id: $id, label: $label)';
}


}

/// @nodoc
abstract mixin class _$LiveEditCodexModelOptionCopyWith<$Res> implements $LiveEditCodexModelOptionCopyWith<$Res> {
  factory _$LiveEditCodexModelOptionCopyWith(_LiveEditCodexModelOption value, $Res Function(_LiveEditCodexModelOption) _then) = __$LiveEditCodexModelOptionCopyWithImpl;
@override @useResult
$Res call({
 String id, String label
});




}
/// @nodoc
class __$LiveEditCodexModelOptionCopyWithImpl<$Res>
    implements _$LiveEditCodexModelOptionCopyWith<$Res> {
  __$LiveEditCodexModelOptionCopyWithImpl(this._self, this._then);

  final _LiveEditCodexModelOption _self;
  final $Res Function(_LiveEditCodexModelOption) _then;

/// Create a copy of LiveEditCodexModelOption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,}) {
  return _then(_LiveEditCodexModelOption(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$LiveEditDraftChange {

 String get nodeId; String get propertyId; Object? get targetValue; LiveEditPreviewMode get previewMode;@JsonKey(fromJson: _confidenceFromJson) double get confidence; String? get intentText;@JsonKey(fromJson: _parseDraftTargetContext, toJson: _draftTargetContextToJson) DraftTargetContext? get targetContext; Map<String, Object?> get meta;
/// Create a copy of LiveEditDraftChange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditDraftChangeCopyWith<LiveEditDraftChange> get copyWith => _$LiveEditDraftChangeCopyWithImpl<LiveEditDraftChange>(this as LiveEditDraftChange, _$identity);

  /// Serializes this LiveEditDraftChange to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditDraftChange&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.propertyId, propertyId) || other.propertyId == propertyId)&&const DeepCollectionEquality().equals(other.targetValue, targetValue)&&(identical(other.previewMode, previewMode) || other.previewMode == previewMode)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.intentText, intentText) || other.intentText == intentText)&&const DeepCollectionEquality().equals(other.targetContext, targetContext)&&const DeepCollectionEquality().equals(other.meta, meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,nodeId,propertyId,const DeepCollectionEquality().hash(targetValue),previewMode,confidence,intentText,const DeepCollectionEquality().hash(targetContext),const DeepCollectionEquality().hash(meta));

@override
String toString() {
  return 'LiveEditDraftChange(nodeId: $nodeId, propertyId: $propertyId, targetValue: $targetValue, previewMode: $previewMode, confidence: $confidence, intentText: $intentText, targetContext: $targetContext, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $LiveEditDraftChangeCopyWith<$Res>  {
  factory $LiveEditDraftChangeCopyWith(LiveEditDraftChange value, $Res Function(LiveEditDraftChange) _then) = _$LiveEditDraftChangeCopyWithImpl;
@useResult
$Res call({
 String nodeId, String propertyId, Object? targetValue, LiveEditPreviewMode previewMode,@JsonKey(fromJson: _confidenceFromJson) double confidence, String? intentText,@JsonKey(fromJson: _parseDraftTargetContext, toJson: _draftTargetContextToJson) DraftTargetContext? targetContext, Map<String, Object?> meta
});




}
/// @nodoc
class _$LiveEditDraftChangeCopyWithImpl<$Res>
    implements $LiveEditDraftChangeCopyWith<$Res> {
  _$LiveEditDraftChangeCopyWithImpl(this._self, this._then);

  final LiveEditDraftChange _self;
  final $Res Function(LiveEditDraftChange) _then;

/// Create a copy of LiveEditDraftChange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nodeId = null,Object? propertyId = null,Object? targetValue = freezed,Object? previewMode = null,Object? confidence = null,Object? intentText = freezed,Object? targetContext = freezed,Object? meta = null,}) {
  return _then(_self.copyWith(
nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,propertyId: null == propertyId ? _self.propertyId : propertyId // ignore: cast_nullable_to_non_nullable
as String,targetValue: freezed == targetValue ? _self.targetValue : targetValue ,previewMode: null == previewMode ? _self.previewMode : previewMode // ignore: cast_nullable_to_non_nullable
as LiveEditPreviewMode,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,intentText: freezed == intentText ? _self.intentText : intentText // ignore: cast_nullable_to_non_nullable
as String?,targetContext: freezed == targetContext ? _self.targetContext : targetContext // ignore: cast_nullable_to_non_nullable
as DraftTargetContext?,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveEditDraftChange].
extension LiveEditDraftChangePatterns on LiveEditDraftChange {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditDraftChange value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditDraftChange() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditDraftChange value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditDraftChange():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditDraftChange value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditDraftChange() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String nodeId,  String propertyId,  Object? targetValue,  LiveEditPreviewMode previewMode, @JsonKey(fromJson: _confidenceFromJson)  double confidence,  String? intentText, @JsonKey(fromJson: _parseDraftTargetContext, toJson: _draftTargetContextToJson)  DraftTargetContext? targetContext,  Map<String, Object?> meta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditDraftChange() when $default != null:
return $default(_that.nodeId,_that.propertyId,_that.targetValue,_that.previewMode,_that.confidence,_that.intentText,_that.targetContext,_that.meta);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String nodeId,  String propertyId,  Object? targetValue,  LiveEditPreviewMode previewMode, @JsonKey(fromJson: _confidenceFromJson)  double confidence,  String? intentText, @JsonKey(fromJson: _parseDraftTargetContext, toJson: _draftTargetContextToJson)  DraftTargetContext? targetContext,  Map<String, Object?> meta)  $default,) {final _that = this;
switch (_that) {
case _LiveEditDraftChange():
return $default(_that.nodeId,_that.propertyId,_that.targetValue,_that.previewMode,_that.confidence,_that.intentText,_that.targetContext,_that.meta);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String nodeId,  String propertyId,  Object? targetValue,  LiveEditPreviewMode previewMode, @JsonKey(fromJson: _confidenceFromJson)  double confidence,  String? intentText, @JsonKey(fromJson: _parseDraftTargetContext, toJson: _draftTargetContextToJson)  DraftTargetContext? targetContext,  Map<String, Object?> meta)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditDraftChange() when $default != null:
return $default(_that.nodeId,_that.propertyId,_that.targetValue,_that.previewMode,_that.confidence,_that.intentText,_that.targetContext,_that.meta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEditDraftChange implements LiveEditDraftChange {
  const _LiveEditDraftChange({required this.nodeId, required this.propertyId, required this.targetValue, this.previewMode = LiveEditPreviewMode.none, @JsonKey(fromJson: _confidenceFromJson) this.confidence = 1, this.intentText, @JsonKey(fromJson: _parseDraftTargetContext, toJson: _draftTargetContextToJson) this.targetContext, final  Map<String, Object?> meta = const <String, Object?>{}}): _meta = meta;
  factory _LiveEditDraftChange.fromJson(Map<String, dynamic> json) => _$LiveEditDraftChangeFromJson(json);

@override final  String nodeId;
@override final  String propertyId;
@override final  Object? targetValue;
@override@JsonKey() final  LiveEditPreviewMode previewMode;
@override@JsonKey(fromJson: _confidenceFromJson) final  double confidence;
@override final  String? intentText;
@override@JsonKey(fromJson: _parseDraftTargetContext, toJson: _draftTargetContextToJson) final  DraftTargetContext? targetContext;
 final  Map<String, Object?> _meta;
@override@JsonKey() Map<String, Object?> get meta {
  if (_meta is EqualUnmodifiableMapView) return _meta;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_meta);
}


/// Create a copy of LiveEditDraftChange
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditDraftChangeCopyWith<_LiveEditDraftChange> get copyWith => __$LiveEditDraftChangeCopyWithImpl<_LiveEditDraftChange>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEditDraftChangeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditDraftChange&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.propertyId, propertyId) || other.propertyId == propertyId)&&const DeepCollectionEquality().equals(other.targetValue, targetValue)&&(identical(other.previewMode, previewMode) || other.previewMode == previewMode)&&(identical(other.confidence, confidence) || other.confidence == confidence)&&(identical(other.intentText, intentText) || other.intentText == intentText)&&const DeepCollectionEquality().equals(other.targetContext, targetContext)&&const DeepCollectionEquality().equals(other._meta, _meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,nodeId,propertyId,const DeepCollectionEquality().hash(targetValue),previewMode,confidence,intentText,const DeepCollectionEquality().hash(targetContext),const DeepCollectionEquality().hash(_meta));

@override
String toString() {
  return 'LiveEditDraftChange(nodeId: $nodeId, propertyId: $propertyId, targetValue: $targetValue, previewMode: $previewMode, confidence: $confidence, intentText: $intentText, targetContext: $targetContext, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$LiveEditDraftChangeCopyWith<$Res> implements $LiveEditDraftChangeCopyWith<$Res> {
  factory _$LiveEditDraftChangeCopyWith(_LiveEditDraftChange value, $Res Function(_LiveEditDraftChange) _then) = __$LiveEditDraftChangeCopyWithImpl;
@override @useResult
$Res call({
 String nodeId, String propertyId, Object? targetValue, LiveEditPreviewMode previewMode,@JsonKey(fromJson: _confidenceFromJson) double confidence, String? intentText,@JsonKey(fromJson: _parseDraftTargetContext, toJson: _draftTargetContextToJson) DraftTargetContext? targetContext, Map<String, Object?> meta
});




}
/// @nodoc
class __$LiveEditDraftChangeCopyWithImpl<$Res>
    implements _$LiveEditDraftChangeCopyWith<$Res> {
  __$LiveEditDraftChangeCopyWithImpl(this._self, this._then);

  final _LiveEditDraftChange _self;
  final $Res Function(_LiveEditDraftChange) _then;

/// Create a copy of LiveEditDraftChange
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nodeId = null,Object? propertyId = null,Object? targetValue = freezed,Object? previewMode = null,Object? confidence = null,Object? intentText = freezed,Object? targetContext = freezed,Object? meta = null,}) {
  return _then(_LiveEditDraftChange(
nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,propertyId: null == propertyId ? _self.propertyId : propertyId // ignore: cast_nullable_to_non_nullable
as String,targetValue: freezed == targetValue ? _self.targetValue : targetValue ,previewMode: null == previewMode ? _self.previewMode : previewMode // ignore: cast_nullable_to_non_nullable
as LiveEditPreviewMode,confidence: null == confidence ? _self.confidence : confidence // ignore: cast_nullable_to_non_nullable
as double,intentText: freezed == intentText ? _self.intentText : intentText // ignore: cast_nullable_to_non_nullable
as String?,targetContext: freezed == targetContext ? _self.targetContext : targetContext // ignore: cast_nullable_to_non_nullable
as DraftTargetContext?,meta: null == meta ? _self._meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}


/// @nodoc
mixin _$LiveEditFilePatch {

 String get path; String get content; String get patch; Map<String, Object?> get meta;
/// Create a copy of LiveEditFilePatch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditFilePatchCopyWith<LiveEditFilePatch> get copyWith => _$LiveEditFilePatchCopyWithImpl<LiveEditFilePatch>(this as LiveEditFilePatch, _$identity);

  /// Serializes this LiveEditFilePatch to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditFilePatch&&(identical(other.path, path) || other.path == path)&&(identical(other.content, content) || other.content == content)&&(identical(other.patch, patch) || other.patch == patch)&&const DeepCollectionEquality().equals(other.meta, meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,content,patch,const DeepCollectionEquality().hash(meta));

@override
String toString() {
  return 'LiveEditFilePatch(path: $path, content: $content, patch: $patch, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $LiveEditFilePatchCopyWith<$Res>  {
  factory $LiveEditFilePatchCopyWith(LiveEditFilePatch value, $Res Function(LiveEditFilePatch) _then) = _$LiveEditFilePatchCopyWithImpl;
@useResult
$Res call({
 String path, String content, String patch, Map<String, Object?> meta
});




}
/// @nodoc
class _$LiveEditFilePatchCopyWithImpl<$Res>
    implements $LiveEditFilePatchCopyWith<$Res> {
  _$LiveEditFilePatchCopyWithImpl(this._self, this._then);

  final LiveEditFilePatch _self;
  final $Res Function(LiveEditFilePatch) _then;

/// Create a copy of LiveEditFilePatch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? content = null,Object? patch = null,Object? meta = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,patch: null == patch ? _self.patch : patch // ignore: cast_nullable_to_non_nullable
as String,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveEditFilePatch].
extension LiveEditFilePatchPatterns on LiveEditFilePatch {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditFilePatch value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditFilePatch() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditFilePatch value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditFilePatch():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditFilePatch value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditFilePatch() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  String content,  String patch,  Map<String, Object?> meta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditFilePatch() when $default != null:
return $default(_that.path,_that.content,_that.patch,_that.meta);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  String content,  String patch,  Map<String, Object?> meta)  $default,) {final _that = this;
switch (_that) {
case _LiveEditFilePatch():
return $default(_that.path,_that.content,_that.patch,_that.meta);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  String content,  String patch,  Map<String, Object?> meta)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditFilePatch() when $default != null:
return $default(_that.path,_that.content,_that.patch,_that.meta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEditFilePatch implements LiveEditFilePatch {
  const _LiveEditFilePatch({required this.path, required this.content, required this.patch, final  Map<String, Object?> meta = const <String, Object?>{}}): _meta = meta;
  factory _LiveEditFilePatch.fromJson(Map<String, dynamic> json) => _$LiveEditFilePatchFromJson(json);

@override final  String path;
@override final  String content;
@override final  String patch;
 final  Map<String, Object?> _meta;
@override@JsonKey() Map<String, Object?> get meta {
  if (_meta is EqualUnmodifiableMapView) return _meta;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_meta);
}


/// Create a copy of LiveEditFilePatch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditFilePatchCopyWith<_LiveEditFilePatch> get copyWith => __$LiveEditFilePatchCopyWithImpl<_LiveEditFilePatch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEditFilePatchToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditFilePatch&&(identical(other.path, path) || other.path == path)&&(identical(other.content, content) || other.content == content)&&(identical(other.patch, patch) || other.patch == patch)&&const DeepCollectionEquality().equals(other._meta, _meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,content,patch,const DeepCollectionEquality().hash(_meta));

@override
String toString() {
  return 'LiveEditFilePatch(path: $path, content: $content, patch: $patch, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$LiveEditFilePatchCopyWith<$Res> implements $LiveEditFilePatchCopyWith<$Res> {
  factory _$LiveEditFilePatchCopyWith(_LiveEditFilePatch value, $Res Function(_LiveEditFilePatch) _then) = __$LiveEditFilePatchCopyWithImpl;
@override @useResult
$Res call({
 String path, String content, String patch, Map<String, Object?> meta
});




}
/// @nodoc
class __$LiveEditFilePatchCopyWithImpl<$Res>
    implements _$LiveEditFilePatchCopyWith<$Res> {
  __$LiveEditFilePatchCopyWithImpl(this._self, this._then);

  final _LiveEditFilePatch _self;
  final $Res Function(_LiveEditFilePatch) _then;

/// Create a copy of LiveEditFilePatch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? content = null,Object? patch = null,Object? meta = null,}) {
  return _then(_LiveEditFilePatch(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,patch: null == patch ? _self.patch : patch // ignore: cast_nullable_to_non_nullable
as String,meta: null == meta ? _self._meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

/// @nodoc
mixin _$LiveEditInferenceConfig {

 String? get model; String? get reasoningEffort;
/// Create a copy of LiveEditInferenceConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditInferenceConfigCopyWith<LiveEditInferenceConfig> get copyWith => _$LiveEditInferenceConfigCopyWithImpl<LiveEditInferenceConfig>(this as LiveEditInferenceConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditInferenceConfig&&(identical(other.model, model) || other.model == model)&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort));
}


@override
int get hashCode => Object.hash(runtimeType,model,reasoningEffort);

@override
String toString() {
  return 'LiveEditInferenceConfig(model: $model, reasoningEffort: $reasoningEffort)';
}


}

/// @nodoc
abstract mixin class $LiveEditInferenceConfigCopyWith<$Res>  {
  factory $LiveEditInferenceConfigCopyWith(LiveEditInferenceConfig value, $Res Function(LiveEditInferenceConfig) _then) = _$LiveEditInferenceConfigCopyWithImpl;
@useResult
$Res call({
 String? model, String? reasoningEffort
});




}
/// @nodoc
class _$LiveEditInferenceConfigCopyWithImpl<$Res>
    implements $LiveEditInferenceConfigCopyWith<$Res> {
  _$LiveEditInferenceConfigCopyWithImpl(this._self, this._then);

  final LiveEditInferenceConfig _self;
  final $Res Function(LiveEditInferenceConfig) _then;

/// Create a copy of LiveEditInferenceConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? model = freezed,Object? reasoningEffort = freezed,}) {
  return _then(_self.copyWith(
model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveEditInferenceConfig].
extension LiveEditInferenceConfigPatterns on LiveEditInferenceConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditInferenceConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditInferenceConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditInferenceConfig value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditInferenceConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditInferenceConfig value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditInferenceConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? model,  String? reasoningEffort)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditInferenceConfig() when $default != null:
return $default(_that.model,_that.reasoningEffort);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? model,  String? reasoningEffort)  $default,) {final _that = this;
switch (_that) {
case _LiveEditInferenceConfig():
return $default(_that.model,_that.reasoningEffort);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? model,  String? reasoningEffort)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditInferenceConfig() when $default != null:
return $default(_that.model,_that.reasoningEffort);case _:
  return null;

}
}

}

/// @nodoc


class _LiveEditInferenceConfig extends LiveEditInferenceConfig {
  const _LiveEditInferenceConfig({this.model, this.reasoningEffort}): super._();
  

@override final  String? model;
@override final  String? reasoningEffort;

/// Create a copy of LiveEditInferenceConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditInferenceConfigCopyWith<_LiveEditInferenceConfig> get copyWith => __$LiveEditInferenceConfigCopyWithImpl<_LiveEditInferenceConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditInferenceConfig&&(identical(other.model, model) || other.model == model)&&(identical(other.reasoningEffort, reasoningEffort) || other.reasoningEffort == reasoningEffort));
}


@override
int get hashCode => Object.hash(runtimeType,model,reasoningEffort);

@override
String toString() {
  return 'LiveEditInferenceConfig(model: $model, reasoningEffort: $reasoningEffort)';
}


}

/// @nodoc
abstract mixin class _$LiveEditInferenceConfigCopyWith<$Res> implements $LiveEditInferenceConfigCopyWith<$Res> {
  factory _$LiveEditInferenceConfigCopyWith(_LiveEditInferenceConfig value, $Res Function(_LiveEditInferenceConfig) _then) = __$LiveEditInferenceConfigCopyWithImpl;
@override @useResult
$Res call({
 String? model, String? reasoningEffort
});




}
/// @nodoc
class __$LiveEditInferenceConfigCopyWithImpl<$Res>
    implements _$LiveEditInferenceConfigCopyWith<$Res> {
  __$LiveEditInferenceConfigCopyWithImpl(this._self, this._then);

  final _LiveEditInferenceConfig _self;
  final $Res Function(_LiveEditInferenceConfig) _then;

/// Create a copy of LiveEditInferenceConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? model = freezed,Object? reasoningEffort = freezed,}) {
  return _then(_LiveEditInferenceConfig(
model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,reasoningEffort: freezed == reasoningEffort ? _self.reasoningEffort : reasoningEffort // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LiveEditRuntimeRefreshResult {

 LiveEditRuntimeAction get action; Map<String, Object?> get validation; Map<String, Object?> get hotReload; Map<String, Object?> get hotRestart; Map<String, Object?> get validationRecovery;
/// Create a copy of LiveEditRuntimeRefreshResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditRuntimeRefreshResultCopyWith<LiveEditRuntimeRefreshResult> get copyWith => _$LiveEditRuntimeRefreshResultCopyWithImpl<LiveEditRuntimeRefreshResult>(this as LiveEditRuntimeRefreshResult, _$identity);

  /// Serializes this LiveEditRuntimeRefreshResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditRuntimeRefreshResult&&(identical(other.action, action) || other.action == action)&&const DeepCollectionEquality().equals(other.validation, validation)&&const DeepCollectionEquality().equals(other.hotReload, hotReload)&&const DeepCollectionEquality().equals(other.hotRestart, hotRestart)&&const DeepCollectionEquality().equals(other.validationRecovery, validationRecovery));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,action,const DeepCollectionEquality().hash(validation),const DeepCollectionEquality().hash(hotReload),const DeepCollectionEquality().hash(hotRestart),const DeepCollectionEquality().hash(validationRecovery));

@override
String toString() {
  return 'LiveEditRuntimeRefreshResult(action: $action, validation: $validation, hotReload: $hotReload, hotRestart: $hotRestart, validationRecovery: $validationRecovery)';
}


}

/// @nodoc
abstract mixin class $LiveEditRuntimeRefreshResultCopyWith<$Res>  {
  factory $LiveEditRuntimeRefreshResultCopyWith(LiveEditRuntimeRefreshResult value, $Res Function(LiveEditRuntimeRefreshResult) _then) = _$LiveEditRuntimeRefreshResultCopyWithImpl;
@useResult
$Res call({
 LiveEditRuntimeAction action, Map<String, Object?> validation, Map<String, Object?> hotReload, Map<String, Object?> hotRestart, Map<String, Object?> validationRecovery
});




}
/// @nodoc
class _$LiveEditRuntimeRefreshResultCopyWithImpl<$Res>
    implements $LiveEditRuntimeRefreshResultCopyWith<$Res> {
  _$LiveEditRuntimeRefreshResultCopyWithImpl(this._self, this._then);

  final LiveEditRuntimeRefreshResult _self;
  final $Res Function(LiveEditRuntimeRefreshResult) _then;

/// Create a copy of LiveEditRuntimeRefreshResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? action = null,Object? validation = null,Object? hotReload = null,Object? hotRestart = null,Object? validationRecovery = null,}) {
  return _then(_self.copyWith(
action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as LiveEditRuntimeAction,validation: null == validation ? _self.validation : validation // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,hotReload: null == hotReload ? _self.hotReload : hotReload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,hotRestart: null == hotRestart ? _self.hotRestart : hotRestart // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,validationRecovery: null == validationRecovery ? _self.validationRecovery : validationRecovery // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveEditRuntimeRefreshResult].
extension LiveEditRuntimeRefreshResultPatterns on LiveEditRuntimeRefreshResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditRuntimeRefreshResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditRuntimeRefreshResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditRuntimeRefreshResult value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditRuntimeRefreshResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditRuntimeRefreshResult value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditRuntimeRefreshResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LiveEditRuntimeAction action,  Map<String, Object?> validation,  Map<String, Object?> hotReload,  Map<String, Object?> hotRestart,  Map<String, Object?> validationRecovery)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditRuntimeRefreshResult() when $default != null:
return $default(_that.action,_that.validation,_that.hotReload,_that.hotRestart,_that.validationRecovery);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LiveEditRuntimeAction action,  Map<String, Object?> validation,  Map<String, Object?> hotReload,  Map<String, Object?> hotRestart,  Map<String, Object?> validationRecovery)  $default,) {final _that = this;
switch (_that) {
case _LiveEditRuntimeRefreshResult():
return $default(_that.action,_that.validation,_that.hotReload,_that.hotRestart,_that.validationRecovery);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LiveEditRuntimeAction action,  Map<String, Object?> validation,  Map<String, Object?> hotReload,  Map<String, Object?> hotRestart,  Map<String, Object?> validationRecovery)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditRuntimeRefreshResult() when $default != null:
return $default(_that.action,_that.validation,_that.hotReload,_that.hotRestart,_that.validationRecovery);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEditRuntimeRefreshResult extends LiveEditRuntimeRefreshResult {
  const _LiveEditRuntimeRefreshResult({this.action = LiveEditRuntimeAction.none, final  Map<String, Object?> validation = const <String, Object?>{}, final  Map<String, Object?> hotReload = const <String, Object?>{}, final  Map<String, Object?> hotRestart = const <String, Object?>{}, final  Map<String, Object?> validationRecovery = const <String, Object?>{}}): _validation = validation,_hotReload = hotReload,_hotRestart = hotRestart,_validationRecovery = validationRecovery,super._();
  factory _LiveEditRuntimeRefreshResult.fromJson(Map<String, dynamic> json) => _$LiveEditRuntimeRefreshResultFromJson(json);

@override@JsonKey() final  LiveEditRuntimeAction action;
 final  Map<String, Object?> _validation;
@override@JsonKey() Map<String, Object?> get validation {
  if (_validation is EqualUnmodifiableMapView) return _validation;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_validation);
}

 final  Map<String, Object?> _hotReload;
@override@JsonKey() Map<String, Object?> get hotReload {
  if (_hotReload is EqualUnmodifiableMapView) return _hotReload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_hotReload);
}

 final  Map<String, Object?> _hotRestart;
@override@JsonKey() Map<String, Object?> get hotRestart {
  if (_hotRestart is EqualUnmodifiableMapView) return _hotRestart;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_hotRestart);
}

 final  Map<String, Object?> _validationRecovery;
@override@JsonKey() Map<String, Object?> get validationRecovery {
  if (_validationRecovery is EqualUnmodifiableMapView) return _validationRecovery;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_validationRecovery);
}


/// Create a copy of LiveEditRuntimeRefreshResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditRuntimeRefreshResultCopyWith<_LiveEditRuntimeRefreshResult> get copyWith => __$LiveEditRuntimeRefreshResultCopyWithImpl<_LiveEditRuntimeRefreshResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEditRuntimeRefreshResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditRuntimeRefreshResult&&(identical(other.action, action) || other.action == action)&&const DeepCollectionEquality().equals(other._validation, _validation)&&const DeepCollectionEquality().equals(other._hotReload, _hotReload)&&const DeepCollectionEquality().equals(other._hotRestart, _hotRestart)&&const DeepCollectionEquality().equals(other._validationRecovery, _validationRecovery));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,action,const DeepCollectionEquality().hash(_validation),const DeepCollectionEquality().hash(_hotReload),const DeepCollectionEquality().hash(_hotRestart),const DeepCollectionEquality().hash(_validationRecovery));

@override
String toString() {
  return 'LiveEditRuntimeRefreshResult(action: $action, validation: $validation, hotReload: $hotReload, hotRestart: $hotRestart, validationRecovery: $validationRecovery)';
}


}

/// @nodoc
abstract mixin class _$LiveEditRuntimeRefreshResultCopyWith<$Res> implements $LiveEditRuntimeRefreshResultCopyWith<$Res> {
  factory _$LiveEditRuntimeRefreshResultCopyWith(_LiveEditRuntimeRefreshResult value, $Res Function(_LiveEditRuntimeRefreshResult) _then) = __$LiveEditRuntimeRefreshResultCopyWithImpl;
@override @useResult
$Res call({
 LiveEditRuntimeAction action, Map<String, Object?> validation, Map<String, Object?> hotReload, Map<String, Object?> hotRestart, Map<String, Object?> validationRecovery
});




}
/// @nodoc
class __$LiveEditRuntimeRefreshResultCopyWithImpl<$Res>
    implements _$LiveEditRuntimeRefreshResultCopyWith<$Res> {
  __$LiveEditRuntimeRefreshResultCopyWithImpl(this._self, this._then);

  final _LiveEditRuntimeRefreshResult _self;
  final $Res Function(_LiveEditRuntimeRefreshResult) _then;

/// Create a copy of LiveEditRuntimeRefreshResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? action = null,Object? validation = null,Object? hotReload = null,Object? hotRestart = null,Object? validationRecovery = null,}) {
  return _then(_LiveEditRuntimeRefreshResult(
action: null == action ? _self.action : action // ignore: cast_nullable_to_non_nullable
as LiveEditRuntimeAction,validation: null == validation ? _self._validation : validation // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,hotReload: null == hotReload ? _self._hotReload : hotReload // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,hotRestart: null == hotRestart ? _self._hotRestart : hotRestart // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,validationRecovery: null == validationRecovery ? _self._validationRecovery : validationRecovery // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}


/// @nodoc
mixin _$LiveEditResolutionProposal {

 String get proposalId; String get backendId; String get summary; String get patch; List<String> get changedFiles; List<LiveEditFilePatch> get filePatches; List<String> get expectedRuntimeEffects; List<String> get validationSteps; List<String> get warnings; List<String> get riskFlags; Map<String, Object?> get meta;
/// Create a copy of LiveEditResolutionProposal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditResolutionProposalCopyWith<LiveEditResolutionProposal> get copyWith => _$LiveEditResolutionProposalCopyWithImpl<LiveEditResolutionProposal>(this as LiveEditResolutionProposal, _$identity);

  /// Serializes this LiveEditResolutionProposal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditResolutionProposal&&(identical(other.proposalId, proposalId) || other.proposalId == proposalId)&&(identical(other.backendId, backendId) || other.backendId == backendId)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.patch, patch) || other.patch == patch)&&const DeepCollectionEquality().equals(other.changedFiles, changedFiles)&&const DeepCollectionEquality().equals(other.filePatches, filePatches)&&const DeepCollectionEquality().equals(other.expectedRuntimeEffects, expectedRuntimeEffects)&&const DeepCollectionEquality().equals(other.validationSteps, validationSteps)&&const DeepCollectionEquality().equals(other.warnings, warnings)&&const DeepCollectionEquality().equals(other.riskFlags, riskFlags)&&const DeepCollectionEquality().equals(other.meta, meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,proposalId,backendId,summary,patch,const DeepCollectionEquality().hash(changedFiles),const DeepCollectionEquality().hash(filePatches),const DeepCollectionEquality().hash(expectedRuntimeEffects),const DeepCollectionEquality().hash(validationSteps),const DeepCollectionEquality().hash(warnings),const DeepCollectionEquality().hash(riskFlags),const DeepCollectionEquality().hash(meta));

@override
String toString() {
  return 'LiveEditResolutionProposal(proposalId: $proposalId, backendId: $backendId, summary: $summary, patch: $patch, changedFiles: $changedFiles, filePatches: $filePatches, expectedRuntimeEffects: $expectedRuntimeEffects, validationSteps: $validationSteps, warnings: $warnings, riskFlags: $riskFlags, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $LiveEditResolutionProposalCopyWith<$Res>  {
  factory $LiveEditResolutionProposalCopyWith(LiveEditResolutionProposal value, $Res Function(LiveEditResolutionProposal) _then) = _$LiveEditResolutionProposalCopyWithImpl;
@useResult
$Res call({
 String proposalId, String backendId, String summary, String patch, List<String> changedFiles, List<LiveEditFilePatch> filePatches, List<String> expectedRuntimeEffects, List<String> validationSteps, List<String> warnings, List<String> riskFlags, Map<String, Object?> meta
});




}
/// @nodoc
class _$LiveEditResolutionProposalCopyWithImpl<$Res>
    implements $LiveEditResolutionProposalCopyWith<$Res> {
  _$LiveEditResolutionProposalCopyWithImpl(this._self, this._then);

  final LiveEditResolutionProposal _self;
  final $Res Function(LiveEditResolutionProposal) _then;

/// Create a copy of LiveEditResolutionProposal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? proposalId = null,Object? backendId = null,Object? summary = null,Object? patch = null,Object? changedFiles = null,Object? filePatches = null,Object? expectedRuntimeEffects = null,Object? validationSteps = null,Object? warnings = null,Object? riskFlags = null,Object? meta = null,}) {
  return _then(_self.copyWith(
proposalId: null == proposalId ? _self.proposalId : proposalId // ignore: cast_nullable_to_non_nullable
as String,backendId: null == backendId ? _self.backendId : backendId // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,patch: null == patch ? _self.patch : patch // ignore: cast_nullable_to_non_nullable
as String,changedFiles: null == changedFiles ? _self.changedFiles : changedFiles // ignore: cast_nullable_to_non_nullable
as List<String>,filePatches: null == filePatches ? _self.filePatches : filePatches // ignore: cast_nullable_to_non_nullable
as List<LiveEditFilePatch>,expectedRuntimeEffects: null == expectedRuntimeEffects ? _self.expectedRuntimeEffects : expectedRuntimeEffects // ignore: cast_nullable_to_non_nullable
as List<String>,validationSteps: null == validationSteps ? _self.validationSteps : validationSteps // ignore: cast_nullable_to_non_nullable
as List<String>,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,riskFlags: null == riskFlags ? _self.riskFlags : riskFlags // ignore: cast_nullable_to_non_nullable
as List<String>,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveEditResolutionProposal].
extension LiveEditResolutionProposalPatterns on LiveEditResolutionProposal {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditResolutionProposal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditResolutionProposal() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditResolutionProposal value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditResolutionProposal():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditResolutionProposal value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditResolutionProposal() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String proposalId,  String backendId,  String summary,  String patch,  List<String> changedFiles,  List<LiveEditFilePatch> filePatches,  List<String> expectedRuntimeEffects,  List<String> validationSteps,  List<String> warnings,  List<String> riskFlags,  Map<String, Object?> meta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditResolutionProposal() when $default != null:
return $default(_that.proposalId,_that.backendId,_that.summary,_that.patch,_that.changedFiles,_that.filePatches,_that.expectedRuntimeEffects,_that.validationSteps,_that.warnings,_that.riskFlags,_that.meta);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String proposalId,  String backendId,  String summary,  String patch,  List<String> changedFiles,  List<LiveEditFilePatch> filePatches,  List<String> expectedRuntimeEffects,  List<String> validationSteps,  List<String> warnings,  List<String> riskFlags,  Map<String, Object?> meta)  $default,) {final _that = this;
switch (_that) {
case _LiveEditResolutionProposal():
return $default(_that.proposalId,_that.backendId,_that.summary,_that.patch,_that.changedFiles,_that.filePatches,_that.expectedRuntimeEffects,_that.validationSteps,_that.warnings,_that.riskFlags,_that.meta);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String proposalId,  String backendId,  String summary,  String patch,  List<String> changedFiles,  List<LiveEditFilePatch> filePatches,  List<String> expectedRuntimeEffects,  List<String> validationSteps,  List<String> warnings,  List<String> riskFlags,  Map<String, Object?> meta)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditResolutionProposal() when $default != null:
return $default(_that.proposalId,_that.backendId,_that.summary,_that.patch,_that.changedFiles,_that.filePatches,_that.expectedRuntimeEffects,_that.validationSteps,_that.warnings,_that.riskFlags,_that.meta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEditResolutionProposal implements LiveEditResolutionProposal {
  const _LiveEditResolutionProposal({required this.proposalId, required this.backendId, required this.summary, required this.patch, required final  List<String> changedFiles, required final  List<LiveEditFilePatch> filePatches, required final  List<String> expectedRuntimeEffects, required final  List<String> validationSteps, final  List<String> warnings = const <String>[], final  List<String> riskFlags = const <String>[], final  Map<String, Object?> meta = const <String, Object?>{}}): _changedFiles = changedFiles,_filePatches = filePatches,_expectedRuntimeEffects = expectedRuntimeEffects,_validationSteps = validationSteps,_warnings = warnings,_riskFlags = riskFlags,_meta = meta;
  factory _LiveEditResolutionProposal.fromJson(Map<String, dynamic> json) => _$LiveEditResolutionProposalFromJson(json);

@override final  String proposalId;
@override final  String backendId;
@override final  String summary;
@override final  String patch;
 final  List<String> _changedFiles;
@override List<String> get changedFiles {
  if (_changedFiles is EqualUnmodifiableListView) return _changedFiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_changedFiles);
}

 final  List<LiveEditFilePatch> _filePatches;
@override List<LiveEditFilePatch> get filePatches {
  if (_filePatches is EqualUnmodifiableListView) return _filePatches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_filePatches);
}

 final  List<String> _expectedRuntimeEffects;
@override List<String> get expectedRuntimeEffects {
  if (_expectedRuntimeEffects is EqualUnmodifiableListView) return _expectedRuntimeEffects;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_expectedRuntimeEffects);
}

 final  List<String> _validationSteps;
@override List<String> get validationSteps {
  if (_validationSteps is EqualUnmodifiableListView) return _validationSteps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_validationSteps);
}

 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}

 final  List<String> _riskFlags;
@override@JsonKey() List<String> get riskFlags {
  if (_riskFlags is EqualUnmodifiableListView) return _riskFlags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_riskFlags);
}

 final  Map<String, Object?> _meta;
@override@JsonKey() Map<String, Object?> get meta {
  if (_meta is EqualUnmodifiableMapView) return _meta;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_meta);
}


/// Create a copy of LiveEditResolutionProposal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditResolutionProposalCopyWith<_LiveEditResolutionProposal> get copyWith => __$LiveEditResolutionProposalCopyWithImpl<_LiveEditResolutionProposal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEditResolutionProposalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditResolutionProposal&&(identical(other.proposalId, proposalId) || other.proposalId == proposalId)&&(identical(other.backendId, backendId) || other.backendId == backendId)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.patch, patch) || other.patch == patch)&&const DeepCollectionEquality().equals(other._changedFiles, _changedFiles)&&const DeepCollectionEquality().equals(other._filePatches, _filePatches)&&const DeepCollectionEquality().equals(other._expectedRuntimeEffects, _expectedRuntimeEffects)&&const DeepCollectionEquality().equals(other._validationSteps, _validationSteps)&&const DeepCollectionEquality().equals(other._warnings, _warnings)&&const DeepCollectionEquality().equals(other._riskFlags, _riskFlags)&&const DeepCollectionEquality().equals(other._meta, _meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,proposalId,backendId,summary,patch,const DeepCollectionEquality().hash(_changedFiles),const DeepCollectionEquality().hash(_filePatches),const DeepCollectionEquality().hash(_expectedRuntimeEffects),const DeepCollectionEquality().hash(_validationSteps),const DeepCollectionEquality().hash(_warnings),const DeepCollectionEquality().hash(_riskFlags),const DeepCollectionEquality().hash(_meta));

@override
String toString() {
  return 'LiveEditResolutionProposal(proposalId: $proposalId, backendId: $backendId, summary: $summary, patch: $patch, changedFiles: $changedFiles, filePatches: $filePatches, expectedRuntimeEffects: $expectedRuntimeEffects, validationSteps: $validationSteps, warnings: $warnings, riskFlags: $riskFlags, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$LiveEditResolutionProposalCopyWith<$Res> implements $LiveEditResolutionProposalCopyWith<$Res> {
  factory _$LiveEditResolutionProposalCopyWith(_LiveEditResolutionProposal value, $Res Function(_LiveEditResolutionProposal) _then) = __$LiveEditResolutionProposalCopyWithImpl;
@override @useResult
$Res call({
 String proposalId, String backendId, String summary, String patch, List<String> changedFiles, List<LiveEditFilePatch> filePatches, List<String> expectedRuntimeEffects, List<String> validationSteps, List<String> warnings, List<String> riskFlags, Map<String, Object?> meta
});




}
/// @nodoc
class __$LiveEditResolutionProposalCopyWithImpl<$Res>
    implements _$LiveEditResolutionProposalCopyWith<$Res> {
  __$LiveEditResolutionProposalCopyWithImpl(this._self, this._then);

  final _LiveEditResolutionProposal _self;
  final $Res Function(_LiveEditResolutionProposal) _then;

/// Create a copy of LiveEditResolutionProposal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? proposalId = null,Object? backendId = null,Object? summary = null,Object? patch = null,Object? changedFiles = null,Object? filePatches = null,Object? expectedRuntimeEffects = null,Object? validationSteps = null,Object? warnings = null,Object? riskFlags = null,Object? meta = null,}) {
  return _then(_LiveEditResolutionProposal(
proposalId: null == proposalId ? _self.proposalId : proposalId // ignore: cast_nullable_to_non_nullable
as String,backendId: null == backendId ? _self.backendId : backendId // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,patch: null == patch ? _self.patch : patch // ignore: cast_nullable_to_non_nullable
as String,changedFiles: null == changedFiles ? _self._changedFiles : changedFiles // ignore: cast_nullable_to_non_nullable
as List<String>,filePatches: null == filePatches ? _self._filePatches : filePatches // ignore: cast_nullable_to_non_nullable
as List<LiveEditFilePatch>,expectedRuntimeEffects: null == expectedRuntimeEffects ? _self._expectedRuntimeEffects : expectedRuntimeEffects // ignore: cast_nullable_to_non_nullable
as List<String>,validationSteps: null == validationSteps ? _self._validationSteps : validationSteps // ignore: cast_nullable_to_non_nullable
as List<String>,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,riskFlags: null == riskFlags ? _self._riskFlags : riskFlags // ignore: cast_nullable_to_non_nullable
as List<String>,meta: null == meta ? _self._meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}

/// @nodoc
mixin _$LiveEditResolutionRequest {

 String get sessionId; String get workingDirectory; String? get bubbleId; String? get instructionText; LiveEditSelection? get primarySelection; List<LiveEditSelection> get selectedWidgets; List<LiveEditSourceTarget> get sourceTargets; LiveEditApplyMode get applyMode; LiveEditSelection? get selection; String? get backendId; LiveEditInferenceConfig? get inferenceConfig; String? get intentText;@JsonKey(fromJson: _parseFlowSelectionIntent, toJson: _flowSelectionIntentToJson) FlowSelectionIntent? get selectionIntent;@JsonKey(fromJson: _parseAgentContextEnvelope, toJson: _agentContextEnvelopeToJson) AgentContextEnvelope? get contextEnvelope; Map<String, Object?> get evidence; Map<String, Object?> get meta;
/// Create a copy of LiveEditResolutionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditResolutionRequestCopyWith<LiveEditResolutionRequest> get copyWith => _$LiveEditResolutionRequestCopyWithImpl<LiveEditResolutionRequest>(this as LiveEditResolutionRequest, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditResolutionRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.workingDirectory, workingDirectory) || other.workingDirectory == workingDirectory)&&(identical(other.bubbleId, bubbleId) || other.bubbleId == bubbleId)&&(identical(other.instructionText, instructionText) || other.instructionText == instructionText)&&(identical(other.primarySelection, primarySelection) || other.primarySelection == primarySelection)&&const DeepCollectionEquality().equals(other.selectedWidgets, selectedWidgets)&&const DeepCollectionEquality().equals(other.sourceTargets, sourceTargets)&&(identical(other.applyMode, applyMode) || other.applyMode == applyMode)&&(identical(other.selection, selection) || other.selection == selection)&&(identical(other.backendId, backendId) || other.backendId == backendId)&&(identical(other.inferenceConfig, inferenceConfig) || other.inferenceConfig == inferenceConfig)&&(identical(other.intentText, intentText) || other.intentText == intentText)&&const DeepCollectionEquality().equals(other.selectionIntent, selectionIntent)&&const DeepCollectionEquality().equals(other.contextEnvelope, contextEnvelope)&&const DeepCollectionEquality().equals(other.evidence, evidence)&&const DeepCollectionEquality().equals(other.meta, meta));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,workingDirectory,bubbleId,instructionText,primarySelection,const DeepCollectionEquality().hash(selectedWidgets),const DeepCollectionEquality().hash(sourceTargets),applyMode,selection,backendId,inferenceConfig,intentText,const DeepCollectionEquality().hash(selectionIntent),const DeepCollectionEquality().hash(contextEnvelope),const DeepCollectionEquality().hash(evidence),const DeepCollectionEquality().hash(meta));

@override
String toString() {
  return 'LiveEditResolutionRequest(sessionId: $sessionId, workingDirectory: $workingDirectory, bubbleId: $bubbleId, instructionText: $instructionText, primarySelection: $primarySelection, selectedWidgets: $selectedWidgets, sourceTargets: $sourceTargets, applyMode: $applyMode, selection: $selection, backendId: $backendId, inferenceConfig: $inferenceConfig, intentText: $intentText, selectionIntent: $selectionIntent, contextEnvelope: $contextEnvelope, evidence: $evidence, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $LiveEditResolutionRequestCopyWith<$Res>  {
  factory $LiveEditResolutionRequestCopyWith(LiveEditResolutionRequest value, $Res Function(LiveEditResolutionRequest) _then) = _$LiveEditResolutionRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, String workingDirectory, String? bubbleId, String? instructionText, LiveEditSelection? primarySelection, List<LiveEditSelection> selectedWidgets, List<LiveEditSourceTarget> sourceTargets, LiveEditApplyMode applyMode, LiveEditSelection? selection, String? backendId, LiveEditInferenceConfig? inferenceConfig, String? intentText,@JsonKey(fromJson: _parseFlowSelectionIntent, toJson: _flowSelectionIntentToJson) FlowSelectionIntent? selectionIntent,@JsonKey(fromJson: _parseAgentContextEnvelope, toJson: _agentContextEnvelopeToJson) AgentContextEnvelope? contextEnvelope, Map<String, Object?> evidence, Map<String, Object?> meta
});


$LiveEditSelectionCopyWith<$Res>? get primarySelection;$LiveEditSelectionCopyWith<$Res>? get selection;$LiveEditInferenceConfigCopyWith<$Res>? get inferenceConfig;

}
/// @nodoc
class _$LiveEditResolutionRequestCopyWithImpl<$Res>
    implements $LiveEditResolutionRequestCopyWith<$Res> {
  _$LiveEditResolutionRequestCopyWithImpl(this._self, this._then);

  final LiveEditResolutionRequest _self;
  final $Res Function(LiveEditResolutionRequest) _then;

/// Create a copy of LiveEditResolutionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? workingDirectory = null,Object? bubbleId = freezed,Object? instructionText = freezed,Object? primarySelection = freezed,Object? selectedWidgets = null,Object? sourceTargets = null,Object? applyMode = null,Object? selection = freezed,Object? backendId = freezed,Object? inferenceConfig = freezed,Object? intentText = freezed,Object? selectionIntent = freezed,Object? contextEnvelope = freezed,Object? evidence = null,Object? meta = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,workingDirectory: null == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String,bubbleId: freezed == bubbleId ? _self.bubbleId : bubbleId // ignore: cast_nullable_to_non_nullable
as String?,instructionText: freezed == instructionText ? _self.instructionText : instructionText // ignore: cast_nullable_to_non_nullable
as String?,primarySelection: freezed == primarySelection ? _self.primarySelection : primarySelection // ignore: cast_nullable_to_non_nullable
as LiveEditSelection?,selectedWidgets: null == selectedWidgets ? _self.selectedWidgets : selectedWidgets // ignore: cast_nullable_to_non_nullable
as List<LiveEditSelection>,sourceTargets: null == sourceTargets ? _self.sourceTargets : sourceTargets // ignore: cast_nullable_to_non_nullable
as List<LiveEditSourceTarget>,applyMode: null == applyMode ? _self.applyMode : applyMode // ignore: cast_nullable_to_non_nullable
as LiveEditApplyMode,selection: freezed == selection ? _self.selection : selection // ignore: cast_nullable_to_non_nullable
as LiveEditSelection?,backendId: freezed == backendId ? _self.backendId : backendId // ignore: cast_nullable_to_non_nullable
as String?,inferenceConfig: freezed == inferenceConfig ? _self.inferenceConfig : inferenceConfig // ignore: cast_nullable_to_non_nullable
as LiveEditInferenceConfig?,intentText: freezed == intentText ? _self.intentText : intentText // ignore: cast_nullable_to_non_nullable
as String?,selectionIntent: freezed == selectionIntent ? _self.selectionIntent : selectionIntent // ignore: cast_nullable_to_non_nullable
as FlowSelectionIntent?,contextEnvelope: freezed == contextEnvelope ? _self.contextEnvelope : contextEnvelope // ignore: cast_nullable_to_non_nullable
as AgentContextEnvelope?,evidence: null == evidence ? _self.evidence : evidence // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}
/// Create a copy of LiveEditResolutionRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditSelectionCopyWith<$Res>? get primarySelection {
    if (_self.primarySelection == null) {
    return null;
  }

  return $LiveEditSelectionCopyWith<$Res>(_self.primarySelection!, (value) {
    return _then(_self.copyWith(primarySelection: value));
  });
}/// Create a copy of LiveEditResolutionRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditSelectionCopyWith<$Res>? get selection {
    if (_self.selection == null) {
    return null;
  }

  return $LiveEditSelectionCopyWith<$Res>(_self.selection!, (value) {
    return _then(_self.copyWith(selection: value));
  });
}/// Create a copy of LiveEditResolutionRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditInferenceConfigCopyWith<$Res>? get inferenceConfig {
    if (_self.inferenceConfig == null) {
    return null;
  }

  return $LiveEditInferenceConfigCopyWith<$Res>(_self.inferenceConfig!, (value) {
    return _then(_self.copyWith(inferenceConfig: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveEditResolutionRequest].
extension LiveEditResolutionRequestPatterns on LiveEditResolutionRequest {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditResolutionRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditResolutionRequest() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditResolutionRequest value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditResolutionRequest():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditResolutionRequest value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditResolutionRequest() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId,  String workingDirectory,  String? bubbleId,  String? instructionText,  LiveEditSelection? primarySelection,  List<LiveEditSelection> selectedWidgets,  List<LiveEditSourceTarget> sourceTargets,  LiveEditApplyMode applyMode,  LiveEditSelection? selection,  String? backendId,  LiveEditInferenceConfig? inferenceConfig,  String? intentText, @JsonKey(fromJson: _parseFlowSelectionIntent, toJson: _flowSelectionIntentToJson)  FlowSelectionIntent? selectionIntent, @JsonKey(fromJson: _parseAgentContextEnvelope, toJson: _agentContextEnvelopeToJson)  AgentContextEnvelope? contextEnvelope,  Map<String, Object?> evidence,  Map<String, Object?> meta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditResolutionRequest() when $default != null:
return $default(_that.sessionId,_that.workingDirectory,_that.bubbleId,_that.instructionText,_that.primarySelection,_that.selectedWidgets,_that.sourceTargets,_that.applyMode,_that.selection,_that.backendId,_that.inferenceConfig,_that.intentText,_that.selectionIntent,_that.contextEnvelope,_that.evidence,_that.meta);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId,  String workingDirectory,  String? bubbleId,  String? instructionText,  LiveEditSelection? primarySelection,  List<LiveEditSelection> selectedWidgets,  List<LiveEditSourceTarget> sourceTargets,  LiveEditApplyMode applyMode,  LiveEditSelection? selection,  String? backendId,  LiveEditInferenceConfig? inferenceConfig,  String? intentText, @JsonKey(fromJson: _parseFlowSelectionIntent, toJson: _flowSelectionIntentToJson)  FlowSelectionIntent? selectionIntent, @JsonKey(fromJson: _parseAgentContextEnvelope, toJson: _agentContextEnvelopeToJson)  AgentContextEnvelope? contextEnvelope,  Map<String, Object?> evidence,  Map<String, Object?> meta)  $default,) {final _that = this;
switch (_that) {
case _LiveEditResolutionRequest():
return $default(_that.sessionId,_that.workingDirectory,_that.bubbleId,_that.instructionText,_that.primarySelection,_that.selectedWidgets,_that.sourceTargets,_that.applyMode,_that.selection,_that.backendId,_that.inferenceConfig,_that.intentText,_that.selectionIntent,_that.contextEnvelope,_that.evidence,_that.meta);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId,  String workingDirectory,  String? bubbleId,  String? instructionText,  LiveEditSelection? primarySelection,  List<LiveEditSelection> selectedWidgets,  List<LiveEditSourceTarget> sourceTargets,  LiveEditApplyMode applyMode,  LiveEditSelection? selection,  String? backendId,  LiveEditInferenceConfig? inferenceConfig,  String? intentText, @JsonKey(fromJson: _parseFlowSelectionIntent, toJson: _flowSelectionIntentToJson)  FlowSelectionIntent? selectionIntent, @JsonKey(fromJson: _parseAgentContextEnvelope, toJson: _agentContextEnvelopeToJson)  AgentContextEnvelope? contextEnvelope,  Map<String, Object?> evidence,  Map<String, Object?> meta)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditResolutionRequest() when $default != null:
return $default(_that.sessionId,_that.workingDirectory,_that.bubbleId,_that.instructionText,_that.primarySelection,_that.selectedWidgets,_that.sourceTargets,_that.applyMode,_that.selection,_that.backendId,_that.inferenceConfig,_that.intentText,_that.selectionIntent,_that.contextEnvelope,_that.evidence,_that.meta);case _:
  return null;

}
}

}

/// @nodoc


class _LiveEditResolutionRequest extends LiveEditResolutionRequest {
  const _LiveEditResolutionRequest({required this.sessionId, required this.workingDirectory, this.bubbleId, this.instructionText, this.primarySelection, final  List<LiveEditSelection> selectedWidgets = const <LiveEditSelection>[], final  List<LiveEditSourceTarget> sourceTargets = const <LiveEditSourceTarget>[], this.applyMode = LiveEditApplyMode.singleBubble, this.selection, this.backendId, this.inferenceConfig, this.intentText, @JsonKey(fromJson: _parseFlowSelectionIntent, toJson: _flowSelectionIntentToJson) this.selectionIntent, @JsonKey(fromJson: _parseAgentContextEnvelope, toJson: _agentContextEnvelopeToJson) this.contextEnvelope, final  Map<String, Object?> evidence = const <String, Object?>{}, final  Map<String, Object?> meta = const <String, Object?>{}}): _selectedWidgets = selectedWidgets,_sourceTargets = sourceTargets,_evidence = evidence,_meta = meta,super._();
  

@override final  String sessionId;
@override final  String workingDirectory;
@override final  String? bubbleId;
@override final  String? instructionText;
@override final  LiveEditSelection? primarySelection;
 final  List<LiveEditSelection> _selectedWidgets;
@override@JsonKey() List<LiveEditSelection> get selectedWidgets {
  if (_selectedWidgets is EqualUnmodifiableListView) return _selectedWidgets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_selectedWidgets);
}

 final  List<LiveEditSourceTarget> _sourceTargets;
@override@JsonKey() List<LiveEditSourceTarget> get sourceTargets {
  if (_sourceTargets is EqualUnmodifiableListView) return _sourceTargets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sourceTargets);
}

@override@JsonKey() final  LiveEditApplyMode applyMode;
@override final  LiveEditSelection? selection;
@override final  String? backendId;
@override final  LiveEditInferenceConfig? inferenceConfig;
@override final  String? intentText;
@override@JsonKey(fromJson: _parseFlowSelectionIntent, toJson: _flowSelectionIntentToJson) final  FlowSelectionIntent? selectionIntent;
@override@JsonKey(fromJson: _parseAgentContextEnvelope, toJson: _agentContextEnvelopeToJson) final  AgentContextEnvelope? contextEnvelope;
 final  Map<String, Object?> _evidence;
@override@JsonKey() Map<String, Object?> get evidence {
  if (_evidence is EqualUnmodifiableMapView) return _evidence;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_evidence);
}

 final  Map<String, Object?> _meta;
@override@JsonKey() Map<String, Object?> get meta {
  if (_meta is EqualUnmodifiableMapView) return _meta;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_meta);
}


/// Create a copy of LiveEditResolutionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditResolutionRequestCopyWith<_LiveEditResolutionRequest> get copyWith => __$LiveEditResolutionRequestCopyWithImpl<_LiveEditResolutionRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditResolutionRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.workingDirectory, workingDirectory) || other.workingDirectory == workingDirectory)&&(identical(other.bubbleId, bubbleId) || other.bubbleId == bubbleId)&&(identical(other.instructionText, instructionText) || other.instructionText == instructionText)&&(identical(other.primarySelection, primarySelection) || other.primarySelection == primarySelection)&&const DeepCollectionEquality().equals(other._selectedWidgets, _selectedWidgets)&&const DeepCollectionEquality().equals(other._sourceTargets, _sourceTargets)&&(identical(other.applyMode, applyMode) || other.applyMode == applyMode)&&(identical(other.selection, selection) || other.selection == selection)&&(identical(other.backendId, backendId) || other.backendId == backendId)&&(identical(other.inferenceConfig, inferenceConfig) || other.inferenceConfig == inferenceConfig)&&(identical(other.intentText, intentText) || other.intentText == intentText)&&const DeepCollectionEquality().equals(other.selectionIntent, selectionIntent)&&const DeepCollectionEquality().equals(other.contextEnvelope, contextEnvelope)&&const DeepCollectionEquality().equals(other._evidence, _evidence)&&const DeepCollectionEquality().equals(other._meta, _meta));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,workingDirectory,bubbleId,instructionText,primarySelection,const DeepCollectionEquality().hash(_selectedWidgets),const DeepCollectionEquality().hash(_sourceTargets),applyMode,selection,backendId,inferenceConfig,intentText,const DeepCollectionEquality().hash(selectionIntent),const DeepCollectionEquality().hash(contextEnvelope),const DeepCollectionEquality().hash(_evidence),const DeepCollectionEquality().hash(_meta));

@override
String toString() {
  return 'LiveEditResolutionRequest(sessionId: $sessionId, workingDirectory: $workingDirectory, bubbleId: $bubbleId, instructionText: $instructionText, primarySelection: $primarySelection, selectedWidgets: $selectedWidgets, sourceTargets: $sourceTargets, applyMode: $applyMode, selection: $selection, backendId: $backendId, inferenceConfig: $inferenceConfig, intentText: $intentText, selectionIntent: $selectionIntent, contextEnvelope: $contextEnvelope, evidence: $evidence, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$LiveEditResolutionRequestCopyWith<$Res> implements $LiveEditResolutionRequestCopyWith<$Res> {
  factory _$LiveEditResolutionRequestCopyWith(_LiveEditResolutionRequest value, $Res Function(_LiveEditResolutionRequest) _then) = __$LiveEditResolutionRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String workingDirectory, String? bubbleId, String? instructionText, LiveEditSelection? primarySelection, List<LiveEditSelection> selectedWidgets, List<LiveEditSourceTarget> sourceTargets, LiveEditApplyMode applyMode, LiveEditSelection? selection, String? backendId, LiveEditInferenceConfig? inferenceConfig, String? intentText,@JsonKey(fromJson: _parseFlowSelectionIntent, toJson: _flowSelectionIntentToJson) FlowSelectionIntent? selectionIntent,@JsonKey(fromJson: _parseAgentContextEnvelope, toJson: _agentContextEnvelopeToJson) AgentContextEnvelope? contextEnvelope, Map<String, Object?> evidence, Map<String, Object?> meta
});


@override $LiveEditSelectionCopyWith<$Res>? get primarySelection;@override $LiveEditSelectionCopyWith<$Res>? get selection;@override $LiveEditInferenceConfigCopyWith<$Res>? get inferenceConfig;

}
/// @nodoc
class __$LiveEditResolutionRequestCopyWithImpl<$Res>
    implements _$LiveEditResolutionRequestCopyWith<$Res> {
  __$LiveEditResolutionRequestCopyWithImpl(this._self, this._then);

  final _LiveEditResolutionRequest _self;
  final $Res Function(_LiveEditResolutionRequest) _then;

/// Create a copy of LiveEditResolutionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? workingDirectory = null,Object? bubbleId = freezed,Object? instructionText = freezed,Object? primarySelection = freezed,Object? selectedWidgets = null,Object? sourceTargets = null,Object? applyMode = null,Object? selection = freezed,Object? backendId = freezed,Object? inferenceConfig = freezed,Object? intentText = freezed,Object? selectionIntent = freezed,Object? contextEnvelope = freezed,Object? evidence = null,Object? meta = null,}) {
  return _then(_LiveEditResolutionRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,workingDirectory: null == workingDirectory ? _self.workingDirectory : workingDirectory // ignore: cast_nullable_to_non_nullable
as String,bubbleId: freezed == bubbleId ? _self.bubbleId : bubbleId // ignore: cast_nullable_to_non_nullable
as String?,instructionText: freezed == instructionText ? _self.instructionText : instructionText // ignore: cast_nullable_to_non_nullable
as String?,primarySelection: freezed == primarySelection ? _self.primarySelection : primarySelection // ignore: cast_nullable_to_non_nullable
as LiveEditSelection?,selectedWidgets: null == selectedWidgets ? _self._selectedWidgets : selectedWidgets // ignore: cast_nullable_to_non_nullable
as List<LiveEditSelection>,sourceTargets: null == sourceTargets ? _self._sourceTargets : sourceTargets // ignore: cast_nullable_to_non_nullable
as List<LiveEditSourceTarget>,applyMode: null == applyMode ? _self.applyMode : applyMode // ignore: cast_nullable_to_non_nullable
as LiveEditApplyMode,selection: freezed == selection ? _self.selection : selection // ignore: cast_nullable_to_non_nullable
as LiveEditSelection?,backendId: freezed == backendId ? _self.backendId : backendId // ignore: cast_nullable_to_non_nullable
as String?,inferenceConfig: freezed == inferenceConfig ? _self.inferenceConfig : inferenceConfig // ignore: cast_nullable_to_non_nullable
as LiveEditInferenceConfig?,intentText: freezed == intentText ? _self.intentText : intentText // ignore: cast_nullable_to_non_nullable
as String?,selectionIntent: freezed == selectionIntent ? _self.selectionIntent : selectionIntent // ignore: cast_nullable_to_non_nullable
as FlowSelectionIntent?,contextEnvelope: freezed == contextEnvelope ? _self.contextEnvelope : contextEnvelope // ignore: cast_nullable_to_non_nullable
as AgentContextEnvelope?,evidence: null == evidence ? _self._evidence : evidence // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,meta: null == meta ? _self._meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

/// Create a copy of LiveEditResolutionRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditSelectionCopyWith<$Res>? get primarySelection {
    if (_self.primarySelection == null) {
    return null;
  }

  return $LiveEditSelectionCopyWith<$Res>(_self.primarySelection!, (value) {
    return _then(_self.copyWith(primarySelection: value));
  });
}/// Create a copy of LiveEditResolutionRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditSelectionCopyWith<$Res>? get selection {
    if (_self.selection == null) {
    return null;
  }

  return $LiveEditSelectionCopyWith<$Res>(_self.selection!, (value) {
    return _then(_self.copyWith(selection: value));
  });
}/// Create a copy of LiveEditResolutionRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditInferenceConfigCopyWith<$Res>? get inferenceConfig {
    if (_self.inferenceConfig == null) {
    return null;
  }

  return $LiveEditInferenceConfigCopyWith<$Res>(_self.inferenceConfig!, (value) {
    return _then(_self.copyWith(inferenceConfig: value));
  });
}
}


/// @nodoc
mixin _$LiveEditSourceTarget {

 String get nodeId; String get widgetType; String? get absolutePath; String? get workspacePath; int? get line; int? get column;
/// Create a copy of LiveEditSourceTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditSourceTargetCopyWith<LiveEditSourceTarget> get copyWith => _$LiveEditSourceTargetCopyWithImpl<LiveEditSourceTarget>(this as LiveEditSourceTarget, _$identity);

  /// Serializes this LiveEditSourceTarget to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditSourceTarget&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.widgetType, widgetType) || other.widgetType == widgetType)&&(identical(other.absolutePath, absolutePath) || other.absolutePath == absolutePath)&&(identical(other.workspacePath, workspacePath) || other.workspacePath == workspacePath)&&(identical(other.line, line) || other.line == line)&&(identical(other.column, column) || other.column == column));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,nodeId,widgetType,absolutePath,workspacePath,line,column);

@override
String toString() {
  return 'LiveEditSourceTarget(nodeId: $nodeId, widgetType: $widgetType, absolutePath: $absolutePath, workspacePath: $workspacePath, line: $line, column: $column)';
}


}

/// @nodoc
abstract mixin class $LiveEditSourceTargetCopyWith<$Res>  {
  factory $LiveEditSourceTargetCopyWith(LiveEditSourceTarget value, $Res Function(LiveEditSourceTarget) _then) = _$LiveEditSourceTargetCopyWithImpl;
@useResult
$Res call({
 String nodeId, String widgetType, String? absolutePath, String? workspacePath, int? line, int? column
});




}
/// @nodoc
class _$LiveEditSourceTargetCopyWithImpl<$Res>
    implements $LiveEditSourceTargetCopyWith<$Res> {
  _$LiveEditSourceTargetCopyWithImpl(this._self, this._then);

  final LiveEditSourceTarget _self;
  final $Res Function(LiveEditSourceTarget) _then;

/// Create a copy of LiveEditSourceTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? nodeId = null,Object? widgetType = null,Object? absolutePath = freezed,Object? workspacePath = freezed,Object? line = freezed,Object? column = freezed,}) {
  return _then(_self.copyWith(
nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,widgetType: null == widgetType ? _self.widgetType : widgetType // ignore: cast_nullable_to_non_nullable
as String,absolutePath: freezed == absolutePath ? _self.absolutePath : absolutePath // ignore: cast_nullable_to_non_nullable
as String?,workspacePath: freezed == workspacePath ? _self.workspacePath : workspacePath // ignore: cast_nullable_to_non_nullable
as String?,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,column: freezed == column ? _self.column : column // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveEditSourceTarget].
extension LiveEditSourceTargetPatterns on LiveEditSourceTarget {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditSourceTarget value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditSourceTarget() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditSourceTarget value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditSourceTarget():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditSourceTarget value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditSourceTarget() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String nodeId,  String widgetType,  String? absolutePath,  String? workspacePath,  int? line,  int? column)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditSourceTarget() when $default != null:
return $default(_that.nodeId,_that.widgetType,_that.absolutePath,_that.workspacePath,_that.line,_that.column);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String nodeId,  String widgetType,  String? absolutePath,  String? workspacePath,  int? line,  int? column)  $default,) {final _that = this;
switch (_that) {
case _LiveEditSourceTarget():
return $default(_that.nodeId,_that.widgetType,_that.absolutePath,_that.workspacePath,_that.line,_that.column);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String nodeId,  String widgetType,  String? absolutePath,  String? workspacePath,  int? line,  int? column)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditSourceTarget() when $default != null:
return $default(_that.nodeId,_that.widgetType,_that.absolutePath,_that.workspacePath,_that.line,_that.column);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEditSourceTarget implements LiveEditSourceTarget {
  const _LiveEditSourceTarget({required this.nodeId, required this.widgetType, this.absolutePath, this.workspacePath, this.line, this.column});
  factory _LiveEditSourceTarget.fromJson(Map<String, dynamic> json) => _$LiveEditSourceTargetFromJson(json);

@override final  String nodeId;
@override final  String widgetType;
@override final  String? absolutePath;
@override final  String? workspacePath;
@override final  int? line;
@override final  int? column;

/// Create a copy of LiveEditSourceTarget
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditSourceTargetCopyWith<_LiveEditSourceTarget> get copyWith => __$LiveEditSourceTargetCopyWithImpl<_LiveEditSourceTarget>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEditSourceTargetToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditSourceTarget&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.widgetType, widgetType) || other.widgetType == widgetType)&&(identical(other.absolutePath, absolutePath) || other.absolutePath == absolutePath)&&(identical(other.workspacePath, workspacePath) || other.workspacePath == workspacePath)&&(identical(other.line, line) || other.line == line)&&(identical(other.column, column) || other.column == column));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,nodeId,widgetType,absolutePath,workspacePath,line,column);

@override
String toString() {
  return 'LiveEditSourceTarget(nodeId: $nodeId, widgetType: $widgetType, absolutePath: $absolutePath, workspacePath: $workspacePath, line: $line, column: $column)';
}


}

/// @nodoc
abstract mixin class _$LiveEditSourceTargetCopyWith<$Res> implements $LiveEditSourceTargetCopyWith<$Res> {
  factory _$LiveEditSourceTargetCopyWith(_LiveEditSourceTarget value, $Res Function(_LiveEditSourceTarget) _then) = __$LiveEditSourceTargetCopyWithImpl;
@override @useResult
$Res call({
 String nodeId, String widgetType, String? absolutePath, String? workspacePath, int? line, int? column
});




}
/// @nodoc
class __$LiveEditSourceTargetCopyWithImpl<$Res>
    implements _$LiveEditSourceTargetCopyWith<$Res> {
  __$LiveEditSourceTargetCopyWithImpl(this._self, this._then);

  final _LiveEditSourceTarget _self;
  final $Res Function(_LiveEditSourceTarget) _then;

/// Create a copy of LiveEditSourceTarget
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? nodeId = null,Object? widgetType = null,Object? absolutePath = freezed,Object? workspacePath = freezed,Object? line = freezed,Object? column = freezed,}) {
  return _then(_LiveEditSourceTarget(
nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,widgetType: null == widgetType ? _self.widgetType : widgetType // ignore: cast_nullable_to_non_nullable
as String,absolutePath: freezed == absolutePath ? _self.absolutePath : absolutePath // ignore: cast_nullable_to_non_nullable
as String?,workspacePath: freezed == workspacePath ? _self.workspacePath : workspacePath // ignore: cast_nullable_to_non_nullable
as String?,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,column: freezed == column ? _self.column : column // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$LiveEditDirectApplyResult {

 String get executionId; String get backendId; String get summary; List<String> get changedFiles; List<String> get warnings; List<String> get validationSteps; LiveEditRuntimeRefreshResult? get runtimeRefresh; Map<String, Object?> get meta;
/// Create a copy of LiveEditDirectApplyResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditDirectApplyResultCopyWith<LiveEditDirectApplyResult> get copyWith => _$LiveEditDirectApplyResultCopyWithImpl<LiveEditDirectApplyResult>(this as LiveEditDirectApplyResult, _$identity);

  /// Serializes this LiveEditDirectApplyResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditDirectApplyResult&&(identical(other.executionId, executionId) || other.executionId == executionId)&&(identical(other.backendId, backendId) || other.backendId == backendId)&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other.changedFiles, changedFiles)&&const DeepCollectionEquality().equals(other.warnings, warnings)&&const DeepCollectionEquality().equals(other.validationSteps, validationSteps)&&(identical(other.runtimeRefresh, runtimeRefresh) || other.runtimeRefresh == runtimeRefresh)&&const DeepCollectionEquality().equals(other.meta, meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,executionId,backendId,summary,const DeepCollectionEquality().hash(changedFiles),const DeepCollectionEquality().hash(warnings),const DeepCollectionEquality().hash(validationSteps),runtimeRefresh,const DeepCollectionEquality().hash(meta));

@override
String toString() {
  return 'LiveEditDirectApplyResult(executionId: $executionId, backendId: $backendId, summary: $summary, changedFiles: $changedFiles, warnings: $warnings, validationSteps: $validationSteps, runtimeRefresh: $runtimeRefresh, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $LiveEditDirectApplyResultCopyWith<$Res>  {
  factory $LiveEditDirectApplyResultCopyWith(LiveEditDirectApplyResult value, $Res Function(LiveEditDirectApplyResult) _then) = _$LiveEditDirectApplyResultCopyWithImpl;
@useResult
$Res call({
 String executionId, String backendId, String summary, List<String> changedFiles, List<String> warnings, List<String> validationSteps, LiveEditRuntimeRefreshResult? runtimeRefresh, Map<String, Object?> meta
});


$LiveEditRuntimeRefreshResultCopyWith<$Res>? get runtimeRefresh;

}
/// @nodoc
class _$LiveEditDirectApplyResultCopyWithImpl<$Res>
    implements $LiveEditDirectApplyResultCopyWith<$Res> {
  _$LiveEditDirectApplyResultCopyWithImpl(this._self, this._then);

  final LiveEditDirectApplyResult _self;
  final $Res Function(LiveEditDirectApplyResult) _then;

/// Create a copy of LiveEditDirectApplyResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? executionId = null,Object? backendId = null,Object? summary = null,Object? changedFiles = null,Object? warnings = null,Object? validationSteps = null,Object? runtimeRefresh = freezed,Object? meta = null,}) {
  return _then(_self.copyWith(
executionId: null == executionId ? _self.executionId : executionId // ignore: cast_nullable_to_non_nullable
as String,backendId: null == backendId ? _self.backendId : backendId // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,changedFiles: null == changedFiles ? _self.changedFiles : changedFiles // ignore: cast_nullable_to_non_nullable
as List<String>,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,validationSteps: null == validationSteps ? _self.validationSteps : validationSteps // ignore: cast_nullable_to_non_nullable
as List<String>,runtimeRefresh: freezed == runtimeRefresh ? _self.runtimeRefresh : runtimeRefresh // ignore: cast_nullable_to_non_nullable
as LiveEditRuntimeRefreshResult?,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}
/// Create a copy of LiveEditDirectApplyResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditRuntimeRefreshResultCopyWith<$Res>? get runtimeRefresh {
    if (_self.runtimeRefresh == null) {
    return null;
  }

  return $LiveEditRuntimeRefreshResultCopyWith<$Res>(_self.runtimeRefresh!, (value) {
    return _then(_self.copyWith(runtimeRefresh: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveEditDirectApplyResult].
extension LiveEditDirectApplyResultPatterns on LiveEditDirectApplyResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditDirectApplyResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditDirectApplyResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditDirectApplyResult value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditDirectApplyResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditDirectApplyResult value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditDirectApplyResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String executionId,  String backendId,  String summary,  List<String> changedFiles,  List<String> warnings,  List<String> validationSteps,  LiveEditRuntimeRefreshResult? runtimeRefresh,  Map<String, Object?> meta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditDirectApplyResult() when $default != null:
return $default(_that.executionId,_that.backendId,_that.summary,_that.changedFiles,_that.warnings,_that.validationSteps,_that.runtimeRefresh,_that.meta);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String executionId,  String backendId,  String summary,  List<String> changedFiles,  List<String> warnings,  List<String> validationSteps,  LiveEditRuntimeRefreshResult? runtimeRefresh,  Map<String, Object?> meta)  $default,) {final _that = this;
switch (_that) {
case _LiveEditDirectApplyResult():
return $default(_that.executionId,_that.backendId,_that.summary,_that.changedFiles,_that.warnings,_that.validationSteps,_that.runtimeRefresh,_that.meta);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String executionId,  String backendId,  String summary,  List<String> changedFiles,  List<String> warnings,  List<String> validationSteps,  LiveEditRuntimeRefreshResult? runtimeRefresh,  Map<String, Object?> meta)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditDirectApplyResult() when $default != null:
return $default(_that.executionId,_that.backendId,_that.summary,_that.changedFiles,_that.warnings,_that.validationSteps,_that.runtimeRefresh,_that.meta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEditDirectApplyResult implements LiveEditDirectApplyResult {
  const _LiveEditDirectApplyResult({required this.executionId, required this.backendId, required this.summary, final  List<String> changedFiles = const <String>[], final  List<String> warnings = const <String>[], final  List<String> validationSteps = const <String>[], this.runtimeRefresh, final  Map<String, Object?> meta = const <String, Object?>{}}): _changedFiles = changedFiles,_warnings = warnings,_validationSteps = validationSteps,_meta = meta;
  factory _LiveEditDirectApplyResult.fromJson(Map<String, dynamic> json) => _$LiveEditDirectApplyResultFromJson(json);

@override final  String executionId;
@override final  String backendId;
@override final  String summary;
 final  List<String> _changedFiles;
@override@JsonKey() List<String> get changedFiles {
  if (_changedFiles is EqualUnmodifiableListView) return _changedFiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_changedFiles);
}

 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}

 final  List<String> _validationSteps;
@override@JsonKey() List<String> get validationSteps {
  if (_validationSteps is EqualUnmodifiableListView) return _validationSteps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_validationSteps);
}

@override final  LiveEditRuntimeRefreshResult? runtimeRefresh;
 final  Map<String, Object?> _meta;
@override@JsonKey() Map<String, Object?> get meta {
  if (_meta is EqualUnmodifiableMapView) return _meta;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_meta);
}


/// Create a copy of LiveEditDirectApplyResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditDirectApplyResultCopyWith<_LiveEditDirectApplyResult> get copyWith => __$LiveEditDirectApplyResultCopyWithImpl<_LiveEditDirectApplyResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEditDirectApplyResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditDirectApplyResult&&(identical(other.executionId, executionId) || other.executionId == executionId)&&(identical(other.backendId, backendId) || other.backendId == backendId)&&(identical(other.summary, summary) || other.summary == summary)&&const DeepCollectionEquality().equals(other._changedFiles, _changedFiles)&&const DeepCollectionEquality().equals(other._warnings, _warnings)&&const DeepCollectionEquality().equals(other._validationSteps, _validationSteps)&&(identical(other.runtimeRefresh, runtimeRefresh) || other.runtimeRefresh == runtimeRefresh)&&const DeepCollectionEquality().equals(other._meta, _meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,executionId,backendId,summary,const DeepCollectionEquality().hash(_changedFiles),const DeepCollectionEquality().hash(_warnings),const DeepCollectionEquality().hash(_validationSteps),runtimeRefresh,const DeepCollectionEquality().hash(_meta));

@override
String toString() {
  return 'LiveEditDirectApplyResult(executionId: $executionId, backendId: $backendId, summary: $summary, changedFiles: $changedFiles, warnings: $warnings, validationSteps: $validationSteps, runtimeRefresh: $runtimeRefresh, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$LiveEditDirectApplyResultCopyWith<$Res> implements $LiveEditDirectApplyResultCopyWith<$Res> {
  factory _$LiveEditDirectApplyResultCopyWith(_LiveEditDirectApplyResult value, $Res Function(_LiveEditDirectApplyResult) _then) = __$LiveEditDirectApplyResultCopyWithImpl;
@override @useResult
$Res call({
 String executionId, String backendId, String summary, List<String> changedFiles, List<String> warnings, List<String> validationSteps, LiveEditRuntimeRefreshResult? runtimeRefresh, Map<String, Object?> meta
});


@override $LiveEditRuntimeRefreshResultCopyWith<$Res>? get runtimeRefresh;

}
/// @nodoc
class __$LiveEditDirectApplyResultCopyWithImpl<$Res>
    implements _$LiveEditDirectApplyResultCopyWith<$Res> {
  __$LiveEditDirectApplyResultCopyWithImpl(this._self, this._then);

  final _LiveEditDirectApplyResult _self;
  final $Res Function(_LiveEditDirectApplyResult) _then;

/// Create a copy of LiveEditDirectApplyResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? executionId = null,Object? backendId = null,Object? summary = null,Object? changedFiles = null,Object? warnings = null,Object? validationSteps = null,Object? runtimeRefresh = freezed,Object? meta = null,}) {
  return _then(_LiveEditDirectApplyResult(
executionId: null == executionId ? _self.executionId : executionId // ignore: cast_nullable_to_non_nullable
as String,backendId: null == backendId ? _self.backendId : backendId // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,changedFiles: null == changedFiles ? _self._changedFiles : changedFiles // ignore: cast_nullable_to_non_nullable
as List<String>,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,validationSteps: null == validationSteps ? _self._validationSteps : validationSteps // ignore: cast_nullable_to_non_nullable
as List<String>,runtimeRefresh: freezed == runtimeRefresh ? _self.runtimeRefresh : runtimeRefresh // ignore: cast_nullable_to_non_nullable
as LiveEditRuntimeRefreshResult?,meta: null == meta ? _self._meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

/// Create a copy of LiveEditDirectApplyResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditRuntimeRefreshResultCopyWith<$Res>? get runtimeRefresh {
    if (_self.runtimeRefresh == null) {
    return null;
  }

  return $LiveEditRuntimeRefreshResultCopyWith<$Res>(_self.runtimeRefresh!, (value) {
    return _then(_self.copyWith(runtimeRefresh: value));
  });
}
}


/// @nodoc
mixin _$LiveEditResolutionResult {

 String get proposalId; LiveEditResolutionStatus get status; List<String> get changedFiles; Map<String, Object?> get validation; List<String> get warnings; Map<String, Object?> get meta;
/// Create a copy of LiveEditResolutionResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditResolutionResultCopyWith<LiveEditResolutionResult> get copyWith => _$LiveEditResolutionResultCopyWithImpl<LiveEditResolutionResult>(this as LiveEditResolutionResult, _$identity);

  /// Serializes this LiveEditResolutionResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditResolutionResult&&(identical(other.proposalId, proposalId) || other.proposalId == proposalId)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.changedFiles, changedFiles)&&const DeepCollectionEquality().equals(other.validation, validation)&&const DeepCollectionEquality().equals(other.warnings, warnings)&&const DeepCollectionEquality().equals(other.meta, meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,proposalId,status,const DeepCollectionEquality().hash(changedFiles),const DeepCollectionEquality().hash(validation),const DeepCollectionEquality().hash(warnings),const DeepCollectionEquality().hash(meta));

@override
String toString() {
  return 'LiveEditResolutionResult(proposalId: $proposalId, status: $status, changedFiles: $changedFiles, validation: $validation, warnings: $warnings, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $LiveEditResolutionResultCopyWith<$Res>  {
  factory $LiveEditResolutionResultCopyWith(LiveEditResolutionResult value, $Res Function(LiveEditResolutionResult) _then) = _$LiveEditResolutionResultCopyWithImpl;
@useResult
$Res call({
 String proposalId, LiveEditResolutionStatus status, List<String> changedFiles, Map<String, Object?> validation, List<String> warnings, Map<String, Object?> meta
});




}
/// @nodoc
class _$LiveEditResolutionResultCopyWithImpl<$Res>
    implements $LiveEditResolutionResultCopyWith<$Res> {
  _$LiveEditResolutionResultCopyWithImpl(this._self, this._then);

  final LiveEditResolutionResult _self;
  final $Res Function(LiveEditResolutionResult) _then;

/// Create a copy of LiveEditResolutionResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? proposalId = null,Object? status = null,Object? changedFiles = null,Object? validation = null,Object? warnings = null,Object? meta = null,}) {
  return _then(_self.copyWith(
proposalId: null == proposalId ? _self.proposalId : proposalId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LiveEditResolutionStatus,changedFiles: null == changedFiles ? _self.changedFiles : changedFiles // ignore: cast_nullable_to_non_nullable
as List<String>,validation: null == validation ? _self.validation : validation // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,warnings: null == warnings ? _self.warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveEditResolutionResult].
extension LiveEditResolutionResultPatterns on LiveEditResolutionResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditResolutionResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditResolutionResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditResolutionResult value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditResolutionResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditResolutionResult value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditResolutionResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String proposalId,  LiveEditResolutionStatus status,  List<String> changedFiles,  Map<String, Object?> validation,  List<String> warnings,  Map<String, Object?> meta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditResolutionResult() when $default != null:
return $default(_that.proposalId,_that.status,_that.changedFiles,_that.validation,_that.warnings,_that.meta);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String proposalId,  LiveEditResolutionStatus status,  List<String> changedFiles,  Map<String, Object?> validation,  List<String> warnings,  Map<String, Object?> meta)  $default,) {final _that = this;
switch (_that) {
case _LiveEditResolutionResult():
return $default(_that.proposalId,_that.status,_that.changedFiles,_that.validation,_that.warnings,_that.meta);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String proposalId,  LiveEditResolutionStatus status,  List<String> changedFiles,  Map<String, Object?> validation,  List<String> warnings,  Map<String, Object?> meta)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditResolutionResult() when $default != null:
return $default(_that.proposalId,_that.status,_that.changedFiles,_that.validation,_that.warnings,_that.meta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEditResolutionResult implements LiveEditResolutionResult {
  const _LiveEditResolutionResult({required this.proposalId, required this.status, final  List<String> changedFiles = const <String>[], final  Map<String, Object?> validation = const <String, Object?>{}, final  List<String> warnings = const <String>[], final  Map<String, Object?> meta = const <String, Object?>{}}): _changedFiles = changedFiles,_validation = validation,_warnings = warnings,_meta = meta;
  factory _LiveEditResolutionResult.fromJson(Map<String, dynamic> json) => _$LiveEditResolutionResultFromJson(json);

@override final  String proposalId;
@override final  LiveEditResolutionStatus status;
 final  List<String> _changedFiles;
@override@JsonKey() List<String> get changedFiles {
  if (_changedFiles is EqualUnmodifiableListView) return _changedFiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_changedFiles);
}

 final  Map<String, Object?> _validation;
@override@JsonKey() Map<String, Object?> get validation {
  if (_validation is EqualUnmodifiableMapView) return _validation;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_validation);
}

 final  List<String> _warnings;
@override@JsonKey() List<String> get warnings {
  if (_warnings is EqualUnmodifiableListView) return _warnings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warnings);
}

 final  Map<String, Object?> _meta;
@override@JsonKey() Map<String, Object?> get meta {
  if (_meta is EqualUnmodifiableMapView) return _meta;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_meta);
}


/// Create a copy of LiveEditResolutionResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditResolutionResultCopyWith<_LiveEditResolutionResult> get copyWith => __$LiveEditResolutionResultCopyWithImpl<_LiveEditResolutionResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEditResolutionResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditResolutionResult&&(identical(other.proposalId, proposalId) || other.proposalId == proposalId)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._changedFiles, _changedFiles)&&const DeepCollectionEquality().equals(other._validation, _validation)&&const DeepCollectionEquality().equals(other._warnings, _warnings)&&const DeepCollectionEquality().equals(other._meta, _meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,proposalId,status,const DeepCollectionEquality().hash(_changedFiles),const DeepCollectionEquality().hash(_validation),const DeepCollectionEquality().hash(_warnings),const DeepCollectionEquality().hash(_meta));

@override
String toString() {
  return 'LiveEditResolutionResult(proposalId: $proposalId, status: $status, changedFiles: $changedFiles, validation: $validation, warnings: $warnings, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$LiveEditResolutionResultCopyWith<$Res> implements $LiveEditResolutionResultCopyWith<$Res> {
  factory _$LiveEditResolutionResultCopyWith(_LiveEditResolutionResult value, $Res Function(_LiveEditResolutionResult) _then) = __$LiveEditResolutionResultCopyWithImpl;
@override @useResult
$Res call({
 String proposalId, LiveEditResolutionStatus status, List<String> changedFiles, Map<String, Object?> validation, List<String> warnings, Map<String, Object?> meta
});




}
/// @nodoc
class __$LiveEditResolutionResultCopyWithImpl<$Res>
    implements _$LiveEditResolutionResultCopyWith<$Res> {
  __$LiveEditResolutionResultCopyWithImpl(this._self, this._then);

  final _LiveEditResolutionResult _self;
  final $Res Function(_LiveEditResolutionResult) _then;

/// Create a copy of LiveEditResolutionResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? proposalId = null,Object? status = null,Object? changedFiles = null,Object? validation = null,Object? warnings = null,Object? meta = null,}) {
  return _then(_LiveEditResolutionResult(
proposalId: null == proposalId ? _self.proposalId : proposalId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LiveEditResolutionStatus,changedFiles: null == changedFiles ? _self._changedFiles : changedFiles // ignore: cast_nullable_to_non_nullable
as List<String>,validation: null == validation ? _self._validation : validation // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,warnings: null == warnings ? _self._warnings : warnings // ignore: cast_nullable_to_non_nullable
as List<String>,meta: null == meta ? _self._meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}


}


/// @nodoc
mixin _$LiveEditSelection {

 String get sessionId;@JsonKey(defaultValue: '') String get selectionKey; String get nodeId; String get widgetType;@JsonKey(fromJson: _asMap) Map<String, Object?> get rawNode;@JsonKey(name: 'properties') List<Object?> get propertiesForWire; LiveEditTargetDomain get targetDomain; String? get renderObjectType; LiveEditBounds? get bounds; LiveEditSourceLocation? get source; Map<String, Object?> get layoutContext; List<Map<String, Object?>> get parentChain; Map<String, Object?> get detailsTree; Map<String, Object?> get propertiesTree; LiveEditSelectionMode get selectionMode; List<String> get selectedNodeIds;
/// Create a copy of LiveEditSelection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditSelectionCopyWith<LiveEditSelection> get copyWith => _$LiveEditSelectionCopyWithImpl<LiveEditSelection>(this as LiveEditSelection, _$identity);

  /// Serializes this LiveEditSelection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditSelection&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.selectionKey, selectionKey) || other.selectionKey == selectionKey)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.widgetType, widgetType) || other.widgetType == widgetType)&&const DeepCollectionEquality().equals(other.rawNode, rawNode)&&const DeepCollectionEquality().equals(other.propertiesForWire, propertiesForWire)&&(identical(other.targetDomain, targetDomain) || other.targetDomain == targetDomain)&&(identical(other.renderObjectType, renderObjectType) || other.renderObjectType == renderObjectType)&&(identical(other.bounds, bounds) || other.bounds == bounds)&&(identical(other.source, source) || other.source == source)&&const DeepCollectionEquality().equals(other.layoutContext, layoutContext)&&const DeepCollectionEquality().equals(other.parentChain, parentChain)&&const DeepCollectionEquality().equals(other.detailsTree, detailsTree)&&const DeepCollectionEquality().equals(other.propertiesTree, propertiesTree)&&(identical(other.selectionMode, selectionMode) || other.selectionMode == selectionMode)&&const DeepCollectionEquality().equals(other.selectedNodeIds, selectedNodeIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,selectionKey,nodeId,widgetType,const DeepCollectionEquality().hash(rawNode),const DeepCollectionEquality().hash(propertiesForWire),targetDomain,renderObjectType,bounds,source,const DeepCollectionEquality().hash(layoutContext),const DeepCollectionEquality().hash(parentChain),const DeepCollectionEquality().hash(detailsTree),const DeepCollectionEquality().hash(propertiesTree),selectionMode,const DeepCollectionEquality().hash(selectedNodeIds));

@override
String toString() {
  return 'LiveEditSelection(sessionId: $sessionId, selectionKey: $selectionKey, nodeId: $nodeId, widgetType: $widgetType, rawNode: $rawNode, propertiesForWire: $propertiesForWire, targetDomain: $targetDomain, renderObjectType: $renderObjectType, bounds: $bounds, source: $source, layoutContext: $layoutContext, parentChain: $parentChain, detailsTree: $detailsTree, propertiesTree: $propertiesTree, selectionMode: $selectionMode, selectedNodeIds: $selectedNodeIds)';
}


}

/// @nodoc
abstract mixin class $LiveEditSelectionCopyWith<$Res>  {
  factory $LiveEditSelectionCopyWith(LiveEditSelection value, $Res Function(LiveEditSelection) _then) = _$LiveEditSelectionCopyWithImpl;
@useResult
$Res call({
 String sessionId,@JsonKey(defaultValue: '') String selectionKey, String nodeId, String widgetType,@JsonKey(fromJson: _asMap) Map<String, Object?> rawNode,@JsonKey(name: 'properties') List<Object?> propertiesForWire, LiveEditTargetDomain targetDomain, String? renderObjectType, LiveEditBounds? bounds, LiveEditSourceLocation? source, Map<String, Object?> layoutContext, List<Map<String, Object?>> parentChain, Map<String, Object?> detailsTree, Map<String, Object?> propertiesTree, LiveEditSelectionMode selectionMode, List<String> selectedNodeIds
});


$LiveEditBoundsCopyWith<$Res>? get bounds;$LiveEditSourceLocationCopyWith<$Res>? get source;

}
/// @nodoc
class _$LiveEditSelectionCopyWithImpl<$Res>
    implements $LiveEditSelectionCopyWith<$Res> {
  _$LiveEditSelectionCopyWithImpl(this._self, this._then);

  final LiveEditSelection _self;
  final $Res Function(LiveEditSelection) _then;

/// Create a copy of LiveEditSelection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? selectionKey = null,Object? nodeId = null,Object? widgetType = null,Object? rawNode = null,Object? propertiesForWire = null,Object? targetDomain = null,Object? renderObjectType = freezed,Object? bounds = freezed,Object? source = freezed,Object? layoutContext = null,Object? parentChain = null,Object? detailsTree = null,Object? propertiesTree = null,Object? selectionMode = null,Object? selectedNodeIds = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,selectionKey: null == selectionKey ? _self.selectionKey : selectionKey // ignore: cast_nullable_to_non_nullable
as String,nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,widgetType: null == widgetType ? _self.widgetType : widgetType // ignore: cast_nullable_to_non_nullable
as String,rawNode: null == rawNode ? _self.rawNode : rawNode // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,propertiesForWire: null == propertiesForWire ? _self.propertiesForWire : propertiesForWire // ignore: cast_nullable_to_non_nullable
as List<Object?>,targetDomain: null == targetDomain ? _self.targetDomain : targetDomain // ignore: cast_nullable_to_non_nullable
as LiveEditTargetDomain,renderObjectType: freezed == renderObjectType ? _self.renderObjectType : renderObjectType // ignore: cast_nullable_to_non_nullable
as String?,bounds: freezed == bounds ? _self.bounds : bounds // ignore: cast_nullable_to_non_nullable
as LiveEditBounds?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as LiveEditSourceLocation?,layoutContext: null == layoutContext ? _self.layoutContext : layoutContext // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,parentChain: null == parentChain ? _self.parentChain : parentChain // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>,detailsTree: null == detailsTree ? _self.detailsTree : detailsTree // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,propertiesTree: null == propertiesTree ? _self.propertiesTree : propertiesTree // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,selectionMode: null == selectionMode ? _self.selectionMode : selectionMode // ignore: cast_nullable_to_non_nullable
as LiveEditSelectionMode,selectedNodeIds: null == selectedNodeIds ? _self.selectedNodeIds : selectedNodeIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of LiveEditSelection
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditBoundsCopyWith<$Res>? get bounds {
    if (_self.bounds == null) {
    return null;
  }

  return $LiveEditBoundsCopyWith<$Res>(_self.bounds!, (value) {
    return _then(_self.copyWith(bounds: value));
  });
}/// Create a copy of LiveEditSelection
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditSourceLocationCopyWith<$Res>? get source {
    if (_self.source == null) {
    return null;
  }

  return $LiveEditSourceLocationCopyWith<$Res>(_self.source!, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveEditSelection].
extension LiveEditSelectionPatterns on LiveEditSelection {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditSelection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditSelection() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditSelection value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditSelection():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditSelection value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditSelection() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String sessionId, @JsonKey(defaultValue: '')  String selectionKey,  String nodeId,  String widgetType, @JsonKey(fromJson: _asMap)  Map<String, Object?> rawNode, @JsonKey(name: 'properties')  List<Object?> propertiesForWire,  LiveEditTargetDomain targetDomain,  String? renderObjectType,  LiveEditBounds? bounds,  LiveEditSourceLocation? source,  Map<String, Object?> layoutContext,  List<Map<String, Object?>> parentChain,  Map<String, Object?> detailsTree,  Map<String, Object?> propertiesTree,  LiveEditSelectionMode selectionMode,  List<String> selectedNodeIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditSelection() when $default != null:
return $default(_that.sessionId,_that.selectionKey,_that.nodeId,_that.widgetType,_that.rawNode,_that.propertiesForWire,_that.targetDomain,_that.renderObjectType,_that.bounds,_that.source,_that.layoutContext,_that.parentChain,_that.detailsTree,_that.propertiesTree,_that.selectionMode,_that.selectedNodeIds);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String sessionId, @JsonKey(defaultValue: '')  String selectionKey,  String nodeId,  String widgetType, @JsonKey(fromJson: _asMap)  Map<String, Object?> rawNode, @JsonKey(name: 'properties')  List<Object?> propertiesForWire,  LiveEditTargetDomain targetDomain,  String? renderObjectType,  LiveEditBounds? bounds,  LiveEditSourceLocation? source,  Map<String, Object?> layoutContext,  List<Map<String, Object?>> parentChain,  Map<String, Object?> detailsTree,  Map<String, Object?> propertiesTree,  LiveEditSelectionMode selectionMode,  List<String> selectedNodeIds)  $default,) {final _that = this;
switch (_that) {
case _LiveEditSelection():
return $default(_that.sessionId,_that.selectionKey,_that.nodeId,_that.widgetType,_that.rawNode,_that.propertiesForWire,_that.targetDomain,_that.renderObjectType,_that.bounds,_that.source,_that.layoutContext,_that.parentChain,_that.detailsTree,_that.propertiesTree,_that.selectionMode,_that.selectedNodeIds);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String sessionId, @JsonKey(defaultValue: '')  String selectionKey,  String nodeId,  String widgetType, @JsonKey(fromJson: _asMap)  Map<String, Object?> rawNode, @JsonKey(name: 'properties')  List<Object?> propertiesForWire,  LiveEditTargetDomain targetDomain,  String? renderObjectType,  LiveEditBounds? bounds,  LiveEditSourceLocation? source,  Map<String, Object?> layoutContext,  List<Map<String, Object?>> parentChain,  Map<String, Object?> detailsTree,  Map<String, Object?> propertiesTree,  LiveEditSelectionMode selectionMode,  List<String> selectedNodeIds)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditSelection() when $default != null:
return $default(_that.sessionId,_that.selectionKey,_that.nodeId,_that.widgetType,_that.rawNode,_that.propertiesForWire,_that.targetDomain,_that.renderObjectType,_that.bounds,_that.source,_that.layoutContext,_that.parentChain,_that.detailsTree,_that.propertiesTree,_that.selectionMode,_that.selectedNodeIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEditSelection implements LiveEditSelection {
  const _LiveEditSelection({required this.sessionId, @JsonKey(defaultValue: '') this.selectionKey = '', required this.nodeId, required this.widgetType, @JsonKey(fromJson: _asMap) required final  Map<String, Object?> rawNode, @JsonKey(name: 'properties') final  List<Object?> propertiesForWire = const <Object?>[], this.targetDomain = LiveEditTargetDomain.appScene, this.renderObjectType, this.bounds, this.source, final  Map<String, Object?> layoutContext = const <String, Object?>{}, final  List<Map<String, Object?>> parentChain = const <Map<String, Object?>>[], final  Map<String, Object?> detailsTree = const <String, Object?>{}, final  Map<String, Object?> propertiesTree = const <String, Object?>{}, this.selectionMode = LiveEditSelectionMode.single, final  List<String> selectedNodeIds = const <String>[]}): _rawNode = rawNode,_propertiesForWire = propertiesForWire,_layoutContext = layoutContext,_parentChain = parentChain,_detailsTree = detailsTree,_propertiesTree = propertiesTree,_selectedNodeIds = selectedNodeIds;
  factory _LiveEditSelection.fromJson(Map<String, dynamic> json) => _$LiveEditSelectionFromJson(json);

@override final  String sessionId;
@override@JsonKey(defaultValue: '') final  String selectionKey;
@override final  String nodeId;
@override final  String widgetType;
 final  Map<String, Object?> _rawNode;
@override@JsonKey(fromJson: _asMap) Map<String, Object?> get rawNode {
  if (_rawNode is EqualUnmodifiableMapView) return _rawNode;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_rawNode);
}

 final  List<Object?> _propertiesForWire;
@override@JsonKey(name: 'properties') List<Object?> get propertiesForWire {
  if (_propertiesForWire is EqualUnmodifiableListView) return _propertiesForWire;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_propertiesForWire);
}

@override@JsonKey() final  LiveEditTargetDomain targetDomain;
@override final  String? renderObjectType;
@override final  LiveEditBounds? bounds;
@override final  LiveEditSourceLocation? source;
 final  Map<String, Object?> _layoutContext;
@override@JsonKey() Map<String, Object?> get layoutContext {
  if (_layoutContext is EqualUnmodifiableMapView) return _layoutContext;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_layoutContext);
}

 final  List<Map<String, Object?>> _parentChain;
@override@JsonKey() List<Map<String, Object?>> get parentChain {
  if (_parentChain is EqualUnmodifiableListView) return _parentChain;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_parentChain);
}

 final  Map<String, Object?> _detailsTree;
@override@JsonKey() Map<String, Object?> get detailsTree {
  if (_detailsTree is EqualUnmodifiableMapView) return _detailsTree;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_detailsTree);
}

 final  Map<String, Object?> _propertiesTree;
@override@JsonKey() Map<String, Object?> get propertiesTree {
  if (_propertiesTree is EqualUnmodifiableMapView) return _propertiesTree;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_propertiesTree);
}

@override@JsonKey() final  LiveEditSelectionMode selectionMode;
 final  List<String> _selectedNodeIds;
@override@JsonKey() List<String> get selectedNodeIds {
  if (_selectedNodeIds is EqualUnmodifiableListView) return _selectedNodeIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_selectedNodeIds);
}


/// Create a copy of LiveEditSelection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditSelectionCopyWith<_LiveEditSelection> get copyWith => __$LiveEditSelectionCopyWithImpl<_LiveEditSelection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEditSelectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditSelection&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.selectionKey, selectionKey) || other.selectionKey == selectionKey)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.widgetType, widgetType) || other.widgetType == widgetType)&&const DeepCollectionEquality().equals(other._rawNode, _rawNode)&&const DeepCollectionEquality().equals(other._propertiesForWire, _propertiesForWire)&&(identical(other.targetDomain, targetDomain) || other.targetDomain == targetDomain)&&(identical(other.renderObjectType, renderObjectType) || other.renderObjectType == renderObjectType)&&(identical(other.bounds, bounds) || other.bounds == bounds)&&(identical(other.source, source) || other.source == source)&&const DeepCollectionEquality().equals(other._layoutContext, _layoutContext)&&const DeepCollectionEquality().equals(other._parentChain, _parentChain)&&const DeepCollectionEquality().equals(other._detailsTree, _detailsTree)&&const DeepCollectionEquality().equals(other._propertiesTree, _propertiesTree)&&(identical(other.selectionMode, selectionMode) || other.selectionMode == selectionMode)&&const DeepCollectionEquality().equals(other._selectedNodeIds, _selectedNodeIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,selectionKey,nodeId,widgetType,const DeepCollectionEquality().hash(_rawNode),const DeepCollectionEquality().hash(_propertiesForWire),targetDomain,renderObjectType,bounds,source,const DeepCollectionEquality().hash(_layoutContext),const DeepCollectionEquality().hash(_parentChain),const DeepCollectionEquality().hash(_detailsTree),const DeepCollectionEquality().hash(_propertiesTree),selectionMode,const DeepCollectionEquality().hash(_selectedNodeIds));

@override
String toString() {
  return 'LiveEditSelection(sessionId: $sessionId, selectionKey: $selectionKey, nodeId: $nodeId, widgetType: $widgetType, rawNode: $rawNode, propertiesForWire: $propertiesForWire, targetDomain: $targetDomain, renderObjectType: $renderObjectType, bounds: $bounds, source: $source, layoutContext: $layoutContext, parentChain: $parentChain, detailsTree: $detailsTree, propertiesTree: $propertiesTree, selectionMode: $selectionMode, selectedNodeIds: $selectedNodeIds)';
}


}

/// @nodoc
abstract mixin class _$LiveEditSelectionCopyWith<$Res> implements $LiveEditSelectionCopyWith<$Res> {
  factory _$LiveEditSelectionCopyWith(_LiveEditSelection value, $Res Function(_LiveEditSelection) _then) = __$LiveEditSelectionCopyWithImpl;
@override @useResult
$Res call({
 String sessionId,@JsonKey(defaultValue: '') String selectionKey, String nodeId, String widgetType,@JsonKey(fromJson: _asMap) Map<String, Object?> rawNode,@JsonKey(name: 'properties') List<Object?> propertiesForWire, LiveEditTargetDomain targetDomain, String? renderObjectType, LiveEditBounds? bounds, LiveEditSourceLocation? source, Map<String, Object?> layoutContext, List<Map<String, Object?>> parentChain, Map<String, Object?> detailsTree, Map<String, Object?> propertiesTree, LiveEditSelectionMode selectionMode, List<String> selectedNodeIds
});


@override $LiveEditBoundsCopyWith<$Res>? get bounds;@override $LiveEditSourceLocationCopyWith<$Res>? get source;

}
/// @nodoc
class __$LiveEditSelectionCopyWithImpl<$Res>
    implements _$LiveEditSelectionCopyWith<$Res> {
  __$LiveEditSelectionCopyWithImpl(this._self, this._then);

  final _LiveEditSelection _self;
  final $Res Function(_LiveEditSelection) _then;

/// Create a copy of LiveEditSelection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? selectionKey = null,Object? nodeId = null,Object? widgetType = null,Object? rawNode = null,Object? propertiesForWire = null,Object? targetDomain = null,Object? renderObjectType = freezed,Object? bounds = freezed,Object? source = freezed,Object? layoutContext = null,Object? parentChain = null,Object? detailsTree = null,Object? propertiesTree = null,Object? selectionMode = null,Object? selectedNodeIds = null,}) {
  return _then(_LiveEditSelection(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,selectionKey: null == selectionKey ? _self.selectionKey : selectionKey // ignore: cast_nullable_to_non_nullable
as String,nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,widgetType: null == widgetType ? _self.widgetType : widgetType // ignore: cast_nullable_to_non_nullable
as String,rawNode: null == rawNode ? _self._rawNode : rawNode // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,propertiesForWire: null == propertiesForWire ? _self._propertiesForWire : propertiesForWire // ignore: cast_nullable_to_non_nullable
as List<Object?>,targetDomain: null == targetDomain ? _self.targetDomain : targetDomain // ignore: cast_nullable_to_non_nullable
as LiveEditTargetDomain,renderObjectType: freezed == renderObjectType ? _self.renderObjectType : renderObjectType // ignore: cast_nullable_to_non_nullable
as String?,bounds: freezed == bounds ? _self.bounds : bounds // ignore: cast_nullable_to_non_nullable
as LiveEditBounds?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as LiveEditSourceLocation?,layoutContext: null == layoutContext ? _self._layoutContext : layoutContext // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,parentChain: null == parentChain ? _self._parentChain : parentChain // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>,detailsTree: null == detailsTree ? _self._detailsTree : detailsTree // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,propertiesTree: null == propertiesTree ? _self._propertiesTree : propertiesTree // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,selectionMode: null == selectionMode ? _self.selectionMode : selectionMode // ignore: cast_nullable_to_non_nullable
as LiveEditSelectionMode,selectedNodeIds: null == selectedNodeIds ? _self._selectedNodeIds : selectedNodeIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of LiveEditSelection
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditBoundsCopyWith<$Res>? get bounds {
    if (_self.bounds == null) {
    return null;
  }

  return $LiveEditBoundsCopyWith<$Res>(_self.bounds!, (value) {
    return _then(_self.copyWith(bounds: value));
  });
}/// Create a copy of LiveEditSelection
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditSourceLocationCopyWith<$Res>? get source {
    if (_self.source == null) {
    return null;
  }

  return $LiveEditSourceLocationCopyWith<$Res>(_self.source!, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}


/// @nodoc
mixin _$LiveEditSelectionCandidate {

@JsonKey(defaultValue: '') String get selectionKey; String get nodeId; String get widgetType; LiveEditBounds? get bounds;@JsonKey(fromJson: _depthFromJson) int get depth; LiveEditSourceLocation? get source; bool get createdByLocalProject; bool get active;
/// Create a copy of LiveEditSelectionCandidate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditSelectionCandidateCopyWith<LiveEditSelectionCandidate> get copyWith => _$LiveEditSelectionCandidateCopyWithImpl<LiveEditSelectionCandidate>(this as LiveEditSelectionCandidate, _$identity);

  /// Serializes this LiveEditSelectionCandidate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditSelectionCandidate&&(identical(other.selectionKey, selectionKey) || other.selectionKey == selectionKey)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.widgetType, widgetType) || other.widgetType == widgetType)&&(identical(other.bounds, bounds) || other.bounds == bounds)&&(identical(other.depth, depth) || other.depth == depth)&&(identical(other.source, source) || other.source == source)&&(identical(other.createdByLocalProject, createdByLocalProject) || other.createdByLocalProject == createdByLocalProject)&&(identical(other.active, active) || other.active == active));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,selectionKey,nodeId,widgetType,bounds,depth,source,createdByLocalProject,active);

@override
String toString() {
  return 'LiveEditSelectionCandidate(selectionKey: $selectionKey, nodeId: $nodeId, widgetType: $widgetType, bounds: $bounds, depth: $depth, source: $source, createdByLocalProject: $createdByLocalProject, active: $active)';
}


}

/// @nodoc
abstract mixin class $LiveEditSelectionCandidateCopyWith<$Res>  {
  factory $LiveEditSelectionCandidateCopyWith(LiveEditSelectionCandidate value, $Res Function(LiveEditSelectionCandidate) _then) = _$LiveEditSelectionCandidateCopyWithImpl;
@useResult
$Res call({
@JsonKey(defaultValue: '') String selectionKey, String nodeId, String widgetType, LiveEditBounds? bounds,@JsonKey(fromJson: _depthFromJson) int depth, LiveEditSourceLocation? source, bool createdByLocalProject, bool active
});


$LiveEditBoundsCopyWith<$Res>? get bounds;$LiveEditSourceLocationCopyWith<$Res>? get source;

}
/// @nodoc
class _$LiveEditSelectionCandidateCopyWithImpl<$Res>
    implements $LiveEditSelectionCandidateCopyWith<$Res> {
  _$LiveEditSelectionCandidateCopyWithImpl(this._self, this._then);

  final LiveEditSelectionCandidate _self;
  final $Res Function(LiveEditSelectionCandidate) _then;

/// Create a copy of LiveEditSelectionCandidate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selectionKey = null,Object? nodeId = null,Object? widgetType = null,Object? bounds = freezed,Object? depth = null,Object? source = freezed,Object? createdByLocalProject = null,Object? active = null,}) {
  return _then(_self.copyWith(
selectionKey: null == selectionKey ? _self.selectionKey : selectionKey // ignore: cast_nullable_to_non_nullable
as String,nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,widgetType: null == widgetType ? _self.widgetType : widgetType // ignore: cast_nullable_to_non_nullable
as String,bounds: freezed == bounds ? _self.bounds : bounds // ignore: cast_nullable_to_non_nullable
as LiveEditBounds?,depth: null == depth ? _self.depth : depth // ignore: cast_nullable_to_non_nullable
as int,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as LiveEditSourceLocation?,createdByLocalProject: null == createdByLocalProject ? _self.createdByLocalProject : createdByLocalProject // ignore: cast_nullable_to_non_nullable
as bool,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of LiveEditSelectionCandidate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditBoundsCopyWith<$Res>? get bounds {
    if (_self.bounds == null) {
    return null;
  }

  return $LiveEditBoundsCopyWith<$Res>(_self.bounds!, (value) {
    return _then(_self.copyWith(bounds: value));
  });
}/// Create a copy of LiveEditSelectionCandidate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditSourceLocationCopyWith<$Res>? get source {
    if (_self.source == null) {
    return null;
  }

  return $LiveEditSourceLocationCopyWith<$Res>(_self.source!, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}


/// Adds pattern-matching-related methods to [LiveEditSelectionCandidate].
extension LiveEditSelectionCandidatePatterns on LiveEditSelectionCandidate {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditSelectionCandidate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditSelectionCandidate() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditSelectionCandidate value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditSelectionCandidate():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditSelectionCandidate value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditSelectionCandidate() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(defaultValue: '')  String selectionKey,  String nodeId,  String widgetType,  LiveEditBounds? bounds, @JsonKey(fromJson: _depthFromJson)  int depth,  LiveEditSourceLocation? source,  bool createdByLocalProject,  bool active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditSelectionCandidate() when $default != null:
return $default(_that.selectionKey,_that.nodeId,_that.widgetType,_that.bounds,_that.depth,_that.source,_that.createdByLocalProject,_that.active);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(defaultValue: '')  String selectionKey,  String nodeId,  String widgetType,  LiveEditBounds? bounds, @JsonKey(fromJson: _depthFromJson)  int depth,  LiveEditSourceLocation? source,  bool createdByLocalProject,  bool active)  $default,) {final _that = this;
switch (_that) {
case _LiveEditSelectionCandidate():
return $default(_that.selectionKey,_that.nodeId,_that.widgetType,_that.bounds,_that.depth,_that.source,_that.createdByLocalProject,_that.active);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(defaultValue: '')  String selectionKey,  String nodeId,  String widgetType,  LiveEditBounds? bounds, @JsonKey(fromJson: _depthFromJson)  int depth,  LiveEditSourceLocation? source,  bool createdByLocalProject,  bool active)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditSelectionCandidate() when $default != null:
return $default(_that.selectionKey,_that.nodeId,_that.widgetType,_that.bounds,_that.depth,_that.source,_that.createdByLocalProject,_that.active);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEditSelectionCandidate implements LiveEditSelectionCandidate {
  const _LiveEditSelectionCandidate({@JsonKey(defaultValue: '') this.selectionKey = '', required this.nodeId, required this.widgetType, this.bounds, @JsonKey(fromJson: _depthFromJson) this.depth = 0, this.source, this.createdByLocalProject = false, this.active = false});
  factory _LiveEditSelectionCandidate.fromJson(Map<String, dynamic> json) => _$LiveEditSelectionCandidateFromJson(json);

@override@JsonKey(defaultValue: '') final  String selectionKey;
@override final  String nodeId;
@override final  String widgetType;
@override final  LiveEditBounds? bounds;
@override@JsonKey(fromJson: _depthFromJson) final  int depth;
@override final  LiveEditSourceLocation? source;
@override@JsonKey() final  bool createdByLocalProject;
@override@JsonKey() final  bool active;

/// Create a copy of LiveEditSelectionCandidate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditSelectionCandidateCopyWith<_LiveEditSelectionCandidate> get copyWith => __$LiveEditSelectionCandidateCopyWithImpl<_LiveEditSelectionCandidate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEditSelectionCandidateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditSelectionCandidate&&(identical(other.selectionKey, selectionKey) || other.selectionKey == selectionKey)&&(identical(other.nodeId, nodeId) || other.nodeId == nodeId)&&(identical(other.widgetType, widgetType) || other.widgetType == widgetType)&&(identical(other.bounds, bounds) || other.bounds == bounds)&&(identical(other.depth, depth) || other.depth == depth)&&(identical(other.source, source) || other.source == source)&&(identical(other.createdByLocalProject, createdByLocalProject) || other.createdByLocalProject == createdByLocalProject)&&(identical(other.active, active) || other.active == active));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,selectionKey,nodeId,widgetType,bounds,depth,source,createdByLocalProject,active);

@override
String toString() {
  return 'LiveEditSelectionCandidate(selectionKey: $selectionKey, nodeId: $nodeId, widgetType: $widgetType, bounds: $bounds, depth: $depth, source: $source, createdByLocalProject: $createdByLocalProject, active: $active)';
}


}

/// @nodoc
abstract mixin class _$LiveEditSelectionCandidateCopyWith<$Res> implements $LiveEditSelectionCandidateCopyWith<$Res> {
  factory _$LiveEditSelectionCandidateCopyWith(_LiveEditSelectionCandidate value, $Res Function(_LiveEditSelectionCandidate) _then) = __$LiveEditSelectionCandidateCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(defaultValue: '') String selectionKey, String nodeId, String widgetType, LiveEditBounds? bounds,@JsonKey(fromJson: _depthFromJson) int depth, LiveEditSourceLocation? source, bool createdByLocalProject, bool active
});


@override $LiveEditBoundsCopyWith<$Res>? get bounds;@override $LiveEditSourceLocationCopyWith<$Res>? get source;

}
/// @nodoc
class __$LiveEditSelectionCandidateCopyWithImpl<$Res>
    implements _$LiveEditSelectionCandidateCopyWith<$Res> {
  __$LiveEditSelectionCandidateCopyWithImpl(this._self, this._then);

  final _LiveEditSelectionCandidate _self;
  final $Res Function(_LiveEditSelectionCandidate) _then;

/// Create a copy of LiveEditSelectionCandidate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selectionKey = null,Object? nodeId = null,Object? widgetType = null,Object? bounds = freezed,Object? depth = null,Object? source = freezed,Object? createdByLocalProject = null,Object? active = null,}) {
  return _then(_LiveEditSelectionCandidate(
selectionKey: null == selectionKey ? _self.selectionKey : selectionKey // ignore: cast_nullable_to_non_nullable
as String,nodeId: null == nodeId ? _self.nodeId : nodeId // ignore: cast_nullable_to_non_nullable
as String,widgetType: null == widgetType ? _self.widgetType : widgetType // ignore: cast_nullable_to_non_nullable
as String,bounds: freezed == bounds ? _self.bounds : bounds // ignore: cast_nullable_to_non_nullable
as LiveEditBounds?,depth: null == depth ? _self.depth : depth // ignore: cast_nullable_to_non_nullable
as int,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as LiveEditSourceLocation?,createdByLocalProject: null == createdByLocalProject ? _self.createdByLocalProject : createdByLocalProject // ignore: cast_nullable_to_non_nullable
as bool,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of LiveEditSelectionCandidate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditBoundsCopyWith<$Res>? get bounds {
    if (_self.bounds == null) {
    return null;
  }

  return $LiveEditBoundsCopyWith<$Res>(_self.bounds!, (value) {
    return _then(_self.copyWith(bounds: value));
  });
}/// Create a copy of LiveEditSelectionCandidate
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LiveEditSourceLocationCopyWith<$Res>? get source {
    if (_self.source == null) {
    return null;
  }

  return $LiveEditSourceLocationCopyWith<$Res>(_self.source!, (value) {
    return _then(_self.copyWith(source: value));
  });
}
}


/// @nodoc
mixin _$LiveEditSourceLocation {

 String get file; int? get line; int? get column; String? get sourceHint;
/// Create a copy of LiveEditSourceLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditSourceLocationCopyWith<LiveEditSourceLocation> get copyWith => _$LiveEditSourceLocationCopyWithImpl<LiveEditSourceLocation>(this as LiveEditSourceLocation, _$identity);

  /// Serializes this LiveEditSourceLocation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditSourceLocation&&(identical(other.file, file) || other.file == file)&&(identical(other.line, line) || other.line == line)&&(identical(other.column, column) || other.column == column)&&(identical(other.sourceHint, sourceHint) || other.sourceHint == sourceHint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,file,line,column,sourceHint);

@override
String toString() {
  return 'LiveEditSourceLocation(file: $file, line: $line, column: $column, sourceHint: $sourceHint)';
}


}

/// @nodoc
abstract mixin class $LiveEditSourceLocationCopyWith<$Res>  {
  factory $LiveEditSourceLocationCopyWith(LiveEditSourceLocation value, $Res Function(LiveEditSourceLocation) _then) = _$LiveEditSourceLocationCopyWithImpl;
@useResult
$Res call({
 String file, int? line, int? column, String? sourceHint
});




}
/// @nodoc
class _$LiveEditSourceLocationCopyWithImpl<$Res>
    implements $LiveEditSourceLocationCopyWith<$Res> {
  _$LiveEditSourceLocationCopyWithImpl(this._self, this._then);

  final LiveEditSourceLocation _self;
  final $Res Function(LiveEditSourceLocation) _then;

/// Create a copy of LiveEditSourceLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? file = null,Object? line = freezed,Object? column = freezed,Object? sourceHint = freezed,}) {
  return _then(_self.copyWith(
file: null == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,column: freezed == column ? _self.column : column // ignore: cast_nullable_to_non_nullable
as int?,sourceHint: freezed == sourceHint ? _self.sourceHint : sourceHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveEditSourceLocation].
extension LiveEditSourceLocationPatterns on LiveEditSourceLocation {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditSourceLocation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditSourceLocation() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditSourceLocation value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditSourceLocation():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditSourceLocation value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditSourceLocation() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String file,  int? line,  int? column,  String? sourceHint)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditSourceLocation() when $default != null:
return $default(_that.file,_that.line,_that.column,_that.sourceHint);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String file,  int? line,  int? column,  String? sourceHint)  $default,) {final _that = this;
switch (_that) {
case _LiveEditSourceLocation():
return $default(_that.file,_that.line,_that.column,_that.sourceHint);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String file,  int? line,  int? column,  String? sourceHint)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditSourceLocation() when $default != null:
return $default(_that.file,_that.line,_that.column,_that.sourceHint);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEditSourceLocation implements LiveEditSourceLocation {
  const _LiveEditSourceLocation({required this.file, this.line, this.column, this.sourceHint});
  factory _LiveEditSourceLocation.fromJson(Map<String, dynamic> json) => _$LiveEditSourceLocationFromJson(json);

@override final  String file;
@override final  int? line;
@override final  int? column;
@override final  String? sourceHint;

/// Create a copy of LiveEditSourceLocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditSourceLocationCopyWith<_LiveEditSourceLocation> get copyWith => __$LiveEditSourceLocationCopyWithImpl<_LiveEditSourceLocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEditSourceLocationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditSourceLocation&&(identical(other.file, file) || other.file == file)&&(identical(other.line, line) || other.line == line)&&(identical(other.column, column) || other.column == column)&&(identical(other.sourceHint, sourceHint) || other.sourceHint == sourceHint));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,file,line,column,sourceHint);

@override
String toString() {
  return 'LiveEditSourceLocation(file: $file, line: $line, column: $column, sourceHint: $sourceHint)';
}


}

/// @nodoc
abstract mixin class _$LiveEditSourceLocationCopyWith<$Res> implements $LiveEditSourceLocationCopyWith<$Res> {
  factory _$LiveEditSourceLocationCopyWith(_LiveEditSourceLocation value, $Res Function(_LiveEditSourceLocation) _then) = __$LiveEditSourceLocationCopyWithImpl;
@override @useResult
$Res call({
 String file, int? line, int? column, String? sourceHint
});




}
/// @nodoc
class __$LiveEditSourceLocationCopyWithImpl<$Res>
    implements _$LiveEditSourceLocationCopyWith<$Res> {
  __$LiveEditSourceLocationCopyWithImpl(this._self, this._then);

  final _LiveEditSourceLocation _self;
  final $Res Function(_LiveEditSourceLocation) _then;

/// Create a copy of LiveEditSourceLocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? file = null,Object? line = freezed,Object? column = freezed,Object? sourceHint = freezed,}) {
  return _then(_LiveEditSourceLocation(
file: null == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,column: freezed == column ? _self.column : column // ignore: cast_nullable_to_non_nullable
as int?,sourceHint: freezed == sourceHint ? _self.sourceHint : sourceHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
