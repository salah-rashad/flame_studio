import 'diagnostics.dart';

// The per-library scan's results, written to the build cache as
// `lib/**.pyro.json` and read by the aggregator (data-model.md). Internal to
// pyro_generator: the cache is rebuilt whenever the generator changes, so the
// format can change in any release.

/// One Editable field as the Registry emitter needs it.
final class RegistryFieldEntry {
  /// Describes field [name].
  const RegistryFieldEntry({
    required this.name,
    required this.kind,
    required this.nullable,
    required this.typeName,
    this.typeImport,
  });

  /// Reads an entry written by [toJson].
  factory RegistryFieldEntry.fromJson(Map<String, Object?> json) =>
      RegistryFieldEntry(
        name: json['name']! as String,
        kind: json['kind']! as String,
        nullable: json['nullable']! as bool,
        typeName: json['typeName']! as String,
        typeImport: json['typeImport'] as String?,
      );

  /// The field's name.
  final String name;

  /// The `FieldType` value's name in `pyro_runtime`, such as `vector2`.
  final String kind;

  /// Whether the field accepts null.
  final bool nullable;

  /// The field type's class name, such as `Vector2` or `PatrolMode`.
  final String typeName;

  /// The URI to import [typeName] from; null for `dart:core` types.
  final String? typeImport;

  /// The JSON form.
  Map<String, Object?> toJson() => {
    'kind': kind,
    'name': name,
    'nullable': nullable,
    'typeImport': ?typeImport,
    'typeName': typeName,
  };
}

/// One annotated type as the Registry emitter needs it.
final class RegistryEntry {
  /// Describes class [className] from [classImport].
  const RegistryEntry({
    required this.classImport,
    required this.className,
    required this.role,
    required this.fields,
  });

  /// Reads an entry written by [toJson].
  factory RegistryEntry.fromJson(Map<String, Object?> json) => RegistryEntry(
    classImport: json['classImport']! as String,
    className: json['className']! as String,
    role: json['role']! as String,
    fields: [
      for (final field in json['fields']! as List<Object?>)
        RegistryFieldEntry.fromJson(field! as Map<String, Object?>),
    ],
  );

  /// The URI of the library declaring the class.
  final String classImport;

  /// The class's name.
  final String className;

  /// `behavior` or `component`, the `TypeRole` value's name.
  final String role;

  /// The Editable fields, in Manifest order.
  final List<RegistryFieldEntry> fields;

  /// The JSON form.
  Map<String, Object?> toJson() => {
    'classImport': classImport,
    'className': className,
    'fields': [for (final field in fields) field.toJson()],
    'role': role,
  };
}

/// An annotated class found by the scan, valid or not.
final class TypeRecord {
  /// The record of class [className], Type ID [typeId].
  const TypeRecord({
    required this.key,
    required this.typeId,
    required this.className,
    required this.file,
    required this.line,
    required this.linearization,
    this.manifest,
    this.registry,
  });

  /// Reads a record written by [toJson].
  factory TypeRecord.fromJson(Map<String, Object?> json) => TypeRecord(
    key: json['key']! as String,
    typeId: json['typeId']! as String,
    className: json['className']! as String,
    file: json['file']! as String,
    line: json['line']! as int,
    linearization: (json['linearization']! as List<Object?>).cast<String>(),
    manifest: json['manifest'] as Map<String, Object?>?,
    registry: json['registry'] == null
        ? null
        : RegistryEntry.fromJson(json['registry']! as Map<String, Object?>),
  );

  /// The class key: `<library URI>#<class name>`.
  final String key;

  /// The Type ID: the explicit `id:` or the class name.
  final String typeId;

  /// The class's name.
  final String className;

  /// The package-relative path of the file declaring the class.
  final String file;

  /// The 1-based line of the class name.
  final int line;

  /// The class keys of its superclasses, their mixins and itself, top-down,
  /// so the aggregator can tell which `@Editable` holders are used.
  final List<String> linearization;

  /// The Manifest entry; null when the class has an error.
  final Map<String, Object?>? manifest;

  /// What the Registry needs; null when the class has an error.
  final RegistryEntry? registry;

  /// Whether the class had no error.
  bool get isValid => manifest != null && registry != null;

  /// The JSON form.
  Map<String, Object?> toJson() => {
    'className': className,
    'file': file,
    'key': key,
    'line': line,
    'linearization': linearization,
    'manifest': ?manifest,
    'registry': ?registry?.toJson(),
    'typeId': typeId,
  };
}

/// An unannotated class or mixin with `@Editable` fields (FR-014a).
final class EditableHolder {
  /// The holder [className] at [file]:[line], whose first Editable field is
  /// [field].
  const EditableHolder({
    required this.key,
    required this.className,
    required this.file,
    required this.line,
    required this.field,
  });

  /// Reads a holder written by [toJson].
  factory EditableHolder.fromJson(Map<String, Object?> json) => EditableHolder(
    key: json['key']! as String,
    className: json['className']! as String,
    file: json['file']! as String,
    line: json['line']! as int,
    field: json['field']! as String,
  );

  /// The class key: `<library URI>#<class name>`.
  final String key;

  /// The class or mixin's name.
  final String className;

  /// The package-relative path of the file declaring it.
  final String file;

  /// The 1-based line of its first `@Editable` field.
  final int line;

  /// The name of its first `@Editable` field.
  final String field;

  /// The JSON form.
  Map<String, Object?> toJson() => {
    'className': className,
    'field': field,
    'file': file,
    'key': key,
    'line': line,
  };
}

/// Everything the scan found in one library.
final class ScanFragment {
  /// A fragment of [types], [holders] and [diagnostics].
  const ScanFragment({
    required this.types,
    required this.holders,
    required this.diagnostics,
  });

  /// Reads a fragment written by [toJson].
  factory ScanFragment.fromJson(Map<String, Object?> json) => ScanFragment(
    types: [
      for (final type in json['types']! as List<Object?>)
        TypeRecord.fromJson(type! as Map<String, Object?>),
    ],
    holders: [
      for (final holder in json['holders']! as List<Object?>)
        EditableHolder.fromJson(holder! as Map<String, Object?>),
    ],
    diagnostics: [
      for (final diagnostic in json['diagnostics']! as List<Object?>)
        Diagnostic.fromJson(diagnostic! as Map<String, Object?>),
    ],
  );

  /// Every annotated class in the library.
  final List<TypeRecord> types;

  /// Every unannotated class or mixin with `@Editable` fields.
  final List<EditableHolder> holders;

  /// The errors and warnings found in the library.
  final List<Diagnostic> diagnostics;

  /// Whether there is nothing to write.
  bool get isEmpty => types.isEmpty && holders.isEmpty && diagnostics.isEmpty;

  /// The JSON form.
  Map<String, Object?> toJson() => {
    'diagnostics': [for (final d in diagnostics) d.toJson()],
    'holders': [for (final h in holders) h.toJson()],
    'types': [for (final t in types) t.toJson()],
  };
}
