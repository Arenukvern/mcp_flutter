// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LiveEditBounds {

 double get left; double get top; double get right; double get bottom; double get width; double get height;
/// Create a copy of LiveEditBounds
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveEditBoundsCopyWith<LiveEditBounds> get copyWith => _$LiveEditBoundsCopyWithImpl<LiveEditBounds>(this as LiveEditBounds, _$identity);

  /// Serializes this LiveEditBounds to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveEditBounds&&(identical(other.left, left) || other.left == left)&&(identical(other.top, top) || other.top == top)&&(identical(other.right, right) || other.right == right)&&(identical(other.bottom, bottom) || other.bottom == bottom)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,left,top,right,bottom,width,height);

@override
String toString() {
  return 'LiveEditBounds(left: $left, top: $top, right: $right, bottom: $bottom, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $LiveEditBoundsCopyWith<$Res>  {
  factory $LiveEditBoundsCopyWith(LiveEditBounds value, $Res Function(LiveEditBounds) _then) = _$LiveEditBoundsCopyWithImpl;
@useResult
$Res call({
 double left, double top, double right, double bottom, double width, double height
});




}
/// @nodoc
class _$LiveEditBoundsCopyWithImpl<$Res>
    implements $LiveEditBoundsCopyWith<$Res> {
  _$LiveEditBoundsCopyWithImpl(this._self, this._then);

  final LiveEditBounds _self;
  final $Res Function(LiveEditBounds) _then;

/// Create a copy of LiveEditBounds
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? left = null,Object? top = null,Object? right = null,Object? bottom = null,Object? width = null,Object? height = null,}) {
  return _then(_self.copyWith(
left: null == left ? _self.left : left // ignore: cast_nullable_to_non_nullable
as double,top: null == top ? _self.top : top // ignore: cast_nullable_to_non_nullable
as double,right: null == right ? _self.right : right // ignore: cast_nullable_to_non_nullable
as double,bottom: null == bottom ? _self.bottom : bottom // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveEditBounds].
extension LiveEditBoundsPatterns on LiveEditBounds {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveEditBounds value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveEditBounds() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveEditBounds value)  $default,){
final _that = this;
switch (_that) {
case _LiveEditBounds():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveEditBounds value)?  $default,){
final _that = this;
switch (_that) {
case _LiveEditBounds() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double left,  double top,  double right,  double bottom,  double width,  double height)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveEditBounds() when $default != null:
return $default(_that.left,_that.top,_that.right,_that.bottom,_that.width,_that.height);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double left,  double top,  double right,  double bottom,  double width,  double height)  $default,) {final _that = this;
switch (_that) {
case _LiveEditBounds():
return $default(_that.left,_that.top,_that.right,_that.bottom,_that.width,_that.height);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double left,  double top,  double right,  double bottom,  double width,  double height)?  $default,) {final _that = this;
switch (_that) {
case _LiveEditBounds() when $default != null:
return $default(_that.left,_that.top,_that.right,_that.bottom,_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LiveEditBounds implements LiveEditBounds {
  const _LiveEditBounds({required this.left, required this.top, required this.right, required this.bottom, required this.width, required this.height});
  factory _LiveEditBounds.fromJson(Map<String, dynamic> json) => _$LiveEditBoundsFromJson(json);

@override final  double left;
@override final  double top;
@override final  double right;
@override final  double bottom;
@override final  double width;
@override final  double height;

/// Create a copy of LiveEditBounds
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveEditBoundsCopyWith<_LiveEditBounds> get copyWith => __$LiveEditBoundsCopyWithImpl<_LiveEditBounds>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LiveEditBoundsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveEditBounds&&(identical(other.left, left) || other.left == left)&&(identical(other.top, top) || other.top == top)&&(identical(other.right, right) || other.right == right)&&(identical(other.bottom, bottom) || other.bottom == bottom)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,left,top,right,bottom,width,height);

@override
String toString() {
  return 'LiveEditBounds(left: $left, top: $top, right: $right, bottom: $bottom, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$LiveEditBoundsCopyWith<$Res> implements $LiveEditBoundsCopyWith<$Res> {
  factory _$LiveEditBoundsCopyWith(_LiveEditBounds value, $Res Function(_LiveEditBounds) _then) = __$LiveEditBoundsCopyWithImpl;
@override @useResult
$Res call({
 double left, double top, double right, double bottom, double width, double height
});




}
/// @nodoc
class __$LiveEditBoundsCopyWithImpl<$Res>
    implements _$LiveEditBoundsCopyWith<$Res> {
  __$LiveEditBoundsCopyWithImpl(this._self, this._then);

  final _LiveEditBounds _self;
  final $Res Function(_LiveEditBounds) _then;

/// Create a copy of LiveEditBounds
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? left = null,Object? top = null,Object? right = null,Object? bottom = null,Object? width = null,Object? height = null,}) {
  return _then(_LiveEditBounds(
left: null == left ? _self.left : left // ignore: cast_nullable_to_non_nullable
as double,top: null == top ? _self.top : top // ignore: cast_nullable_to_non_nullable
as double,right: null == right ? _self.right : right // ignore: cast_nullable_to_non_nullable
as double,bottom: null == bottom ? _self.bottom : bottom // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
