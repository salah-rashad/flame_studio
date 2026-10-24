import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flame/components.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'disk_assets.dart';
import 'preview/node_previews.dart';
import 'preview/preview_component.dart';
import 'reconciler.dart';

/// Where the viewport wiring applies the reconciler's ops
/// (`contracts/reconciler.md`): the preview world, or a recorder in tests.
abstract interface class PreviewWorld {
  /// Applies [ops], made against [document], in order.
  void apply(IList<PreviewOp> ops, SceneDocument document);

  /// Removes every component; the next [apply] seeds from scratch.
  void clear();

  /// The project's types changed: placeholders and Missing states
  /// re-evaluate (FR-013).
  void catalogChanged(TypeCatalog catalog);

  /// The files [paths] changed on disk: the components that read them
  /// reload (FR-021).
  void assetsChanged(Set<AssetPath> paths);
}

/// The preview components of one Scene under [root] (the game's world),
/// by Node ID.
final class PreviewTree implements PreviewWorld {
  /// Creates the tree under [root], reading files from [assets] and types
  /// from [catalog].
  PreviewTree(
    this.root, {
    required DiskAssetSource assets,
    required TypeCatalog catalog,
  }) : _context = PreviewContext(assets: assets, catalog: catalog);

  /// The component the scene root stands for.
  final Component root;

  PreviewContext _context;
  final Map<NodeId, PreviewComponent> _components = {};
  final AssetDependents<PreviewComponent> _dependents = AssetDependents();
  SceneDocument? _document;

  /// The document last applied, or null before the first.
  SceneDocument? get document => _document;

  /// Node [id] as last applied, or null (also for a null [id]).
  Node? nodeOf(NodeId? id) => id == null ? null : _document?.node(id);

  /// The component of Node [id], or null.
  PreviewComponent? componentOf(NodeId id) => _components[id];

  /// How many Nodes have components.
  int get length => _components.length;

  @override
  void apply(IList<PreviewOp> ops, SceneDocument document) {
    final old = _document;
    _document = document;
    final reordered = <NodeId>{};
    for (final op in ops) {
      switch (op) {
        case AddNode(:final node, :final parentId):
          _build(node, document).parent = _parentOf(parentId);
          reordered.add(parentId);
        case RemoveNode(:final nodeId):
          final component = _components[nodeId];
          if (component == null) continue;
          _forget(nodeId, old, document);
          component.removeFromParent();
        case PatchNode(:final nodeId):
          final component = _components[nodeId];
          if (component == null) continue;
          component.patch(document.node(nodeId)!, _context);
          _dependents.record(component, component.assetPaths);
        case ReparentNode(:final nodeId, :final parentId):
          final component = _components[nodeId];
          if (component == null) continue;
          component.parent = _parentOf(parentId);
          reordered.add(parentId);
      }
    }
    for (final parentId in reordered) {
      _order(parentId, document);
    }
  }

  /// [node]'s component with every child that has none yet; existing
  /// children moved under it arrive by their own `ReparentNode`.
  PreviewComponent _build(Node node, SceneDocument document) {
    final component = previewOf(node, _context);
    _components[node.id] = component;
    _dependents.record(component, component.assetPaths);
    for (final childId in node.childIds) {
      if (_components.containsKey(childId)) continue;
      _build(document.node(childId)!, document).parent = component;
    }
    _order(node.id, document);
    return component;
  }

  /// Sets the priorities of [parentId]'s children to their `childIds`
  /// order, so later children draw on top — as in the game. Only after
  /// structural ops: drags never touch priorities (frame budget).
  void _order(NodeId parentId, SceneDocument document) {
    final children = document.childrenOf(parentId);
    for (var i = 0; i < children.length; i++) {
      final component = _components[children[i]];
      if (component != null && component.priority != i) {
        component.priority = i;
      }
    }
  }

  Component _parentOf(NodeId id) =>
      id == _document?.rootId ? root : _components[id]!;

  /// Drops the records of [id]'s subtree as it was in [old], keeping the
  /// Nodes still in [next]: one moved out of a removed subtree has its
  /// own `ReparentNode`, and Flame only queues that move, so the removed
  /// component's children can't tell.
  void _forget(NodeId id, SceneDocument? old, SceneDocument next) {
    final component = _components.remove(id);
    if (component != null) _dependents.forget(component);
    for (final child in old?.childrenOf(id) ?? const <NodeId>[]) {
      if (!next.contains(child)) _forget(child, old, next);
    }
  }

  @override
  void clear() {
    for (final component in _components.values) {
      if (component.parent == root) component.removeFromParent();
    }
    _components.clear();
    _dependents.clear();
    _document = null;
  }

  @override
  void catalogChanged(TypeCatalog catalog) {
    _context = PreviewContext(assets: _context.assets, catalog: catalog);
    final document = _document;
    if (document == null) return;
    for (final component in _components.values) {
      if (component is PlaceholderPreview) {
        component.patch(document.node(component.nodeId)!, _context);
        _dependents.record(component, component.assetPaths);
      }
    }
  }

  @override
  void assetsChanged(Set<AssetPath> paths) {
    for (final component in _dependents.of(paths)) {
      component.reloadAssets(_context).ignore();
    }
  }
}
