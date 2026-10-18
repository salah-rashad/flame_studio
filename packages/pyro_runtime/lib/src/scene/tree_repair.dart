import 'values.dart';

/// Repairs the `childIds` lists of a Scene so they form one tree under
/// [rootId] (FR-021), deterministically (FR-022), changing only the lists
/// (FR-023). [childIds] holds every Node's list, in file order.
///
/// The passes, from research R8:
///
/// 1. **Clean each list**: drop IDs with no Node, the Node's own ID, the
///    root's ID and repeats.
/// 2. **Walk from the root**, depth-first, children in list order. A child
///    already claimed stays with the parent that claimed it first and is
///    removed from the later list. A cycle reachable from the root ends
///    this way too.
/// 3. **Attach orphans**: unvisited Nodes no unvisited Node lists go under
///    the root in ascending ID order, each walked like the root.
/// 4. **Break cycles**: every remaining Node is listed by another one. From
///    the smallest remaining ID, follow listing parents (smallest first)
///    until one repeats; the smallest ID on that cycle goes under the root,
///    and the walk from it removes its back-reference.
///
/// The walk uses an explicit stack, so deep trees can't overflow it.
({Map<NodeId, List<NodeId>> childIds, RepairReport report}) repairTree(
  NodeId rootId,
  Map<NodeId, List<NodeId>> childIds,
) {
  final issues = <TreeIssue>[];

  // 1. Clean each list.
  final lists = <NodeId, List<NodeId>>{};
  for (final MapEntry(key: parent, value: children) in childIds.entries) {
    final kept = <NodeId>[];
    final seen = <NodeId>{};
    for (final child in children) {
      if (!childIds.containsKey(child)) {
        issues.add(MissingChild(parentId: parent, childId: child));
      } else if (child == parent) {
        issues.add(SelfChild(nodeId: parent));
      } else if (child == rootId) {
        issues.add(RootAsChild(parentId: parent, rootId: rootId));
      } else if (!seen.add(child)) {
        issues.add(DuplicateChild(parentId: parent, childId: child));
      } else {
        kept.add(child);
      }
    }
    lists[parent] = kept;
  }

  final visited = <NodeId>{rootId};
  final parentOf = <NodeId, NodeId>{};

  void walk(NodeId start, void Function(NodeId child, NodeId from) removed) {
    final stack = [start];
    while (stack.isNotEmpty) {
      final parent = stack.removeLast();
      final kept = <NodeId>[];
      for (final child in lists[parent]!) {
        if (visited.add(child)) {
          parentOf[child] = parent;
          kept.add(child);
        } else {
          removed(child, parent);
        }
      }
      lists[parent] = kept;
      for (var i = kept.length - 1; i >= 0; i--) {
        stack.add(kept[i]);
      }
    }
  }

  void multipleParents(NodeId child, NodeId from) => issues.add(
    MultipleParents(
      nodeId: child,
      keptParentId: parentOf[child]!,
      removedFromParentId: from,
    ),
  );

  void attachToRoot(NodeId id) {
    lists[rootId]!.add(id);
    visited.add(id);
    parentOf[id] = rootId;
  }

  List<NodeId> unvisited() =>
      childIds.keys.where((id) => !visited.contains(id)).toList()..sort();

  // 2. Walk from the root.
  walk(rootId, multipleParents);

  // 3. Attach orphans.
  final orphans = unvisited();
  final listed = {for (final id in orphans) ...lists[id]!};
  for (final head in orphans.where((id) => !listed.contains(id))) {
    attachToRoot(head);
    issues.add(OrphanAttached(nodeId: head));
    walk(head, multipleParents);
  }

  // 4. Break cycles.
  for (
    var remaining = unvisited();
    remaining.isNotEmpty;
    remaining = unvisited()
  ) {
    final listers = <NodeId, List<NodeId>>{};
    for (final parent in remaining) {
      for (final child in lists[parent]!) {
        (listers[child] ??= []).add(parent);
      }
    }
    final start = _smallestOnCycle(remaining.first, listers);
    final index = issues.length;
    NodeId? backReference;
    attachToRoot(start);
    walk(start, (child, from) {
      if (child == start && backReference == null) {
        backReference = from;
      } else {
        multipleParents(child, from);
      }
    });
    issues.insert(
      index,
      CycleBroken(
        nodeIds: [
          for (final id in remaining)
            if (visited.contains(id)) id,
        ],
        attachedNodeId: start,
        removedFromParentId: backReference!,
      ),
    );
  }

  return (childIds: lists, report: RepairReport(issues));
}

/// Follows the smallest listing parent up from [from] until a Node repeats,
/// and returns the smallest ID on the cycle found.
NodeId _smallestOnCycle(NodeId from, Map<NodeId, List<NodeId>> listers) {
  final path = <NodeId>[];
  final seenAt = <NodeId, int>{};
  var current = from;
  while (!seenAt.containsKey(current)) {
    seenAt[current] = path.length;
    path.add(current);
    current = (listers[current]!..sort()).first;
  }
  final cycle = path.sublist(seenAt[current]!)..sort();
  return cycle.first;
}

/// The inconsistencies in a Scene's tree that reading found and fixed, in
/// the order they were found (FR-024). Empty for a healthy file.
final class RepairReport {
  /// Creates a report of [issues].
  RepairReport(List<TreeIssue> issues) : issues = List.unmodifiable(issues);

  /// A report with no issues.
  static final RepairReport empty = RepairReport(const []);

  /// The issues, in discovery order.
  final List<TreeIssue> issues;

  /// Whether the tree needed no repair.
  bool get isEmpty => issues.isEmpty;

  /// One line per issue, naming the Nodes involved.
  String describe() => issues.map((issue) => issue.description).join('\n');

  @override
  String toString() => 'RepairReport(${issues.length} issues)';
}

/// One inconsistency in a Scene's `childIds` lists and how it was repaired.
/// Repairs only ever change `childIds` lists (FR-023).
sealed class TreeIssue {
  const TreeIssue();

  /// A one-line description naming the Nodes involved.
  String get description;

  @override
  String toString() => description;
}

/// A parent listed a child ID with no matching Node; the ID was dropped.
final class MissingChild extends TreeIssue {
  /// Creates the issue.
  const MissingChild({required this.parentId, required this.childId});

  /// The Node whose list held the ID.
  final NodeId parentId;

  /// The ID with no Node.
  final NodeId childId;

  @override
  String get description =>
      'Node "$parentId" listed child "$childId", which doesn\'t exist; '
      'removed it from the list.';
}

/// A Node listed itself as a child; the entry was dropped.
final class SelfChild extends TreeIssue {
  /// Creates the issue.
  const SelfChild({required this.nodeId});

  /// The Node.
  final NodeId nodeId;

  @override
  String get description =>
      'Node "$nodeId" listed itself as a child; removed the entry.';
}

/// A Node listed the root as a child; the entry was dropped.
final class RootAsChild extends TreeIssue {
  /// Creates the issue.
  const RootAsChild({required this.parentId, required this.rootId});

  /// The Node whose list held the root.
  final NodeId parentId;

  /// The root's ID.
  final NodeId rootId;

  @override
  String get description =>
      'Node "$parentId" listed the root "$rootId" as a child; removed the '
      'entry.';
}

/// A parent listed the same child more than once; later entries were
/// dropped.
final class DuplicateChild extends TreeIssue {
  /// Creates the issue.
  const DuplicateChild({required this.parentId, required this.childId});

  /// The Node whose list held the duplicate.
  final NodeId parentId;

  /// The repeated child.
  final NodeId childId;

  @override
  String get description =>
      'Node "$parentId" listed child "$childId" more than once; kept the '
      'first entry.';
}

/// A Node was listed under two parents; it stays under the first parent a
/// depth-first walk from the root reaches.
final class MultipleParents extends TreeIssue {
  /// Creates the issue.
  const MultipleParents({
    required this.nodeId,
    required this.keptParentId,
    required this.removedFromParentId,
  });

  /// The Node.
  final NodeId nodeId;

  /// The parent it stays under.
  final NodeId keptParentId;

  /// The parent it was removed from.
  final NodeId removedFromParentId;

  @override
  String get description =>
      'Node "$nodeId" was listed under both "$keptParentId" and '
      '"$removedFromParentId"; kept it under "$keptParentId".';
}

/// A Node no parent listed; it was appended under the root.
final class OrphanAttached extends TreeIssue {
  /// Creates the issue.
  const OrphanAttached({required this.nodeId});

  /// The Node.
  final NodeId nodeId;

  @override
  String get description =>
      'Node "$nodeId" had no parent; moved it under the root.';
}

/// A group of Nodes listed each other in a cycle unreachable from the root;
/// the smallest ID was appended under the root and its back-reference
/// removed.
final class CycleBroken extends TreeIssue {
  /// Creates the issue.
  CycleBroken({
    required List<NodeId> nodeIds,
    required this.attachedNodeId,
    required this.removedFromParentId,
  }) : nodeIds = List.unmodifiable(nodeIds);

  /// The Nodes involved, sorted.
  final List<NodeId> nodeIds;

  /// The Node moved under the root.
  final NodeId attachedNodeId;

  /// The Node whose list held the back-reference.
  final NodeId removedFromParentId;

  @override
  String get description =>
      'Nodes ${nodeIds.map((id) => '"$id"').join(', ')} formed a cycle with '
      'no path from the root; moved "$attachedNodeId" under the root and '
      'removed it from "$removedFromParentId".';
}
