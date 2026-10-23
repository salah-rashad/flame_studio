// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'runtime_compat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RuntimeCompatibility {

 RuntimeCompatStatus get status;/// The resolved `pyro_runtime` version, when one was found.
 String? get foundVersion;/// The newest `schemaVersion` the project's Runtime reads, for every
/// save (`DocumentSession.save(runtimeReadsUpTo:)`); null when unknown.
 int? get readsUpTo;
/// Create a copy of RuntimeCompatibility
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuntimeCompatibilityCopyWith<RuntimeCompatibility> get copyWith => _$RuntimeCompatibilityCopyWithImpl<RuntimeCompatibility>(this as RuntimeCompatibility, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuntimeCompatibility&&(identical(other.status, status) || other.status == status)&&(identical(other.foundVersion, foundVersion) || other.foundVersion == foundVersion)&&(identical(other.readsUpTo, readsUpTo) || other.readsUpTo == readsUpTo));
}


@override
int get hashCode => Object.hash(runtimeType,status,foundVersion,readsUpTo);

@override
String toString() {
  return 'RuntimeCompatibility(status: $status, foundVersion: $foundVersion, readsUpTo: $readsUpTo)';
}


}

/// @nodoc
abstract mixin class $RuntimeCompatibilityCopyWith<$Res>  {
  factory $RuntimeCompatibilityCopyWith(RuntimeCompatibility value, $Res Function(RuntimeCompatibility) _then) = _$RuntimeCompatibilityCopyWithImpl;
@useResult
$Res call({
 RuntimeCompatStatus status, String? foundVersion, int? readsUpTo
});




}
/// @nodoc
class _$RuntimeCompatibilityCopyWithImpl<$Res>
    implements $RuntimeCompatibilityCopyWith<$Res> {
  _$RuntimeCompatibilityCopyWithImpl(this._self, this._then);

  final RuntimeCompatibility _self;
  final $Res Function(RuntimeCompatibility) _then;

/// Create a copy of RuntimeCompatibility
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? foundVersion = freezed,Object? readsUpTo = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RuntimeCompatStatus,foundVersion: freezed == foundVersion ? _self.foundVersion : foundVersion // ignore: cast_nullable_to_non_nullable
as String?,readsUpTo: freezed == readsUpTo ? _self.readsUpTo : readsUpTo // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [RuntimeCompatibility].
extension RuntimeCompatibilityPatterns on RuntimeCompatibility {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuntimeCompatibility value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuntimeCompatibility() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuntimeCompatibility value)  $default,){
final _that = this;
switch (_that) {
case _RuntimeCompatibility():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuntimeCompatibility value)?  $default,){
final _that = this;
switch (_that) {
case _RuntimeCompatibility() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RuntimeCompatStatus status,  String? foundVersion,  int? readsUpTo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuntimeCompatibility() when $default != null:
return $default(_that.status,_that.foundVersion,_that.readsUpTo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RuntimeCompatStatus status,  String? foundVersion,  int? readsUpTo)  $default,) {final _that = this;
switch (_that) {
case _RuntimeCompatibility():
return $default(_that.status,_that.foundVersion,_that.readsUpTo);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RuntimeCompatStatus status,  String? foundVersion,  int? readsUpTo)?  $default,) {final _that = this;
switch (_that) {
case _RuntimeCompatibility() when $default != null:
return $default(_that.status,_that.foundVersion,_that.readsUpTo);case _:
  return null;

}
}

}

/// @nodoc


class _RuntimeCompatibility implements RuntimeCompatibility {
  const _RuntimeCompatibility({required this.status, required this.foundVersion, required this.readsUpTo});
  

@override final  RuntimeCompatStatus status;
/// The resolved `pyro_runtime` version, when one was found.
@override final  String? foundVersion;
/// The newest `schemaVersion` the project's Runtime reads, for every
/// save (`DocumentSession.save(runtimeReadsUpTo:)`); null when unknown.
@override final  int? readsUpTo;

/// Create a copy of RuntimeCompatibility
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuntimeCompatibilityCopyWith<_RuntimeCompatibility> get copyWith => __$RuntimeCompatibilityCopyWithImpl<_RuntimeCompatibility>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuntimeCompatibility&&(identical(other.status, status) || other.status == status)&&(identical(other.foundVersion, foundVersion) || other.foundVersion == foundVersion)&&(identical(other.readsUpTo, readsUpTo) || other.readsUpTo == readsUpTo));
}


@override
int get hashCode => Object.hash(runtimeType,status,foundVersion,readsUpTo);

@override
String toString() {
  return 'RuntimeCompatibility(status: $status, foundVersion: $foundVersion, readsUpTo: $readsUpTo)';
}


}

/// @nodoc
abstract mixin class _$RuntimeCompatibilityCopyWith<$Res> implements $RuntimeCompatibilityCopyWith<$Res> {
  factory _$RuntimeCompatibilityCopyWith(_RuntimeCompatibility value, $Res Function(_RuntimeCompatibility) _then) = __$RuntimeCompatibilityCopyWithImpl;
@override @useResult
$Res call({
 RuntimeCompatStatus status, String? foundVersion, int? readsUpTo
});




}
/// @nodoc
class __$RuntimeCompatibilityCopyWithImpl<$Res>
    implements _$RuntimeCompatibilityCopyWith<$Res> {
  __$RuntimeCompatibilityCopyWithImpl(this._self, this._then);

  final _RuntimeCompatibility _self;
  final $Res Function(_RuntimeCompatibility) _then;

/// Create a copy of RuntimeCompatibility
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? foundVersion = freezed,Object? readsUpTo = freezed,}) {
  return _then(_RuntimeCompatibility(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RuntimeCompatStatus,foundVersion: freezed == foundVersion ? _self.foundVersion : foundVersion // ignore: cast_nullable_to_non_nullable
as String?,readsUpTo: freezed == readsUpTo ? _self.readsUpTo : readsUpTo // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
