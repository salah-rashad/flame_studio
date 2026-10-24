import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../../document/document.dart';
import 'manifest_parse.dart';

/// Where a new Node would be added: under the scene root, or under a Node
/// of a type.
sealed class AddParent {
  const AddParent();

  /// The scene root.
  const factory AddParent.root() = _RootParent;

  /// A Node of type [id].
  const factory AddParent.type(TypeId id) = _TypeParent;
}

final class _RootParent extends AddParent {
  const _RootParent();
}

final class _TypeParent extends AddParent {
  const _TypeParent(this.id);

  final TypeId id;
}

/// One entry of an Add list: the type, and why it can't be added when it
/// can't — a menu shows the reason (disabled, with a tooltip) instead of
/// hiding the rule a user can't guess (FR-025, *Q115*).
final class OfferedChild {
  /// Creates the entry; [refusal] is null when the type is offered.
  const OfferedChild({required this.type, this.refusal});

  /// The type on offer.
  final TypeDescriptor type;

  /// Why it can't be added under the parent, or null when it can.
  final String? refusal;

  /// Whether the entry is offered.
  bool get offered => refusal == null;
}

/// The answer of [canReparent].
sealed class ReparentCheck {
  const ReparentCheck();

  /// Whether the move may go ahead.
  bool get allowed => this is ReparentAllowed;
}

/// The move is allowed.
final class ReparentAllowed extends ReparentCheck {
  const ReparentAllowed();
}

/// The move is refused; [reason] says why.
final class ReparentRefused extends ReparentCheck {
  const ReparentRefused(this.reason);

  /// The refusing rule, as the drag's reject state shows it.
  final String reason;
}

/// The hitbox-under-root rule's message (*Q115*): the Runtime refuses the
/// Scene at load, so the editor refuses it first.
const String hitboxUnderRootReason =
    'A hitbox needs a Node to belong to — the game refuses one under the '
    'scene root.';

/// Every component type under [parent], each with its refusal when the
/// parenting table (`contracts/type-catalog.md`) doesn't offer it — the one
/// table the Add menus, the drag rules and the tests share.
///
/// Behaviors never appear: they are not Nodes and attach through the
/// inspector only.
IList<OfferedChild> childOffers(TypeCatalog catalog, AddParent parent) {
  final kind = switch (parent) {
    _RootParent() => const _RootKind(),
    _TypeParent(:final id) => _kindOf(catalog, id),
  };
  return IList([
    for (final type in catalog.sorted)
      if (type.role == TypeRole.component)
        OfferedChild(type: type, refusal: _tableRefusal(type, kind)),
  ]);
}

/// Whether [nodeId] may move under [newParentId] in [doc] (FR-027): the
/// hard rules first — the root never moves, and no Node into its own
/// subtree — then the same table [childOffers] reads.
///
/// A Missing type or unknown kind keeps editing (the catalog is derived
/// state, never a gate), so only the hard rules answer for it.
ReparentCheck canReparent(
  SceneDocument doc,
  TypeCatalog catalog,
  NodeId nodeId,
  NodeId newParentId,
) {
  final node = doc.node(nodeId);
  if (node == null) {
    return const ReparentRefused('There is no such Node.');
  }
  if (node is RootNode) {
    return const ReparentRefused("The scene root can't be moved.");
  }
  final newParent = doc.node(newParentId);
  if (newParent == null) {
    return const ReparentRefused('There is no Node to move under.');
  }
  if (newParentId == nodeId || doc.isAncestor(nodeId, newParentId)) {
    return const ReparentRefused("A Node can't be moved inside itself.");
  }
  final child = switch (node) {
    EntityNode() => catalog[const TypeId('entity')],
    SpriteNode() => catalog[const TypeId('sprite')],
    RectangleHitboxNode() => catalog[const TypeId('rectangleHitbox')],
    CircleHitboxNode() => catalog[const TypeId('circleHitbox')],
    CustomNode(:final type) => catalog[type],
    UnknownNode() || RootNode() => null,
  };
  if (child == null) return const ReparentAllowed();
  final kind = switch (newParent) {
    RootNode() => const _RootKind(),
    EntityNode() => const _EntityKind(),
    SpriteNode() => const _SpriteKind(),
    RectangleHitboxNode() || CircleHitboxNode() => const _HitboxKind(),
    CustomNode(:final type) => _kindOf(catalog, type),
    UnknownNode() => const _EntityKind(),
  };
  final refusal = _tableRefusal(child, kind);
  return refusal == null ? const ReparentAllowed() : ReparentRefused(refusal);
}

/// What a parent accepts, collapsing the table's rows: entity-like parents
/// (an Entity, or a Custom component that accepts Behaviors, *Q57*) behave
/// as the table's entity row; hitboxes and other Custom components are
/// leaves.
sealed class _ParentKind {
  const _ParentKind();
}

/// The scene root's row: entities and custom components.
final class _RootKind extends _ParentKind {
  const _RootKind();
}

/// The entity's row: sprites, both hitbox kinds, custom components and
/// entities.
final class _EntityKind extends _ParentKind {
  const _EntityKind();
}

/// The sprite's row: hitboxes and custom components.
final class _SpriteKind extends _ParentKind {
  const _SpriteKind();
}

/// The hitboxes' row: nothing (leaf kinds).
final class _HitboxKind extends _ParentKind {
  const _HitboxKind();
}

/// A Custom component that holds no Behaviors: nothing (a leaf).
final class _LeafKind extends _ParentKind {
  const _LeafKind(this.label);

  /// The type's display name, for the refusal's message.
  final String label;
}

/// The row a type of [id] sits in. A type missing from the catalog reads as
/// entity-like — the conservative default that keeps editing — and a
/// Behavior is never a parent of Nodes.
_ParentKind _kindOf(TypeCatalog catalog, TypeId id) {
  switch (id.value) {
    case 'entity':
      return const _EntityKind();
    case 'sprite':
      return const _SpriteKind();
    case 'rectangleHitbox':
    case 'circleHitbox':
      return const _HitboxKind();
  }
  final type = catalog[id];
  if (type == null) return const _EntityKind();
  if (type.role == TypeRole.behavior) {
    return _LeafKind(type.label);
  }
  return type.acceptsBehaviors ? const _EntityKind() : _LeafKind(type.label);
}

/// The table itself: null when [child] is offered under [kind], the
/// refusal's reason otherwise.
String? _tableRefusal(TypeDescriptor child, _ParentKind kind) {
  return switch (kind) {
    _RootKind() => switch (child.id.value) {
      'entity' => null,
      'sprite' => 'A Sprite needs a positioned parent, such as an Entity.',
      'rectangleHitbox' || 'circleHitbox' => hitboxUnderRootReason,
      // Custom components: offered unless the Manifest restricts them.
      _ => null,
    },
    _EntityKind() => null,
    _SpriteKind() => switch (child.id.value) {
      'entity' =>
        'An Entity belongs under the scene root or another Entity-like Node.',
      'sprite' => 'A Sprite needs an Entity-like parent.',
      // Hitboxes and custom components.
      _ => null,
    },
    _HitboxKind() => 'A hitbox is a leaf: nothing can be added under it.',
    _LeafKind(:final label) => '"$label" accepts no children.',
  };
}
