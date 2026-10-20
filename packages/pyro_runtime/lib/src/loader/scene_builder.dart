import 'dart:ui' show Image;

import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';

import '../animation/animation_codec.dart';
import '../animation/animation_file.dart';
import '../animation/sprite_sheet.dart';
import '../assets/asset_source.dart';
import '../scene/errors.dart';
import '../scene/node.dart';
import '../scene/overrides.dart';
import '../scene/scene.dart';
import '../scene/values.dart';
import 'built_scene.dart';
import 'builtin_nodes.dart';
import 'field_values.dart';
import 'load_exception.dart';
import 'registry.dart';
import 'unknown_type.dart';

/// Builds one Scene into a detached [BuiltScene] in four passes (research
/// R4, FR-003): construct every component, configure it (assets, transforms,
/// Overrides), resolve entity references, attach children.
///
/// Nothing is added to a live tree, so a failed build leaves nothing behind
/// (FR-004, FR-026). Every failure is a [SceneLoadException].
final class SceneBuilder {
  /// Prepares the build of [scene], read from [path] as [text].
  SceneBuilder({
    required this.path,
    required this.text,
    required this.scene,
    required this.registry,
    required this.source,
    required this.onUnknownType,
    required this.root,
  });

  /// The Scene's asset path.
  final AssetPath path;

  /// The Scene file's text, kept for the Hot-swap comparison.
  final String text;

  /// The decoded Scene.
  final Scene scene;

  /// The game's Registry.
  final PyroRegistry registry;

  /// Where assets are read from.
  final AssetSource source;

  /// What to do with unknown Type IDs and Node kinds.
  final UnknownType onUnknownType;

  /// The component standing for the root Node: the `PyroScene` the build is
  /// for, the same instance across Hot-swaps.
  final Component root;

  final List<_Built> _built = [];
  final List<_Built> _rootChildren = [];
  final List<NodeEntry> _entries = [];
  final Map<NodeId, Component> _componentsById = {};
  final Set<NodeId> _skippedIds = {};
  final List<SkippedItem> _skipped = [];
  final List<UnusedOverride> _unused = [];
  final Map<AssetPath, _Requester> _images = {};
  final Map<AssetPath, _Requester> _animationFiles = {};

  /// Runs the four passes.
  Future<BuiltScene> build() async {
    _componentsById[scene.rootId] = root;
    for (final id in scene.root.childIds) {
      _construct(id, null);
    }
    final texts = <AssetPath, String>{path: text};
    await _configure(texts);
    _resolve();
    _attach();
    return BuiltScene(
      children: [for (final built in _rootChildren) built.component],
      entries: _entries,
      componentsById: _componentsById,
      texts: texts,
      skipped: _skipped,
      unusedOverrides: _unused,
    );
  }

  // Pass 1: construct.

  void _construct(NodeId id, _Built? parent) {
    final node = scene.nodes[id]!;
    final Component? component;
    RegistryType? type;
    switch (node) {
      case RootNode():
        // The Scene constructor guarantees the root is nobody's child.
        throw StateError('Root Node $id listed as a child');
      case EntityNode():
        component = entityOf(node);
      case SpriteNode():
        component = spriteOf(node);
        _request(_images, node.image, _Requester(node));
      case RectangleHitboxNode():
        _checkHitboxParent(node, parent);
        component = rectangleHitboxOf(node);
      case CircleHitboxNode():
        _checkHitboxParent(node, parent);
        component = circleHitboxOf(node);
      case CustomNode():
        type = _typeFor(
          node,
          node.type,
          TypeRole.component,
          'Custom component',
          skippedWhat:
              'Custom component "${node.type}" and everything under '
              'it',
        );
        component = type == null ? null : _create(node, type);
      case UnknownNode():
        _unknown(
          node,
          'is of kind "${node.kind}", which this version of pyro_runtime '
          "doesn't know. Was it written by a newer Pyro, or edited by hand?",
          what: 'Node of kind "${node.kind}" and everything under it',
        );
        component = null;
    }
    if (component == null) {
      _skipSubtree(node);
      return;
    }

    final named = node as NamedNode;
    final entry = NodeEntry(
      id: id,
      name: named.name,
      tags: named.tags,
      component: component,
      parent: parent?.entry,
    );
    final built = _Built(node, component, entry);
    _built.add(built);
    _entries.add(entry);
    _componentsById[id] = component;
    (parent?.children ?? _rootChildren).add(built);

    if (type != null) {
      _convertAll(built, type, component, (node as CustomNode).fields);
    }
    final behaviors = switch (node) {
      EntityNode(:final behaviors) || CustomNode(:final behaviors) => behaviors,
      _ => const <BehaviorAttachment>[],
    };
    for (final attachment in behaviors) {
      final behaviorType = _typeFor(
        node,
        attachment.type,
        TypeRole.behavior,
        'Behavior',
      );
      if (behaviorType == null) continue;
      final behavior = _create(node, behaviorType);
      built.behaviors.add((type: behaviorType, component: behavior));
      _convertAll(built, behaviorType, behavior, attachment.fields);
    }
    for (final child in node.childIds) {
      _construct(child, built);
    }
  }

  /// Fails unless [node], a hitbox, is under a positioned Node: Flame needs a
  /// `PositionComponent` ancestor to own a hitbox's collisions.
  void _checkHitboxParent(Node node, _Built? parent) {
    if (parent != null && parent.component is PositionComponent) return;
    _fail(
      'is a hitbox ${parent == null ? 'directly under the root' : 'under a '
                '${_typeName(parent.component)}'}. Flame needs a hitbox inside '
      'an entity, sprite or Custom component, which owns its collisions; '
      'move it there in Pyro.',
      node: node,
    );
  }

  /// The Registry type for [typeId], or null when it is unknown and
  /// skipped.
  RegistryType? _typeFor(
    Node node,
    TypeId typeId,
    TypeRole role,
    String what, {
    String? skippedWhat,
  }) {
    final type = registry[typeId];
    if (type == null) {
      _unknown(
        node,
        'uses the $what "$typeId", which isn\'t in the Registry. Was the class '
        'renamed or deleted? Keep its old name as an explicit id:, or pass '
        'onUnknownType: UnknownType.skip to load without it.',
        typeId: typeId,
        what: skippedWhat ?? '$what "$typeId"',
      );
      return null;
    }
    if (type.role != role) {
      _fail(
        'uses "$typeId" as a $what, but the Registry has it as a '
        '${type.role == TypeRole.behavior ? 'Behavior' : 'Custom component'}.',
        node: node,
        typeId: typeId,
      );
    }
    return type;
  }

  Component _create(Node node, RegistryType type) {
    try {
      return type.create();
    } on Object catch (error, stackTrace) {
      _fail(
        "couldn't be created: the constructor of ${type.id} threw.",
        node: node,
        typeId: type.id,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  /// Converts every Override in [overrides] for [target] (an instance of
  /// [type]), queuing assignments and asset requests.
  void _convertAll(
    _Built built,
    RegistryType type,
    Component target,
    Overrides overrides,
  ) {
    for (final MapEntry(key: name, :value) in overrides.values.entries) {
      final field = type.fields[name];
      if (field == null) {
        _unused.add(
          UnusedOverride(
            nodeId: built.node.id,
            nodeName: built.entry.name,
            typeId: type.id,
            field: name,
          ),
        );
        continue;
      }
      final conversion = convertOverride(field, value);
      switch (conversion) {
        case Mismatch():
          _fail(
            '${conversion.message}.',
            node: built.node,
            typeId: type.id,
            field: name,
          );
        case AssetValue(:final path, :final animation):
          final requester = _Requester(built.node, type.id, name);
          _request(
            animation == null ? _images : _animationFiles,
            path,
            requester,
          );
        case ConvertedValue() || ReferenceValue():
          break;
      }
      built.assignments.add(
        _Assignment(
          type: type,
          field: field,
          target: target,
          value: conversion,
        ),
      );
    }
  }

  void _request(
    Map<AssetPath, _Requester> requests,
    AssetPath path,
    _Requester requester,
  ) => requests.putIfAbsent(path, () => requester);

  void _unknown(
    Node node,
    String message, {
    TypeId? typeId,
    required String what,
  }) {
    if (onUnknownType == UnknownType.error) {
      _fail(message, node: node, typeId: typeId);
    }
    _skipped.add(
      SkippedItem(nodeId: node.id, nodeName: _nameOf(node), what: what),
    );
  }

  /// Records [node] and its descendants as skipped, so references to them
  /// become null.
  void _skipSubtree(Node node) {
    final stack = [node.id];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      _skippedIds.add(id);
      stack.addAll(scene.nodes[id]!.childIds);
    }
  }

  // Pass 2: configure.

  Future<void> _configure(Map<AssetPath, String> texts) async {
    final files = <AssetPath, AnimationFile>{};
    final fileResults = await Future.wait([
      for (final MapEntry(key: path, value: requester)
          in _animationFiles.entries)
        _attempt(() async {
          final text = await source.loadText(path);
          return (text: text, file: AnimationCodec.decode(text, path: path));
        }).then((result) => (path: path, requester: requester, result: result)),
    ]);
    for (final (:path, :requester, :result) in fileResults) {
      final (:text, :file) = _unwrap(
        result,
        requester,
        path,
        (error) => error is SceneFormatException
            ? "isn't a valid animation file: ${error.message}"
            : "couldn't read the animation file.",
      );
      texts[path] = text;
      files[path] = file;
      _request(_images, file.image, requester);
    }

    final images = <AssetPath, Image>{};
    final imageResults = await Future.wait([
      for (final MapEntry(key: path, value: requester) in _images.entries)
        _attempt(
          () => source.loadImage(path),
        ).then((result) => (path: path, requester: requester, result: result)),
    ]);
    for (final (:path, :requester, :result) in imageResults) {
      images[path] = _unwrap(
        result,
        requester,
        path,
        (_) => "couldn't load the image.",
      );
    }

    for (final built in _built) {
      final node = built.node;
      final component = built.component;
      if (node is SpriteNode) {
        applySprite(component as SpriteComponent, node, images[node.image]!);
      }
      if (node is CustomNode && component is PositionComponent) {
        applyTransform(component, node.transform);
      }
      for (final assignment in built.assignments) {
        switch (assignment.value) {
          case ConvertedValue(:final value):
            _assign(built, assignment, value);
          case AssetValue(:final path, animation: null):
            _assign(built, assignment, Sprite(images[path]!));
          case AssetValue(:final path, animation: final String name):
            final animation = _animation(
              built,
              assignment,
              files[path]!,
              name,
              images,
            );
            _assign(built, assignment, animation);
          case ReferenceValue() || Mismatch():
            // References wait for pass 3; mismatches failed in pass 1.
            break;
        }
      }
    }
  }

  SpriteAnimation _animation(
    _Built built,
    _Assignment assignment,
    AnimationFile file,
    String name,
    Map<AssetPath, Image> images,
  ) {
    if (!file.animations.containsKey(name)) {
      final names = file.animations.keys.toList()..sort();
      _fail(
        'the animation "$name" isn\'t in ${file.path}, which holds '
        '${names.map((n) => '"$n"').join(', ')}.',
        node: built.node,
        typeId: assignment.type.id,
        field: assignment.field.name,
        asset: file.path,
      );
    }
    try {
      return toSpriteAnimation(file, name, images[file.image]!);
    } on RangeError catch (error, stackTrace) {
      _fail(
        '${error.message}.',
        node: built.node,
        typeId: assignment.type.id,
        field: assignment.field.name,
        asset: file.path,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  // Pass 3: resolve.

  void _resolve() {
    for (final built in _built) {
      for (final assignment in built.assignments) {
        if (assignment.value case ReferenceValue(:final target)) {
          final component = _componentsById[target];
          if (component == null) {
            if (!_skippedIds.contains(target)) {
              _fail(
                'points at Node "$target", which isn\'t in the Scene.',
                node: built.node,
                typeId: assignment.type.id,
                field: assignment.field.name,
              );
            }
            _skipped.add(
              SkippedItem(
                nodeId: built.node.id,
                nodeName: built.entry.name,
                what:
                    'reference ${assignment.type.id}.${assignment.field.name} '
                    'to the left-out Node "$target" (now null)',
              ),
            );
            _assign(built, assignment, null);
            continue;
          }
          if (!assignment.field.accepts(component)) {
            _fail(
              'points at Node "$target", a ${_typeName(component)}, which the '
              'field doesn\'t accept.',
              node: built.node,
              typeId: assignment.type.id,
              field: assignment.field.name,
            );
          }
          _assign(built, assignment, component);
        }
      }
    }
  }

  void _assign(_Built built, _Assignment assignment, Object? value) {
    final _Assignment(:type, :field, :target) = assignment;
    if (!field.accepts(value)) {
      // The conversion matched the Field type, so the Registry and its
      // classes disagree, such as a hand-written Registry with a wrong type.
      _fail(
        "the converted Override doesn't fit the field, whose Registry type is "
        '${field.type.name}. Regenerate lib/pyro.g.dart.',
        node: built.node,
        typeId: type.id,
        field: field.name,
      );
    }
    try {
      field.set(target, value);
    } on Object catch (error, stackTrace) {
      _fail(
        "couldn't be set: the setter of ${type.id}.${field.name} threw.",
        node: built.node,
        typeId: type.id,
        field: field.name,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  // Pass 4: attach.

  void _attach() {
    for (final built in _built) {
      final component = built.component;
      for (final (:type, component: _) in built.behaviors) {
        if (component is! EntityMixin) {
          _fail(
            'is a ${_typeName(component)}, which can\'t hold Behaviors, so the '
            'Behavior "${type.id}" can\'t be attached. Mix EntityMixin into '
            'it, or remove the Behavior in Pyro.',
            node: built.node,
            typeId: type.id,
          );
        }
        if (!type.acceptsParent!(component)) {
          _fail(
            'is a ${_typeName(component)}, but the Behavior "${type.id}" '
            'needs a different parent type (its Behavior<T>).',
            node: built.node,
            typeId: type.id,
          );
        }
      }
    }
    for (final built in _built) {
      final component = built.component;
      for (final (type: _, component: behavior) in built.behaviors) {
        _add(component, behavior);
      }
      for (final child in built.children) {
        _add(component, child.component);
      }
    }
  }

  /// Adds [child] to [parent], which isn't in a game yet, so Flame only
  /// queues it: no `onLoad` runs until the Scene is added to a game.
  static void _add(Component parent, Component child) {
    // ignore: discarded_futures, an unmounted parent returns no future (research R4).
    parent.add(child);
  }

  // Errors.

  Never _fail(
    String message, {
    Node? node,
    TypeId? typeId,
    String? field,
    AssetPath? asset,
    Object? cause,
    StackTrace? causeStackTrace,
  }) => throw SceneLoadException(
    path,
    message,
    nodeId: node?.id,
    nodeName: node == null ? null : _nameOf(node),
    typeId: typeId,
    field: field,
    asset: asset,
    cause: cause,
    causeStackTrace: causeStackTrace,
  );

  T _unwrap<T>(
    _Result<T> result,
    _Requester requester,
    AssetPath asset,
    String Function(Object error) describe,
  ) => switch (result) {
    _Value(:final value) => value,
    _Error(:final error, :final stackTrace) => _fail(
      describe(error),
      node: requester.node,
      typeId: requester.typeId,
      field: requester.field,
      asset: asset,
      cause: error,
      causeStackTrace: stackTrace,
    ),
  };

  static Future<_Result<T>> _attempt<T>(Future<T> Function() load) async {
    try {
      return _Value(await load());
    } on Object catch (error, stackTrace) {
      return _Error(error, stackTrace);
    }
  }

  static String? _nameOf(Node node) => node is NamedNode ? node.name : null;

  // A debug message naming the component's class; native builds keep type
  // names.
  // ignore: avoid_type_to_string
  static String _typeName(Component component) => '${component.runtimeType}';
}

/// One Node being built.
final class _Built {
  _Built(this.node, this.component, this.entry);

  final Node node;
  final Component component;
  final NodeEntry entry;
  final List<_Built> children = [];
  final List<({RegistryType type, Component component})> behaviors = [];
  final List<_Assignment> assignments = [];
}

/// One Override to assign.
final class _Assignment {
  const _Assignment({
    required this.type,
    required this.field,
    required this.target,
    required this.value,
  });

  final RegistryType type;
  final RegistryField field;
  final Object target;
  final FieldConversion value;
}

/// The first Node (and field) that asked for an asset, for messages.
final class _Requester {
  const _Requester(this.node, [this.typeId, this.field]);

  final Node node;
  final TypeId? typeId;
  final String? field;
}

sealed class _Result<T> {
  const _Result();
}

final class _Value<T> extends _Result<T> {
  const _Value(this.value);

  final T value;
}

final class _Error<T> extends _Result<T> {
  const _Error(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
