// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recovery_store.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RecoveryInfo {

/// The project the Scene belongs to.
 String get projectRoot;/// The Scene file the copy is of.
 String get scenePath;/// When the copy was written (UTC).
 DateTime get writtenAt;/// When the Scene file itself was last written, or null if it's gone.
 DateTime? get sceneFileModifiedAt;/// The copy's file-name key.
 String get key;
/// Create a copy of RecoveryInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecoveryInfoCopyWith<RecoveryInfo> get copyWith => _$RecoveryInfoCopyWithImpl<RecoveryInfo>(this as RecoveryInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecoveryInfo&&(identical(other.projectRoot, projectRoot) || other.projectRoot == projectRoot)&&(identical(other.scenePath, scenePath) || other.scenePath == scenePath)&&(identical(other.writtenAt, writtenAt) || other.writtenAt == writtenAt)&&(identical(other.sceneFileModifiedAt, sceneFileModifiedAt) || other.sceneFileModifiedAt == sceneFileModifiedAt)&&(identical(other.key, key) || other.key == key));
}


@override
int get hashCode => Object.hash(runtimeType,projectRoot,scenePath,writtenAt,sceneFileModifiedAt,key);

@override
String toString() {
  return 'RecoveryInfo(projectRoot: $projectRoot, scenePath: $scenePath, writtenAt: $writtenAt, sceneFileModifiedAt: $sceneFileModifiedAt, key: $key)';
}


}

/// @nodoc
abstract mixin class $RecoveryInfoCopyWith<$Res>  {
  factory $RecoveryInfoCopyWith(RecoveryInfo value, $Res Function(RecoveryInfo) _then) = _$RecoveryInfoCopyWithImpl;
@useResult
$Res call({
 String projectRoot, String scenePath, DateTime writtenAt, DateTime? sceneFileModifiedAt, String key
});




}
/// @nodoc
class _$RecoveryInfoCopyWithImpl<$Res>
    implements $RecoveryInfoCopyWith<$Res> {
  _$RecoveryInfoCopyWithImpl(this._self, this._then);

  final RecoveryInfo _self;
  final $Res Function(RecoveryInfo) _then;

/// Create a copy of RecoveryInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectRoot = null,Object? scenePath = null,Object? writtenAt = null,Object? sceneFileModifiedAt = freezed,Object? key = null,}) {
  return _then(_self.copyWith(
projectRoot: null == projectRoot ? _self.projectRoot : projectRoot // ignore: cast_nullable_to_non_nullable
as String,scenePath: null == scenePath ? _self.scenePath : scenePath // ignore: cast_nullable_to_non_nullable
as String,writtenAt: null == writtenAt ? _self.writtenAt : writtenAt // ignore: cast_nullable_to_non_nullable
as DateTime,sceneFileModifiedAt: freezed == sceneFileModifiedAt ? _self.sceneFileModifiedAt : sceneFileModifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RecoveryInfo].
extension RecoveryInfoPatterns on RecoveryInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecoveryInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecoveryInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecoveryInfo value)  $default,){
final _that = this;
switch (_that) {
case _RecoveryInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecoveryInfo value)?  $default,){
final _that = this;
switch (_that) {
case _RecoveryInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String projectRoot,  String scenePath,  DateTime writtenAt,  DateTime? sceneFileModifiedAt,  String key)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecoveryInfo() when $default != null:
return $default(_that.projectRoot,_that.scenePath,_that.writtenAt,_that.sceneFileModifiedAt,_that.key);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String projectRoot,  String scenePath,  DateTime writtenAt,  DateTime? sceneFileModifiedAt,  String key)  $default,) {final _that = this;
switch (_that) {
case _RecoveryInfo():
return $default(_that.projectRoot,_that.scenePath,_that.writtenAt,_that.sceneFileModifiedAt,_that.key);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String projectRoot,  String scenePath,  DateTime writtenAt,  DateTime? sceneFileModifiedAt,  String key)?  $default,) {final _that = this;
switch (_that) {
case _RecoveryInfo() when $default != null:
return $default(_that.projectRoot,_that.scenePath,_that.writtenAt,_that.sceneFileModifiedAt,_that.key);case _:
  return null;

}
}

}

/// @nodoc


class _RecoveryInfo implements RecoveryInfo {
  const _RecoveryInfo({required this.projectRoot, required this.scenePath, required this.writtenAt, required this.sceneFileModifiedAt, required this.key});
  

/// The project the Scene belongs to.
@override final  String projectRoot;
/// The Scene file the copy is of.
@override final  String scenePath;
/// When the copy was written (UTC).
@override final  DateTime writtenAt;
/// When the Scene file itself was last written, or null if it's gone.
@override final  DateTime? sceneFileModifiedAt;
/// The copy's file-name key.
@override final  String key;

/// Create a copy of RecoveryInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecoveryInfoCopyWith<_RecoveryInfo> get copyWith => __$RecoveryInfoCopyWithImpl<_RecoveryInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecoveryInfo&&(identical(other.projectRoot, projectRoot) || other.projectRoot == projectRoot)&&(identical(other.scenePath, scenePath) || other.scenePath == scenePath)&&(identical(other.writtenAt, writtenAt) || other.writtenAt == writtenAt)&&(identical(other.sceneFileModifiedAt, sceneFileModifiedAt) || other.sceneFileModifiedAt == sceneFileModifiedAt)&&(identical(other.key, key) || other.key == key));
}


@override
int get hashCode => Object.hash(runtimeType,projectRoot,scenePath,writtenAt,sceneFileModifiedAt,key);

@override
String toString() {
  return 'RecoveryInfo(projectRoot: $projectRoot, scenePath: $scenePath, writtenAt: $writtenAt, sceneFileModifiedAt: $sceneFileModifiedAt, key: $key)';
}


}

/// @nodoc
abstract mixin class _$RecoveryInfoCopyWith<$Res> implements $RecoveryInfoCopyWith<$Res> {
  factory _$RecoveryInfoCopyWith(_RecoveryInfo value, $Res Function(_RecoveryInfo) _then) = __$RecoveryInfoCopyWithImpl;
@override @useResult
$Res call({
 String projectRoot, String scenePath, DateTime writtenAt, DateTime? sceneFileModifiedAt, String key
});




}
/// @nodoc
class __$RecoveryInfoCopyWithImpl<$Res>
    implements _$RecoveryInfoCopyWith<$Res> {
  __$RecoveryInfoCopyWithImpl(this._self, this._then);

  final _RecoveryInfo _self;
  final $Res Function(_RecoveryInfo) _then;

/// Create a copy of RecoveryInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectRoot = null,Object? scenePath = null,Object? writtenAt = null,Object? sceneFileModifiedAt = freezed,Object? key = null,}) {
  return _then(_RecoveryInfo(
projectRoot: null == projectRoot ? _self.projectRoot : projectRoot // ignore: cast_nullable_to_non_nullable
as String,scenePath: null == scenePath ? _self.scenePath : scenePath // ignore: cast_nullable_to_non_nullable
as String,writtenAt: null == writtenAt ? _self.writtenAt : writtenAt // ignore: cast_nullable_to_non_nullable
as DateTime,sceneFileModifiedAt: freezed == sceneFileModifiedAt ? _self.sceneFileModifiedAt : sceneFileModifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
