// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'asset_folders.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AssetFolders {

/// The `flutter: assets:` folder entries, project-relative with `/`
/// separators, as written in the pubspec.
 IList<String> get declared;/// Every `*.scene.json` under the declared folders, project-relative,
/// sorted.
 IList<String> get scenes;
/// Create a copy of AssetFolders
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssetFoldersCopyWith<AssetFolders> get copyWith => _$AssetFoldersCopyWithImpl<AssetFolders>(this as AssetFolders, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssetFolders&&const DeepCollectionEquality().equals(other.declared, declared)&&const DeepCollectionEquality().equals(other.scenes, scenes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(declared),const DeepCollectionEquality().hash(scenes));

@override
String toString() {
  return 'AssetFolders(declared: $declared, scenes: $scenes)';
}


}

/// @nodoc
abstract mixin class $AssetFoldersCopyWith<$Res>  {
  factory $AssetFoldersCopyWith(AssetFolders value, $Res Function(AssetFolders) _then) = _$AssetFoldersCopyWithImpl;
@useResult
$Res call({
 IList<String> declared, IList<String> scenes
});




}
/// @nodoc
class _$AssetFoldersCopyWithImpl<$Res>
    implements $AssetFoldersCopyWith<$Res> {
  _$AssetFoldersCopyWithImpl(this._self, this._then);

  final AssetFolders _self;
  final $Res Function(AssetFolders) _then;

/// Create a copy of AssetFolders
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? declared = null,Object? scenes = null,}) {
  return _then(_self.copyWith(
declared: null == declared ? _self.declared : declared // ignore: cast_nullable_to_non_nullable
as IList<String>,scenes: null == scenes ? _self.scenes : scenes // ignore: cast_nullable_to_non_nullable
as IList<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [AssetFolders].
extension AssetFoldersPatterns on AssetFolders {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssetFolders value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssetFolders() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssetFolders value)  $default,){
final _that = this;
switch (_that) {
case _AssetFolders():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssetFolders value)?  $default,){
final _that = this;
switch (_that) {
case _AssetFolders() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IList<String> declared,  IList<String> scenes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssetFolders() when $default != null:
return $default(_that.declared,_that.scenes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IList<String> declared,  IList<String> scenes)  $default,) {final _that = this;
switch (_that) {
case _AssetFolders():
return $default(_that.declared,_that.scenes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IList<String> declared,  IList<String> scenes)?  $default,) {final _that = this;
switch (_that) {
case _AssetFolders() when $default != null:
return $default(_that.declared,_that.scenes);case _:
  return null;

}
}

}

/// @nodoc


class _AssetFolders implements AssetFolders {
  const _AssetFolders({required this.declared, required this.scenes});
  

/// The `flutter: assets:` folder entries, project-relative with `/`
/// separators, as written in the pubspec.
@override final  IList<String> declared;
/// Every `*.scene.json` under the declared folders, project-relative,
/// sorted.
@override final  IList<String> scenes;

/// Create a copy of AssetFolders
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssetFoldersCopyWith<_AssetFolders> get copyWith => __$AssetFoldersCopyWithImpl<_AssetFolders>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssetFolders&&const DeepCollectionEquality().equals(other.declared, declared)&&const DeepCollectionEquality().equals(other.scenes, scenes));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(declared),const DeepCollectionEquality().hash(scenes));

@override
String toString() {
  return 'AssetFolders(declared: $declared, scenes: $scenes)';
}


}

/// @nodoc
abstract mixin class _$AssetFoldersCopyWith<$Res> implements $AssetFoldersCopyWith<$Res> {
  factory _$AssetFoldersCopyWith(_AssetFolders value, $Res Function(_AssetFolders) _then) = __$AssetFoldersCopyWithImpl;
@override @useResult
$Res call({
 IList<String> declared, IList<String> scenes
});




}
/// @nodoc
class __$AssetFoldersCopyWithImpl<$Res>
    implements _$AssetFoldersCopyWith<$Res> {
  __$AssetFoldersCopyWithImpl(this._self, this._then);

  final _AssetFolders _self;
  final $Res Function(_AssetFolders) _then;

/// Create a copy of AssetFolders
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? declared = null,Object? scenes = null,}) {
  return _then(_AssetFolders(
declared: null == declared ? _self.declared : declared // ignore: cast_nullable_to_non_nullable
as IList<String>,scenes: null == scenes ? _self.scenes : scenes // ignore: cast_nullable_to_non_nullable
as IList<String>,
  ));
}


}

// dart format on
