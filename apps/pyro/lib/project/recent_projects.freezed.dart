// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recent_projects.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RecentProjects {

/// The recently opened project roots, most recent first.
 IList<String> get paths;/// The last opened project's root, when there was one.
 String? get lastOpened;/// The dock sizes per project path.
 IMap<String, PrShellSizes> get sizes;
/// Create a copy of RecentProjects
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecentProjectsCopyWith<RecentProjects> get copyWith => _$RecentProjectsCopyWithImpl<RecentProjects>(this as RecentProjects, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecentProjects&&const DeepCollectionEquality().equals(other.paths, paths)&&(identical(other.lastOpened, lastOpened) || other.lastOpened == lastOpened)&&(identical(other.sizes, sizes) || other.sizes == sizes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(paths),lastOpened,sizes);

@override
String toString() {
  return 'RecentProjects(paths: $paths, lastOpened: $lastOpened, sizes: $sizes)';
}


}

/// @nodoc
abstract mixin class $RecentProjectsCopyWith<$Res>  {
  factory $RecentProjectsCopyWith(RecentProjects value, $Res Function(RecentProjects) _then) = _$RecentProjectsCopyWithImpl;
@useResult
$Res call({
 IList<String> paths, String? lastOpened, IMap<String, PrShellSizes> sizes
});




}
/// @nodoc
class _$RecentProjectsCopyWithImpl<$Res>
    implements $RecentProjectsCopyWith<$Res> {
  _$RecentProjectsCopyWithImpl(this._self, this._then);

  final RecentProjects _self;
  final $Res Function(RecentProjects) _then;

/// Create a copy of RecentProjects
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? paths = null,Object? lastOpened = freezed,Object? sizes = null,}) {
  return _then(_self.copyWith(
paths: null == paths ? _self.paths : paths // ignore: cast_nullable_to_non_nullable
as IList<String>,lastOpened: freezed == lastOpened ? _self.lastOpened : lastOpened // ignore: cast_nullable_to_non_nullable
as String?,sizes: null == sizes ? _self.sizes : sizes // ignore: cast_nullable_to_non_nullable
as IMap<String, PrShellSizes>,
  ));
}

}


/// Adds pattern-matching-related methods to [RecentProjects].
extension RecentProjectsPatterns on RecentProjects {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecentProjects value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecentProjects() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecentProjects value)  $default,){
final _that = this;
switch (_that) {
case _RecentProjects():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecentProjects value)?  $default,){
final _that = this;
switch (_that) {
case _RecentProjects() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IList<String> paths,  String? lastOpened,  IMap<String, PrShellSizes> sizes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecentProjects() when $default != null:
return $default(_that.paths,_that.lastOpened,_that.sizes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IList<String> paths,  String? lastOpened,  IMap<String, PrShellSizes> sizes)  $default,) {final _that = this;
switch (_that) {
case _RecentProjects():
return $default(_that.paths,_that.lastOpened,_that.sizes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IList<String> paths,  String? lastOpened,  IMap<String, PrShellSizes> sizes)?  $default,) {final _that = this;
switch (_that) {
case _RecentProjects() when $default != null:
return $default(_that.paths,_that.lastOpened,_that.sizes);case _:
  return null;

}
}

}

/// @nodoc


class _RecentProjects implements RecentProjects {
  const _RecentProjects({required this.paths, required this.lastOpened, required this.sizes});
  

/// The recently opened project roots, most recent first.
@override final  IList<String> paths;
/// The last opened project's root, when there was one.
@override final  String? lastOpened;
/// The dock sizes per project path.
@override final  IMap<String, PrShellSizes> sizes;

/// Create a copy of RecentProjects
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecentProjectsCopyWith<_RecentProjects> get copyWith => __$RecentProjectsCopyWithImpl<_RecentProjects>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecentProjects&&const DeepCollectionEquality().equals(other.paths, paths)&&(identical(other.lastOpened, lastOpened) || other.lastOpened == lastOpened)&&(identical(other.sizes, sizes) || other.sizes == sizes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(paths),lastOpened,sizes);

@override
String toString() {
  return 'RecentProjects(paths: $paths, lastOpened: $lastOpened, sizes: $sizes)';
}


}

/// @nodoc
abstract mixin class _$RecentProjectsCopyWith<$Res> implements $RecentProjectsCopyWith<$Res> {
  factory _$RecentProjectsCopyWith(_RecentProjects value, $Res Function(_RecentProjects) _then) = __$RecentProjectsCopyWithImpl;
@override @useResult
$Res call({
 IList<String> paths, String? lastOpened, IMap<String, PrShellSizes> sizes
});




}
/// @nodoc
class __$RecentProjectsCopyWithImpl<$Res>
    implements _$RecentProjectsCopyWith<$Res> {
  __$RecentProjectsCopyWithImpl(this._self, this._then);

  final _RecentProjects _self;
  final $Res Function(_RecentProjects) _then;

/// Create a copy of RecentProjects
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? paths = null,Object? lastOpened = freezed,Object? sizes = null,}) {
  return _then(_RecentProjects(
paths: null == paths ? _self.paths : paths // ignore: cast_nullable_to_non_nullable
as IList<String>,lastOpened: freezed == lastOpened ? _self.lastOpened : lastOpened // ignore: cast_nullable_to_non_nullable
as String?,sizes: null == sizes ? _self.sizes : sizes // ignore: cast_nullable_to_non_nullable
as IMap<String, PrShellSizes>,
  ));
}


}

// dart format on
