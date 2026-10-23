import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

part 'manifest_parse.freezed.dart';

/// The newest `manifestVersion` this Pyro reads (FR-012, *Q105*). A newer
/// one keeps the last good types instead of guessing at the file.
const int maxManifestVersion = 1;

/// One problem the Manifest reports (FR-014): an error that failed the
/// build that wrote it, or a warning that build still succeeded with.
@freezed
sealed class ManifestProblem with _$ManifestProblem {
  /// Creates the problem as the Manifest wrote it.
  const factory ManifestProblem({
    /// The stable code, such as `fieldFinal` or `defaultOutOfRange`.
    required String code,

    /// The declaring file, package-relative, or a `package:` URI.
    String? file,

    /// The 1-based line of the declaration's name.
    int? line,

    /// The class the problem concerns, when one does.
    String? className,

    /// The field the problem concerns, when one does.
    String? field,

    /// What is wrong and how to fix it.
    required String message,

    /// Whether the build still succeeded with this problem.
    required bool isWarning,
  }) = _ManifestProblem;

  const ManifestProblem._();

  /// The problem's location, as the catalog's dialog shows it:
  /// `lib/components/ship.dart:14 Ship.speed`, or null when the Manifest
  /// named none.
  String? get location {
    final at = file == null
        ? null
        : line == null
        ? file
        : '$file:$line';
    final owner = [
      if (className != null) className,
      if (field != null) field,
    ].join('.');
    final parts = [?at, if (owner.isNotEmpty) owner];
    return parts.isEmpty ? null : parts.join(' ');
  }
}

/// One Editable field of a user type, as the panels edit it
/// (`contracts/type-catalog.md`).
@freezed
sealed class FieldDescriptor with _$FieldDescriptor {
  /// Creates the descriptor.
  const factory FieldDescriptor({
    /// The field's name, as Scenes key its Override.
    required String name,

    /// The field's Field type.
    required FieldType type,

    /// Whether the field accepts `null`.
    required bool nullable,

    /// The evaluated default in its Scene written form, or null.
    Object? defaultValue,

    /// The initializer's source text, when the default wasn't a constant
    /// the generator could evaluate (§7.3).
    String? defaultSource,

    /// The inclusive lower bound, numeric fields only.
    double? min,

    /// The inclusive upper bound, numeric fields only.
    double? max,

    /// The value names in declaration order, `enum` fields only.
    IList<String>? enumValues,

    /// The `@Editable(tooltip:)` text.
    String? tooltip,
  }) = _FieldDescriptor;
}

/// One user type: what every panel shows and edits of it. Built-ins
/// ([TypeDescriptor.builtIn]) are hand-written in `built_in.dart` and never
/// come from the Manifest.
@freezed
sealed class TypeDescriptor with _$TypeDescriptor {
  /// Creates the descriptor.
  const factory TypeDescriptor({
    /// The type's Type ID.
    required TypeId id,

    /// Whether it is a Behavior or a Custom component.
    required TypeRole role,

    /// The display name; the Type ID when the Manifest named none.
    required String label,

    /// Groups the Add Behavior list, when given.
    String? category,

    /// The class's documentation comment.
    String? doc,

    /// The declaring file, package-relative.
    String? source,

    /// Behaviors: the required parent type.
    TypeId? parentType,

    /// The superclass chain's names, for reference and parenting filtering
    /// (*Q57*).
    required ISet<String> supertypes,

    /// Components only: whether the class is an `EntityMixin`, so it can
    /// hold Behaviors.
    required bool acceptsBehaviors,

    /// The `@PyroComponent(preview:)` image, project-root-relative.
    AssetPath? preview,

    /// Whether this is a hand-written built-in descriptor.
    required bool builtIn,

    /// The Editable fields in Manifest order.
    required IList<FieldDescriptor> fields,
  }) = _TypeDescriptor;
}

/// How the catalog came by its types (FR-012, `contracts/type-catalog.md`).
sealed class ManifestOrigin {
  const ManifestOrigin();
}

/// The Manifest parsed cleanly; its warnings may still be carried as
/// problems.
final class ManifestUpToDate extends ManifestOrigin {
  /// The good outcome.
  const ManifestUpToDate();
}

/// No Manifest file at all — a project without annotated types still edits
/// the built-in kinds.
final class ManifestAbsent extends ManifestOrigin {
  /// The project has no annotated types.
  const ManifestAbsent();
}

/// The Manifest was unreadable, had errors, or carries a version this Pyro
/// can't read (*Q105*): the previous types stay active — stale, not empty —
/// so Missing states never fire from them.
final class ManifestStale extends ManifestOrigin {
  /// The outcome that keeps the last good types.
  const ManifestStale(this.reason);

  /// Why they are kept, surfaced in the status bar and the catalog dialog.
  final String reason;
}

/// The project's types: the built-in descriptors joined with the
/// Manifest's (FR-012), as every panel reads them through
/// `typeCatalogProvider` and nothing else.
@freezed
sealed class TypeCatalog with _$TypeCatalog {
  /// Creates the catalog.
  const factory TypeCatalog({
    /// Every type by Type ID: the built-ins plus the Manifest's.
    required IMap<TypeId, TypeDescriptor> types,

    /// The Manifest's problems, when it parsed with warnings or failed.
    required IList<ManifestProblem> problems,

    /// Where the types came from.
    required ManifestOrigin origin,
  }) = _TypeCatalog;

  const TypeCatalog._();

  /// The type with Type ID [id], or null if there is none.
  TypeDescriptor? operator [](TypeId id) => types[id];

  /// The types in Type ID order, a stable listing order for menus.
  IList<TypeDescriptor> get sorted =>
      IList([...types.values]..sort((a, b) => a.id.compareTo(b.id)));
}

/// What reading a Manifest file came to, mapping straight onto the
/// catalog's states (`contracts/type-catalog.md`): parsed (its warnings may
/// remain), failed with errors, unreadable, or a version this Pyro can't
/// read.
sealed class ManifestRead {
  const ManifestRead();
}

/// The Manifest parsed; [problems] carries its warnings, if any.
final class ManifestParsed extends ManifestRead {
  /// Creates the successful read.
  const ManifestParsed({required this.types, required this.problems});

  /// The user types, in Manifest order.
  final IList<TypeDescriptor> types;

  /// The Manifest's warnings.
  final IList<ManifestProblem> problems;
}

/// The build that wrote the Manifest failed, so its types are unusable
/// (the catalog keeps the previous ones).
final class ManifestFailed extends ManifestRead {
  /// Creates the failed read.
  const ManifestFailed({required this.problems});

  /// The errors and warnings the build reported.
  final IList<ManifestProblem> problems;
}

/// The file isn't a Manifest of this shape; [message] says why.
final class ManifestUnreadable extends ManifestRead {
  /// Creates the unreadable read.
  const ManifestUnreadable(this.message);

  /// Why the file couldn't be read.
  final String message;

  @override
  String toString() => 'the Manifest is unreadable: $message';
}

/// The Manifest's `manifestVersion` postdates [maxManifestVersion]
/// (*Q105*).
final class ManifestNewer extends ManifestRead {
  /// Creates the refused read.
  const ManifestNewer(this.manifestVersion);

  /// The version the file carries.
  final int manifestVersion;

  @override
  String toString() =>
      'the Manifest needs a newer Pyro (manifestVersion $manifestVersion)';
}

/// Reads [text], a `lib/pyro.manifest.json` of `manifestVersion` 1
/// (FR-012): unknown keys are ignored, a newer version is refused, and any
/// structural surprise — invalid JSON, a missing `manifestVersion`, a type
/// without its required keys — reads as unreadable, never as a crash.
ManifestRead readManifest(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (error) {
    return ManifestUnreadable("it isn't valid JSON: ${error.message}");
  }
  if (json is! Map) {
    return const ManifestUnreadable('its top level is not a JSON object');
  }
  try {
    return _Reader(json).read();
  } on _Malformed catch (malformed) {
    return ManifestUnreadable(malformed.message);
  }
}

/// A structural surprise in the Manifest, turned into a
/// [ManifestUnreadable] by [readManifest].
final class _Malformed implements Exception {
  const _Malformed(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The Field types by the Manifest's name for them; it spells
/// [FieldType.enumeration] `enum`
/// (`specs/003-generator/contracts/manifest-v1.md`).
const Map<String, FieldType> fieldTypesByName = {
  'int': FieldType.int,
  'double': FieldType.double,
  'bool': FieldType.bool,
  'string': FieldType.string,
  'enum': FieldType.enumeration,
  'vector2': FieldType.vector2,
  'color': FieldType.color,
  'imagePath': FieldType.imagePath,
  'sprite': FieldType.sprite,
  'spriteAnimation': FieldType.spriteAnimation,
  'entityRef': FieldType.entityRef,
};

final class _Reader {
  _Reader(this._json);

  final Map<Object?, Object?> _json;

  ManifestRead read() {
    final version = _json['manifestVersion'];
    if (version is! int) {
      throw const _Malformed('manifestVersion is missing or not a number');
    }
    if (version > maxManifestVersion) return ManifestNewer(version);
    // Errors mean the build failed, so the types list is not to be trusted
    // and is never read.
    final problems = [
      ..._problems(_json['errors'], isWarning: false),
      ..._problems(_json['warnings'], isWarning: true),
    ];
    if (problems.any((problem) => !problem.isWarning)) {
      return ManifestFailed(problems: IList(problems));
    }
    final types = _json['types'] ?? const <Object?>[];
    if (types is! List) throw const _Malformed('types is not an array');
    return ManifestParsed(
      types: IList([for (final type in types) _type(type)]),
      problems: IList(problems),
    );
  }

  Iterable<ManifestProblem> _problems(
    Object? json, {
    required bool isWarning,
  }) sync* {
    final what = isWarning ? 'warning' : 'error';
    final list = json ?? const <Object?>[];
    if (list is! List) {
      throw _Malformed(
        'the ${isWarning ? 'warnings' : 'errors'} are not an array',
      );
    }
    for (final entry in list) {
      if (entry is! Map) throw _Malformed('a $what is not an object');
      final code = entry['code'];
      final message = entry['message'];
      if (code is! String || message is! String) {
        throw _Malformed('a $what is missing its code or message');
      }
      final line = entry['line'];
      yield ManifestProblem(
        code: code,
        message: message,
        isWarning: isWarning,
        file: _string(entry['file']),
        line: line is int ? line : null,
        className: _string(entry['className']),
        field: _string(entry['field']),
      );
    }
  }

  TypeDescriptor _type(Object? json) {
    if (json is! Map) throw const _Malformed('a type is not an object');
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const _Malformed('a type has no id');
    }
    final role = switch (json['role']) {
      'behavior' => TypeRole.behavior,
      'component' => TypeRole.component,
      _ => throw _Malformed('the type "$id" has no role'),
    };
    final supertypes = json['supertypes'] ?? const <Object?>[];
    if (supertypes is! List) {
      throw _Malformed('the type "$id" has no supertypes array');
    }
    final fields = json['fields'] ?? const <Object?>[];
    if (fields is! List) throw _Malformed('the type "$id" has no fields array');
    return TypeDescriptor(
      id: TypeId(id),
      role: role,
      label: _string(json['label']) ?? id,
      category: _string(json['category']),
      doc: _string(json['doc']),
      source: _string(json['source']),
      parentType: switch (json['parentType']) {
        final String parent => TypeId(parent),
        _ => null,
      },
      supertypes: ISet([
        for (final supertype in supertypes)
          if (supertype is! String)
            throw _Malformed(
              'the type "$id" has a supertype that is not a string',
            )
          else
            supertype,
      ]),
      acceptsBehaviors: json['acceptsBehaviors'] == true,
      preview: switch (json['preview']) {
        final String preview => AssetPath(preview),
        _ => null,
      },
      builtIn: false,
      fields: IList([for (final field in fields) _field(field, of: id)]),
    );
  }

  FieldDescriptor _field(Object? json, {required String of}) {
    if (json is! Map) throw _Malformed('a field of "$of" is not an object');
    final name = json['name'];
    if (name is! String || name.isEmpty) {
      throw _Malformed('a field of "$of" has no name');
    }
    final typeName = json['type'];
    final type = typeName is String ? fieldTypesByName[typeName] : null;
    if (type == null) {
      throw _Malformed(
        'the field "$of.$name" has the unknown type "$typeName"',
      );
    }
    final values = json['values'];
    IList<String>? enumValues;
    if (values is List) {
      enumValues = IList([
        for (final value in values)
          if (value is! String)
            throw _Malformed(
              'the field "$of.$name" has a value that is not a string',
            )
          else
            value,
      ]);
    } else if (values != null) {
      throw _Malformed(
        'the field "$of.$name" has values that are not an array',
      );
    }
    return FieldDescriptor(
      name: name,
      type: type,
      nullable: json['nullable'] == true,
      defaultValue: json['default'],
      defaultSource: _string(json['defaultSource']),
      min: _number(json['min']),
      max: _number(json['max']),
      enumValues: enumValues,
      tooltip: _string(json['tooltip']),
    );
  }

  static String? _string(Object? value) => value is String ? value : null;

  static double? _number(Object? value) =>
      value is num ? value.toDouble() : null;
}
