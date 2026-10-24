import 'dart:convert';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

const _behaviorChecker = TypeChecker.typeNamedLiterally(
  'StudioBehavior',
  inPackage: 'studio_annotations',
);
const _componentChecker = TypeChecker.typeNamedLiterally(
  'StudioComponent',
  inPackage: 'studio_annotations',
);
const _editableChecker = TypeChecker.typeNamedLiterally(
  'Editable',
  inPackage: 'studio_annotations',
);

/// Per-library step: writes `<file>.studio.json` (build cache) with the
/// annotated types in that library. The `$lib$` aggregator combines them.
///
/// Writes nothing for libraries without annotated classes, so with
/// `run_only_if_triggered` most files cost nothing at all.
class StudioScanBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.dart': ['.studio.json'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    if (!await buildStep.resolver.isLibrary(buildStep.inputId)) return;
    final library = await buildStep.inputLibrary;
    final reader = LibraryReader(library);

    final types = <Map<String, Object?>>[];
    final errors = <String>[];
    final source = buildStep.inputId.path;

    for (final cls in reader.classes) {
      final behavior = _behaviorChecker.firstAnnotationOfExact(cls);
      final component = _componentChecker.firstAnnotationOfExact(cls);
      if (behavior == null && component == null) continue;
      final annotation = ConstantReader(behavior ?? component);
      final role = behavior != null ? 'behavior' : 'component';
      final name = cls.name!;

      final problems = <String>[];
      if (cls.isPrivate) problems.add('$name must be public');
      if (cls.isAbstract) problems.add('$name must not be abstract');
      final ctor = cls.unnamedConstructor;
      if (ctor == null || ctor.formalParameters.any((p) => p.isRequired)) {
        problems.add(
          '$name needs an unnamed constructor callable with no '
          'arguments',
        );
      }

      final supertypes = [
        for (final t in cls.allSupertypes)
          if (!t.isDartCoreObject) t.element.name!,
      ];

      String? parentType;
      if (role == 'behavior') {
        final b = cls.allSupertypes
            .where((t) => t.element.name == 'Behavior')
            .firstOrNull;
        if (b == null) {
          problems.add('@StudioBehavior $name must extend Behavior<T>');
        } else if (b.typeArguments.isNotEmpty) {
          parentType = b.typeArguments.first.element?.name;
        }
      } else if (!supertypes.contains('PositionComponent')) {
        problems.add('@StudioComponent $name must extend PositionComponent');
      }

      final fields = <Map<String, Object?>>[];
      final setters = <Map<String, Object?>>[];
      for (final field in cls.fields) {
        final editable = _editableChecker.firstAnnotationOfExact(field);
        if (editable == null) continue;
        final where = '$source: $name.${field.name}';
        if (field.isPrivate || field.isFinal || field.isStatic) {
          problems.add(
            '$where: @Editable fields must be public, '
            'non-final instance fields',
          );
          continue;
        }
        final kind = _fieldKind(field.type);
        if (kind == null) {
          problems.add(
            '$where: unsupported Field type '
            '${field.type.getDisplayString()}',
          );
          continue;
        }
        final e = ConstantReader(editable);
        final entry = <String, Object?>{'name': field.name, 'type': kind};
        await _addDefault(buildStep, field, kind, entry);
        if (kind == 'enum') {
          entry['values'] = [
            for (final c in (field.type.element as EnumElement).constants)
              c.name,
          ];
        }
        if (kind == 'entityRef') entry['refType'] = field.type.element!.name;
        if (kind == 'asset') entry['assetType'] = field.type.element!.name;
        _copy(e, 'min', entry);
        _copy(e, 'max', entry);
        _copy(e, 'tooltip', entry);
        fields.add(entry);

        final t = field.type as InterfaceType;
        setters.add({
          'name': field.name,
          'kind': kind,
          'typeName': t.element.name,
          'typeLibrary': t.element.library.uri.toString(),
          'nullable': t.nullabilitySuffix == NullabilitySuffix.question,
        });
      }

      if (problems.isNotEmpty) {
        errors.addAll(problems);
        continue;
      }

      types.add({
        'manifest': {
          'id': annotation.peek('id')?.stringValue ?? name,
          'role': role,
          'label': annotation.peek('label')?.stringValue ?? name,
          if (annotation.peek('category') != null)
            'category': annotation.peek('category')!.stringValue,
          'parentType': ?parentType,
          if (role == 'component')
            'acceptsBehaviors': supertypes.contains('EntityMixin'),
          if (annotation.peek('preview') != null)
            'preview': annotation.peek('preview')!.stringValue,
          'supertypes': supertypes,
          'source': source,
          if (cls.documentationComment != null)
            'doc': _stripDoc(cls.documentationComment!),
          'fields': fields,
        },
        'registry': {
          'className': name,
          'library': library.uri.toString(),
          'setters': setters,
        },
      });
    }

    if (types.isEmpty && errors.isEmpty) return;
    await buildStep.writeAsString(
      buildStep.inputId.changeExtension('.studio.json'),
      jsonEncode({'types': types, 'errors': errors}),
    );
  }
}

String? _fieldKind(DartType type) {
  if (type is! InterfaceType) return null;
  if (type.isDartCoreInt) return 'int';
  if (type.isDartCoreDouble) return 'double';
  if (type.isDartCoreBool) return 'bool';
  if (type.isDartCoreString) return 'string';
  final element = type.element;
  if (element is EnumElement) return 'enum';
  switch (element.name) {
    case 'Vector2':
      return 'vector2';
    case 'Color':
      return 'color';
    case 'Sprite':
    case 'SpriteAnimation':
      return 'asset';
  }
  if (element.allSupertypes.any((t) => t.element.name == 'Component')) {
    return 'entityRef';
  }
  return null;
}

/// Constant defaults are evaluated; anything else keeps its source text.
Future<void> _addDefault(
  BuildStep step,
  FieldElement field,
  String kind,
  Map<String, Object?> entry,
) async {
  final node = await step.resolver.astNodeFor(field.firstFragment);
  final init = node is VariableDeclaration ? node.initializer : null;
  if (init == null) {
    entry['default'] = null;
    return;
  }
  final value = switch (init) {
    IntegerLiteral(:final value) => value,
    DoubleLiteral(:final value) => value,
    BooleanLiteral(:final value) => value,
    SimpleStringLiteral(:final value) => value,
    NullLiteral() => null,
    PrefixExpression(operator: Token(lexeme: '-'), :final operand)
        when operand is IntegerLiteral =>
      -operand.value!,
    PrefixExpression(operator: Token(lexeme: '-'), :final operand)
        when operand is DoubleLiteral =>
      -operand.value,
    PrefixedIdentifier(:final identifier) when kind == 'enum' =>
      identifier.name,
    _ => const _NotConstant(),
  };
  if (value is _NotConstant) {
    entry['default'] = null;
    entry['defaultSource'] = init.toSource();
  } else {
    entry['default'] = value;
  }
}

class _NotConstant {
  const _NotConstant();
}

void _copy(ConstantReader r, String key, Map<String, Object?> out) {
  final v = r.peek(key);
  if (v == null) return;
  out[key] = v.literalValue;
}

String _stripDoc(String doc) => doc
    .split('\n')
    .map((l) => l.replaceFirst(RegExp(r'^\s*///\s?'), ''))
    .join('\n')
    .trim();
