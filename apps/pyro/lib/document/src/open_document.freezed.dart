// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'open_document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SaveResult {

/// The state that was written.
 SceneDocument get state;/// Where it was written.
 String get path;/// The SHA-256 of the bytes written.
 Digest get digest;
/// Create a copy of SaveResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SaveResultCopyWith<SaveResult> get copyWith => _$SaveResultCopyWithImpl<SaveResult>(this as SaveResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SaveResult&&(identical(other.state, state) || other.state == state)&&(identical(other.path, path) || other.path == path)&&(identical(other.digest, digest) || other.digest == digest));
}


@override
int get hashCode => Object.hash(runtimeType,state,path,digest);

@override
String toString() {
  return 'SaveResult(state: $state, path: $path, digest: $digest)';
}


}

/// @nodoc
abstract mixin class $SaveResultCopyWith<$Res>  {
  factory $SaveResultCopyWith(SaveResult value, $Res Function(SaveResult) _then) = _$SaveResultCopyWithImpl;
@useResult
$Res call({
 SceneDocument state, String path, Digest digest
});




}
/// @nodoc
class _$SaveResultCopyWithImpl<$Res>
    implements $SaveResultCopyWith<$Res> {
  _$SaveResultCopyWithImpl(this._self, this._then);

  final SaveResult _self;
  final $Res Function(SaveResult) _then;

/// Create a copy of SaveResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? state = null,Object? path = null,Object? digest = null,}) {
  return _then(_self.copyWith(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as SceneDocument,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,digest: null == digest ? _self.digest : digest // ignore: cast_nullable_to_non_nullable
as Digest,
  ));
}

}


/// Adds pattern-matching-related methods to [SaveResult].
extension SaveResultPatterns on SaveResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SaveResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SaveResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SaveResult value)  $default,){
final _that = this;
switch (_that) {
case _SaveResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SaveResult value)?  $default,){
final _that = this;
switch (_that) {
case _SaveResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SceneDocument state,  String path,  Digest digest)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SaveResult() when $default != null:
return $default(_that.state,_that.path,_that.digest);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SceneDocument state,  String path,  Digest digest)  $default,) {final _that = this;
switch (_that) {
case _SaveResult():
return $default(_that.state,_that.path,_that.digest);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SceneDocument state,  String path,  Digest digest)?  $default,) {final _that = this;
switch (_that) {
case _SaveResult() when $default != null:
return $default(_that.state,_that.path,_that.digest);case _:
  return null;

}
}

}

/// @nodoc


class _SaveResult implements SaveResult {
  const _SaveResult({required this.state, required this.path, required this.digest});
  

/// The state that was written.
@override final  SceneDocument state;
/// Where it was written.
@override final  String path;
/// The SHA-256 of the bytes written.
@override final  Digest digest;

/// Create a copy of SaveResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SaveResultCopyWith<_SaveResult> get copyWith => __$SaveResultCopyWithImpl<_SaveResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SaveResult&&(identical(other.state, state) || other.state == state)&&(identical(other.path, path) || other.path == path)&&(identical(other.digest, digest) || other.digest == digest));
}


@override
int get hashCode => Object.hash(runtimeType,state,path,digest);

@override
String toString() {
  return 'SaveResult(state: $state, path: $path, digest: $digest)';
}


}

/// @nodoc
abstract mixin class _$SaveResultCopyWith<$Res> implements $SaveResultCopyWith<$Res> {
  factory _$SaveResultCopyWith(_SaveResult value, $Res Function(_SaveResult) _then) = __$SaveResultCopyWithImpl;
@override @useResult
$Res call({
 SceneDocument state, String path, Digest digest
});




}
/// @nodoc
class __$SaveResultCopyWithImpl<$Res>
    implements _$SaveResultCopyWith<$Res> {
  __$SaveResultCopyWithImpl(this._self, this._then);

  final _SaveResult _self;
  final $Res Function(_SaveResult) _then;

/// Create a copy of SaveResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? state = null,Object? path = null,Object? digest = null,}) {
  return _then(_SaveResult(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as SceneDocument,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,digest: null == digest ? _self.digest : digest // ignore: cast_nullable_to_non_nullable
as Digest,
  ));
}


}

// dart format on
