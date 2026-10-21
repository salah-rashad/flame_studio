import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'checkers.dart';
import 'defaults.dart';
import 'diagnostics.dart';
import 'fields.dart';
import 'fragment.dart';
import 'imports.dart';
import 'places.dart';

/// Scans one library: every annotated class becomes a [TypeRecord], every
/// unannotated class or mixin with `@Editable` fields an [EditableHolder],
/// and every broken rule a [Diagnostic] (research R4, R5).
Future<ScanFragment> scanLibrary(LibraryElement library, BuildStep step) async {
  final root = step.inputId.package;
  final types = <TypeRecord>[];
  final holders = <EditableHolder>[];
  final diagnostics = <Diagnostic>[];

  for (final cls in library.classes) {
    final behavior = pyroBehaviorChecker.firstAnnotationOfExact(cls);
    final component = pyroComponentChecker.firstAnnotationOfExact(cls);
    if (behavior == null && component == null) {
      final holder = _holder(cls, root);
      if (holder != null) holders.add(holder);
      continue;
    }
    final scan = _ClassScan(cls, behavior, component, step, root);
    types.add(await scan.run());
    diagnostics.addAll(scan.diagnostics);
  }
  for (final mixin in library.mixins) {
    final holder = _holder(mixin, root);
    if (holder != null) holders.add(holder);
  }
  return ScanFragment(types: types, holders: holders, diagnostics: diagnostics);
}

/// The Type ID of [element] if it is annotated, else its class name, for
/// supertypes, parent types and entity references (*Q57*).
String typeIdOrName(InterfaceElement element) {
  final annotation =
      pyroBehaviorChecker.firstAnnotationOfExact(element) ??
      pyroComponentChecker.firstAnnotationOfExact(element);
  final id = annotation == null
      ? null
      : ConstantReader(annotation).peek('id')?.stringValue;
  return id ?? element.name!;
}

EditableHolder? _holder(InterfaceElement element, String root) {
  for (final field in element.fields) {
    if (!field.isOriginDeclaration) continue;
    if (editableChecker.firstAnnotationOfExact(field) == null) continue;
    final place = placeOf(field.firstFragment, root);
    return EditableHolder(
      key: classKey(element),
      className: element.name!,
      file: place.file,
      line: place.line,
      field: field.name!,
    );
  }
  return null;
}

/// The superclasses, their mixins and the class itself, top-down, without
/// `Object` (research R5). Mixins' own superclass constraints are not walked.
List<InterfaceElement> linearize(InterfaceElement element) {
  final result = <InterfaceElement>[];
  void visit(InterfaceElement current) {
    final superclass = current.supertype;
    if (superclass != null && !superclass.isDartCoreObject) {
      visit(superclass.element);
    }
    for (final mixin in current.mixins) {
      if (!result.contains(mixin.element)) result.add(mixin.element);
    }
    if (!result.contains(current)) result.add(current);
  }

  visit(element);
  return result;
}

final _whitespace = RegExp(r'\s');

const _flameBehaviorsImport = 'package:flame_behaviors/flame_behaviors.dart';

final class _ClassScan {
  _ClassScan(this.cls, this.behavior, this.component, this.step, this.root);

  final ClassElement cls;
  final DartObject? behavior;
  final DartObject? component;
  final BuildStep step;
  final String root;
  final diagnostics = <Diagnostic>[];

  String get className => cls.name!;
  late final ConstantReader annotation = ConstantReader(behavior ?? component);
  late final String? explicitId = annotation.peek('id')?.stringValue;
  late final String typeId = explicitId ?? className;
  late final Place place = placeOf(cls.firstFragment, root);
  bool get isBehavior => behavior != null;

  void _error(DiagnosticCode code, String message, {String? field, Place? at}) {
    final where = at ?? place;
    diagnostics.add(
      Diagnostic(
        code: code,
        message: message,
        file: where.file,
        line: where.line,
        typeId: typeId,
        className: className,
        field: field,
      ),
    );
  }

  bool get _hasErrors => diagnostics.any((d) => d.isError);

  Future<TypeRecord> run() async {
    _checkClass();
    final parentType = _parentType();
    final fields = await _fields();
    final linearization = [for (final e in linearize(cls)) classKey(e)];

    final valid = !_hasErrors;
    return TypeRecord(
      key: classKey(cls),
      typeId: typeId,
      className: className,
      file: place.file,
      line: place.line,
      linearization: linearization,
      manifest: valid ? _manifest(parentType, fields) : null,
      registry: valid
          ? RegistryEntry(
              classImport: cls.library.uri.toString(),
              className: className,
              role: isBehavior ? 'behavior' : 'component',
              fields: [for (final f in fields) f.registry],
              parentClass: _registryParent?.name,
              parentImport: _registryParent?.import,
            )
          : null,
    );
  }

  void _checkClass() {
    final annotationName = isBehavior ? '@PyroBehavior' : '@PyroComponent';
    if (behavior != null && component != null) {
      _error(
        DiagnosticCode.bothAnnotations,
        '$className has both @PyroBehavior and @PyroComponent. Keep the one '
        'that matches what it is: a Behavior or a Custom component.',
      );
    }
    if (cls.isPrivate) {
      _error(
        DiagnosticCode.privateClass,
        '$annotationName class $className is private. Make it public so the '
        'Registry can create it.',
      );
    }
    if (cls.isAbstract || cls.isSealed) {
      _error(
        DiagnosticCode.abstractClass,
        '$annotationName class $className is '
        '${cls.isSealed ? 'sealed' : 'abstract'}, so the Registry can\'t '
        'create it. Annotate a concrete subclass instead.',
      );
    }
    if (cls.typeParameters.isNotEmpty) {
      _error(
        DiagnosticCode.genericClass,
        '$annotationName class $className has type parameters, so a Scene '
        "can't say which version to create. Annotate a non-generic subclass.",
      );
    }
    final constructor = cls.unnamedConstructor;
    if (constructor == null ||
        constructor.formalParameters.any((p) => p.isRequired)) {
      _error(
        DiagnosticCode.badConstructor,
        '$annotationName class $className needs an unnamed constructor that '
        'can be called with no arguments (optional parameters are fine), so '
        'the Registry can create it.',
      );
    }
    // With both annotations the role is unclear; bothAnnotations says so.
    final oneRole = behavior == null || component == null;
    if (oneRole && isBehavior && !behaviorChecker.isAssignableFrom(cls)) {
      _error(
        DiagnosticCode.notBehavior,
        '@PyroBehavior class $className doesn\'t extend Behavior from '
        'flame_behaviors. Extend Behavior<YourEntity>, or use @PyroComponent '
        'for a component.',
      );
    }
    if (oneRole &&
        component != null &&
        !positionComponentChecker.isAssignableFrom(cls)) {
      _error(
        DiagnosticCode.notPositionComponent,
        '@PyroComponent class $className doesn\'t extend PositionComponent, '
        'which Custom components must in v1 (Q50).',
      );
    }
    final id = explicitId;
    if (id != null && (id.isEmpty || id.contains(_whitespace))) {
      _error(
        DiagnosticCode.badTypeId,
        'The id "$id" of $className is ${id.isEmpty ? 'empty' : 'not '
                  'allowed: Type IDs contain no whitespace'}. Use a name like '
        '"enemy.patrol", or leave id out to use the class name.',
      );
    }
  }

  /// The class a Behavior's `acceptsParent` tests, and where the Registry
  /// imports it from; set by [_parentType], null for Custom components.
  ({String name, String import})? _registryParent;

  /// The required parent type of a Behavior, or null for any entity.
  String? _parentType() {
    if (!isBehavior) return null;
    _registryParent = (name: 'EntityMixin', import: _flameBehaviorsImport);
    InterfaceType? behaviorType;
    for (final supertype in cls.allSupertypes) {
      if (behaviorChecker.isExactly(supertype.element)) {
        behaviorType = supertype;
        break;
      }
    }
    final argument = behaviorType?.typeArguments.firstOrNull;
    if (argument is! InterfaceType) return null;
    final element = argument.element;
    if (entityMixinChecker.isExactly(element)) return null;
    if (element is! ClassElement) {
      _error(
        DiagnosticCode.parentTypeNotClass,
        "The parent type ${element.name} of Behavior $className isn't a "
        "class, so Pyro can't tell which Nodes accept it. Use the entity "
        'class it attaches to, as in Behavior<Enemy>.',
      );
      return null;
    }
    final import = element.isPrivate
        ? null
        : importFor(element, [cls.library], root);
    if (import == null) {
      _error(
        DiagnosticCode.unreachableParentType,
        'The parent type ${element.name} of Behavior $className is '
        '${element.isPrivate ? 'private' : "not exported by any library "
                  "${packagePath(cls.library.uri, root)} imports"}, so the '
        "Registry can't check that a Node accepts $className. "
        '${element.isPrivate ? 'Make ${element.name} public.' : "Import "
                  "${element.name}'s public library in that file."}',
      );
      return null;
    }
    _registryParent = (name: element.name!, import: import);
    return typeIdOrName(element);
  }

  List<String> _supertypes() {
    final names = <String>[];
    var current = cls.supertype;
    while (current != null && !current.isDartCoreObject) {
      final element = current.element;
      names.add(typeIdOrName(element));
      if (componentChecker.isExactly(element) ||
          behaviorChecker.isExactly(element)) {
        break;
      }
      current = element.supertype;
    }
    return names;
  }

  Map<String, Object?> _manifest(String? parentType, List<_Field> fields) {
    final doc = cls.documentationComment;
    final label = annotation.peek('label')?.stringValue;
    final category = annotation.peek('category')?.stringValue;
    final preview = annotation.peek('preview')?.stringValue;
    return {
      'category': ?category,
      'doc': ?(doc == null ? null : _stripDoc(doc)),
      'fields': [for (final f in fields) f.manifest],
      'id': typeId,
      'label': label ?? className,
      'role': isBehavior ? 'behavior' : 'component',
      'source': place.file,
      'supertypes': _supertypes(),
      if (isBehavior) 'parentType': ?parentType,
      if (!isBehavior) ...{
        'acceptsBehaviors': entityMixinChecker.isAssignableFrom(cls),
        'preview': ?preview,
      },
    };
  }

  /// The Editable fields of the class and its linearization (FR-013), with
  /// a field redeclared lower down keeping its first position.
  Future<List<_Field>> _fields() async {
    final byName = <String, _Field>{};
    for (final owner in linearize(cls)) {
      for (final accessor in [...owner.getters, ...owner.setters]) {
        if (!accessor.isOriginDeclaration) continue;
        if (editableChecker.firstAnnotationOfExact(accessor) == null) continue;
        _error(
          DiagnosticCode.editableOnAccessor,
          '@Editable is on the ${accessor is GetterElement ? 'getter' : 'setter'} '
          '${owner.name}.${accessor.name}. Put it on a plain field; react to '
          'the value in onLoad, after the Runtime has set every Override.',
          field: accessor.name,
          at: placeOf(accessor.firstFragment, root),
        );
      }
      for (final field in owner.fields) {
        if (!field.isOriginDeclaration) continue;
        final editable = editableChecker.firstAnnotationOfExact(field);
        if (editable == null) continue;
        final described = await _field(owner, field, ConstantReader(editable));
        if (described != null) byName[field.name!] = described;
      }
    }
    return byName.values.toList();
  }

  Future<_Field?> _field(
    InterfaceElement owner,
    FieldElement field,
    ConstantReader editable,
  ) async {
    final name = field.name!;
    final at = placeOf(field.firstFragment, root);
    final qualified = '${owner.name}.$name';
    final errorsBefore = diagnostics.where((d) => d.isError).length;
    void error(DiagnosticCode code, String message) =>
        _error(code, message, field: name, at: at);

    if (field.isStatic) {
      error(
        DiagnosticCode.fieldStatic,
        '@Editable field $qualified is static. Make it an instance field: '
        'each Node has its own value.',
      );
    }
    if (field.isPrivate) {
      error(
        DiagnosticCode.fieldNotPublic,
        '@Editable field $qualified is private. Make it public so the '
        'Registry can set it.',
      );
    }
    if (field.isFinal || field.isConst) {
      error(
        DiagnosticCode.fieldFinal,
        '@Editable field $qualified is ${field.isConst ? 'const' : 'final'}, '
        "so the Registry can't set it. Remove the modifier.",
      );
    }
    final concrete = !field.isAbstract && !field.isExternal;
    if (!concrete) {
      error(
        DiagnosticCode.editableNotConcrete,
        '@Editable field $qualified is '
        '${field.isAbstract ? 'abstract' : 'external'}. Put @Editable on a '
        'concrete field with storage.',
      );
    }

    final min = editable.peek('min')?.literalValue as num?;
    final max = editable.peek('max')?.literalValue as num?;
    final tooltip = editable.peek('tooltip')?.stringValue;
    final label = editable.peek('label')?.stringValue;

    final type = field.type;
    final fieldClass = classifyField(type);
    if (fieldClass == null) {
      final hint = unsupportedHint(type);
      error(
        DiagnosticCode.unsupportedFieldType,
        '@Editable field $qualified has type '
        '${type.getDisplayString()}, which isn\'t a Field type'
        '${hint == null ? '' : ' ($hint)'}. Use int, double, bool, String, '
        'an enum, Vector2, Color, ImagePath, Sprite, SpriteAnimation or a '
        'Component type.',
      );
      return null;
    }
    final kind = fieldClass.kind;

    if ((min != null || max != null) && !kind.isNumeric) {
      error(
        DiagnosticCode.rangeOnNonNumeric,
        '@Editable field $qualified is a ${kind.manifestName} but has min or '
        'max, which apply only to int and double fields. Remove them.',
      );
    }
    final rangeValid = min == null || max == null || min <= max;
    if (!rangeValid) {
      error(
        DiagnosticCode.minAboveMax,
        '@Editable field $qualified has min $min above max $max. Swap them.',
      );
    }
    if (kind.mustBeNullable && !fieldClass.nullable) {
      final why = kind == FieldKind.entityRef
          ? 'an entity reference is resolved after the Scene is built'
          : 'a ${fieldClass.element.name} is loaded by the Runtime';
      error(
        DiagnosticCode.fieldMustBeNullable,
        '@Editable field $qualified must be nullable '
        '(${type.getDisplayString()}?): $why, and a Node without an Override '
        'keeps null.',
      );
    }

    final node = await step.resolver.astNodeFor(
      field.firstFragment,
      resolve: true,
    );
    final initializer = node is VariableDeclaration ? node.initializer : null;
    final fieldDefault = readDefault(initializer, fieldClass);
    if (concrete && !fieldDefault.hasInitializer && !fieldClass.nullable) {
      error(
        DiagnosticCode.fieldNoDefault,
        '@Editable field $qualified is not nullable and has no initializer, '
        'so a Node without an Override would have no value. Give it a '
        'default, or make it nullable.',
      );
    }

    final typeName = fieldClass.element.name!;
    final isCore = kind.isCore;
    final isPrivateType = fieldClass.element.isPrivate;
    if (isPrivateType) {
      error(
        DiagnosticCode.privateFieldType,
        '@Editable field $qualified has the private type $typeName, which '
        "the Registry can't name from another library. Make $typeName "
        'public.',
      );
    }
    final typeImport = isCore
        ? null
        : importFor(fieldClass.element, [owner.library, cls.library], root);
    if (!isCore && !isPrivateType && typeImport == null) {
      error(
        DiagnosticCode.unreachableFieldType,
        "The type $typeName of @Editable field $qualified isn't exported by "
        'any library ${packagePath(owner.library.uri, root)} imports, so the '
        "Registry can't name it. Import $typeName's public library in that "
        'file.',
      );
    }

    final number = fieldDefault.number;
    if (number != null &&
        rangeValid &&
        ((min != null && number < min) || (max != null && number > max))) {
      diagnostics.add(
        Diagnostic(
          code: DiagnosticCode.defaultOutOfRange,
          message:
              'The default $number of @Editable field $qualified is outside '
              '[${min ?? '-∞'}, ${max ?? '∞'}]. The inspector still shows it; '
              'widen the range if the default is meant to be reachable.',
          file: at.file,
          line: at.line,
          typeId: typeId,
          className: className,
          field: name,
        ),
      );
    }

    if (diagnostics.where((d) => d.isError).length > errorsBefore) return null;
    return _Field(
      manifest: {
        'declaredIn': ?(owner == cls ? null : owner.name),
        'default': fieldDefault.value,
        'defaultSource': ?fieldDefault.source,
        'label': ?label,
        'max': ?max,
        'min': ?min,
        'name': name,
        'nullable': fieldClass.nullable,
        'refType': ?(kind == FieldKind.entityRef
            ? typeIdOrName(fieldClass.element)
            : null),
        'tooltip': ?tooltip,
        'type': kind.manifestName,
        if (kind == FieldKind.enumeration) 'values': fieldClass.enumValues,
      },
      registry: RegistryFieldEntry(
        name: name,
        kind: kind.registryName,
        nullable: fieldClass.nullable,
        typeName: typeName,
        typeImport: typeImport,
      ),
    );
  }
}

final class _Field {
  const _Field({required this.manifest, required this.registry});

  final Map<String, Object?> manifest;
  final RegistryFieldEntry registry;
}

String _stripDoc(String doc) => doc
    .split('\n')
    .map((line) => line.replaceFirst(RegExp(r'^\s*///\s?'), ''))
    .join('\n')
    .trim();
