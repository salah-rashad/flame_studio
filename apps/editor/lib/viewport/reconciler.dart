/// The reconciler (spec 006, FR-017, `contracts/reconciler.md`): document
/// diff → preview-component operations, as a pure function. No clock, no
/// I/O, no Flame — old and new documents in, ops out (constitution V).
library;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

/// One change to apply to the preview world.
sealed class PreviewOp {
  const PreviewOp();
}

/// [node] is new: build its component — with every new Node of its subtree,
/// which travel with it — under [parentId]'s at [index].
final class AddNode extends PreviewOp {
  /// Creates the op.
  const AddNode(this.node, {required this.parentId, required this.index});

  /// The added Node, as it is in the new document.
  final Node node;

  /// Its parent.
  final NodeId parentId;

  /// Its index among the parent's children in the new document.
  final int index;

  @override
  bool operator ==(Object other) =>
      other is AddNode &&
      identical(other.node, node) &&
      other.parentId == parentId &&
      other.index == index;

  @override
  int get hashCode => Object.hash(AddNode, node.id, parentId, index);

  @override
  String toString() => 'AddNode(${node.id}, $parentId, $index)';
}

/// [nodeId] is gone: remove its component with its whole subtree.
final class RemoveNode extends PreviewOp {
  /// Creates the op.
  const RemoveNode(this.nodeId);

  /// The removed Node.
  final NodeId nodeId;

  @override
  bool operator ==(Object other) =>
      other is RemoveNode && other.nodeId == nodeId;

  @override
  int get hashCode => Object.hash(RemoveNode, nodeId);

  @override
  String toString() => 'RemoveNode($nodeId)';
}

/// [nodeId] changed: update its component in place from the new document.
final class PatchNode extends PreviewOp {
  /// Creates the op.
  const PatchNode(this.nodeId);

  /// The changed Node.
  final NodeId nodeId;

  @override
  bool operator ==(Object other) =>
      other is PatchNode && other.nodeId == nodeId;

  @override
  int get hashCode => Object.hash(PatchNode, nodeId);

  @override
  String toString() => 'PatchNode($nodeId)';
}

/// [nodeId] moved: put its existing component under [parentId]'s at
/// [index], keeping its state.
final class ReparentNode extends PreviewOp {
  /// Creates the op.
  const ReparentNode(
    this.nodeId, {
    required this.parentId,
    required this.index,
  });

  /// The moved Node.
  final NodeId nodeId;

  /// Its parent in the new document.
  final NodeId parentId;

  /// Its index among the parent's children in the new document.
  final int index;

  @override
  bool operator ==(Object other) =>
      other is ReparentNode &&
      other.nodeId == nodeId &&
      other.parentId == parentId &&
      other.index == index;

  @override
  int get hashCode => Object.hash(ReparentNode, nodeId, parentId, index);

  @override
  String toString() => 'ReparentNode($nodeId, $parentId, $index)';
}

/// The ops that turn the preview world of [old] into the world of [next];
/// a null [old] seeds the world from scratch.
///
/// Ops come in apply order: adds, reparents and patches in a pre-order
/// walk of [next] (a parent's component exists before anything moves
/// under it), then removals — so a Node moved out of a removed subtree
/// is safe before the subtree goes. Nodes inside an added or removed
/// subtree get no ops of their own (they travel with it), except
/// existing Nodes moved into a new subtree, which are reparented after
/// its add.
IList<PreviewOp> reconcile(SceneDocument? old, SceneDocument next) {
  if (identical(old, next)) return const IList.empty();
  final ops = <PreviewOp>[];
  final added = <NodeId>{};

  void visitChildren(NodeId parentId) {
    final parent = next.node(parentId)!;
    final oldParent = old?.node(parentId);
    final children = parent.childIds;
    // An identical child list means every child kept its parent and slot.
    final moved = oldParent != null && identical(oldParent.childIds, children)
        ? const <NodeId>{}
        : _moved(old, parentId, children);
    for (var i = 0; i < children.length; i++) {
      final id = children[i];
      final node = next.node(id)!;
      final before = old?.node(id);
      if (before == null) {
        added.add(id);
        if (!added.contains(parentId)) {
          ops.add(AddNode(node, parentId: parentId, index: i));
        }
      } else {
        if (moved.contains(id)) {
          ops.add(ReparentNode(id, parentId: parentId, index: i));
        }
        if (!identical(before, node) && !_sameExceptChildren(before, node)) {
          ops.add(PatchNode(id));
        }
      }
      visitChildren(id);
    }
  }

  final root = next.node(next.rootId)!;
  final oldRoot = old?.node(next.rootId);
  if (oldRoot != null &&
      !identical(oldRoot, root) &&
      !_sameExceptChildren(oldRoot, root)) {
    ops.add(PatchNode(next.rootId));
  }
  visitChildren(next.rootId);

  if (old != null) {
    void visitRemoved(NodeId id) {
      for (final child in old.childrenOf(id)) {
        if (!next.contains(child)) {
          ops.add(RemoveNode(child));
        } else {
          visitRemoved(child);
        }
      }
    }

    visitRemoved(old.rootId);
  }
  return IList(ops);
}

/// The [children] of [parentId] in the new document that need a
/// `ReparentNode`: those that came from another parent, plus the fewest
/// that must move to put the rest in their new order (the ones off the
/// longest run already in order).
Set<NodeId> _moved(SceneDocument? old, NodeId parentId, List<NodeId> children) {
  if (old == null) return const {};
  final moved = <NodeId>{};
  final stayed = <NodeId>[];
  final oldIndex = <int>[];
  final oldChildren = old.childrenOf(parentId);
  final positions = {
    for (var i = 0; i < oldChildren.length; i++) oldChildren[i]: i,
  };
  for (final id in children) {
    if (!old.contains(id)) continue;
    final at = old.parentOf(id) == parentId ? positions[id] : null;
    if (at == null) {
      moved.add(id);
    } else {
      stayed.add(id);
      oldIndex.add(at);
    }
  }
  final keep = _longestIncreasing(oldIndex);
  for (var i = 0; i < stayed.length; i++) {
    if (!keep.contains(i)) moved.add(stayed[i]);
  }
  return moved;
}

/// The indexes into [values] of one longest strictly increasing
/// subsequence (patience sorting, O(n log n)).
Set<int> _longestIncreasing(List<int> values) {
  if (values.isEmpty) return const {};
  final tails = <int>[]; // index into values of each pile's top
  final previous = List<int>.filled(values.length, -1);
  for (var i = 0; i < values.length; i++) {
    var lo = 0;
    var hi = tails.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (values[tails[mid]] < values[i]) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo > 0) previous[i] = tails[lo - 1];
    if (lo == tails.length) {
      tails.add(i);
    } else {
      tails[lo] = i;
    }
  }
  final result = <int>{};
  for (var i = tails.last; i >= 0; i = previous[i]) {
    result.add(i);
  }
  return result;
}

/// Whether [a] and [b] differ at most in their children — a parent whose
/// only change is a child list has nothing to patch. Node constructors
/// copy their lists and maps, so those compare by content.
bool _sameExceptChildren(Node a, Node b) {
  if (!_sameMap(a.extra, b.extra)) return false;
  if (a is NamedNode && b is NamedNode) {
    if (a.name != b.name || !_sameList(a.tags, b.tags)) return false;
  }
  return switch (a) {
    RootNode() => b is RootNode,
    EntityNode() =>
      b is EntityNode &&
          a.transform == b.transform &&
          _sameList(a.behaviors, b.behaviors),
    SpriteNode() =>
      b is SpriteNode &&
          a.transform == b.transform &&
          a.image == b.image &&
          a.region == b.region &&
          _sameMap(a.propsExtra, b.propsExtra),
    RectangleHitboxNode() =>
      b is RectangleHitboxNode &&
          a.position == b.position &&
          a.size == b.size &&
          a.angle == b.angle &&
          a.anchor == b.anchor &&
          a.collisionType == b.collisionType &&
          a.isSolid == b.isSolid &&
          _sameMap(a.propsExtra, b.propsExtra),
    CircleHitboxNode() =>
      b is CircleHitboxNode &&
          a.position == b.position &&
          a.radius == b.radius &&
          a.anchor == b.anchor &&
          a.collisionType == b.collisionType &&
          a.isSolid == b.isSolid &&
          _sameMap(a.propsExtra, b.propsExtra),
    CustomNode() =>
      b is CustomNode &&
          a.type == b.type &&
          a.transform == b.transform &&
          (identical(a.fields, b.fields) ||
              _sameMap(a.fields.values, b.fields.values)) &&
          _sameList(a.behaviors, b.behaviors),
    UnknownNode() => b is UnknownNode && a.kind == b.kind,
  };
}

bool _sameList(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i]) && a[i] != b[i]) return false;
  }
  return true;
}

bool _sameMap(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    final other = b[entry.key];
    if (!identical(entry.value, other) && entry.value != other) return false;
  }
  return true;
}
