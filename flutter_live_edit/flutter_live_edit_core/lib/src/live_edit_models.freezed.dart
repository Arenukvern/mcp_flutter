// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_edit_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

LiveEditAgentBackend _$LiveEditAgentBackendFromJson(Map<String, dynamic> json) {
  return _LiveEditAgentBackend.fromJson(json);
}

/// @nodoc
mixin _$LiveEditAgentBackend {
  String get id => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  bool get available => throw _privateConstructorUsedError;
  bool get isDefault => throw _privateConstructorUsedError;
  Map<String, Object?> get meta => throw _privateConstructorUsedError;

  /// Serializes this LiveEditAgentBackend to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditAgentBackend
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditAgentBackendCopyWith<LiveEditAgentBackend> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditAgentBackendCopyWith<$Res> {
  factory $LiveEditAgentBackendCopyWith(
    LiveEditAgentBackend value,
    $Res Function(LiveEditAgentBackend) then,
  ) = _$LiveEditAgentBackendCopyWithImpl<$Res, LiveEditAgentBackend>;
  @useResult
  $Res call({
    String id,
    String label,
    String description,
    bool available,
    bool isDefault,
    Map<String, Object?> meta,
  });
}

/// @nodoc
class _$LiveEditAgentBackendCopyWithImpl<
  $Res,
  $Val extends LiveEditAgentBackend
>
    implements $LiveEditAgentBackendCopyWith<$Res> {
  _$LiveEditAgentBackendCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditAgentBackend
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? description = null,
    Object? available = null,
    Object? isDefault = null,
    Object? meta = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            available: null == available
                ? _value.available
                : available // ignore: cast_nullable_to_non_nullable
                      as bool,
            isDefault: null == isDefault
                ? _value.isDefault
                : isDefault // ignore: cast_nullable_to_non_nullable
                      as bool,
            meta: null == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LiveEditAgentBackendImplCopyWith<$Res>
    implements $LiveEditAgentBackendCopyWith<$Res> {
  factory _$$LiveEditAgentBackendImplCopyWith(
    _$LiveEditAgentBackendImpl value,
    $Res Function(_$LiveEditAgentBackendImpl) then,
  ) = __$$LiveEditAgentBackendImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String label,
    String description,
    bool available,
    bool isDefault,
    Map<String, Object?> meta,
  });
}

/// @nodoc
class __$$LiveEditAgentBackendImplCopyWithImpl<$Res>
    extends _$LiveEditAgentBackendCopyWithImpl<$Res, _$LiveEditAgentBackendImpl>
    implements _$$LiveEditAgentBackendImplCopyWith<$Res> {
  __$$LiveEditAgentBackendImplCopyWithImpl(
    _$LiveEditAgentBackendImpl _value,
    $Res Function(_$LiveEditAgentBackendImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditAgentBackend
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? description = null,
    Object? available = null,
    Object? isDefault = null,
    Object? meta = null,
  }) {
    return _then(
      _$LiveEditAgentBackendImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        available: null == available
            ? _value.available
            : available // ignore: cast_nullable_to_non_nullable
                  as bool,
        isDefault: null == isDefault
            ? _value.isDefault
            : isDefault // ignore: cast_nullable_to_non_nullable
                  as bool,
        meta: null == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LiveEditAgentBackendImpl implements _LiveEditAgentBackend {
  const _$LiveEditAgentBackendImpl({
    required this.id,
    required this.label,
    required this.description,
    required this.available,
    this.isDefault = false,
    final Map<String, Object?> meta = const <String, Object?>{},
  }) : _meta = meta;

  factory _$LiveEditAgentBackendImpl.fromJson(Map<String, dynamic> json) =>
      _$$LiveEditAgentBackendImplFromJson(json);

  @override
  final String id;
  @override
  final String label;
  @override
  final String description;
  @override
  final bool available;
  @override
  @JsonKey()
  final bool isDefault;
  final Map<String, Object?> _meta;
  @override
  @JsonKey()
  Map<String, Object?> get meta {
    if (_meta is EqualUnmodifiableMapView) return _meta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_meta);
  }

  @override
  String toString() {
    return 'LiveEditAgentBackend(id: $id, label: $label, description: $description, available: $available, isDefault: $isDefault, meta: $meta)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditAgentBackendImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.available, available) ||
                other.available == available) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault) &&
            const DeepCollectionEquality().equals(other._meta, _meta));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    label,
    description,
    available,
    isDefault,
    const DeepCollectionEquality().hash(_meta),
  );

  /// Create a copy of LiveEditAgentBackend
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditAgentBackendImplCopyWith<_$LiveEditAgentBackendImpl>
  get copyWith =>
      __$$LiveEditAgentBackendImplCopyWithImpl<_$LiveEditAgentBackendImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$LiveEditAgentBackendImplToJson(this);
  }
}

abstract class _LiveEditAgentBackend implements LiveEditAgentBackend {
  const factory _LiveEditAgentBackend({
    required final String id,
    required final String label,
    required final String description,
    required final bool available,
    final bool isDefault,
    final Map<String, Object?> meta,
  }) = _$LiveEditAgentBackendImpl;

  factory _LiveEditAgentBackend.fromJson(Map<String, dynamic> json) =
      _$LiveEditAgentBackendImpl.fromJson;

  @override
  String get id;
  @override
  String get label;
  @override
  String get description;
  @override
  bool get available;
  @override
  bool get isDefault;
  @override
  Map<String, Object?> get meta;

  /// Create a copy of LiveEditAgentBackend
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditAgentBackendImplCopyWith<_$LiveEditAgentBackendImpl>
  get copyWith => throw _privateConstructorUsedError;
}

LiveEditBounds _$LiveEditBoundsFromJson(Map<String, dynamic> json) {
  return _LiveEditBounds.fromJson(json);
}

/// @nodoc
mixin _$LiveEditBounds {
  double get left => throw _privateConstructorUsedError;
  double get top => throw _privateConstructorUsedError;
  double get right => throw _privateConstructorUsedError;
  double get bottom => throw _privateConstructorUsedError;
  double get width => throw _privateConstructorUsedError;
  double get height => throw _privateConstructorUsedError;

  /// Serializes this LiveEditBounds to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditBounds
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditBoundsCopyWith<LiveEditBounds> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditBoundsCopyWith<$Res> {
  factory $LiveEditBoundsCopyWith(
    LiveEditBounds value,
    $Res Function(LiveEditBounds) then,
  ) = _$LiveEditBoundsCopyWithImpl<$Res, LiveEditBounds>;
  @useResult
  $Res call({
    double left,
    double top,
    double right,
    double bottom,
    double width,
    double height,
  });
}

/// @nodoc
class _$LiveEditBoundsCopyWithImpl<$Res, $Val extends LiveEditBounds>
    implements $LiveEditBoundsCopyWith<$Res> {
  _$LiveEditBoundsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditBounds
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? left = null,
    Object? top = null,
    Object? right = null,
    Object? bottom = null,
    Object? width = null,
    Object? height = null,
  }) {
    return _then(
      _value.copyWith(
            left: null == left
                ? _value.left
                : left // ignore: cast_nullable_to_non_nullable
                      as double,
            top: null == top
                ? _value.top
                : top // ignore: cast_nullable_to_non_nullable
                      as double,
            right: null == right
                ? _value.right
                : right // ignore: cast_nullable_to_non_nullable
                      as double,
            bottom: null == bottom
                ? _value.bottom
                : bottom // ignore: cast_nullable_to_non_nullable
                      as double,
            width: null == width
                ? _value.width
                : width // ignore: cast_nullable_to_non_nullable
                      as double,
            height: null == height
                ? _value.height
                : height // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LiveEditBoundsImplCopyWith<$Res>
    implements $LiveEditBoundsCopyWith<$Res> {
  factory _$$LiveEditBoundsImplCopyWith(
    _$LiveEditBoundsImpl value,
    $Res Function(_$LiveEditBoundsImpl) then,
  ) = __$$LiveEditBoundsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double left,
    double top,
    double right,
    double bottom,
    double width,
    double height,
  });
}

/// @nodoc
class __$$LiveEditBoundsImplCopyWithImpl<$Res>
    extends _$LiveEditBoundsCopyWithImpl<$Res, _$LiveEditBoundsImpl>
    implements _$$LiveEditBoundsImplCopyWith<$Res> {
  __$$LiveEditBoundsImplCopyWithImpl(
    _$LiveEditBoundsImpl _value,
    $Res Function(_$LiveEditBoundsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditBounds
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? left = null,
    Object? top = null,
    Object? right = null,
    Object? bottom = null,
    Object? width = null,
    Object? height = null,
  }) {
    return _then(
      _$LiveEditBoundsImpl(
        left: null == left
            ? _value.left
            : left // ignore: cast_nullable_to_non_nullable
                  as double,
        top: null == top
            ? _value.top
            : top // ignore: cast_nullable_to_non_nullable
                  as double,
        right: null == right
            ? _value.right
            : right // ignore: cast_nullable_to_non_nullable
                  as double,
        bottom: null == bottom
            ? _value.bottom
            : bottom // ignore: cast_nullable_to_non_nullable
                  as double,
        width: null == width
            ? _value.width
            : width // ignore: cast_nullable_to_non_nullable
                  as double,
        height: null == height
            ? _value.height
            : height // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LiveEditBoundsImpl implements _LiveEditBounds {
  const _$LiveEditBoundsImpl({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.width,
    required this.height,
  });

  factory _$LiveEditBoundsImpl.fromJson(Map<String, dynamic> json) =>
      _$$LiveEditBoundsImplFromJson(json);

  @override
  final double left;
  @override
  final double top;
  @override
  final double right;
  @override
  final double bottom;
  @override
  final double width;
  @override
  final double height;

  @override
  String toString() {
    return 'LiveEditBounds(left: $left, top: $top, right: $right, bottom: $bottom, width: $width, height: $height)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditBoundsImpl &&
            (identical(other.left, left) || other.left == left) &&
            (identical(other.top, top) || other.top == top) &&
            (identical(other.right, right) || other.right == right) &&
            (identical(other.bottom, bottom) || other.bottom == bottom) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, left, top, right, bottom, width, height);

  /// Create a copy of LiveEditBounds
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditBoundsImplCopyWith<_$LiveEditBoundsImpl> get copyWith =>
      __$$LiveEditBoundsImplCopyWithImpl<_$LiveEditBoundsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$LiveEditBoundsImplToJson(this);
  }
}

abstract class _LiveEditBounds implements LiveEditBounds {
  const factory _LiveEditBounds({
    required final double left,
    required final double top,
    required final double right,
    required final double bottom,
    required final double width,
    required final double height,
  }) = _$LiveEditBoundsImpl;

  factory _LiveEditBounds.fromJson(Map<String, dynamic> json) =
      _$LiveEditBoundsImpl.fromJson;

  @override
  double get left;
  @override
  double get top;
  @override
  double get right;
  @override
  double get bottom;
  @override
  double get width;
  @override
  double get height;

  /// Create a copy of LiveEditBounds
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditBoundsImplCopyWith<_$LiveEditBoundsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LiveEditCodexModelOption _$LiveEditCodexModelOptionFromJson(
  Map<String, dynamic> json,
) {
  return _LiveEditCodexModelOption.fromJson(json);
}

/// @nodoc
mixin _$LiveEditCodexModelOption {
  String get id => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;

  /// Serializes this LiveEditCodexModelOption to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditCodexModelOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditCodexModelOptionCopyWith<LiveEditCodexModelOption> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditCodexModelOptionCopyWith<$Res> {
  factory $LiveEditCodexModelOptionCopyWith(
    LiveEditCodexModelOption value,
    $Res Function(LiveEditCodexModelOption) then,
  ) = _$LiveEditCodexModelOptionCopyWithImpl<$Res, LiveEditCodexModelOption>;
  @useResult
  $Res call({String id, String label});
}

/// @nodoc
class _$LiveEditCodexModelOptionCopyWithImpl<
  $Res,
  $Val extends LiveEditCodexModelOption
>
    implements $LiveEditCodexModelOptionCopyWith<$Res> {
  _$LiveEditCodexModelOptionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditCodexModelOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? label = null}) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LiveEditCodexModelOptionImplCopyWith<$Res>
    implements $LiveEditCodexModelOptionCopyWith<$Res> {
  factory _$$LiveEditCodexModelOptionImplCopyWith(
    _$LiveEditCodexModelOptionImpl value,
    $Res Function(_$LiveEditCodexModelOptionImpl) then,
  ) = __$$LiveEditCodexModelOptionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String label});
}

/// @nodoc
class __$$LiveEditCodexModelOptionImplCopyWithImpl<$Res>
    extends
        _$LiveEditCodexModelOptionCopyWithImpl<
          $Res,
          _$LiveEditCodexModelOptionImpl
        >
    implements _$$LiveEditCodexModelOptionImplCopyWith<$Res> {
  __$$LiveEditCodexModelOptionImplCopyWithImpl(
    _$LiveEditCodexModelOptionImpl _value,
    $Res Function(_$LiveEditCodexModelOptionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditCodexModelOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? id = null, Object? label = null}) {
    return _then(
      _$LiveEditCodexModelOptionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LiveEditCodexModelOptionImpl implements _LiveEditCodexModelOption {
  const _$LiveEditCodexModelOptionImpl({required this.id, required this.label});

  factory _$LiveEditCodexModelOptionImpl.fromJson(Map<String, dynamic> json) =>
      _$$LiveEditCodexModelOptionImplFromJson(json);

  @override
  final String id;
  @override
  final String label;

  @override
  String toString() {
    return 'LiveEditCodexModelOption(id: $id, label: $label)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditCodexModelOptionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, label);

  /// Create a copy of LiveEditCodexModelOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditCodexModelOptionImplCopyWith<_$LiveEditCodexModelOptionImpl>
  get copyWith =>
      __$$LiveEditCodexModelOptionImplCopyWithImpl<
        _$LiveEditCodexModelOptionImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LiveEditCodexModelOptionImplToJson(this);
  }
}

abstract class _LiveEditCodexModelOption implements LiveEditCodexModelOption {
  const factory _LiveEditCodexModelOption({
    required final String id,
    required final String label,
  }) = _$LiveEditCodexModelOptionImpl;

  factory _LiveEditCodexModelOption.fromJson(Map<String, dynamic> json) =
      _$LiveEditCodexModelOptionImpl.fromJson;

  @override
  String get id;
  @override
  String get label;

  /// Create a copy of LiveEditCodexModelOption
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditCodexModelOptionImplCopyWith<_$LiveEditCodexModelOptionImpl>
  get copyWith => throw _privateConstructorUsedError;
}

LiveEditDraftChange _$LiveEditDraftChangeFromJson(Map<String, dynamic> json) {
  return _LiveEditDraftChange.fromJson(json);
}

/// @nodoc
mixin _$LiveEditDraftChange {
  String get nodeId => throw _privateConstructorUsedError;
  String get propertyId => throw _privateConstructorUsedError;
  Object? get targetValue => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _previewModeFromJson, toJson: _enumToWire)
  LiveEditPreviewMode get previewMode => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _confidenceFromJson)
  double get confidence => throw _privateConstructorUsedError;
  String? get intentText => throw _privateConstructorUsedError;
  Map<String, Object?> get meta => throw _privateConstructorUsedError;

  /// Serializes this LiveEditDraftChange to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditDraftChange
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditDraftChangeCopyWith<LiveEditDraftChange> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditDraftChangeCopyWith<$Res> {
  factory $LiveEditDraftChangeCopyWith(
    LiveEditDraftChange value,
    $Res Function(LiveEditDraftChange) then,
  ) = _$LiveEditDraftChangeCopyWithImpl<$Res, LiveEditDraftChange>;
  @useResult
  $Res call({
    String nodeId,
    String propertyId,
    Object? targetValue,
    @JsonKey(fromJson: _previewModeFromJson, toJson: _enumToWire)
    LiveEditPreviewMode previewMode,
    @JsonKey(fromJson: _confidenceFromJson) double confidence,
    String? intentText,
    Map<String, Object?> meta,
  });
}

/// @nodoc
class _$LiveEditDraftChangeCopyWithImpl<$Res, $Val extends LiveEditDraftChange>
    implements $LiveEditDraftChangeCopyWith<$Res> {
  _$LiveEditDraftChangeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditDraftChange
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeId = null,
    Object? propertyId = null,
    Object? targetValue = freezed,
    Object? previewMode = null,
    Object? confidence = null,
    Object? intentText = freezed,
    Object? meta = null,
  }) {
    return _then(
      _value.copyWith(
            nodeId: null == nodeId
                ? _value.nodeId
                : nodeId // ignore: cast_nullable_to_non_nullable
                      as String,
            propertyId: null == propertyId
                ? _value.propertyId
                : propertyId // ignore: cast_nullable_to_non_nullable
                      as String,
            targetValue: freezed == targetValue
                ? _value.targetValue
                : targetValue,
            previewMode: null == previewMode
                ? _value.previewMode
                : previewMode // ignore: cast_nullable_to_non_nullable
                      as LiveEditPreviewMode,
            confidence: null == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                      as double,
            intentText: freezed == intentText
                ? _value.intentText
                : intentText // ignore: cast_nullable_to_non_nullable
                      as String?,
            meta: null == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LiveEditDraftChangeImplCopyWith<$Res>
    implements $LiveEditDraftChangeCopyWith<$Res> {
  factory _$$LiveEditDraftChangeImplCopyWith(
    _$LiveEditDraftChangeImpl value,
    $Res Function(_$LiveEditDraftChangeImpl) then,
  ) = __$$LiveEditDraftChangeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String nodeId,
    String propertyId,
    Object? targetValue,
    @JsonKey(fromJson: _previewModeFromJson, toJson: _enumToWire)
    LiveEditPreviewMode previewMode,
    @JsonKey(fromJson: _confidenceFromJson) double confidence,
    String? intentText,
    Map<String, Object?> meta,
  });
}

/// @nodoc
class __$$LiveEditDraftChangeImplCopyWithImpl<$Res>
    extends _$LiveEditDraftChangeCopyWithImpl<$Res, _$LiveEditDraftChangeImpl>
    implements _$$LiveEditDraftChangeImplCopyWith<$Res> {
  __$$LiveEditDraftChangeImplCopyWithImpl(
    _$LiveEditDraftChangeImpl _value,
    $Res Function(_$LiveEditDraftChangeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditDraftChange
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeId = null,
    Object? propertyId = null,
    Object? targetValue = freezed,
    Object? previewMode = null,
    Object? confidence = null,
    Object? intentText = freezed,
    Object? meta = null,
  }) {
    return _then(
      _$LiveEditDraftChangeImpl(
        nodeId: null == nodeId
            ? _value.nodeId
            : nodeId // ignore: cast_nullable_to_non_nullable
                  as String,
        propertyId: null == propertyId
            ? _value.propertyId
            : propertyId // ignore: cast_nullable_to_non_nullable
                  as String,
        targetValue: freezed == targetValue ? _value.targetValue : targetValue,
        previewMode: null == previewMode
            ? _value.previewMode
            : previewMode // ignore: cast_nullable_to_non_nullable
                  as LiveEditPreviewMode,
        confidence: null == confidence
            ? _value.confidence
            : confidence // ignore: cast_nullable_to_non_nullable
                  as double,
        intentText: freezed == intentText
            ? _value.intentText
            : intentText // ignore: cast_nullable_to_non_nullable
                  as String?,
        meta: null == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LiveEditDraftChangeImpl implements _LiveEditDraftChange {
  const _$LiveEditDraftChangeImpl({
    required this.nodeId,
    required this.propertyId,
    required this.targetValue,
    @JsonKey(fromJson: _previewModeFromJson, toJson: _enumToWire)
    this.previewMode = LiveEditPreviewMode.none,
    @JsonKey(fromJson: _confidenceFromJson) this.confidence = 1,
    this.intentText,
    final Map<String, Object?> meta = const <String, Object?>{},
  }) : _meta = meta;

  factory _$LiveEditDraftChangeImpl.fromJson(Map<String, dynamic> json) =>
      _$$LiveEditDraftChangeImplFromJson(json);

  @override
  final String nodeId;
  @override
  final String propertyId;
  @override
  final Object? targetValue;
  @override
  @JsonKey(fromJson: _previewModeFromJson, toJson: _enumToWire)
  final LiveEditPreviewMode previewMode;
  @override
  @JsonKey(fromJson: _confidenceFromJson)
  final double confidence;
  @override
  final String? intentText;
  final Map<String, Object?> _meta;
  @override
  @JsonKey()
  Map<String, Object?> get meta {
    if (_meta is EqualUnmodifiableMapView) return _meta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_meta);
  }

  @override
  String toString() {
    return 'LiveEditDraftChange(nodeId: $nodeId, propertyId: $propertyId, targetValue: $targetValue, previewMode: $previewMode, confidence: $confidence, intentText: $intentText, meta: $meta)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditDraftChangeImpl &&
            (identical(other.nodeId, nodeId) || other.nodeId == nodeId) &&
            (identical(other.propertyId, propertyId) ||
                other.propertyId == propertyId) &&
            const DeepCollectionEquality().equals(
              other.targetValue,
              targetValue,
            ) &&
            (identical(other.previewMode, previewMode) ||
                other.previewMode == previewMode) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.intentText, intentText) ||
                other.intentText == intentText) &&
            const DeepCollectionEquality().equals(other._meta, _meta));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    nodeId,
    propertyId,
    const DeepCollectionEquality().hash(targetValue),
    previewMode,
    confidence,
    intentText,
    const DeepCollectionEquality().hash(_meta),
  );

  /// Create a copy of LiveEditDraftChange
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditDraftChangeImplCopyWith<_$LiveEditDraftChangeImpl> get copyWith =>
      __$$LiveEditDraftChangeImplCopyWithImpl<_$LiveEditDraftChangeImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$LiveEditDraftChangeImplToJson(this);
  }
}

abstract class _LiveEditDraftChange implements LiveEditDraftChange {
  const factory _LiveEditDraftChange({
    required final String nodeId,
    required final String propertyId,
    required final Object? targetValue,
    @JsonKey(fromJson: _previewModeFromJson, toJson: _enumToWire)
    final LiveEditPreviewMode previewMode,
    @JsonKey(fromJson: _confidenceFromJson) final double confidence,
    final String? intentText,
    final Map<String, Object?> meta,
  }) = _$LiveEditDraftChangeImpl;

  factory _LiveEditDraftChange.fromJson(Map<String, dynamic> json) =
      _$LiveEditDraftChangeImpl.fromJson;

  @override
  String get nodeId;
  @override
  String get propertyId;
  @override
  Object? get targetValue;
  @override
  @JsonKey(fromJson: _previewModeFromJson, toJson: _enumToWire)
  LiveEditPreviewMode get previewMode;
  @override
  @JsonKey(fromJson: _confidenceFromJson)
  double get confidence;
  @override
  String? get intentText;
  @override
  Map<String, Object?> get meta;

  /// Create a copy of LiveEditDraftChange
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditDraftChangeImplCopyWith<_$LiveEditDraftChangeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LiveEditFilePatch _$LiveEditFilePatchFromJson(Map<String, dynamic> json) {
  return _LiveEditFilePatch.fromJson(json);
}

/// @nodoc
mixin _$LiveEditFilePatch {
  String get path => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  String get patch => throw _privateConstructorUsedError;
  Map<String, Object?> get meta => throw _privateConstructorUsedError;

  /// Serializes this LiveEditFilePatch to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditFilePatch
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditFilePatchCopyWith<LiveEditFilePatch> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditFilePatchCopyWith<$Res> {
  factory $LiveEditFilePatchCopyWith(
    LiveEditFilePatch value,
    $Res Function(LiveEditFilePatch) then,
  ) = _$LiveEditFilePatchCopyWithImpl<$Res, LiveEditFilePatch>;
  @useResult
  $Res call({
    String path,
    String content,
    String patch,
    Map<String, Object?> meta,
  });
}

/// @nodoc
class _$LiveEditFilePatchCopyWithImpl<$Res, $Val extends LiveEditFilePatch>
    implements $LiveEditFilePatchCopyWith<$Res> {
  _$LiveEditFilePatchCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditFilePatch
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? path = null,
    Object? content = null,
    Object? patch = null,
    Object? meta = null,
  }) {
    return _then(
      _value.copyWith(
            path: null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String,
            content: null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String,
            patch: null == patch
                ? _value.patch
                : patch // ignore: cast_nullable_to_non_nullable
                      as String,
            meta: null == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LiveEditFilePatchImplCopyWith<$Res>
    implements $LiveEditFilePatchCopyWith<$Res> {
  factory _$$LiveEditFilePatchImplCopyWith(
    _$LiveEditFilePatchImpl value,
    $Res Function(_$LiveEditFilePatchImpl) then,
  ) = __$$LiveEditFilePatchImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String path,
    String content,
    String patch,
    Map<String, Object?> meta,
  });
}

/// @nodoc
class __$$LiveEditFilePatchImplCopyWithImpl<$Res>
    extends _$LiveEditFilePatchCopyWithImpl<$Res, _$LiveEditFilePatchImpl>
    implements _$$LiveEditFilePatchImplCopyWith<$Res> {
  __$$LiveEditFilePatchImplCopyWithImpl(
    _$LiveEditFilePatchImpl _value,
    $Res Function(_$LiveEditFilePatchImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditFilePatch
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? path = null,
    Object? content = null,
    Object? patch = null,
    Object? meta = null,
  }) {
    return _then(
      _$LiveEditFilePatchImpl(
        path: null == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String,
        content: null == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
        patch: null == patch
            ? _value.patch
            : patch // ignore: cast_nullable_to_non_nullable
                  as String,
        meta: null == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LiveEditFilePatchImpl implements _LiveEditFilePatch {
  const _$LiveEditFilePatchImpl({
    required this.path,
    required this.content,
    required this.patch,
    final Map<String, Object?> meta = const <String, Object?>{},
  }) : _meta = meta;

  factory _$LiveEditFilePatchImpl.fromJson(Map<String, dynamic> json) =>
      _$$LiveEditFilePatchImplFromJson(json);

  @override
  final String path;
  @override
  final String content;
  @override
  final String patch;
  final Map<String, Object?> _meta;
  @override
  @JsonKey()
  Map<String, Object?> get meta {
    if (_meta is EqualUnmodifiableMapView) return _meta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_meta);
  }

  @override
  String toString() {
    return 'LiveEditFilePatch(path: $path, content: $content, patch: $patch, meta: $meta)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditFilePatchImpl &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.patch, patch) || other.patch == patch) &&
            const DeepCollectionEquality().equals(other._meta, _meta));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    path,
    content,
    patch,
    const DeepCollectionEquality().hash(_meta),
  );

  /// Create a copy of LiveEditFilePatch
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditFilePatchImplCopyWith<_$LiveEditFilePatchImpl> get copyWith =>
      __$$LiveEditFilePatchImplCopyWithImpl<_$LiveEditFilePatchImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$LiveEditFilePatchImplToJson(this);
  }
}

abstract class _LiveEditFilePatch implements LiveEditFilePatch {
  const factory _LiveEditFilePatch({
    required final String path,
    required final String content,
    required final String patch,
    final Map<String, Object?> meta,
  }) = _$LiveEditFilePatchImpl;

  factory _LiveEditFilePatch.fromJson(Map<String, dynamic> json) =
      _$LiveEditFilePatchImpl.fromJson;

  @override
  String get path;
  @override
  String get content;
  @override
  String get patch;
  @override
  Map<String, Object?> get meta;

  /// Create a copy of LiveEditFilePatch
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditFilePatchImplCopyWith<_$LiveEditFilePatchImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$LiveEditInferenceConfig {
  String? get model => throw _privateConstructorUsedError;
  String? get reasoningEffort => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditInferenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditInferenceConfigCopyWith<LiveEditInferenceConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditInferenceConfigCopyWith<$Res> {
  factory $LiveEditInferenceConfigCopyWith(
    LiveEditInferenceConfig value,
    $Res Function(LiveEditInferenceConfig) then,
  ) = _$LiveEditInferenceConfigCopyWithImpl<$Res, LiveEditInferenceConfig>;
  @useResult
  $Res call({String? model, String? reasoningEffort});
}

/// @nodoc
class _$LiveEditInferenceConfigCopyWithImpl<
  $Res,
  $Val extends LiveEditInferenceConfig
>
    implements $LiveEditInferenceConfigCopyWith<$Res> {
  _$LiveEditInferenceConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditInferenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? model = freezed, Object? reasoningEffort = freezed}) {
    return _then(
      _value.copyWith(
            model: freezed == model
                ? _value.model
                : model // ignore: cast_nullable_to_non_nullable
                      as String?,
            reasoningEffort: freezed == reasoningEffort
                ? _value.reasoningEffort
                : reasoningEffort // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LiveEditInferenceConfigImplCopyWith<$Res>
    implements $LiveEditInferenceConfigCopyWith<$Res> {
  factory _$$LiveEditInferenceConfigImplCopyWith(
    _$LiveEditInferenceConfigImpl value,
    $Res Function(_$LiveEditInferenceConfigImpl) then,
  ) = __$$LiveEditInferenceConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? model, String? reasoningEffort});
}

/// @nodoc
class __$$LiveEditInferenceConfigImplCopyWithImpl<$Res>
    extends
        _$LiveEditInferenceConfigCopyWithImpl<
          $Res,
          _$LiveEditInferenceConfigImpl
        >
    implements _$$LiveEditInferenceConfigImplCopyWith<$Res> {
  __$$LiveEditInferenceConfigImplCopyWithImpl(
    _$LiveEditInferenceConfigImpl _value,
    $Res Function(_$LiveEditInferenceConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditInferenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? model = freezed, Object? reasoningEffort = freezed}) {
    return _then(
      _$LiveEditInferenceConfigImpl(
        model: freezed == model
            ? _value.model
            : model // ignore: cast_nullable_to_non_nullable
                  as String?,
        reasoningEffort: freezed == reasoningEffort
            ? _value.reasoningEffort
            : reasoningEffort // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$LiveEditInferenceConfigImpl extends _LiveEditInferenceConfig {
  const _$LiveEditInferenceConfigImpl({this.model, this.reasoningEffort})
    : super._();

  @override
  final String? model;
  @override
  final String? reasoningEffort;

  @override
  String toString() {
    return 'LiveEditInferenceConfig(model: $model, reasoningEffort: $reasoningEffort)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditInferenceConfigImpl &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.reasoningEffort, reasoningEffort) ||
                other.reasoningEffort == reasoningEffort));
  }

  @override
  int get hashCode => Object.hash(runtimeType, model, reasoningEffort);

  /// Create a copy of LiveEditInferenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditInferenceConfigImplCopyWith<_$LiveEditInferenceConfigImpl>
  get copyWith =>
      __$$LiveEditInferenceConfigImplCopyWithImpl<
        _$LiveEditInferenceConfigImpl
      >(this, _$identity);
}

abstract class _LiveEditInferenceConfig extends LiveEditInferenceConfig {
  const factory _LiveEditInferenceConfig({
    final String? model,
    final String? reasoningEffort,
  }) = _$LiveEditInferenceConfigImpl;
  const _LiveEditInferenceConfig._() : super._();

  @override
  String? get model;
  @override
  String? get reasoningEffort;

  /// Create a copy of LiveEditInferenceConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditInferenceConfigImplCopyWith<_$LiveEditInferenceConfigImpl>
  get copyWith => throw _privateConstructorUsedError;
}

LiveEditRuntimeRefreshResult _$LiveEditRuntimeRefreshResultFromJson(
  Map<String, dynamic> json,
) {
  return _LiveEditRuntimeRefreshResult.fromJson(json);
}

/// @nodoc
mixin _$LiveEditRuntimeRefreshResult {
  @JsonKey(fromJson: _runtimeActionFromJson, toJson: _enumToWire)
  LiveEditRuntimeAction get action => throw _privateConstructorUsedError;
  Map<String, Object?> get validation => throw _privateConstructorUsedError;
  Map<String, Object?> get hotReload => throw _privateConstructorUsedError;
  Map<String, Object?> get hotRestart => throw _privateConstructorUsedError;
  Map<String, Object?> get validationRecovery =>
      throw _privateConstructorUsedError;

  /// Serializes this LiveEditRuntimeRefreshResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditRuntimeRefreshResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditRuntimeRefreshResultCopyWith<LiveEditRuntimeRefreshResult>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditRuntimeRefreshResultCopyWith<$Res> {
  factory $LiveEditRuntimeRefreshResultCopyWith(
    LiveEditRuntimeRefreshResult value,
    $Res Function(LiveEditRuntimeRefreshResult) then,
  ) =
      _$LiveEditRuntimeRefreshResultCopyWithImpl<
        $Res,
        LiveEditRuntimeRefreshResult
      >;
  @useResult
  $Res call({
    @JsonKey(fromJson: _runtimeActionFromJson, toJson: _enumToWire)
    LiveEditRuntimeAction action,
    Map<String, Object?> validation,
    Map<String, Object?> hotReload,
    Map<String, Object?> hotRestart,
    Map<String, Object?> validationRecovery,
  });
}

/// @nodoc
class _$LiveEditRuntimeRefreshResultCopyWithImpl<
  $Res,
  $Val extends LiveEditRuntimeRefreshResult
>
    implements $LiveEditRuntimeRefreshResultCopyWith<$Res> {
  _$LiveEditRuntimeRefreshResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditRuntimeRefreshResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? action = null,
    Object? validation = null,
    Object? hotReload = null,
    Object? hotRestart = null,
    Object? validationRecovery = null,
  }) {
    return _then(
      _value.copyWith(
            action: null == action
                ? _value.action
                : action // ignore: cast_nullable_to_non_nullable
                      as LiveEditRuntimeAction,
            validation: null == validation
                ? _value.validation
                : validation // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            hotReload: null == hotReload
                ? _value.hotReload
                : hotReload // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            hotRestart: null == hotRestart
                ? _value.hotRestart
                : hotRestart // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            validationRecovery: null == validationRecovery
                ? _value.validationRecovery
                : validationRecovery // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LiveEditRuntimeRefreshResultImplCopyWith<$Res>
    implements $LiveEditRuntimeRefreshResultCopyWith<$Res> {
  factory _$$LiveEditRuntimeRefreshResultImplCopyWith(
    _$LiveEditRuntimeRefreshResultImpl value,
    $Res Function(_$LiveEditRuntimeRefreshResultImpl) then,
  ) = __$$LiveEditRuntimeRefreshResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: _runtimeActionFromJson, toJson: _enumToWire)
    LiveEditRuntimeAction action,
    Map<String, Object?> validation,
    Map<String, Object?> hotReload,
    Map<String, Object?> hotRestart,
    Map<String, Object?> validationRecovery,
  });
}

/// @nodoc
class __$$LiveEditRuntimeRefreshResultImplCopyWithImpl<$Res>
    extends
        _$LiveEditRuntimeRefreshResultCopyWithImpl<
          $Res,
          _$LiveEditRuntimeRefreshResultImpl
        >
    implements _$$LiveEditRuntimeRefreshResultImplCopyWith<$Res> {
  __$$LiveEditRuntimeRefreshResultImplCopyWithImpl(
    _$LiveEditRuntimeRefreshResultImpl _value,
    $Res Function(_$LiveEditRuntimeRefreshResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditRuntimeRefreshResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? action = null,
    Object? validation = null,
    Object? hotReload = null,
    Object? hotRestart = null,
    Object? validationRecovery = null,
  }) {
    return _then(
      _$LiveEditRuntimeRefreshResultImpl(
        action: null == action
            ? _value.action
            : action // ignore: cast_nullable_to_non_nullable
                  as LiveEditRuntimeAction,
        validation: null == validation
            ? _value._validation
            : validation // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        hotReload: null == hotReload
            ? _value._hotReload
            : hotReload // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        hotRestart: null == hotRestart
            ? _value._hotRestart
            : hotRestart // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        validationRecovery: null == validationRecovery
            ? _value._validationRecovery
            : validationRecovery // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LiveEditRuntimeRefreshResultImpl extends _LiveEditRuntimeRefreshResult {
  const _$LiveEditRuntimeRefreshResultImpl({
    @JsonKey(fromJson: _runtimeActionFromJson, toJson: _enumToWire)
    this.action = LiveEditRuntimeAction.none,
    final Map<String, Object?> validation = const <String, Object?>{},
    final Map<String, Object?> hotReload = const <String, Object?>{},
    final Map<String, Object?> hotRestart = const <String, Object?>{},
    final Map<String, Object?> validationRecovery = const <String, Object?>{},
  }) : _validation = validation,
       _hotReload = hotReload,
       _hotRestart = hotRestart,
       _validationRecovery = validationRecovery,
       super._();

  factory _$LiveEditRuntimeRefreshResultImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$LiveEditRuntimeRefreshResultImplFromJson(json);

  @override
  @JsonKey(fromJson: _runtimeActionFromJson, toJson: _enumToWire)
  final LiveEditRuntimeAction action;
  final Map<String, Object?> _validation;
  @override
  @JsonKey()
  Map<String, Object?> get validation {
    if (_validation is EqualUnmodifiableMapView) return _validation;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_validation);
  }

  final Map<String, Object?> _hotReload;
  @override
  @JsonKey()
  Map<String, Object?> get hotReload {
    if (_hotReload is EqualUnmodifiableMapView) return _hotReload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_hotReload);
  }

  final Map<String, Object?> _hotRestart;
  @override
  @JsonKey()
  Map<String, Object?> get hotRestart {
    if (_hotRestart is EqualUnmodifiableMapView) return _hotRestart;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_hotRestart);
  }

  final Map<String, Object?> _validationRecovery;
  @override
  @JsonKey()
  Map<String, Object?> get validationRecovery {
    if (_validationRecovery is EqualUnmodifiableMapView)
      return _validationRecovery;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_validationRecovery);
  }

  @override
  String toString() {
    return 'LiveEditRuntimeRefreshResult(action: $action, validation: $validation, hotReload: $hotReload, hotRestart: $hotRestart, validationRecovery: $validationRecovery)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditRuntimeRefreshResultImpl &&
            (identical(other.action, action) || other.action == action) &&
            const DeepCollectionEquality().equals(
              other._validation,
              _validation,
            ) &&
            const DeepCollectionEquality().equals(
              other._hotReload,
              _hotReload,
            ) &&
            const DeepCollectionEquality().equals(
              other._hotRestart,
              _hotRestart,
            ) &&
            const DeepCollectionEquality().equals(
              other._validationRecovery,
              _validationRecovery,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    action,
    const DeepCollectionEquality().hash(_validation),
    const DeepCollectionEquality().hash(_hotReload),
    const DeepCollectionEquality().hash(_hotRestart),
    const DeepCollectionEquality().hash(_validationRecovery),
  );

  /// Create a copy of LiveEditRuntimeRefreshResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditRuntimeRefreshResultImplCopyWith<
    _$LiveEditRuntimeRefreshResultImpl
  >
  get copyWith =>
      __$$LiveEditRuntimeRefreshResultImplCopyWithImpl<
        _$LiveEditRuntimeRefreshResultImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LiveEditRuntimeRefreshResultImplToJson(this);
  }
}

abstract class _LiveEditRuntimeRefreshResult
    extends LiveEditRuntimeRefreshResult {
  const factory _LiveEditRuntimeRefreshResult({
    @JsonKey(fromJson: _runtimeActionFromJson, toJson: _enumToWire)
    final LiveEditRuntimeAction action,
    final Map<String, Object?> validation,
    final Map<String, Object?> hotReload,
    final Map<String, Object?> hotRestart,
    final Map<String, Object?> validationRecovery,
  }) = _$LiveEditRuntimeRefreshResultImpl;
  const _LiveEditRuntimeRefreshResult._() : super._();

  factory _LiveEditRuntimeRefreshResult.fromJson(Map<String, dynamic> json) =
      _$LiveEditRuntimeRefreshResultImpl.fromJson;

  @override
  @JsonKey(fromJson: _runtimeActionFromJson, toJson: _enumToWire)
  LiveEditRuntimeAction get action;
  @override
  Map<String, Object?> get validation;
  @override
  Map<String, Object?> get hotReload;
  @override
  Map<String, Object?> get hotRestart;
  @override
  Map<String, Object?> get validationRecovery;

  /// Create a copy of LiveEditRuntimeRefreshResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditRuntimeRefreshResultImplCopyWith<
    _$LiveEditRuntimeRefreshResultImpl
  >
  get copyWith => throw _privateConstructorUsedError;
}

LiveEditResolutionProposal _$LiveEditResolutionProposalFromJson(
  Map<String, dynamic> json,
) {
  return _LiveEditResolutionProposal.fromJson(json);
}

/// @nodoc
mixin _$LiveEditResolutionProposal {
  String get proposalId => throw _privateConstructorUsedError;
  String get backendId => throw _privateConstructorUsedError;
  String get summary => throw _privateConstructorUsedError;
  String get patch => throw _privateConstructorUsedError;
  List<String> get changedFiles => throw _privateConstructorUsedError;
  List<LiveEditFilePatch> get filePatches => throw _privateConstructorUsedError;
  List<String> get expectedRuntimeEffects => throw _privateConstructorUsedError;
  List<String> get validationSteps => throw _privateConstructorUsedError;
  List<String> get warnings => throw _privateConstructorUsedError;
  List<String> get riskFlags => throw _privateConstructorUsedError;
  Map<String, Object?> get meta => throw _privateConstructorUsedError;

  /// Serializes this LiveEditResolutionProposal to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditResolutionProposal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditResolutionProposalCopyWith<LiveEditResolutionProposal>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditResolutionProposalCopyWith<$Res> {
  factory $LiveEditResolutionProposalCopyWith(
    LiveEditResolutionProposal value,
    $Res Function(LiveEditResolutionProposal) then,
  ) =
      _$LiveEditResolutionProposalCopyWithImpl<
        $Res,
        LiveEditResolutionProposal
      >;
  @useResult
  $Res call({
    String proposalId,
    String backendId,
    String summary,
    String patch,
    List<String> changedFiles,
    List<LiveEditFilePatch> filePatches,
    List<String> expectedRuntimeEffects,
    List<String> validationSteps,
    List<String> warnings,
    List<String> riskFlags,
    Map<String, Object?> meta,
  });
}

/// @nodoc
class _$LiveEditResolutionProposalCopyWithImpl<
  $Res,
  $Val extends LiveEditResolutionProposal
>
    implements $LiveEditResolutionProposalCopyWith<$Res> {
  _$LiveEditResolutionProposalCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditResolutionProposal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? proposalId = null,
    Object? backendId = null,
    Object? summary = null,
    Object? patch = null,
    Object? changedFiles = null,
    Object? filePatches = null,
    Object? expectedRuntimeEffects = null,
    Object? validationSteps = null,
    Object? warnings = null,
    Object? riskFlags = null,
    Object? meta = null,
  }) {
    return _then(
      _value.copyWith(
            proposalId: null == proposalId
                ? _value.proposalId
                : proposalId // ignore: cast_nullable_to_non_nullable
                      as String,
            backendId: null == backendId
                ? _value.backendId
                : backendId // ignore: cast_nullable_to_non_nullable
                      as String,
            summary: null == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                      as String,
            patch: null == patch
                ? _value.patch
                : patch // ignore: cast_nullable_to_non_nullable
                      as String,
            changedFiles: null == changedFiles
                ? _value.changedFiles
                : changedFiles // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            filePatches: null == filePatches
                ? _value.filePatches
                : filePatches // ignore: cast_nullable_to_non_nullable
                      as List<LiveEditFilePatch>,
            expectedRuntimeEffects: null == expectedRuntimeEffects
                ? _value.expectedRuntimeEffects
                : expectedRuntimeEffects // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            validationSteps: null == validationSteps
                ? _value.validationSteps
                : validationSteps // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            warnings: null == warnings
                ? _value.warnings
                : warnings // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            riskFlags: null == riskFlags
                ? _value.riskFlags
                : riskFlags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            meta: null == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LiveEditResolutionProposalImplCopyWith<$Res>
    implements $LiveEditResolutionProposalCopyWith<$Res> {
  factory _$$LiveEditResolutionProposalImplCopyWith(
    _$LiveEditResolutionProposalImpl value,
    $Res Function(_$LiveEditResolutionProposalImpl) then,
  ) = __$$LiveEditResolutionProposalImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String proposalId,
    String backendId,
    String summary,
    String patch,
    List<String> changedFiles,
    List<LiveEditFilePatch> filePatches,
    List<String> expectedRuntimeEffects,
    List<String> validationSteps,
    List<String> warnings,
    List<String> riskFlags,
    Map<String, Object?> meta,
  });
}

/// @nodoc
class __$$LiveEditResolutionProposalImplCopyWithImpl<$Res>
    extends
        _$LiveEditResolutionProposalCopyWithImpl<
          $Res,
          _$LiveEditResolutionProposalImpl
        >
    implements _$$LiveEditResolutionProposalImplCopyWith<$Res> {
  __$$LiveEditResolutionProposalImplCopyWithImpl(
    _$LiveEditResolutionProposalImpl _value,
    $Res Function(_$LiveEditResolutionProposalImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditResolutionProposal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? proposalId = null,
    Object? backendId = null,
    Object? summary = null,
    Object? patch = null,
    Object? changedFiles = null,
    Object? filePatches = null,
    Object? expectedRuntimeEffects = null,
    Object? validationSteps = null,
    Object? warnings = null,
    Object? riskFlags = null,
    Object? meta = null,
  }) {
    return _then(
      _$LiveEditResolutionProposalImpl(
        proposalId: null == proposalId
            ? _value.proposalId
            : proposalId // ignore: cast_nullable_to_non_nullable
                  as String,
        backendId: null == backendId
            ? _value.backendId
            : backendId // ignore: cast_nullable_to_non_nullable
                  as String,
        summary: null == summary
            ? _value.summary
            : summary // ignore: cast_nullable_to_non_nullable
                  as String,
        patch: null == patch
            ? _value.patch
            : patch // ignore: cast_nullable_to_non_nullable
                  as String,
        changedFiles: null == changedFiles
            ? _value._changedFiles
            : changedFiles // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        filePatches: null == filePatches
            ? _value._filePatches
            : filePatches // ignore: cast_nullable_to_non_nullable
                  as List<LiveEditFilePatch>,
        expectedRuntimeEffects: null == expectedRuntimeEffects
            ? _value._expectedRuntimeEffects
            : expectedRuntimeEffects // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        validationSteps: null == validationSteps
            ? _value._validationSteps
            : validationSteps // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        warnings: null == warnings
            ? _value._warnings
            : warnings // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        riskFlags: null == riskFlags
            ? _value._riskFlags
            : riskFlags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        meta: null == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LiveEditResolutionProposalImpl implements _LiveEditResolutionProposal {
  const _$LiveEditResolutionProposalImpl({
    required this.proposalId,
    required this.backendId,
    required this.summary,
    required this.patch,
    required final List<String> changedFiles,
    required final List<LiveEditFilePatch> filePatches,
    required final List<String> expectedRuntimeEffects,
    required final List<String> validationSteps,
    final List<String> warnings = const <String>[],
    final List<String> riskFlags = const <String>[],
    final Map<String, Object?> meta = const <String, Object?>{},
  }) : _changedFiles = changedFiles,
       _filePatches = filePatches,
       _expectedRuntimeEffects = expectedRuntimeEffects,
       _validationSteps = validationSteps,
       _warnings = warnings,
       _riskFlags = riskFlags,
       _meta = meta;

  factory _$LiveEditResolutionProposalImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$LiveEditResolutionProposalImplFromJson(json);

  @override
  final String proposalId;
  @override
  final String backendId;
  @override
  final String summary;
  @override
  final String patch;
  final List<String> _changedFiles;
  @override
  List<String> get changedFiles {
    if (_changedFiles is EqualUnmodifiableListView) return _changedFiles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_changedFiles);
  }

  final List<LiveEditFilePatch> _filePatches;
  @override
  List<LiveEditFilePatch> get filePatches {
    if (_filePatches is EqualUnmodifiableListView) return _filePatches;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_filePatches);
  }

  final List<String> _expectedRuntimeEffects;
  @override
  List<String> get expectedRuntimeEffects {
    if (_expectedRuntimeEffects is EqualUnmodifiableListView)
      return _expectedRuntimeEffects;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_expectedRuntimeEffects);
  }

  final List<String> _validationSteps;
  @override
  List<String> get validationSteps {
    if (_validationSteps is EqualUnmodifiableListView) return _validationSteps;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_validationSteps);
  }

  final List<String> _warnings;
  @override
  @JsonKey()
  List<String> get warnings {
    if (_warnings is EqualUnmodifiableListView) return _warnings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_warnings);
  }

  final List<String> _riskFlags;
  @override
  @JsonKey()
  List<String> get riskFlags {
    if (_riskFlags is EqualUnmodifiableListView) return _riskFlags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_riskFlags);
  }

  final Map<String, Object?> _meta;
  @override
  @JsonKey()
  Map<String, Object?> get meta {
    if (_meta is EqualUnmodifiableMapView) return _meta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_meta);
  }

  @override
  String toString() {
    return 'LiveEditResolutionProposal(proposalId: $proposalId, backendId: $backendId, summary: $summary, patch: $patch, changedFiles: $changedFiles, filePatches: $filePatches, expectedRuntimeEffects: $expectedRuntimeEffects, validationSteps: $validationSteps, warnings: $warnings, riskFlags: $riskFlags, meta: $meta)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditResolutionProposalImpl &&
            (identical(other.proposalId, proposalId) ||
                other.proposalId == proposalId) &&
            (identical(other.backendId, backendId) ||
                other.backendId == backendId) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.patch, patch) || other.patch == patch) &&
            const DeepCollectionEquality().equals(
              other._changedFiles,
              _changedFiles,
            ) &&
            const DeepCollectionEquality().equals(
              other._filePatches,
              _filePatches,
            ) &&
            const DeepCollectionEquality().equals(
              other._expectedRuntimeEffects,
              _expectedRuntimeEffects,
            ) &&
            const DeepCollectionEquality().equals(
              other._validationSteps,
              _validationSteps,
            ) &&
            const DeepCollectionEquality().equals(other._warnings, _warnings) &&
            const DeepCollectionEquality().equals(
              other._riskFlags,
              _riskFlags,
            ) &&
            const DeepCollectionEquality().equals(other._meta, _meta));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    proposalId,
    backendId,
    summary,
    patch,
    const DeepCollectionEquality().hash(_changedFiles),
    const DeepCollectionEquality().hash(_filePatches),
    const DeepCollectionEquality().hash(_expectedRuntimeEffects),
    const DeepCollectionEquality().hash(_validationSteps),
    const DeepCollectionEquality().hash(_warnings),
    const DeepCollectionEquality().hash(_riskFlags),
    const DeepCollectionEquality().hash(_meta),
  );

  /// Create a copy of LiveEditResolutionProposal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditResolutionProposalImplCopyWith<_$LiveEditResolutionProposalImpl>
  get copyWith =>
      __$$LiveEditResolutionProposalImplCopyWithImpl<
        _$LiveEditResolutionProposalImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LiveEditResolutionProposalImplToJson(this);
  }
}

abstract class _LiveEditResolutionProposal
    implements LiveEditResolutionProposal {
  const factory _LiveEditResolutionProposal({
    required final String proposalId,
    required final String backendId,
    required final String summary,
    required final String patch,
    required final List<String> changedFiles,
    required final List<LiveEditFilePatch> filePatches,
    required final List<String> expectedRuntimeEffects,
    required final List<String> validationSteps,
    final List<String> warnings,
    final List<String> riskFlags,
    final Map<String, Object?> meta,
  }) = _$LiveEditResolutionProposalImpl;

  factory _LiveEditResolutionProposal.fromJson(Map<String, dynamic> json) =
      _$LiveEditResolutionProposalImpl.fromJson;

  @override
  String get proposalId;
  @override
  String get backendId;
  @override
  String get summary;
  @override
  String get patch;
  @override
  List<String> get changedFiles;
  @override
  List<LiveEditFilePatch> get filePatches;
  @override
  List<String> get expectedRuntimeEffects;
  @override
  List<String> get validationSteps;
  @override
  List<String> get warnings;
  @override
  List<String> get riskFlags;
  @override
  Map<String, Object?> get meta;

  /// Create a copy of LiveEditResolutionProposal
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditResolutionProposalImplCopyWith<_$LiveEditResolutionProposalImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$LiveEditResolutionRequest {
  String get sessionId => throw _privateConstructorUsedError;
  String get workingDirectory => throw _privateConstructorUsedError;
  String? get bubbleId => throw _privateConstructorUsedError;
  String? get instructionText => throw _privateConstructorUsedError;
  LiveEditSelection? get primarySelection => throw _privateConstructorUsedError;
  List<LiveEditSelection> get selectedWidgets =>
      throw _privateConstructorUsedError;
  List<LiveEditSourceTarget> get sourceTargets =>
      throw _privateConstructorUsedError;
  LiveEditApplyMode get applyMode => throw _privateConstructorUsedError;
  LiveEditSelection? get selection => throw _privateConstructorUsedError;
  String? get backendId => throw _privateConstructorUsedError;
  LiveEditInferenceConfig? get inferenceConfig =>
      throw _privateConstructorUsedError;
  String? get intentText => throw _privateConstructorUsedError;
  Map<String, Object?> get evidence => throw _privateConstructorUsedError;
  Map<String, Object?> get meta => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditResolutionRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditResolutionRequestCopyWith<LiveEditResolutionRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditResolutionRequestCopyWith<$Res> {
  factory $LiveEditResolutionRequestCopyWith(
    LiveEditResolutionRequest value,
    $Res Function(LiveEditResolutionRequest) then,
  ) = _$LiveEditResolutionRequestCopyWithImpl<$Res, LiveEditResolutionRequest>;
  @useResult
  $Res call({
    String sessionId,
    String workingDirectory,
    String? bubbleId,
    String? instructionText,
    LiveEditSelection? primarySelection,
    List<LiveEditSelection> selectedWidgets,
    List<LiveEditSourceTarget> sourceTargets,
    LiveEditApplyMode applyMode,
    LiveEditSelection? selection,
    String? backendId,
    LiveEditInferenceConfig? inferenceConfig,
    String? intentText,
    Map<String, Object?> evidence,
    Map<String, Object?> meta,
  });

  $LiveEditSelectionCopyWith<$Res>? get primarySelection;
  $LiveEditSelectionCopyWith<$Res>? get selection;
  $LiveEditInferenceConfigCopyWith<$Res>? get inferenceConfig;
}

/// @nodoc
class _$LiveEditResolutionRequestCopyWithImpl<
  $Res,
  $Val extends LiveEditResolutionRequest
>
    implements $LiveEditResolutionRequestCopyWith<$Res> {
  _$LiveEditResolutionRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditResolutionRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? workingDirectory = null,
    Object? bubbleId = freezed,
    Object? instructionText = freezed,
    Object? primarySelection = freezed,
    Object? selectedWidgets = null,
    Object? sourceTargets = null,
    Object? applyMode = null,
    Object? selection = freezed,
    Object? backendId = freezed,
    Object? inferenceConfig = freezed,
    Object? intentText = freezed,
    Object? evidence = null,
    Object? meta = null,
  }) {
    return _then(
      _value.copyWith(
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            workingDirectory: null == workingDirectory
                ? _value.workingDirectory
                : workingDirectory // ignore: cast_nullable_to_non_nullable
                      as String,
            bubbleId: freezed == bubbleId
                ? _value.bubbleId
                : bubbleId // ignore: cast_nullable_to_non_nullable
                      as String?,
            instructionText: freezed == instructionText
                ? _value.instructionText
                : instructionText // ignore: cast_nullable_to_non_nullable
                      as String?,
            primarySelection: freezed == primarySelection
                ? _value.primarySelection
                : primarySelection // ignore: cast_nullable_to_non_nullable
                      as LiveEditSelection?,
            selectedWidgets: null == selectedWidgets
                ? _value.selectedWidgets
                : selectedWidgets // ignore: cast_nullable_to_non_nullable
                      as List<LiveEditSelection>,
            sourceTargets: null == sourceTargets
                ? _value.sourceTargets
                : sourceTargets // ignore: cast_nullable_to_non_nullable
                      as List<LiveEditSourceTarget>,
            applyMode: null == applyMode
                ? _value.applyMode
                : applyMode // ignore: cast_nullable_to_non_nullable
                      as LiveEditApplyMode,
            selection: freezed == selection
                ? _value.selection
                : selection // ignore: cast_nullable_to_non_nullable
                      as LiveEditSelection?,
            backendId: freezed == backendId
                ? _value.backendId
                : backendId // ignore: cast_nullable_to_non_nullable
                      as String?,
            inferenceConfig: freezed == inferenceConfig
                ? _value.inferenceConfig
                : inferenceConfig // ignore: cast_nullable_to_non_nullable
                      as LiveEditInferenceConfig?,
            intentText: freezed == intentText
                ? _value.intentText
                : intentText // ignore: cast_nullable_to_non_nullable
                      as String?,
            evidence: null == evidence
                ? _value.evidence
                : evidence // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            meta: null == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
          )
          as $Val,
    );
  }

  /// Create a copy of LiveEditResolutionRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LiveEditSelectionCopyWith<$Res>? get primarySelection {
    if (_value.primarySelection == null) {
      return null;
    }

    return $LiveEditSelectionCopyWith<$Res>(_value.primarySelection!, (value) {
      return _then(_value.copyWith(primarySelection: value) as $Val);
    });
  }

  /// Create a copy of LiveEditResolutionRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LiveEditSelectionCopyWith<$Res>? get selection {
    if (_value.selection == null) {
      return null;
    }

    return $LiveEditSelectionCopyWith<$Res>(_value.selection!, (value) {
      return _then(_value.copyWith(selection: value) as $Val);
    });
  }

  /// Create a copy of LiveEditResolutionRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LiveEditInferenceConfigCopyWith<$Res>? get inferenceConfig {
    if (_value.inferenceConfig == null) {
      return null;
    }

    return $LiveEditInferenceConfigCopyWith<$Res>(_value.inferenceConfig!, (
      value,
    ) {
      return _then(_value.copyWith(inferenceConfig: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$LiveEditResolutionRequestImplCopyWith<$Res>
    implements $LiveEditResolutionRequestCopyWith<$Res> {
  factory _$$LiveEditResolutionRequestImplCopyWith(
    _$LiveEditResolutionRequestImpl value,
    $Res Function(_$LiveEditResolutionRequestImpl) then,
  ) = __$$LiveEditResolutionRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String sessionId,
    String workingDirectory,
    String? bubbleId,
    String? instructionText,
    LiveEditSelection? primarySelection,
    List<LiveEditSelection> selectedWidgets,
    List<LiveEditSourceTarget> sourceTargets,
    LiveEditApplyMode applyMode,
    LiveEditSelection? selection,
    String? backendId,
    LiveEditInferenceConfig? inferenceConfig,
    String? intentText,
    Map<String, Object?> evidence,
    Map<String, Object?> meta,
  });

  @override
  $LiveEditSelectionCopyWith<$Res>? get primarySelection;
  @override
  $LiveEditSelectionCopyWith<$Res>? get selection;
  @override
  $LiveEditInferenceConfigCopyWith<$Res>? get inferenceConfig;
}

/// @nodoc
class __$$LiveEditResolutionRequestImplCopyWithImpl<$Res>
    extends
        _$LiveEditResolutionRequestCopyWithImpl<
          $Res,
          _$LiveEditResolutionRequestImpl
        >
    implements _$$LiveEditResolutionRequestImplCopyWith<$Res> {
  __$$LiveEditResolutionRequestImplCopyWithImpl(
    _$LiveEditResolutionRequestImpl _value,
    $Res Function(_$LiveEditResolutionRequestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditResolutionRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? workingDirectory = null,
    Object? bubbleId = freezed,
    Object? instructionText = freezed,
    Object? primarySelection = freezed,
    Object? selectedWidgets = null,
    Object? sourceTargets = null,
    Object? applyMode = null,
    Object? selection = freezed,
    Object? backendId = freezed,
    Object? inferenceConfig = freezed,
    Object? intentText = freezed,
    Object? evidence = null,
    Object? meta = null,
  }) {
    return _then(
      _$LiveEditResolutionRequestImpl(
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        workingDirectory: null == workingDirectory
            ? _value.workingDirectory
            : workingDirectory // ignore: cast_nullable_to_non_nullable
                  as String,
        bubbleId: freezed == bubbleId
            ? _value.bubbleId
            : bubbleId // ignore: cast_nullable_to_non_nullable
                  as String?,
        instructionText: freezed == instructionText
            ? _value.instructionText
            : instructionText // ignore: cast_nullable_to_non_nullable
                  as String?,
        primarySelection: freezed == primarySelection
            ? _value.primarySelection
            : primarySelection // ignore: cast_nullable_to_non_nullable
                  as LiveEditSelection?,
        selectedWidgets: null == selectedWidgets
            ? _value._selectedWidgets
            : selectedWidgets // ignore: cast_nullable_to_non_nullable
                  as List<LiveEditSelection>,
        sourceTargets: null == sourceTargets
            ? _value._sourceTargets
            : sourceTargets // ignore: cast_nullable_to_non_nullable
                  as List<LiveEditSourceTarget>,
        applyMode: null == applyMode
            ? _value.applyMode
            : applyMode // ignore: cast_nullable_to_non_nullable
                  as LiveEditApplyMode,
        selection: freezed == selection
            ? _value.selection
            : selection // ignore: cast_nullable_to_non_nullable
                  as LiveEditSelection?,
        backendId: freezed == backendId
            ? _value.backendId
            : backendId // ignore: cast_nullable_to_non_nullable
                  as String?,
        inferenceConfig: freezed == inferenceConfig
            ? _value.inferenceConfig
            : inferenceConfig // ignore: cast_nullable_to_non_nullable
                  as LiveEditInferenceConfig?,
        intentText: freezed == intentText
            ? _value.intentText
            : intentText // ignore: cast_nullable_to_non_nullable
                  as String?,
        evidence: null == evidence
            ? _value._evidence
            : evidence // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        meta: null == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
      ),
    );
  }
}

/// @nodoc

class _$LiveEditResolutionRequestImpl extends _LiveEditResolutionRequest {
  const _$LiveEditResolutionRequestImpl({
    required this.sessionId,
    required this.workingDirectory,
    this.bubbleId,
    this.instructionText,
    this.primarySelection,
    final List<LiveEditSelection> selectedWidgets = const <LiveEditSelection>[],
    final List<LiveEditSourceTarget> sourceTargets =
        const <LiveEditSourceTarget>[],
    this.applyMode = LiveEditApplyMode.singleBubble,
    this.selection,
    this.backendId,
    this.inferenceConfig,
    this.intentText,
    final Map<String, Object?> evidence = const <String, Object?>{},
    final Map<String, Object?> meta = const <String, Object?>{},
  }) : _selectedWidgets = selectedWidgets,
       _sourceTargets = sourceTargets,
       _evidence = evidence,
       _meta = meta,
       super._();

  @override
  final String sessionId;
  @override
  final String workingDirectory;
  @override
  final String? bubbleId;
  @override
  final String? instructionText;
  @override
  final LiveEditSelection? primarySelection;
  final List<LiveEditSelection> _selectedWidgets;
  @override
  @JsonKey()
  List<LiveEditSelection> get selectedWidgets {
    if (_selectedWidgets is EqualUnmodifiableListView) return _selectedWidgets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_selectedWidgets);
  }

  final List<LiveEditSourceTarget> _sourceTargets;
  @override
  @JsonKey()
  List<LiveEditSourceTarget> get sourceTargets {
    if (_sourceTargets is EqualUnmodifiableListView) return _sourceTargets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sourceTargets);
  }

  @override
  @JsonKey()
  final LiveEditApplyMode applyMode;
  @override
  final LiveEditSelection? selection;
  @override
  final String? backendId;
  @override
  final LiveEditInferenceConfig? inferenceConfig;
  @override
  final String? intentText;
  final Map<String, Object?> _evidence;
  @override
  @JsonKey()
  Map<String, Object?> get evidence {
    if (_evidence is EqualUnmodifiableMapView) return _evidence;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_evidence);
  }

  final Map<String, Object?> _meta;
  @override
  @JsonKey()
  Map<String, Object?> get meta {
    if (_meta is EqualUnmodifiableMapView) return _meta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_meta);
  }

  @override
  String toString() {
    return 'LiveEditResolutionRequest(sessionId: $sessionId, workingDirectory: $workingDirectory, bubbleId: $bubbleId, instructionText: $instructionText, primarySelection: $primarySelection, selectedWidgets: $selectedWidgets, sourceTargets: $sourceTargets, applyMode: $applyMode, selection: $selection, backendId: $backendId, inferenceConfig: $inferenceConfig, intentText: $intentText, evidence: $evidence, meta: $meta)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditResolutionRequestImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.workingDirectory, workingDirectory) ||
                other.workingDirectory == workingDirectory) &&
            (identical(other.bubbleId, bubbleId) ||
                other.bubbleId == bubbleId) &&
            (identical(other.instructionText, instructionText) ||
                other.instructionText == instructionText) &&
            (identical(other.primarySelection, primarySelection) ||
                other.primarySelection == primarySelection) &&
            const DeepCollectionEquality().equals(
              other._selectedWidgets,
              _selectedWidgets,
            ) &&
            const DeepCollectionEquality().equals(
              other._sourceTargets,
              _sourceTargets,
            ) &&
            (identical(other.applyMode, applyMode) ||
                other.applyMode == applyMode) &&
            (identical(other.selection, selection) ||
                other.selection == selection) &&
            (identical(other.backendId, backendId) ||
                other.backendId == backendId) &&
            (identical(other.inferenceConfig, inferenceConfig) ||
                other.inferenceConfig == inferenceConfig) &&
            (identical(other.intentText, intentText) ||
                other.intentText == intentText) &&
            const DeepCollectionEquality().equals(other._evidence, _evidence) &&
            const DeepCollectionEquality().equals(other._meta, _meta));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    sessionId,
    workingDirectory,
    bubbleId,
    instructionText,
    primarySelection,
    const DeepCollectionEquality().hash(_selectedWidgets),
    const DeepCollectionEquality().hash(_sourceTargets),
    applyMode,
    selection,
    backendId,
    inferenceConfig,
    intentText,
    const DeepCollectionEquality().hash(_evidence),
    const DeepCollectionEquality().hash(_meta),
  );

  /// Create a copy of LiveEditResolutionRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditResolutionRequestImplCopyWith<_$LiveEditResolutionRequestImpl>
  get copyWith =>
      __$$LiveEditResolutionRequestImplCopyWithImpl<
        _$LiveEditResolutionRequestImpl
      >(this, _$identity);
}

abstract class _LiveEditResolutionRequest extends LiveEditResolutionRequest {
  const factory _LiveEditResolutionRequest({
    required final String sessionId,
    required final String workingDirectory,
    final String? bubbleId,
    final String? instructionText,
    final LiveEditSelection? primarySelection,
    final List<LiveEditSelection> selectedWidgets,
    final List<LiveEditSourceTarget> sourceTargets,
    final LiveEditApplyMode applyMode,
    final LiveEditSelection? selection,
    final String? backendId,
    final LiveEditInferenceConfig? inferenceConfig,
    final String? intentText,
    final Map<String, Object?> evidence,
    final Map<String, Object?> meta,
  }) = _$LiveEditResolutionRequestImpl;
  const _LiveEditResolutionRequest._() : super._();

  @override
  String get sessionId;
  @override
  String get workingDirectory;
  @override
  String? get bubbleId;
  @override
  String? get instructionText;
  @override
  LiveEditSelection? get primarySelection;
  @override
  List<LiveEditSelection> get selectedWidgets;
  @override
  List<LiveEditSourceTarget> get sourceTargets;
  @override
  LiveEditApplyMode get applyMode;
  @override
  LiveEditSelection? get selection;
  @override
  String? get backendId;
  @override
  LiveEditInferenceConfig? get inferenceConfig;
  @override
  String? get intentText;
  @override
  Map<String, Object?> get evidence;
  @override
  Map<String, Object?> get meta;

  /// Create a copy of LiveEditResolutionRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditResolutionRequestImplCopyWith<_$LiveEditResolutionRequestImpl>
  get copyWith => throw _privateConstructorUsedError;
}

LiveEditSourceTarget _$LiveEditSourceTargetFromJson(Map<String, dynamic> json) {
  return _LiveEditSourceTarget.fromJson(json);
}

/// @nodoc
mixin _$LiveEditSourceTarget {
  String get nodeId => throw _privateConstructorUsedError;
  String get widgetType => throw _privateConstructorUsedError;
  String? get absolutePath => throw _privateConstructorUsedError;
  String? get workspacePath => throw _privateConstructorUsedError;
  int? get line => throw _privateConstructorUsedError;
  int? get column => throw _privateConstructorUsedError;

  /// Serializes this LiveEditSourceTarget to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditSourceTarget
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditSourceTargetCopyWith<LiveEditSourceTarget> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditSourceTargetCopyWith<$Res> {
  factory $LiveEditSourceTargetCopyWith(
    LiveEditSourceTarget value,
    $Res Function(LiveEditSourceTarget) then,
  ) = _$LiveEditSourceTargetCopyWithImpl<$Res, LiveEditSourceTarget>;
  @useResult
  $Res call({
    String nodeId,
    String widgetType,
    String? absolutePath,
    String? workspacePath,
    int? line,
    int? column,
  });
}

/// @nodoc
class _$LiveEditSourceTargetCopyWithImpl<
  $Res,
  $Val extends LiveEditSourceTarget
>
    implements $LiveEditSourceTargetCopyWith<$Res> {
  _$LiveEditSourceTargetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditSourceTarget
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeId = null,
    Object? widgetType = null,
    Object? absolutePath = freezed,
    Object? workspacePath = freezed,
    Object? line = freezed,
    Object? column = freezed,
  }) {
    return _then(
      _value.copyWith(
            nodeId: null == nodeId
                ? _value.nodeId
                : nodeId // ignore: cast_nullable_to_non_nullable
                      as String,
            widgetType: null == widgetType
                ? _value.widgetType
                : widgetType // ignore: cast_nullable_to_non_nullable
                      as String,
            absolutePath: freezed == absolutePath
                ? _value.absolutePath
                : absolutePath // ignore: cast_nullable_to_non_nullable
                      as String?,
            workspacePath: freezed == workspacePath
                ? _value.workspacePath
                : workspacePath // ignore: cast_nullable_to_non_nullable
                      as String?,
            line: freezed == line
                ? _value.line
                : line // ignore: cast_nullable_to_non_nullable
                      as int?,
            column: freezed == column
                ? _value.column
                : column // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LiveEditSourceTargetImplCopyWith<$Res>
    implements $LiveEditSourceTargetCopyWith<$Res> {
  factory _$$LiveEditSourceTargetImplCopyWith(
    _$LiveEditSourceTargetImpl value,
    $Res Function(_$LiveEditSourceTargetImpl) then,
  ) = __$$LiveEditSourceTargetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String nodeId,
    String widgetType,
    String? absolutePath,
    String? workspacePath,
    int? line,
    int? column,
  });
}

/// @nodoc
class __$$LiveEditSourceTargetImplCopyWithImpl<$Res>
    extends _$LiveEditSourceTargetCopyWithImpl<$Res, _$LiveEditSourceTargetImpl>
    implements _$$LiveEditSourceTargetImplCopyWith<$Res> {
  __$$LiveEditSourceTargetImplCopyWithImpl(
    _$LiveEditSourceTargetImpl _value,
    $Res Function(_$LiveEditSourceTargetImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditSourceTarget
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeId = null,
    Object? widgetType = null,
    Object? absolutePath = freezed,
    Object? workspacePath = freezed,
    Object? line = freezed,
    Object? column = freezed,
  }) {
    return _then(
      _$LiveEditSourceTargetImpl(
        nodeId: null == nodeId
            ? _value.nodeId
            : nodeId // ignore: cast_nullable_to_non_nullable
                  as String,
        widgetType: null == widgetType
            ? _value.widgetType
            : widgetType // ignore: cast_nullable_to_non_nullable
                  as String,
        absolutePath: freezed == absolutePath
            ? _value.absolutePath
            : absolutePath // ignore: cast_nullable_to_non_nullable
                  as String?,
        workspacePath: freezed == workspacePath
            ? _value.workspacePath
            : workspacePath // ignore: cast_nullable_to_non_nullable
                  as String?,
        line: freezed == line
            ? _value.line
            : line // ignore: cast_nullable_to_non_nullable
                  as int?,
        column: freezed == column
            ? _value.column
            : column // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LiveEditSourceTargetImpl implements _LiveEditSourceTarget {
  const _$LiveEditSourceTargetImpl({
    required this.nodeId,
    required this.widgetType,
    this.absolutePath,
    this.workspacePath,
    this.line,
    this.column,
  });

  factory _$LiveEditSourceTargetImpl.fromJson(Map<String, dynamic> json) =>
      _$$LiveEditSourceTargetImplFromJson(json);

  @override
  final String nodeId;
  @override
  final String widgetType;
  @override
  final String? absolutePath;
  @override
  final String? workspacePath;
  @override
  final int? line;
  @override
  final int? column;

  @override
  String toString() {
    return 'LiveEditSourceTarget(nodeId: $nodeId, widgetType: $widgetType, absolutePath: $absolutePath, workspacePath: $workspacePath, line: $line, column: $column)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditSourceTargetImpl &&
            (identical(other.nodeId, nodeId) || other.nodeId == nodeId) &&
            (identical(other.widgetType, widgetType) ||
                other.widgetType == widgetType) &&
            (identical(other.absolutePath, absolutePath) ||
                other.absolutePath == absolutePath) &&
            (identical(other.workspacePath, workspacePath) ||
                other.workspacePath == workspacePath) &&
            (identical(other.line, line) || other.line == line) &&
            (identical(other.column, column) || other.column == column));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    nodeId,
    widgetType,
    absolutePath,
    workspacePath,
    line,
    column,
  );

  /// Create a copy of LiveEditSourceTarget
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditSourceTargetImplCopyWith<_$LiveEditSourceTargetImpl>
  get copyWith =>
      __$$LiveEditSourceTargetImplCopyWithImpl<_$LiveEditSourceTargetImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$LiveEditSourceTargetImplToJson(this);
  }
}

abstract class _LiveEditSourceTarget implements LiveEditSourceTarget {
  const factory _LiveEditSourceTarget({
    required final String nodeId,
    required final String widgetType,
    final String? absolutePath,
    final String? workspacePath,
    final int? line,
    final int? column,
  }) = _$LiveEditSourceTargetImpl;

  factory _LiveEditSourceTarget.fromJson(Map<String, dynamic> json) =
      _$LiveEditSourceTargetImpl.fromJson;

  @override
  String get nodeId;
  @override
  String get widgetType;
  @override
  String? get absolutePath;
  @override
  String? get workspacePath;
  @override
  int? get line;
  @override
  int? get column;

  /// Create a copy of LiveEditSourceTarget
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditSourceTargetImplCopyWith<_$LiveEditSourceTargetImpl>
  get copyWith => throw _privateConstructorUsedError;
}

LiveEditResolutionResult _$LiveEditResolutionResultFromJson(
  Map<String, dynamic> json,
) {
  return _LiveEditResolutionResult.fromJson(json);
}

/// @nodoc
mixin _$LiveEditResolutionResult {
  String get proposalId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _resolutionStatusFromJson, toJson: _enumToWire)
  LiveEditResolutionStatus get status => throw _privateConstructorUsedError;
  List<String> get changedFiles => throw _privateConstructorUsedError;
  Map<String, Object?> get validation => throw _privateConstructorUsedError;
  List<String> get warnings => throw _privateConstructorUsedError;
  Map<String, Object?> get meta => throw _privateConstructorUsedError;

  /// Serializes this LiveEditResolutionResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditResolutionResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditResolutionResultCopyWith<LiveEditResolutionResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditResolutionResultCopyWith<$Res> {
  factory $LiveEditResolutionResultCopyWith(
    LiveEditResolutionResult value,
    $Res Function(LiveEditResolutionResult) then,
  ) = _$LiveEditResolutionResultCopyWithImpl<$Res, LiveEditResolutionResult>;
  @useResult
  $Res call({
    String proposalId,
    @JsonKey(fromJson: _resolutionStatusFromJson, toJson: _enumToWire)
    LiveEditResolutionStatus status,
    List<String> changedFiles,
    Map<String, Object?> validation,
    List<String> warnings,
    Map<String, Object?> meta,
  });
}

/// @nodoc
class _$LiveEditResolutionResultCopyWithImpl<
  $Res,
  $Val extends LiveEditResolutionResult
>
    implements $LiveEditResolutionResultCopyWith<$Res> {
  _$LiveEditResolutionResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditResolutionResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? proposalId = null,
    Object? status = null,
    Object? changedFiles = null,
    Object? validation = null,
    Object? warnings = null,
    Object? meta = null,
  }) {
    return _then(
      _value.copyWith(
            proposalId: null == proposalId
                ? _value.proposalId
                : proposalId // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as LiveEditResolutionStatus,
            changedFiles: null == changedFiles
                ? _value.changedFiles
                : changedFiles // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            validation: null == validation
                ? _value.validation
                : validation // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            warnings: null == warnings
                ? _value.warnings
                : warnings // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            meta: null == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LiveEditResolutionResultImplCopyWith<$Res>
    implements $LiveEditResolutionResultCopyWith<$Res> {
  factory _$$LiveEditResolutionResultImplCopyWith(
    _$LiveEditResolutionResultImpl value,
    $Res Function(_$LiveEditResolutionResultImpl) then,
  ) = __$$LiveEditResolutionResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String proposalId,
    @JsonKey(fromJson: _resolutionStatusFromJson, toJson: _enumToWire)
    LiveEditResolutionStatus status,
    List<String> changedFiles,
    Map<String, Object?> validation,
    List<String> warnings,
    Map<String, Object?> meta,
  });
}

/// @nodoc
class __$$LiveEditResolutionResultImplCopyWithImpl<$Res>
    extends
        _$LiveEditResolutionResultCopyWithImpl<
          $Res,
          _$LiveEditResolutionResultImpl
        >
    implements _$$LiveEditResolutionResultImplCopyWith<$Res> {
  __$$LiveEditResolutionResultImplCopyWithImpl(
    _$LiveEditResolutionResultImpl _value,
    $Res Function(_$LiveEditResolutionResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditResolutionResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? proposalId = null,
    Object? status = null,
    Object? changedFiles = null,
    Object? validation = null,
    Object? warnings = null,
    Object? meta = null,
  }) {
    return _then(
      _$LiveEditResolutionResultImpl(
        proposalId: null == proposalId
            ? _value.proposalId
            : proposalId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as LiveEditResolutionStatus,
        changedFiles: null == changedFiles
            ? _value._changedFiles
            : changedFiles // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        validation: null == validation
            ? _value._validation
            : validation // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        warnings: null == warnings
            ? _value._warnings
            : warnings // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        meta: null == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LiveEditResolutionResultImpl implements _LiveEditResolutionResult {
  const _$LiveEditResolutionResultImpl({
    required this.proposalId,
    @JsonKey(fromJson: _resolutionStatusFromJson, toJson: _enumToWire)
    required this.status,
    final List<String> changedFiles = const <String>[],
    final Map<String, Object?> validation = const <String, Object?>{},
    final List<String> warnings = const <String>[],
    final Map<String, Object?> meta = const <String, Object?>{},
  }) : _changedFiles = changedFiles,
       _validation = validation,
       _warnings = warnings,
       _meta = meta;

  factory _$LiveEditResolutionResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$LiveEditResolutionResultImplFromJson(json);

  @override
  final String proposalId;
  @override
  @JsonKey(fromJson: _resolutionStatusFromJson, toJson: _enumToWire)
  final LiveEditResolutionStatus status;
  final List<String> _changedFiles;
  @override
  @JsonKey()
  List<String> get changedFiles {
    if (_changedFiles is EqualUnmodifiableListView) return _changedFiles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_changedFiles);
  }

  final Map<String, Object?> _validation;
  @override
  @JsonKey()
  Map<String, Object?> get validation {
    if (_validation is EqualUnmodifiableMapView) return _validation;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_validation);
  }

  final List<String> _warnings;
  @override
  @JsonKey()
  List<String> get warnings {
    if (_warnings is EqualUnmodifiableListView) return _warnings;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_warnings);
  }

  final Map<String, Object?> _meta;
  @override
  @JsonKey()
  Map<String, Object?> get meta {
    if (_meta is EqualUnmodifiableMapView) return _meta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_meta);
  }

  @override
  String toString() {
    return 'LiveEditResolutionResult(proposalId: $proposalId, status: $status, changedFiles: $changedFiles, validation: $validation, warnings: $warnings, meta: $meta)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditResolutionResultImpl &&
            (identical(other.proposalId, proposalId) ||
                other.proposalId == proposalId) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(
              other._changedFiles,
              _changedFiles,
            ) &&
            const DeepCollectionEquality().equals(
              other._validation,
              _validation,
            ) &&
            const DeepCollectionEquality().equals(other._warnings, _warnings) &&
            const DeepCollectionEquality().equals(other._meta, _meta));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    proposalId,
    status,
    const DeepCollectionEquality().hash(_changedFiles),
    const DeepCollectionEquality().hash(_validation),
    const DeepCollectionEquality().hash(_warnings),
    const DeepCollectionEquality().hash(_meta),
  );

  /// Create a copy of LiveEditResolutionResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditResolutionResultImplCopyWith<_$LiveEditResolutionResultImpl>
  get copyWith =>
      __$$LiveEditResolutionResultImplCopyWithImpl<
        _$LiveEditResolutionResultImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LiveEditResolutionResultImplToJson(this);
  }
}

abstract class _LiveEditResolutionResult implements LiveEditResolutionResult {
  const factory _LiveEditResolutionResult({
    required final String proposalId,
    @JsonKey(fromJson: _resolutionStatusFromJson, toJson: _enumToWire)
    required final LiveEditResolutionStatus status,
    final List<String> changedFiles,
    final Map<String, Object?> validation,
    final List<String> warnings,
    final Map<String, Object?> meta,
  }) = _$LiveEditResolutionResultImpl;

  factory _LiveEditResolutionResult.fromJson(Map<String, dynamic> json) =
      _$LiveEditResolutionResultImpl.fromJson;

  @override
  String get proposalId;
  @override
  @JsonKey(fromJson: _resolutionStatusFromJson, toJson: _enumToWire)
  LiveEditResolutionStatus get status;
  @override
  List<String> get changedFiles;
  @override
  Map<String, Object?> get validation;
  @override
  List<String> get warnings;
  @override
  Map<String, Object?> get meta;

  /// Create a copy of LiveEditResolutionResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditResolutionResultImplCopyWith<_$LiveEditResolutionResultImpl>
  get copyWith => throw _privateConstructorUsedError;
}

LiveEditSelection _$LiveEditSelectionFromJson(Map<String, dynamic> json) {
  return _LiveEditSelection.fromJson(json);
}

/// @nodoc
mixin _$LiveEditSelection {
  String get sessionId => throw _privateConstructorUsedError;
  String get nodeId => throw _privateConstructorUsedError;
  String get widgetType => throw _privateConstructorUsedError;
  @JsonKey(name: 'properties')
  List<Object?> get propertiesForWire => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _asMap)
  Map<String, Object?> get rawNode => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _targetDomainFromJson, toJson: _enumToWire)
  LiveEditTargetDomain get targetDomain => throw _privateConstructorUsedError;
  String? get renderObjectType => throw _privateConstructorUsedError;
  LiveEditBounds? get bounds => throw _privateConstructorUsedError;
  LiveEditSourceLocation? get source => throw _privateConstructorUsedError;
  Map<String, Object?> get layoutContext => throw _privateConstructorUsedError;
  List<Map<String, Object?>> get parentChain =>
      throw _privateConstructorUsedError;
  Map<String, Object?> get detailsTree => throw _privateConstructorUsedError;
  Map<String, Object?> get propertiesTree => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _selectionModeFromJson, toJson: _enumToWire)
  LiveEditSelectionMode get selectionMode => throw _privateConstructorUsedError;
  List<String> get selectedNodeIds => throw _privateConstructorUsedError;

  /// Serializes this LiveEditSelection to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditSelection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditSelectionCopyWith<LiveEditSelection> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditSelectionCopyWith<$Res> {
  factory $LiveEditSelectionCopyWith(
    LiveEditSelection value,
    $Res Function(LiveEditSelection) then,
  ) = _$LiveEditSelectionCopyWithImpl<$Res, LiveEditSelection>;
  @useResult
  $Res call({
    String sessionId,
    String nodeId,
    String widgetType,
    @JsonKey(name: 'properties') List<Object?> propertiesForWire,
    @JsonKey(fromJson: _asMap) Map<String, Object?> rawNode,
    @JsonKey(fromJson: _targetDomainFromJson, toJson: _enumToWire)
    LiveEditTargetDomain targetDomain,
    String? renderObjectType,
    LiveEditBounds? bounds,
    LiveEditSourceLocation? source,
    Map<String, Object?> layoutContext,
    List<Map<String, Object?>> parentChain,
    Map<String, Object?> detailsTree,
    Map<String, Object?> propertiesTree,
    @JsonKey(fromJson: _selectionModeFromJson, toJson: _enumToWire)
    LiveEditSelectionMode selectionMode,
    List<String> selectedNodeIds,
  });

  $LiveEditBoundsCopyWith<$Res>? get bounds;
  $LiveEditSourceLocationCopyWith<$Res>? get source;
}

/// @nodoc
class _$LiveEditSelectionCopyWithImpl<$Res, $Val extends LiveEditSelection>
    implements $LiveEditSelectionCopyWith<$Res> {
  _$LiveEditSelectionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditSelection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? nodeId = null,
    Object? widgetType = null,
    Object? propertiesForWire = null,
    Object? rawNode = null,
    Object? targetDomain = null,
    Object? renderObjectType = freezed,
    Object? bounds = freezed,
    Object? source = freezed,
    Object? layoutContext = null,
    Object? parentChain = null,
    Object? detailsTree = null,
    Object? propertiesTree = null,
    Object? selectionMode = null,
    Object? selectedNodeIds = null,
  }) {
    return _then(
      _value.copyWith(
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            nodeId: null == nodeId
                ? _value.nodeId
                : nodeId // ignore: cast_nullable_to_non_nullable
                      as String,
            widgetType: null == widgetType
                ? _value.widgetType
                : widgetType // ignore: cast_nullable_to_non_nullable
                      as String,
            propertiesForWire: null == propertiesForWire
                ? _value.propertiesForWire
                : propertiesForWire // ignore: cast_nullable_to_non_nullable
                      as List<Object?>,
            rawNode: null == rawNode
                ? _value.rawNode
                : rawNode // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            targetDomain: null == targetDomain
                ? _value.targetDomain
                : targetDomain // ignore: cast_nullable_to_non_nullable
                      as LiveEditTargetDomain,
            renderObjectType: freezed == renderObjectType
                ? _value.renderObjectType
                : renderObjectType // ignore: cast_nullable_to_non_nullable
                      as String?,
            bounds: freezed == bounds
                ? _value.bounds
                : bounds // ignore: cast_nullable_to_non_nullable
                      as LiveEditBounds?,
            source: freezed == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as LiveEditSourceLocation?,
            layoutContext: null == layoutContext
                ? _value.layoutContext
                : layoutContext // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            parentChain: null == parentChain
                ? _value.parentChain
                : parentChain // ignore: cast_nullable_to_non_nullable
                      as List<Map<String, Object?>>,
            detailsTree: null == detailsTree
                ? _value.detailsTree
                : detailsTree // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            propertiesTree: null == propertiesTree
                ? _value.propertiesTree
                : propertiesTree // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            selectionMode: null == selectionMode
                ? _value.selectionMode
                : selectionMode // ignore: cast_nullable_to_non_nullable
                      as LiveEditSelectionMode,
            selectedNodeIds: null == selectedNodeIds
                ? _value.selectedNodeIds
                : selectedNodeIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }

  /// Create a copy of LiveEditSelection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LiveEditBoundsCopyWith<$Res>? get bounds {
    if (_value.bounds == null) {
      return null;
    }

    return $LiveEditBoundsCopyWith<$Res>(_value.bounds!, (value) {
      return _then(_value.copyWith(bounds: value) as $Val);
    });
  }

  /// Create a copy of LiveEditSelection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LiveEditSourceLocationCopyWith<$Res>? get source {
    if (_value.source == null) {
      return null;
    }

    return $LiveEditSourceLocationCopyWith<$Res>(_value.source!, (value) {
      return _then(_value.copyWith(source: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$LiveEditSelectionImplCopyWith<$Res>
    implements $LiveEditSelectionCopyWith<$Res> {
  factory _$$LiveEditSelectionImplCopyWith(
    _$LiveEditSelectionImpl value,
    $Res Function(_$LiveEditSelectionImpl) then,
  ) = __$$LiveEditSelectionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String sessionId,
    String nodeId,
    String widgetType,
    @JsonKey(name: 'properties') List<Object?> propertiesForWire,
    @JsonKey(fromJson: _asMap) Map<String, Object?> rawNode,
    @JsonKey(fromJson: _targetDomainFromJson, toJson: _enumToWire)
    LiveEditTargetDomain targetDomain,
    String? renderObjectType,
    LiveEditBounds? bounds,
    LiveEditSourceLocation? source,
    Map<String, Object?> layoutContext,
    List<Map<String, Object?>> parentChain,
    Map<String, Object?> detailsTree,
    Map<String, Object?> propertiesTree,
    @JsonKey(fromJson: _selectionModeFromJson, toJson: _enumToWire)
    LiveEditSelectionMode selectionMode,
    List<String> selectedNodeIds,
  });

  @override
  $LiveEditBoundsCopyWith<$Res>? get bounds;
  @override
  $LiveEditSourceLocationCopyWith<$Res>? get source;
}

/// @nodoc
class __$$LiveEditSelectionImplCopyWithImpl<$Res>
    extends _$LiveEditSelectionCopyWithImpl<$Res, _$LiveEditSelectionImpl>
    implements _$$LiveEditSelectionImplCopyWith<$Res> {
  __$$LiveEditSelectionImplCopyWithImpl(
    _$LiveEditSelectionImpl _value,
    $Res Function(_$LiveEditSelectionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditSelection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? nodeId = null,
    Object? widgetType = null,
    Object? propertiesForWire = null,
    Object? rawNode = null,
    Object? targetDomain = null,
    Object? renderObjectType = freezed,
    Object? bounds = freezed,
    Object? source = freezed,
    Object? layoutContext = null,
    Object? parentChain = null,
    Object? detailsTree = null,
    Object? propertiesTree = null,
    Object? selectionMode = null,
    Object? selectedNodeIds = null,
  }) {
    return _then(
      _$LiveEditSelectionImpl(
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        nodeId: null == nodeId
            ? _value.nodeId
            : nodeId // ignore: cast_nullable_to_non_nullable
                  as String,
        widgetType: null == widgetType
            ? _value.widgetType
            : widgetType // ignore: cast_nullable_to_non_nullable
                  as String,
        propertiesForWire: null == propertiesForWire
            ? _value._propertiesForWire
            : propertiesForWire // ignore: cast_nullable_to_non_nullable
                  as List<Object?>,
        rawNode: null == rawNode
            ? _value._rawNode
            : rawNode // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        targetDomain: null == targetDomain
            ? _value.targetDomain
            : targetDomain // ignore: cast_nullable_to_non_nullable
                  as LiveEditTargetDomain,
        renderObjectType: freezed == renderObjectType
            ? _value.renderObjectType
            : renderObjectType // ignore: cast_nullable_to_non_nullable
                  as String?,
        bounds: freezed == bounds
            ? _value.bounds
            : bounds // ignore: cast_nullable_to_non_nullable
                  as LiveEditBounds?,
        source: freezed == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as LiveEditSourceLocation?,
        layoutContext: null == layoutContext
            ? _value._layoutContext
            : layoutContext // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        parentChain: null == parentChain
            ? _value._parentChain
            : parentChain // ignore: cast_nullable_to_non_nullable
                  as List<Map<String, Object?>>,
        detailsTree: null == detailsTree
            ? _value._detailsTree
            : detailsTree // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        propertiesTree: null == propertiesTree
            ? _value._propertiesTree
            : propertiesTree // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        selectionMode: null == selectionMode
            ? _value.selectionMode
            : selectionMode // ignore: cast_nullable_to_non_nullable
                  as LiveEditSelectionMode,
        selectedNodeIds: null == selectedNodeIds
            ? _value._selectedNodeIds
            : selectedNodeIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LiveEditSelectionImpl implements _LiveEditSelection {
  const _$LiveEditSelectionImpl({
    required this.sessionId,
    required this.nodeId,
    required this.widgetType,
    @JsonKey(name: 'properties')
    final List<Object?> propertiesForWire = const <Object?>[],
    @JsonKey(fromJson: _asMap) required final Map<String, Object?> rawNode,
    @JsonKey(fromJson: _targetDomainFromJson, toJson: _enumToWire)
    this.targetDomain = LiveEditTargetDomain.appScene,
    this.renderObjectType,
    this.bounds,
    this.source,
    final Map<String, Object?> layoutContext = const <String, Object?>{},
    final List<Map<String, Object?>> parentChain =
        const <Map<String, Object?>>[],
    final Map<String, Object?> detailsTree = const <String, Object?>{},
    final Map<String, Object?> propertiesTree = const <String, Object?>{},
    @JsonKey(fromJson: _selectionModeFromJson, toJson: _enumToWire)
    this.selectionMode = LiveEditSelectionMode.single,
    final List<String> selectedNodeIds = const <String>[],
  }) : _propertiesForWire = propertiesForWire,
       _rawNode = rawNode,
       _layoutContext = layoutContext,
       _parentChain = parentChain,
       _detailsTree = detailsTree,
       _propertiesTree = propertiesTree,
       _selectedNodeIds = selectedNodeIds;

  factory _$LiveEditSelectionImpl.fromJson(Map<String, dynamic> json) =>
      _$$LiveEditSelectionImplFromJson(json);

  @override
  final String sessionId;
  @override
  final String nodeId;
  @override
  final String widgetType;
  final List<Object?> _propertiesForWire;
  @override
  @JsonKey(name: 'properties')
  List<Object?> get propertiesForWire {
    if (_propertiesForWire is EqualUnmodifiableListView)
      return _propertiesForWire;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_propertiesForWire);
  }

  final Map<String, Object?> _rawNode;
  @override
  @JsonKey(fromJson: _asMap)
  Map<String, Object?> get rawNode {
    if (_rawNode is EqualUnmodifiableMapView) return _rawNode;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_rawNode);
  }

  @override
  @JsonKey(fromJson: _targetDomainFromJson, toJson: _enumToWire)
  final LiveEditTargetDomain targetDomain;
  @override
  final String? renderObjectType;
  @override
  final LiveEditBounds? bounds;
  @override
  final LiveEditSourceLocation? source;
  final Map<String, Object?> _layoutContext;
  @override
  @JsonKey()
  Map<String, Object?> get layoutContext {
    if (_layoutContext is EqualUnmodifiableMapView) return _layoutContext;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_layoutContext);
  }

  final List<Map<String, Object?>> _parentChain;
  @override
  @JsonKey()
  List<Map<String, Object?>> get parentChain {
    if (_parentChain is EqualUnmodifiableListView) return _parentChain;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_parentChain);
  }

  final Map<String, Object?> _detailsTree;
  @override
  @JsonKey()
  Map<String, Object?> get detailsTree {
    if (_detailsTree is EqualUnmodifiableMapView) return _detailsTree;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_detailsTree);
  }

  final Map<String, Object?> _propertiesTree;
  @override
  @JsonKey()
  Map<String, Object?> get propertiesTree {
    if (_propertiesTree is EqualUnmodifiableMapView) return _propertiesTree;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_propertiesTree);
  }

  @override
  @JsonKey(fromJson: _selectionModeFromJson, toJson: _enumToWire)
  final LiveEditSelectionMode selectionMode;
  final List<String> _selectedNodeIds;
  @override
  @JsonKey()
  List<String> get selectedNodeIds {
    if (_selectedNodeIds is EqualUnmodifiableListView) return _selectedNodeIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_selectedNodeIds);
  }

  @override
  String toString() {
    return 'LiveEditSelection(sessionId: $sessionId, nodeId: $nodeId, widgetType: $widgetType, propertiesForWire: $propertiesForWire, rawNode: $rawNode, targetDomain: $targetDomain, renderObjectType: $renderObjectType, bounds: $bounds, source: $source, layoutContext: $layoutContext, parentChain: $parentChain, detailsTree: $detailsTree, propertiesTree: $propertiesTree, selectionMode: $selectionMode, selectedNodeIds: $selectedNodeIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditSelectionImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.nodeId, nodeId) || other.nodeId == nodeId) &&
            (identical(other.widgetType, widgetType) ||
                other.widgetType == widgetType) &&
            const DeepCollectionEquality().equals(
              other._propertiesForWire,
              _propertiesForWire,
            ) &&
            const DeepCollectionEquality().equals(other._rawNode, _rawNode) &&
            (identical(other.targetDomain, targetDomain) ||
                other.targetDomain == targetDomain) &&
            (identical(other.renderObjectType, renderObjectType) ||
                other.renderObjectType == renderObjectType) &&
            (identical(other.bounds, bounds) || other.bounds == bounds) &&
            (identical(other.source, source) || other.source == source) &&
            const DeepCollectionEquality().equals(
              other._layoutContext,
              _layoutContext,
            ) &&
            const DeepCollectionEquality().equals(
              other._parentChain,
              _parentChain,
            ) &&
            const DeepCollectionEquality().equals(
              other._detailsTree,
              _detailsTree,
            ) &&
            const DeepCollectionEquality().equals(
              other._propertiesTree,
              _propertiesTree,
            ) &&
            (identical(other.selectionMode, selectionMode) ||
                other.selectionMode == selectionMode) &&
            const DeepCollectionEquality().equals(
              other._selectedNodeIds,
              _selectedNodeIds,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    sessionId,
    nodeId,
    widgetType,
    const DeepCollectionEquality().hash(_propertiesForWire),
    const DeepCollectionEquality().hash(_rawNode),
    targetDomain,
    renderObjectType,
    bounds,
    source,
    const DeepCollectionEquality().hash(_layoutContext),
    const DeepCollectionEquality().hash(_parentChain),
    const DeepCollectionEquality().hash(_detailsTree),
    const DeepCollectionEquality().hash(_propertiesTree),
    selectionMode,
    const DeepCollectionEquality().hash(_selectedNodeIds),
  );

  /// Create a copy of LiveEditSelection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditSelectionImplCopyWith<_$LiveEditSelectionImpl> get copyWith =>
      __$$LiveEditSelectionImplCopyWithImpl<_$LiveEditSelectionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$LiveEditSelectionImplToJson(this);
  }
}

abstract class _LiveEditSelection implements LiveEditSelection {
  const factory _LiveEditSelection({
    required final String sessionId,
    required final String nodeId,
    required final String widgetType,
    @JsonKey(name: 'properties') final List<Object?> propertiesForWire,
    @JsonKey(fromJson: _asMap) required final Map<String, Object?> rawNode,
    @JsonKey(fromJson: _targetDomainFromJson, toJson: _enumToWire)
    final LiveEditTargetDomain targetDomain,
    final String? renderObjectType,
    final LiveEditBounds? bounds,
    final LiveEditSourceLocation? source,
    final Map<String, Object?> layoutContext,
    final List<Map<String, Object?>> parentChain,
    final Map<String, Object?> detailsTree,
    final Map<String, Object?> propertiesTree,
    @JsonKey(fromJson: _selectionModeFromJson, toJson: _enumToWire)
    final LiveEditSelectionMode selectionMode,
    final List<String> selectedNodeIds,
  }) = _$LiveEditSelectionImpl;

  factory _LiveEditSelection.fromJson(Map<String, dynamic> json) =
      _$LiveEditSelectionImpl.fromJson;

  @override
  String get sessionId;
  @override
  String get nodeId;
  @override
  String get widgetType;
  @override
  @JsonKey(name: 'properties')
  List<Object?> get propertiesForWire;
  @override
  @JsonKey(fromJson: _asMap)
  Map<String, Object?> get rawNode;
  @override
  @JsonKey(fromJson: _targetDomainFromJson, toJson: _enumToWire)
  LiveEditTargetDomain get targetDomain;
  @override
  String? get renderObjectType;
  @override
  LiveEditBounds? get bounds;
  @override
  LiveEditSourceLocation? get source;
  @override
  Map<String, Object?> get layoutContext;
  @override
  List<Map<String, Object?>> get parentChain;
  @override
  Map<String, Object?> get detailsTree;
  @override
  Map<String, Object?> get propertiesTree;
  @override
  @JsonKey(fromJson: _selectionModeFromJson, toJson: _enumToWire)
  LiveEditSelectionMode get selectionMode;
  @override
  List<String> get selectedNodeIds;

  /// Create a copy of LiveEditSelection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditSelectionImplCopyWith<_$LiveEditSelectionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

LiveEditSelectionCandidate _$LiveEditSelectionCandidateFromJson(
  Map<String, dynamic> json,
) {
  return _LiveEditSelectionCandidate.fromJson(json);
}

/// @nodoc
mixin _$LiveEditSelectionCandidate {
  String get nodeId => throw _privateConstructorUsedError;
  String get widgetType => throw _privateConstructorUsedError;
  LiveEditBounds? get bounds => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _depthFromJson)
  int get depth => throw _privateConstructorUsedError;
  LiveEditSourceLocation? get source => throw _privateConstructorUsedError;
  bool get createdByLocalProject => throw _privateConstructorUsedError;
  bool get active => throw _privateConstructorUsedError;

  /// Serializes this LiveEditSelectionCandidate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditSelectionCandidate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditSelectionCandidateCopyWith<LiveEditSelectionCandidate>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditSelectionCandidateCopyWith<$Res> {
  factory $LiveEditSelectionCandidateCopyWith(
    LiveEditSelectionCandidate value,
    $Res Function(LiveEditSelectionCandidate) then,
  ) =
      _$LiveEditSelectionCandidateCopyWithImpl<
        $Res,
        LiveEditSelectionCandidate
      >;
  @useResult
  $Res call({
    String nodeId,
    String widgetType,
    LiveEditBounds? bounds,
    @JsonKey(fromJson: _depthFromJson) int depth,
    LiveEditSourceLocation? source,
    bool createdByLocalProject,
    bool active,
  });

  $LiveEditBoundsCopyWith<$Res>? get bounds;
  $LiveEditSourceLocationCopyWith<$Res>? get source;
}

/// @nodoc
class _$LiveEditSelectionCandidateCopyWithImpl<
  $Res,
  $Val extends LiveEditSelectionCandidate
>
    implements $LiveEditSelectionCandidateCopyWith<$Res> {
  _$LiveEditSelectionCandidateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditSelectionCandidate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeId = null,
    Object? widgetType = null,
    Object? bounds = freezed,
    Object? depth = null,
    Object? source = freezed,
    Object? createdByLocalProject = null,
    Object? active = null,
  }) {
    return _then(
      _value.copyWith(
            nodeId: null == nodeId
                ? _value.nodeId
                : nodeId // ignore: cast_nullable_to_non_nullable
                      as String,
            widgetType: null == widgetType
                ? _value.widgetType
                : widgetType // ignore: cast_nullable_to_non_nullable
                      as String,
            bounds: freezed == bounds
                ? _value.bounds
                : bounds // ignore: cast_nullable_to_non_nullable
                      as LiveEditBounds?,
            depth: null == depth
                ? _value.depth
                : depth // ignore: cast_nullable_to_non_nullable
                      as int,
            source: freezed == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as LiveEditSourceLocation?,
            createdByLocalProject: null == createdByLocalProject
                ? _value.createdByLocalProject
                : createdByLocalProject // ignore: cast_nullable_to_non_nullable
                      as bool,
            active: null == active
                ? _value.active
                : active // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of LiveEditSelectionCandidate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LiveEditBoundsCopyWith<$Res>? get bounds {
    if (_value.bounds == null) {
      return null;
    }

    return $LiveEditBoundsCopyWith<$Res>(_value.bounds!, (value) {
      return _then(_value.copyWith(bounds: value) as $Val);
    });
  }

  /// Create a copy of LiveEditSelectionCandidate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LiveEditSourceLocationCopyWith<$Res>? get source {
    if (_value.source == null) {
      return null;
    }

    return $LiveEditSourceLocationCopyWith<$Res>(_value.source!, (value) {
      return _then(_value.copyWith(source: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$LiveEditSelectionCandidateImplCopyWith<$Res>
    implements $LiveEditSelectionCandidateCopyWith<$Res> {
  factory _$$LiveEditSelectionCandidateImplCopyWith(
    _$LiveEditSelectionCandidateImpl value,
    $Res Function(_$LiveEditSelectionCandidateImpl) then,
  ) = __$$LiveEditSelectionCandidateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String nodeId,
    String widgetType,
    LiveEditBounds? bounds,
    @JsonKey(fromJson: _depthFromJson) int depth,
    LiveEditSourceLocation? source,
    bool createdByLocalProject,
    bool active,
  });

  @override
  $LiveEditBoundsCopyWith<$Res>? get bounds;
  @override
  $LiveEditSourceLocationCopyWith<$Res>? get source;
}

/// @nodoc
class __$$LiveEditSelectionCandidateImplCopyWithImpl<$Res>
    extends
        _$LiveEditSelectionCandidateCopyWithImpl<
          $Res,
          _$LiveEditSelectionCandidateImpl
        >
    implements _$$LiveEditSelectionCandidateImplCopyWith<$Res> {
  __$$LiveEditSelectionCandidateImplCopyWithImpl(
    _$LiveEditSelectionCandidateImpl _value,
    $Res Function(_$LiveEditSelectionCandidateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditSelectionCandidate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeId = null,
    Object? widgetType = null,
    Object? bounds = freezed,
    Object? depth = null,
    Object? source = freezed,
    Object? createdByLocalProject = null,
    Object? active = null,
  }) {
    return _then(
      _$LiveEditSelectionCandidateImpl(
        nodeId: null == nodeId
            ? _value.nodeId
            : nodeId // ignore: cast_nullable_to_non_nullable
                  as String,
        widgetType: null == widgetType
            ? _value.widgetType
            : widgetType // ignore: cast_nullable_to_non_nullable
                  as String,
        bounds: freezed == bounds
            ? _value.bounds
            : bounds // ignore: cast_nullable_to_non_nullable
                  as LiveEditBounds?,
        depth: null == depth
            ? _value.depth
            : depth // ignore: cast_nullable_to_non_nullable
                  as int,
        source: freezed == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as LiveEditSourceLocation?,
        createdByLocalProject: null == createdByLocalProject
            ? _value.createdByLocalProject
            : createdByLocalProject // ignore: cast_nullable_to_non_nullable
                  as bool,
        active: null == active
            ? _value.active
            : active // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LiveEditSelectionCandidateImpl implements _LiveEditSelectionCandidate {
  const _$LiveEditSelectionCandidateImpl({
    required this.nodeId,
    required this.widgetType,
    this.bounds,
    @JsonKey(fromJson: _depthFromJson) this.depth = 0,
    this.source,
    this.createdByLocalProject = false,
    this.active = false,
  });

  factory _$LiveEditSelectionCandidateImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$LiveEditSelectionCandidateImplFromJson(json);

  @override
  final String nodeId;
  @override
  final String widgetType;
  @override
  final LiveEditBounds? bounds;
  @override
  @JsonKey(fromJson: _depthFromJson)
  final int depth;
  @override
  final LiveEditSourceLocation? source;
  @override
  @JsonKey()
  final bool createdByLocalProject;
  @override
  @JsonKey()
  final bool active;

  @override
  String toString() {
    return 'LiveEditSelectionCandidate(nodeId: $nodeId, widgetType: $widgetType, bounds: $bounds, depth: $depth, source: $source, createdByLocalProject: $createdByLocalProject, active: $active)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditSelectionCandidateImpl &&
            (identical(other.nodeId, nodeId) || other.nodeId == nodeId) &&
            (identical(other.widgetType, widgetType) ||
                other.widgetType == widgetType) &&
            (identical(other.bounds, bounds) || other.bounds == bounds) &&
            (identical(other.depth, depth) || other.depth == depth) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.createdByLocalProject, createdByLocalProject) ||
                other.createdByLocalProject == createdByLocalProject) &&
            (identical(other.active, active) || other.active == active));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    nodeId,
    widgetType,
    bounds,
    depth,
    source,
    createdByLocalProject,
    active,
  );

  /// Create a copy of LiveEditSelectionCandidate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditSelectionCandidateImplCopyWith<_$LiveEditSelectionCandidateImpl>
  get copyWith =>
      __$$LiveEditSelectionCandidateImplCopyWithImpl<
        _$LiveEditSelectionCandidateImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LiveEditSelectionCandidateImplToJson(this);
  }
}

abstract class _LiveEditSelectionCandidate
    implements LiveEditSelectionCandidate {
  const factory _LiveEditSelectionCandidate({
    required final String nodeId,
    required final String widgetType,
    final LiveEditBounds? bounds,
    @JsonKey(fromJson: _depthFromJson) final int depth,
    final LiveEditSourceLocation? source,
    final bool createdByLocalProject,
    final bool active,
  }) = _$LiveEditSelectionCandidateImpl;

  factory _LiveEditSelectionCandidate.fromJson(Map<String, dynamic> json) =
      _$LiveEditSelectionCandidateImpl.fromJson;

  @override
  String get nodeId;
  @override
  String get widgetType;
  @override
  LiveEditBounds? get bounds;
  @override
  @JsonKey(fromJson: _depthFromJson)
  int get depth;
  @override
  LiveEditSourceLocation? get source;
  @override
  bool get createdByLocalProject;
  @override
  bool get active;

  /// Create a copy of LiveEditSelectionCandidate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditSelectionCandidateImplCopyWith<_$LiveEditSelectionCandidateImpl>
  get copyWith => throw _privateConstructorUsedError;
}

LiveEditSourceLocation _$LiveEditSourceLocationFromJson(
  Map<String, dynamic> json,
) {
  return _LiveEditSourceLocation.fromJson(json);
}

/// @nodoc
mixin _$LiveEditSourceLocation {
  String get file => throw _privateConstructorUsedError;
  int? get line => throw _privateConstructorUsedError;
  int? get column => throw _privateConstructorUsedError;
  String? get sourceHint => throw _privateConstructorUsedError;

  /// Serializes this LiveEditSourceLocation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LiveEditSourceLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LiveEditSourceLocationCopyWith<LiveEditSourceLocation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LiveEditSourceLocationCopyWith<$Res> {
  factory $LiveEditSourceLocationCopyWith(
    LiveEditSourceLocation value,
    $Res Function(LiveEditSourceLocation) then,
  ) = _$LiveEditSourceLocationCopyWithImpl<$Res, LiveEditSourceLocation>;
  @useResult
  $Res call({String file, int? line, int? column, String? sourceHint});
}

/// @nodoc
class _$LiveEditSourceLocationCopyWithImpl<
  $Res,
  $Val extends LiveEditSourceLocation
>
    implements $LiveEditSourceLocationCopyWith<$Res> {
  _$LiveEditSourceLocationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LiveEditSourceLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? file = null,
    Object? line = freezed,
    Object? column = freezed,
    Object? sourceHint = freezed,
  }) {
    return _then(
      _value.copyWith(
            file: null == file
                ? _value.file
                : file // ignore: cast_nullable_to_non_nullable
                      as String,
            line: freezed == line
                ? _value.line
                : line // ignore: cast_nullable_to_non_nullable
                      as int?,
            column: freezed == column
                ? _value.column
                : column // ignore: cast_nullable_to_non_nullable
                      as int?,
            sourceHint: freezed == sourceHint
                ? _value.sourceHint
                : sourceHint // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LiveEditSourceLocationImplCopyWith<$Res>
    implements $LiveEditSourceLocationCopyWith<$Res> {
  factory _$$LiveEditSourceLocationImplCopyWith(
    _$LiveEditSourceLocationImpl value,
    $Res Function(_$LiveEditSourceLocationImpl) then,
  ) = __$$LiveEditSourceLocationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String file, int? line, int? column, String? sourceHint});
}

/// @nodoc
class __$$LiveEditSourceLocationImplCopyWithImpl<$Res>
    extends
        _$LiveEditSourceLocationCopyWithImpl<$Res, _$LiveEditSourceLocationImpl>
    implements _$$LiveEditSourceLocationImplCopyWith<$Res> {
  __$$LiveEditSourceLocationImplCopyWithImpl(
    _$LiveEditSourceLocationImpl _value,
    $Res Function(_$LiveEditSourceLocationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LiveEditSourceLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? file = null,
    Object? line = freezed,
    Object? column = freezed,
    Object? sourceHint = freezed,
  }) {
    return _then(
      _$LiveEditSourceLocationImpl(
        file: null == file
            ? _value.file
            : file // ignore: cast_nullable_to_non_nullable
                  as String,
        line: freezed == line
            ? _value.line
            : line // ignore: cast_nullable_to_non_nullable
                  as int?,
        column: freezed == column
            ? _value.column
            : column // ignore: cast_nullable_to_non_nullable
                  as int?,
        sourceHint: freezed == sourceHint
            ? _value.sourceHint
            : sourceHint // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LiveEditSourceLocationImpl implements _LiveEditSourceLocation {
  const _$LiveEditSourceLocationImpl({
    required this.file,
    this.line,
    this.column,
    this.sourceHint,
  });

  factory _$LiveEditSourceLocationImpl.fromJson(Map<String, dynamic> json) =>
      _$$LiveEditSourceLocationImplFromJson(json);

  @override
  final String file;
  @override
  final int? line;
  @override
  final int? column;
  @override
  final String? sourceHint;

  @override
  String toString() {
    return 'LiveEditSourceLocation(file: $file, line: $line, column: $column, sourceHint: $sourceHint)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LiveEditSourceLocationImpl &&
            (identical(other.file, file) || other.file == file) &&
            (identical(other.line, line) || other.line == line) &&
            (identical(other.column, column) || other.column == column) &&
            (identical(other.sourceHint, sourceHint) ||
                other.sourceHint == sourceHint));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, file, line, column, sourceHint);

  /// Create a copy of LiveEditSourceLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LiveEditSourceLocationImplCopyWith<_$LiveEditSourceLocationImpl>
  get copyWith =>
      __$$LiveEditSourceLocationImplCopyWithImpl<_$LiveEditSourceLocationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$LiveEditSourceLocationImplToJson(this);
  }
}

abstract class _LiveEditSourceLocation implements LiveEditSourceLocation {
  const factory _LiveEditSourceLocation({
    required final String file,
    final int? line,
    final int? column,
    final String? sourceHint,
  }) = _$LiveEditSourceLocationImpl;

  factory _LiveEditSourceLocation.fromJson(Map<String, dynamic> json) =
      _$LiveEditSourceLocationImpl.fromJson;

  @override
  String get file;
  @override
  int? get line;
  @override
  int? get column;
  @override
  String? get sourceHint;

  /// Create a copy of LiveEditSourceLocation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LiveEditSourceLocationImplCopyWith<_$LiveEditSourceLocationImpl>
  get copyWith => throw _privateConstructorUsedError;
}
