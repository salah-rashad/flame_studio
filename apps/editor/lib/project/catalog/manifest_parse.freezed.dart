// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'manifest_parse.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ManifestProblem {

/// The stable code, such as `fieldFinal` or `defaultOutOfRange`.
 String get code;/// The declaring file, package-relative, or a `package:` URI.
 String? get file;/// The 1-based line of the declaration's name.
 int? get line;/// The class the problem concerns, when one does.
 String? get className;/// The field the problem concerns, when one does.
 String? get field;/// What is wrong and how to fix it.
 String get message;/// Whether the build still succeeded with this problem.
 bool get isWarning;
/// Create a copy of ManifestProblem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ManifestProblemCopyWith<ManifestProblem> get copyWith => _$ManifestProblemCopyWithImpl<ManifestProblem>(this as ManifestProblem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ManifestProblem&&(identical(other.code, code) || other.code == code)&&(identical(other.file, file) || other.file == file)&&(identical(other.line, line) || other.line == line)&&(identical(other.className, className) || other.className == className)&&(identical(other.field, field) || other.field == field)&&(identical(other.message, message) || other.message == message)&&(identical(other.isWarning, isWarning) || other.isWarning == isWarning));
}


@override
int get hashCode => Object.hash(runtimeType,code,file,line,className,field,message,isWarning);

@override
String toString() {
  return 'ManifestProblem(code: $code, file: $file, line: $line, className: $className, field: $field, message: $message, isWarning: $isWarning)';
}


}

/// @nodoc
abstract mixin class $ManifestProblemCopyWith<$Res>  {
  factory $ManifestProblemCopyWith(ManifestProblem value, $Res Function(ManifestProblem) _then) = _$ManifestProblemCopyWithImpl;
@useResult
$Res call({
 String code, String? file, int? line, String? className, String? field, String message, bool isWarning
});




}
/// @nodoc
class _$ManifestProblemCopyWithImpl<$Res>
    implements $ManifestProblemCopyWith<$Res> {
  _$ManifestProblemCopyWithImpl(this._self, this._then);

  final ManifestProblem _self;
  final $Res Function(ManifestProblem) _then;

/// Create a copy of ManifestProblem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? file = freezed,Object? line = freezed,Object? className = freezed,Object? field = freezed,Object? message = null,Object? isWarning = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,className: freezed == className ? _self.className : className // ignore: cast_nullable_to_non_nullable
as String?,field: freezed == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as String?,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,isWarning: null == isWarning ? _self.isWarning : isWarning // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ManifestProblem].
extension ManifestProblemPatterns on ManifestProblem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ManifestProblem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ManifestProblem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ManifestProblem value)  $default,){
final _that = this;
switch (_that) {
case _ManifestProblem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ManifestProblem value)?  $default,){
final _that = this;
switch (_that) {
case _ManifestProblem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  String? file,  int? line,  String? className,  String? field,  String message,  bool isWarning)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ManifestProblem() when $default != null:
return $default(_that.code,_that.file,_that.line,_that.className,_that.field,_that.message,_that.isWarning);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  String? file,  int? line,  String? className,  String? field,  String message,  bool isWarning)  $default,) {final _that = this;
switch (_that) {
case _ManifestProblem():
return $default(_that.code,_that.file,_that.line,_that.className,_that.field,_that.message,_that.isWarning);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  String? file,  int? line,  String? className,  String? field,  String message,  bool isWarning)?  $default,) {final _that = this;
switch (_that) {
case _ManifestProblem() when $default != null:
return $default(_that.code,_that.file,_that.line,_that.className,_that.field,_that.message,_that.isWarning);case _:
  return null;

}
}

}

/// @nodoc


class _ManifestProblem extends ManifestProblem {
  const _ManifestProblem({required this.code, this.file, this.line, this.className, this.field, required this.message, required this.isWarning}): super._();
  

/// The stable code, such as `fieldFinal` or `defaultOutOfRange`.
@override final  String code;
/// The declaring file, package-relative, or a `package:` URI.
@override final  String? file;
/// The 1-based line of the declaration's name.
@override final  int? line;
/// The class the problem concerns, when one does.
@override final  String? className;
/// The field the problem concerns, when one does.
@override final  String? field;
/// What is wrong and how to fix it.
@override final  String message;
/// Whether the build still succeeded with this problem.
@override final  bool isWarning;

/// Create a copy of ManifestProblem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ManifestProblemCopyWith<_ManifestProblem> get copyWith => __$ManifestProblemCopyWithImpl<_ManifestProblem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ManifestProblem&&(identical(other.code, code) || other.code == code)&&(identical(other.file, file) || other.file == file)&&(identical(other.line, line) || other.line == line)&&(identical(other.className, className) || other.className == className)&&(identical(other.field, field) || other.field == field)&&(identical(other.message, message) || other.message == message)&&(identical(other.isWarning, isWarning) || other.isWarning == isWarning));
}


@override
int get hashCode => Object.hash(runtimeType,code,file,line,className,field,message,isWarning);

@override
String toString() {
  return 'ManifestProblem(code: $code, file: $file, line: $line, className: $className, field: $field, message: $message, isWarning: $isWarning)';
}


}

/// @nodoc
abstract mixin class _$ManifestProblemCopyWith<$Res> implements $ManifestProblemCopyWith<$Res> {
  factory _$ManifestProblemCopyWith(_ManifestProblem value, $Res Function(_ManifestProblem) _then) = __$ManifestProblemCopyWithImpl;
@override @useResult
$Res call({
 String code, String? file, int? line, String? className, String? field, String message, bool isWarning
});




}
/// @nodoc
class __$ManifestProblemCopyWithImpl<$Res>
    implements _$ManifestProblemCopyWith<$Res> {
  __$ManifestProblemCopyWithImpl(this._self, this._then);

  final _ManifestProblem _self;
  final $Res Function(_ManifestProblem) _then;

/// Create a copy of ManifestProblem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? file = freezed,Object? line = freezed,Object? className = freezed,Object? field = freezed,Object? message = null,Object? isWarning = null,}) {
  return _then(_ManifestProblem(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,className: freezed == className ? _self.className : className // ignore: cast_nullable_to_non_nullable
as String?,field: freezed == field ? _self.field : field // ignore: cast_nullable_to_non_nullable
as String?,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,isWarning: null == isWarning ? _self.isWarning : isWarning // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$FieldDescriptor {

/// The field's name, as Scenes key its Override.
 String get name;/// The field's Field type.
 FieldType get type;/// Whether the field accepts `null`.
 bool get nullable;/// The evaluated default in its Scene written form, or null.
 Object? get defaultValue;/// The initializer's source text, when the default wasn't a constant
/// the generator could evaluate (§7.3).
 String? get defaultSource;/// The inclusive lower bound, numeric fields only.
 double? get min;/// The inclusive upper bound, numeric fields only.
 double? get max;/// The value names in declaration order, `enum` fields only.
 IList<String>? get enumValues;/// The `@Editable(tooltip:)` text.
 String? get tooltip;
/// Create a copy of FieldDescriptor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FieldDescriptorCopyWith<FieldDescriptor> get copyWith => _$FieldDescriptorCopyWithImpl<FieldDescriptor>(this as FieldDescriptor, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FieldDescriptor&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.nullable, nullable) || other.nullable == nullable)&&const DeepCollectionEquality().equals(other.defaultValue, defaultValue)&&(identical(other.defaultSource, defaultSource) || other.defaultSource == defaultSource)&&(identical(other.min, min) || other.min == min)&&(identical(other.max, max) || other.max == max)&&const DeepCollectionEquality().equals(other.enumValues, enumValues)&&(identical(other.tooltip, tooltip) || other.tooltip == tooltip));
}


@override
int get hashCode => Object.hash(runtimeType,name,type,nullable,const DeepCollectionEquality().hash(defaultValue),defaultSource,min,max,const DeepCollectionEquality().hash(enumValues),tooltip);

@override
String toString() {
  return 'FieldDescriptor(name: $name, type: $type, nullable: $nullable, defaultValue: $defaultValue, defaultSource: $defaultSource, min: $min, max: $max, enumValues: $enumValues, tooltip: $tooltip)';
}


}

/// @nodoc
abstract mixin class $FieldDescriptorCopyWith<$Res>  {
  factory $FieldDescriptorCopyWith(FieldDescriptor value, $Res Function(FieldDescriptor) _then) = _$FieldDescriptorCopyWithImpl;
@useResult
$Res call({
 String name, FieldType type, bool nullable, Object? defaultValue, String? defaultSource, double? min, double? max, IList<String>? enumValues, String? tooltip
});




}
/// @nodoc
class _$FieldDescriptorCopyWithImpl<$Res>
    implements $FieldDescriptorCopyWith<$Res> {
  _$FieldDescriptorCopyWithImpl(this._self, this._then);

  final FieldDescriptor _self;
  final $Res Function(FieldDescriptor) _then;

/// Create a copy of FieldDescriptor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? type = null,Object? nullable = null,Object? defaultValue = freezed,Object? defaultSource = freezed,Object? min = freezed,Object? max = freezed,Object? enumValues = freezed,Object? tooltip = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as FieldType,nullable: null == nullable ? _self.nullable : nullable // ignore: cast_nullable_to_non_nullable
as bool,defaultValue: freezed == defaultValue ? _self.defaultValue : defaultValue ,defaultSource: freezed == defaultSource ? _self.defaultSource : defaultSource // ignore: cast_nullable_to_non_nullable
as String?,min: freezed == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as double?,max: freezed == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as double?,enumValues: freezed == enumValues ? _self.enumValues : enumValues // ignore: cast_nullable_to_non_nullable
as IList<String>?,tooltip: freezed == tooltip ? _self.tooltip : tooltip // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FieldDescriptor].
extension FieldDescriptorPatterns on FieldDescriptor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FieldDescriptor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FieldDescriptor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FieldDescriptor value)  $default,){
final _that = this;
switch (_that) {
case _FieldDescriptor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FieldDescriptor value)?  $default,){
final _that = this;
switch (_that) {
case _FieldDescriptor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  FieldType type,  bool nullable,  Object? defaultValue,  String? defaultSource,  double? min,  double? max,  IList<String>? enumValues,  String? tooltip)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FieldDescriptor() when $default != null:
return $default(_that.name,_that.type,_that.nullable,_that.defaultValue,_that.defaultSource,_that.min,_that.max,_that.enumValues,_that.tooltip);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  FieldType type,  bool nullable,  Object? defaultValue,  String? defaultSource,  double? min,  double? max,  IList<String>? enumValues,  String? tooltip)  $default,) {final _that = this;
switch (_that) {
case _FieldDescriptor():
return $default(_that.name,_that.type,_that.nullable,_that.defaultValue,_that.defaultSource,_that.min,_that.max,_that.enumValues,_that.tooltip);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  FieldType type,  bool nullable,  Object? defaultValue,  String? defaultSource,  double? min,  double? max,  IList<String>? enumValues,  String? tooltip)?  $default,) {final _that = this;
switch (_that) {
case _FieldDescriptor() when $default != null:
return $default(_that.name,_that.type,_that.nullable,_that.defaultValue,_that.defaultSource,_that.min,_that.max,_that.enumValues,_that.tooltip);case _:
  return null;

}
}

}

/// @nodoc


class _FieldDescriptor implements FieldDescriptor {
  const _FieldDescriptor({required this.name, required this.type, required this.nullable, this.defaultValue, this.defaultSource, this.min, this.max, this.enumValues, this.tooltip});
  

/// The field's name, as Scenes key its Override.
@override final  String name;
/// The field's Field type.
@override final  FieldType type;
/// Whether the field accepts `null`.
@override final  bool nullable;
/// The evaluated default in its Scene written form, or null.
@override final  Object? defaultValue;
/// The initializer's source text, when the default wasn't a constant
/// the generator could evaluate (§7.3).
@override final  String? defaultSource;
/// The inclusive lower bound, numeric fields only.
@override final  double? min;
/// The inclusive upper bound, numeric fields only.
@override final  double? max;
/// The value names in declaration order, `enum` fields only.
@override final  IList<String>? enumValues;
/// The `@Editable(tooltip:)` text.
@override final  String? tooltip;

/// Create a copy of FieldDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FieldDescriptorCopyWith<_FieldDescriptor> get copyWith => __$FieldDescriptorCopyWithImpl<_FieldDescriptor>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FieldDescriptor&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.nullable, nullable) || other.nullable == nullable)&&const DeepCollectionEquality().equals(other.defaultValue, defaultValue)&&(identical(other.defaultSource, defaultSource) || other.defaultSource == defaultSource)&&(identical(other.min, min) || other.min == min)&&(identical(other.max, max) || other.max == max)&&const DeepCollectionEquality().equals(other.enumValues, enumValues)&&(identical(other.tooltip, tooltip) || other.tooltip == tooltip));
}


@override
int get hashCode => Object.hash(runtimeType,name,type,nullable,const DeepCollectionEquality().hash(defaultValue),defaultSource,min,max,const DeepCollectionEquality().hash(enumValues),tooltip);

@override
String toString() {
  return 'FieldDescriptor(name: $name, type: $type, nullable: $nullable, defaultValue: $defaultValue, defaultSource: $defaultSource, min: $min, max: $max, enumValues: $enumValues, tooltip: $tooltip)';
}


}

/// @nodoc
abstract mixin class _$FieldDescriptorCopyWith<$Res> implements $FieldDescriptorCopyWith<$Res> {
  factory _$FieldDescriptorCopyWith(_FieldDescriptor value, $Res Function(_FieldDescriptor) _then) = __$FieldDescriptorCopyWithImpl;
@override @useResult
$Res call({
 String name, FieldType type, bool nullable, Object? defaultValue, String? defaultSource, double? min, double? max, IList<String>? enumValues, String? tooltip
});




}
/// @nodoc
class __$FieldDescriptorCopyWithImpl<$Res>
    implements _$FieldDescriptorCopyWith<$Res> {
  __$FieldDescriptorCopyWithImpl(this._self, this._then);

  final _FieldDescriptor _self;
  final $Res Function(_FieldDescriptor) _then;

/// Create a copy of FieldDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? type = null,Object? nullable = null,Object? defaultValue = freezed,Object? defaultSource = freezed,Object? min = freezed,Object? max = freezed,Object? enumValues = freezed,Object? tooltip = freezed,}) {
  return _then(_FieldDescriptor(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as FieldType,nullable: null == nullable ? _self.nullable : nullable // ignore: cast_nullable_to_non_nullable
as bool,defaultValue: freezed == defaultValue ? _self.defaultValue : defaultValue ,defaultSource: freezed == defaultSource ? _self.defaultSource : defaultSource // ignore: cast_nullable_to_non_nullable
as String?,min: freezed == min ? _self.min : min // ignore: cast_nullable_to_non_nullable
as double?,max: freezed == max ? _self.max : max // ignore: cast_nullable_to_non_nullable
as double?,enumValues: freezed == enumValues ? _self.enumValues : enumValues // ignore: cast_nullable_to_non_nullable
as IList<String>?,tooltip: freezed == tooltip ? _self.tooltip : tooltip // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$TypeDescriptor {

/// The type's Type ID.
 TypeId get id;/// Whether it is a Behavior or a Custom component.
 TypeRole get role;/// The display name; the Type ID when the Manifest named none.
 String get label;/// Groups the Add Behavior list, when given.
 String? get category;/// The class's documentation comment.
 String? get doc;/// The declaring file, package-relative.
 String? get source;/// Behaviors: the required parent type.
 TypeId? get parentType;/// The superclass chain's names, for reference and parenting filtering
/// (*Q57*).
 ISet<String> get supertypes;/// Components only: whether the class is an `EntityMixin`, so it can
/// hold Behaviors.
 bool get acceptsBehaviors;/// The `@PyroComponent(preview:)` image, project-root-relative.
 AssetPath? get preview;/// Whether this is a hand-written built-in descriptor.
 bool get builtIn;/// The Editable fields in Manifest order.
 IList<FieldDescriptor> get fields;
/// Create a copy of TypeDescriptor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TypeDescriptorCopyWith<TypeDescriptor> get copyWith => _$TypeDescriptorCopyWithImpl<TypeDescriptor>(this as TypeDescriptor, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TypeDescriptor&&(identical(other.id, id) || other.id == id)&&(identical(other.role, role) || other.role == role)&&(identical(other.label, label) || other.label == label)&&(identical(other.category, category) || other.category == category)&&(identical(other.doc, doc) || other.doc == doc)&&(identical(other.source, source) || other.source == source)&&(identical(other.parentType, parentType) || other.parentType == parentType)&&const DeepCollectionEquality().equals(other.supertypes, supertypes)&&(identical(other.acceptsBehaviors, acceptsBehaviors) || other.acceptsBehaviors == acceptsBehaviors)&&(identical(other.preview, preview) || other.preview == preview)&&(identical(other.builtIn, builtIn) || other.builtIn == builtIn)&&const DeepCollectionEquality().equals(other.fields, fields));
}


@override
int get hashCode => Object.hash(runtimeType,id,role,label,category,doc,source,parentType,const DeepCollectionEquality().hash(supertypes),acceptsBehaviors,preview,builtIn,const DeepCollectionEquality().hash(fields));

@override
String toString() {
  return 'TypeDescriptor(id: $id, role: $role, label: $label, category: $category, doc: $doc, source: $source, parentType: $parentType, supertypes: $supertypes, acceptsBehaviors: $acceptsBehaviors, preview: $preview, builtIn: $builtIn, fields: $fields)';
}


}

/// @nodoc
abstract mixin class $TypeDescriptorCopyWith<$Res>  {
  factory $TypeDescriptorCopyWith(TypeDescriptor value, $Res Function(TypeDescriptor) _then) = _$TypeDescriptorCopyWithImpl;
@useResult
$Res call({
 TypeId id, TypeRole role, String label, String? category, String? doc, String? source, TypeId? parentType, ISet<String> supertypes, bool acceptsBehaviors, AssetPath? preview, bool builtIn, IList<FieldDescriptor> fields
});




}
/// @nodoc
class _$TypeDescriptorCopyWithImpl<$Res>
    implements $TypeDescriptorCopyWith<$Res> {
  _$TypeDescriptorCopyWithImpl(this._self, this._then);

  final TypeDescriptor _self;
  final $Res Function(TypeDescriptor) _then;

/// Create a copy of TypeDescriptor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? role = null,Object? label = null,Object? category = freezed,Object? doc = freezed,Object? source = freezed,Object? parentType = freezed,Object? supertypes = null,Object? acceptsBehaviors = null,Object? preview = freezed,Object? builtIn = null,Object? fields = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as TypeId,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as TypeRole,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,doc: freezed == doc ? _self.doc : doc // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,parentType: freezed == parentType ? _self.parentType : parentType // ignore: cast_nullable_to_non_nullable
as TypeId?,supertypes: null == supertypes ? _self.supertypes : supertypes // ignore: cast_nullable_to_non_nullable
as ISet<String>,acceptsBehaviors: null == acceptsBehaviors ? _self.acceptsBehaviors : acceptsBehaviors // ignore: cast_nullable_to_non_nullable
as bool,preview: freezed == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as AssetPath?,builtIn: null == builtIn ? _self.builtIn : builtIn // ignore: cast_nullable_to_non_nullable
as bool,fields: null == fields ? _self.fields : fields // ignore: cast_nullable_to_non_nullable
as IList<FieldDescriptor>,
  ));
}

}


/// Adds pattern-matching-related methods to [TypeDescriptor].
extension TypeDescriptorPatterns on TypeDescriptor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TypeDescriptor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TypeDescriptor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TypeDescriptor value)  $default,){
final _that = this;
switch (_that) {
case _TypeDescriptor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TypeDescriptor value)?  $default,){
final _that = this;
switch (_that) {
case _TypeDescriptor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TypeId id,  TypeRole role,  String label,  String? category,  String? doc,  String? source,  TypeId? parentType,  ISet<String> supertypes,  bool acceptsBehaviors,  AssetPath? preview,  bool builtIn,  IList<FieldDescriptor> fields)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TypeDescriptor() when $default != null:
return $default(_that.id,_that.role,_that.label,_that.category,_that.doc,_that.source,_that.parentType,_that.supertypes,_that.acceptsBehaviors,_that.preview,_that.builtIn,_that.fields);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TypeId id,  TypeRole role,  String label,  String? category,  String? doc,  String? source,  TypeId? parentType,  ISet<String> supertypes,  bool acceptsBehaviors,  AssetPath? preview,  bool builtIn,  IList<FieldDescriptor> fields)  $default,) {final _that = this;
switch (_that) {
case _TypeDescriptor():
return $default(_that.id,_that.role,_that.label,_that.category,_that.doc,_that.source,_that.parentType,_that.supertypes,_that.acceptsBehaviors,_that.preview,_that.builtIn,_that.fields);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TypeId id,  TypeRole role,  String label,  String? category,  String? doc,  String? source,  TypeId? parentType,  ISet<String> supertypes,  bool acceptsBehaviors,  AssetPath? preview,  bool builtIn,  IList<FieldDescriptor> fields)?  $default,) {final _that = this;
switch (_that) {
case _TypeDescriptor() when $default != null:
return $default(_that.id,_that.role,_that.label,_that.category,_that.doc,_that.source,_that.parentType,_that.supertypes,_that.acceptsBehaviors,_that.preview,_that.builtIn,_that.fields);case _:
  return null;

}
}

}

/// @nodoc


class _TypeDescriptor implements TypeDescriptor {
  const _TypeDescriptor({required this.id, required this.role, required this.label, this.category, this.doc, this.source, this.parentType, required this.supertypes, required this.acceptsBehaviors, this.preview, required this.builtIn, required this.fields});
  

/// The type's Type ID.
@override final  TypeId id;
/// Whether it is a Behavior or a Custom component.
@override final  TypeRole role;
/// The display name; the Type ID when the Manifest named none.
@override final  String label;
/// Groups the Add Behavior list, when given.
@override final  String? category;
/// The class's documentation comment.
@override final  String? doc;
/// The declaring file, package-relative.
@override final  String? source;
/// Behaviors: the required parent type.
@override final  TypeId? parentType;
/// The superclass chain's names, for reference and parenting filtering
/// (*Q57*).
@override final  ISet<String> supertypes;
/// Components only: whether the class is an `EntityMixin`, so it can
/// hold Behaviors.
@override final  bool acceptsBehaviors;
/// The `@PyroComponent(preview:)` image, project-root-relative.
@override final  AssetPath? preview;
/// Whether this is a hand-written built-in descriptor.
@override final  bool builtIn;
/// The Editable fields in Manifest order.
@override final  IList<FieldDescriptor> fields;

/// Create a copy of TypeDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TypeDescriptorCopyWith<_TypeDescriptor> get copyWith => __$TypeDescriptorCopyWithImpl<_TypeDescriptor>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TypeDescriptor&&(identical(other.id, id) || other.id == id)&&(identical(other.role, role) || other.role == role)&&(identical(other.label, label) || other.label == label)&&(identical(other.category, category) || other.category == category)&&(identical(other.doc, doc) || other.doc == doc)&&(identical(other.source, source) || other.source == source)&&(identical(other.parentType, parentType) || other.parentType == parentType)&&const DeepCollectionEquality().equals(other.supertypes, supertypes)&&(identical(other.acceptsBehaviors, acceptsBehaviors) || other.acceptsBehaviors == acceptsBehaviors)&&(identical(other.preview, preview) || other.preview == preview)&&(identical(other.builtIn, builtIn) || other.builtIn == builtIn)&&const DeepCollectionEquality().equals(other.fields, fields));
}


@override
int get hashCode => Object.hash(runtimeType,id,role,label,category,doc,source,parentType,const DeepCollectionEquality().hash(supertypes),acceptsBehaviors,preview,builtIn,const DeepCollectionEquality().hash(fields));

@override
String toString() {
  return 'TypeDescriptor(id: $id, role: $role, label: $label, category: $category, doc: $doc, source: $source, parentType: $parentType, supertypes: $supertypes, acceptsBehaviors: $acceptsBehaviors, preview: $preview, builtIn: $builtIn, fields: $fields)';
}


}

/// @nodoc
abstract mixin class _$TypeDescriptorCopyWith<$Res> implements $TypeDescriptorCopyWith<$Res> {
  factory _$TypeDescriptorCopyWith(_TypeDescriptor value, $Res Function(_TypeDescriptor) _then) = __$TypeDescriptorCopyWithImpl;
@override @useResult
$Res call({
 TypeId id, TypeRole role, String label, String? category, String? doc, String? source, TypeId? parentType, ISet<String> supertypes, bool acceptsBehaviors, AssetPath? preview, bool builtIn, IList<FieldDescriptor> fields
});




}
/// @nodoc
class __$TypeDescriptorCopyWithImpl<$Res>
    implements _$TypeDescriptorCopyWith<$Res> {
  __$TypeDescriptorCopyWithImpl(this._self, this._then);

  final _TypeDescriptor _self;
  final $Res Function(_TypeDescriptor) _then;

/// Create a copy of TypeDescriptor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? role = null,Object? label = null,Object? category = freezed,Object? doc = freezed,Object? source = freezed,Object? parentType = freezed,Object? supertypes = null,Object? acceptsBehaviors = null,Object? preview = freezed,Object? builtIn = null,Object? fields = null,}) {
  return _then(_TypeDescriptor(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as TypeId,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as TypeRole,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,doc: freezed == doc ? _self.doc : doc // ignore: cast_nullable_to_non_nullable
as String?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,parentType: freezed == parentType ? _self.parentType : parentType // ignore: cast_nullable_to_non_nullable
as TypeId?,supertypes: null == supertypes ? _self.supertypes : supertypes // ignore: cast_nullable_to_non_nullable
as ISet<String>,acceptsBehaviors: null == acceptsBehaviors ? _self.acceptsBehaviors : acceptsBehaviors // ignore: cast_nullable_to_non_nullable
as bool,preview: freezed == preview ? _self.preview : preview // ignore: cast_nullable_to_non_nullable
as AssetPath?,builtIn: null == builtIn ? _self.builtIn : builtIn // ignore: cast_nullable_to_non_nullable
as bool,fields: null == fields ? _self.fields : fields // ignore: cast_nullable_to_non_nullable
as IList<FieldDescriptor>,
  ));
}


}

/// @nodoc
mixin _$TypeCatalog {

/// Every type by Type ID: the built-ins plus the Manifest's.
 IMap<TypeId, TypeDescriptor> get types;/// The Manifest's problems, when it parsed with warnings or failed.
 IList<ManifestProblem> get problems;/// Where the types came from.
 ManifestOrigin get origin;
/// Create a copy of TypeCatalog
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TypeCatalogCopyWith<TypeCatalog> get copyWith => _$TypeCatalogCopyWithImpl<TypeCatalog>(this as TypeCatalog, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TypeCatalog&&(identical(other.types, types) || other.types == types)&&const DeepCollectionEquality().equals(other.problems, problems)&&(identical(other.origin, origin) || other.origin == origin));
}


@override
int get hashCode => Object.hash(runtimeType,types,const DeepCollectionEquality().hash(problems),origin);

@override
String toString() {
  return 'TypeCatalog(types: $types, problems: $problems, origin: $origin)';
}


}

/// @nodoc
abstract mixin class $TypeCatalogCopyWith<$Res>  {
  factory $TypeCatalogCopyWith(TypeCatalog value, $Res Function(TypeCatalog) _then) = _$TypeCatalogCopyWithImpl;
@useResult
$Res call({
 IMap<TypeId, TypeDescriptor> types, IList<ManifestProblem> problems, ManifestOrigin origin
});




}
/// @nodoc
class _$TypeCatalogCopyWithImpl<$Res>
    implements $TypeCatalogCopyWith<$Res> {
  _$TypeCatalogCopyWithImpl(this._self, this._then);

  final TypeCatalog _self;
  final $Res Function(TypeCatalog) _then;

/// Create a copy of TypeCatalog
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? types = null,Object? problems = null,Object? origin = null,}) {
  return _then(_self.copyWith(
types: null == types ? _self.types : types // ignore: cast_nullable_to_non_nullable
as IMap<TypeId, TypeDescriptor>,problems: null == problems ? _self.problems : problems // ignore: cast_nullable_to_non_nullable
as IList<ManifestProblem>,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as ManifestOrigin,
  ));
}

}


/// Adds pattern-matching-related methods to [TypeCatalog].
extension TypeCatalogPatterns on TypeCatalog {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TypeCatalog value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TypeCatalog() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TypeCatalog value)  $default,){
final _that = this;
switch (_that) {
case _TypeCatalog():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TypeCatalog value)?  $default,){
final _that = this;
switch (_that) {
case _TypeCatalog() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( IMap<TypeId, TypeDescriptor> types,  IList<ManifestProblem> problems,  ManifestOrigin origin)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TypeCatalog() when $default != null:
return $default(_that.types,_that.problems,_that.origin);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( IMap<TypeId, TypeDescriptor> types,  IList<ManifestProblem> problems,  ManifestOrigin origin)  $default,) {final _that = this;
switch (_that) {
case _TypeCatalog():
return $default(_that.types,_that.problems,_that.origin);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( IMap<TypeId, TypeDescriptor> types,  IList<ManifestProblem> problems,  ManifestOrigin origin)?  $default,) {final _that = this;
switch (_that) {
case _TypeCatalog() when $default != null:
return $default(_that.types,_that.problems,_that.origin);case _:
  return null;

}
}

}

/// @nodoc


class _TypeCatalog extends TypeCatalog {
  const _TypeCatalog({required this.types, required this.problems, required this.origin}): super._();
  

/// Every type by Type ID: the built-ins plus the Manifest's.
@override final  IMap<TypeId, TypeDescriptor> types;
/// The Manifest's problems, when it parsed with warnings or failed.
@override final  IList<ManifestProblem> problems;
/// Where the types came from.
@override final  ManifestOrigin origin;

/// Create a copy of TypeCatalog
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TypeCatalogCopyWith<_TypeCatalog> get copyWith => __$TypeCatalogCopyWithImpl<_TypeCatalog>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TypeCatalog&&(identical(other.types, types) || other.types == types)&&const DeepCollectionEquality().equals(other.problems, problems)&&(identical(other.origin, origin) || other.origin == origin));
}


@override
int get hashCode => Object.hash(runtimeType,types,const DeepCollectionEquality().hash(problems),origin);

@override
String toString() {
  return 'TypeCatalog(types: $types, problems: $problems, origin: $origin)';
}


}

/// @nodoc
abstract mixin class _$TypeCatalogCopyWith<$Res> implements $TypeCatalogCopyWith<$Res> {
  factory _$TypeCatalogCopyWith(_TypeCatalog value, $Res Function(_TypeCatalog) _then) = __$TypeCatalogCopyWithImpl;
@override @useResult
$Res call({
 IMap<TypeId, TypeDescriptor> types, IList<ManifestProblem> problems, ManifestOrigin origin
});




}
/// @nodoc
class __$TypeCatalogCopyWithImpl<$Res>
    implements _$TypeCatalogCopyWith<$Res> {
  __$TypeCatalogCopyWithImpl(this._self, this._then);

  final _TypeCatalog _self;
  final $Res Function(_TypeCatalog) _then;

/// Create a copy of TypeCatalog
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? types = null,Object? problems = null,Object? origin = null,}) {
  return _then(_TypeCatalog(
types: null == types ? _self.types : types // ignore: cast_nullable_to_non_nullable
as IMap<TypeId, TypeDescriptor>,problems: null == problems ? _self.problems : problems // ignore: cast_nullable_to_non_nullable
as IList<ManifestProblem>,origin: null == origin ? _self.origin : origin // ignore: cast_nullable_to_non_nullable
as ManifestOrigin,
  ));
}


}

// dart format on
