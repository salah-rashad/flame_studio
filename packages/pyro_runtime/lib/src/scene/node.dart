import 'overrides.dart';
import 'values.dart';

/// One element of a Scene's tree.
///
/// Nodes are immutable and compare by identity: Pyro's reconciler and the
/// Document's dirty flag rely on `identical`. Collections are unmodifiable.
/// The parent of a Node isn't stored; `Scene.parentOf` derives it from the
/// [childIds] lists (FR-008).
sealed class Node {
  Node({
    required this.id,
    List<NodeId> childIds = const [],
    Map<String, Object?> extra = const {},
  }) : childIds = List.unmodifiable(childIds),
       extra = Map.unmodifiable(extra);

  /// The Node's ID, unique in its Scene.
  final NodeId id;

  /// The IDs of the Node's children, in order.
  final List<NodeId> childIds;

  /// Keys of the Node this version doesn't know, written back unchanged
  /// (FR-017).
  final Map<String, Object?> extra;
}

/// The root of a Scene's tree. Every Scene has exactly one.
final class RootNode extends Node {
  /// Creates the root.
  RootNode({required super.id, super.childIds, super.extra});

  /// A copy with the given fields replaced.
  RootNode copyWith({List<NodeId>? childIds, Map<String, Object?>? extra}) =>
      RootNode(
        id: id,
        childIds: childIds ?? this.childIds,
        extra: extra ?? this.extra,
      );
}

/// A Node that isn't the root: it can have a Node name and tags.
sealed class NamedNode extends Node {
  NamedNode({
    required super.id,
    super.childIds,
    super.extra,
    this.name,
    List<String> tags = const [],
  }) : tags = List.unmodifiable(tags);

  /// The Node name, used to look the Node up from game code; not unique.
  final String? name;

  /// The Node's tags, in order.
  final List<String> tags;
}

/// A Node that can hold Behaviors.
final class EntityNode extends NamedNode {
  /// Creates an entity.
  EntityNode({
    required super.id,
    super.childIds,
    super.extra,
    super.name,
    super.tags,
    required this.transform,
    List<BehaviorAttachment> behaviors = const [],
  }) : behaviors = List.unmodifiable(behaviors);

  /// The entity's transform.
  final NodeTransform transform;

  /// The attached Behaviors, in order.
  final List<BehaviorAttachment> behaviors;

  /// A copy with the given fields replaced; [clearName] removes the name.
  EntityNode copyWith({
    List<NodeId>? childIds,
    Map<String, Object?>? extra,
    String? name,
    bool clearName = false,
    List<String>? tags,
    NodeTransform? transform,
    List<BehaviorAttachment>? behaviors,
  }) => EntityNode(
    id: id,
    childIds: childIds ?? this.childIds,
    extra: extra ?? this.extra,
    name: clearName ? null : name ?? this.name,
    tags: tags ?? this.tags,
    transform: transform ?? this.transform,
    behaviors: behaviors ?? this.behaviors,
  );
}

/// A Node drawing an image, or a region of one.
final class SpriteNode extends NamedNode {
  /// Creates a sprite.
  SpriteNode({
    required super.id,
    super.childIds,
    super.extra,
    super.name,
    super.tags,
    required this.transform,
    required this.image,
    this.region,
    Map<String, Object?> propsExtra = const {},
  }) : propsExtra = Map.unmodifiable(propsExtra);

  /// The sprite's transform.
  final NodeTransform transform;

  /// The image's asset path.
  final AssetPath image;

  /// The source region within the image, or null for the whole image.
  final SpriteRegion? region;

  /// Unknown keys inside `props`, kept and written back (FR-017).
  final Map<String, Object?> propsExtra;

  /// A copy with the given fields replaced; [clearName] and [clearRegion]
  /// remove the name and the region.
  SpriteNode copyWith({
    List<NodeId>? childIds,
    Map<String, Object?>? extra,
    String? name,
    bool clearName = false,
    List<String>? tags,
    NodeTransform? transform,
    AssetPath? image,
    SpriteRegion? region,
    bool clearRegion = false,
    Map<String, Object?>? propsExtra,
  }) => SpriteNode(
    id: id,
    childIds: childIds ?? this.childIds,
    extra: extra ?? this.extra,
    name: clearName ? null : name ?? this.name,
    tags: tags ?? this.tags,
    transform: transform ?? this.transform,
    image: image ?? this.image,
    region: clearRegion ? null : region ?? this.region,
    propsExtra: propsExtra ?? this.propsExtra,
  );
}

/// A rectangular hitbox, positioned relative to its parent.
final class RectangleHitboxNode extends NamedNode {
  /// Creates a rectangle hitbox. The defaults are Flame's.
  RectangleHitboxNode({
    required super.id,
    super.childIds,
    super.extra,
    super.name,
    super.tags,
    this.position = Vec2.zero,
    required this.size,
    this.angle = 0,
    this.anchor = NodeAnchor.topLeft,
    this.collisionType = NodeCollisionType.active,
    this.isSolid = false,
    Map<String, Object?> propsExtra = const {},
  }) : propsExtra = Map.unmodifiable(propsExtra);

  /// The position relative to the parent.
  final Vec2 position;

  /// The width and height.
  final Vec2 size;

  /// The rotation in radians.
  final double angle;

  /// The anchor.
  final NodeAnchor anchor;

  /// How the hitbox takes part in collisions.
  final NodeCollisionType collisionType;

  /// Whether the hitbox is solid (Flame's `isSolid`).
  final bool isSolid;

  /// Unknown keys inside `props`, kept and written back (FR-017).
  final Map<String, Object?> propsExtra;

  /// A copy with the given fields replaced; [clearName] removes the name.
  RectangleHitboxNode copyWith({
    List<NodeId>? childIds,
    Map<String, Object?>? extra,
    String? name,
    bool clearName = false,
    List<String>? tags,
    Vec2? position,
    Vec2? size,
    double? angle,
    NodeAnchor? anchor,
    NodeCollisionType? collisionType,
    bool? isSolid,
    Map<String, Object?>? propsExtra,
  }) => RectangleHitboxNode(
    id: id,
    childIds: childIds ?? this.childIds,
    extra: extra ?? this.extra,
    name: clearName ? null : name ?? this.name,
    tags: tags ?? this.tags,
    position: position ?? this.position,
    size: size ?? this.size,
    angle: angle ?? this.angle,
    anchor: anchor ?? this.anchor,
    collisionType: collisionType ?? this.collisionType,
    isSolid: isSolid ?? this.isSolid,
    propsExtra: propsExtra ?? this.propsExtra,
  );
}

/// A circular hitbox, positioned relative to its parent.
final class CircleHitboxNode extends NamedNode {
  /// Creates a circle hitbox. The defaults are Flame's.
  CircleHitboxNode({
    required super.id,
    super.childIds,
    super.extra,
    super.name,
    super.tags,
    this.position = Vec2.zero,
    required this.radius,
    this.anchor = NodeAnchor.topLeft,
    this.collisionType = NodeCollisionType.active,
    this.isSolid = false,
    Map<String, Object?> propsExtra = const {},
  }) : propsExtra = Map.unmodifiable(propsExtra);

  /// The position relative to the parent.
  final Vec2 position;

  /// The radius.
  final double radius;

  /// The anchor.
  final NodeAnchor anchor;

  /// How the hitbox takes part in collisions.
  final NodeCollisionType collisionType;

  /// Whether the hitbox is solid (Flame's `isSolid`).
  final bool isSolid;

  /// Unknown keys inside `props`, kept and written back (FR-017).
  final Map<String, Object?> propsExtra;

  /// A copy with the given fields replaced; [clearName] removes the name.
  CircleHitboxNode copyWith({
    List<NodeId>? childIds,
    Map<String, Object?>? extra,
    String? name,
    bool clearName = false,
    List<String>? tags,
    Vec2? position,
    double? radius,
    NodeAnchor? anchor,
    NodeCollisionType? collisionType,
    bool? isSolid,
    Map<String, Object?>? propsExtra,
  }) => CircleHitboxNode(
    id: id,
    childIds: childIds ?? this.childIds,
    extra: extra ?? this.extra,
    name: clearName ? null : name ?? this.name,
    tags: tags ?? this.tags,
    position: position ?? this.position,
    radius: radius ?? this.radius,
    anchor: anchor ?? this.anchor,
    collisionType: collisionType ?? this.collisionType,
    isSolid: isSolid ?? this.isSolid,
    propsExtra: propsExtra ?? this.propsExtra,
  );
}

/// A Custom component: a user-written Flame component named by its Type ID.
final class CustomNode extends NamedNode {
  /// Creates a Custom component Node of [type].
  CustomNode({
    required super.id,
    super.childIds,
    super.extra,
    super.name,
    super.tags,
    required this.type,
    required this.transform,
    this.fields = const Overrides.empty(),
    List<BehaviorAttachment> behaviors = const [],
  }) : behaviors = List.unmodifiable(behaviors);

  /// The component's Type ID.
  final TypeId type;

  /// The component's transform.
  final NodeTransform transform;

  /// The component's Overrides.
  final Overrides fields;

  /// The attached Behaviors, in order.
  final List<BehaviorAttachment> behaviors;

  /// A copy with the given fields replaced; [clearName] removes the name.
  CustomNode copyWith({
    List<NodeId>? childIds,
    Map<String, Object?>? extra,
    String? name,
    bool clearName = false,
    List<String>? tags,
    TypeId? type,
    NodeTransform? transform,
    Overrides? fields,
    List<BehaviorAttachment>? behaviors,
  }) => CustomNode(
    id: id,
    childIds: childIds ?? this.childIds,
    extra: extra ?? this.extra,
    name: clearName ? null : name ?? this.name,
    tags: tags ?? this.tags,
    type: type ?? this.type,
    transform: transform ?? this.transform,
    fields: fields ?? this.fields,
    behaviors: behaviors ?? this.behaviors,
  );
}

/// A Node of a kind this version doesn't know, kept whole and written back
/// unchanged. Real new kinds arrive with a newer `schemaVersion` (FR-020a),
/// so this only happens after a hand edit or a tool bug.
final class UnknownNode extends NamedNode {
  /// Creates a Node of unknown [kind]; [extra] holds all its other keys.
  UnknownNode({
    required super.id,
    super.childIds,
    super.extra,
    super.name,
    super.tags,
    required this.kind,
  });

  /// The `kind` written in the file.
  final String kind;

  /// A copy with the given fields replaced.
  UnknownNode copyWith({List<NodeId>? childIds, Map<String, Object?>? extra}) =>
      UnknownNode(
        id: id,
        childIds: childIds ?? this.childIds,
        extra: extra ?? this.extra,
        name: name,
        tags: tags,
        kind: kind,
      );
}
