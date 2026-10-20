import 'package:flame/components.dart';

import '../scene/values.dart';

/// One complete build of a Scene (data-model.md): what a `PyroScene` holds
/// until a Hot-swap replaces it whole.
final class BuiltScene {
  /// Creates the build.
  BuiltScene({
    required List<Component> children,
    required List<NodeEntry> entries,
    required Map<NodeId, Component> componentsById,
    required Map<AssetPath, String> texts,
    required List<SkippedItem> skipped,
    required List<UnusedOverride> unusedOverrides,
  }) : children = List.unmodifiable(children),
       entries = List.unmodifiable(entries),
       componentsById = Map.unmodifiable(componentsById),
       texts = Map.unmodifiable(texts),
       skipped = List.unmodifiable(skipped),
       unusedOverrides = List.unmodifiable(unusedOverrides);

  /// The root's child components, in `childIds` order, their subtrees
  /// already added.
  final List<Component> children;

  /// Every built Node except the root, in tree order (depth first,
  /// `childIds` order): the lookup index.
  final List<NodeEntry> entries;

  /// Each built Node's component by ID; the root maps to its `PyroScene`.
  final Map<NodeId, Component> componentsById;

  /// The Scene file and each animation file read, by path: what a Hot-swap
  /// compares (research R11).
  final Map<AssetPath, String> texts;

  /// What `UnknownType.skip` left out.
  final List<SkippedItem> skipped;

  /// Overrides for fields the Registry doesn't list (FR-012).
  final List<UnusedOverride> unusedOverrides;

  /// The entries matching every filter given, in tree order (research R10).
  ///
  /// [nameOrPath] is a Node name, or names joined by `/` (a Node and its
  /// nearest ancestors); a leading `/` anchors it at the root. Unnamed
  /// Nodes never match a name.
  Iterable<NodeEntry> match({String? nameOrPath, String? tag}) {
    final segments = nameOrPath == null ? null : _segments(nameOrPath);
    return entries.where(
      (entry) =>
          (tag == null || entry.tags.contains(tag)) &&
          (segments == null || entry._matches(segments)),
    );
  }

  static ({List<String> names, bool anchored}) _segments(String path) {
    final anchored = path.startsWith('/');
    return (
      names: (anchored ? path.substring(1) : path).split('/'),
      anchored: anchored,
    );
  }
}

/// One built Node in the lookup index.
final class NodeEntry {
  /// Creates the entry.
  NodeEntry({
    required this.id,
    required this.name,
    required List<String> tags,
    required this.component,
    required this.parent,
  }) : tags = List.unmodifiable(tags);

  /// The Node's ID.
  final NodeId id;

  /// The Node name, or null.
  final String? name;

  /// The Node's tags.
  final List<String> tags;

  /// The Node's component: what lookups return.
  final Component component;

  /// The parent's entry, or null for a child of the root.
  final NodeEntry? parent;

  /// The Node's path for messages: names from the root down, joined by `/`,
  /// with an unnamed Node shown as `#<id>`.
  String get path {
    final names = <String>[];
    for (NodeEntry? entry = this; entry != null; entry = entry.parent) {
      names.add(entry.name ?? '#${entry.id}');
    }
    return names.reversed.join('/');
  }

  /// The Node as messages name it: `"goblin_1" (3f1c)`, or `(3f1c)`.
  String get label => name == null ? '($id)' : '"$name" ($id)';

  bool _matches(({List<String> names, bool anchored}) segments) {
    NodeEntry? entry = this;
    for (final name in segments.names.reversed) {
      if (entry == null || entry.name == null || entry.name != name) {
        return false;
      }
      entry = entry.parent;
    }
    return !segments.anchored || entry == null;
  }
}

/// A Node, Behavior or reference left out under `UnknownType.skip`.
final class SkippedItem {
  /// Describes what was left out ([what]) at Node [nodeId].
  const SkippedItem({required this.nodeId, this.nodeName, required this.what});

  /// The Node involved.
  final NodeId nodeId;

  /// The Node's name, if any.
  final String? nodeName;

  /// What was left out, such as `Behavior "Patrol"`.
  final String what;
}

/// An Override for a field the Registry doesn't list.
final class UnusedOverride {
  /// Describes the Override of [field] on [typeId] at Node [nodeId].
  const UnusedOverride({
    required this.nodeId,
    this.nodeName,
    required this.typeId,
    required this.field,
  });

  /// The Node holding the Override.
  final NodeId nodeId;

  /// The Node's name, if any.
  final String? nodeName;

  /// The Behavior's or Custom component's Type ID.
  final TypeId typeId;

  /// The field no code knows.
  final String field;
}
