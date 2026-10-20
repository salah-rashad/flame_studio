import 'dart:ui' show Image;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../scene/node.dart';
import '../scene/values.dart';
import 'pyro_entity.dart';

/// Flame's [Anchor] for [anchor]; a named anchor equals Flame's constant of
/// the same name.
Anchor anchorOf(NodeAnchor anchor) => Anchor(anchor.x, anchor.y);

/// Flame's [Vector2] for [value].
Vector2 vectorOf(Vec2 value) => Vector2(value.x, value.y);

/// Flame's [CollisionType] for [type].
CollisionType collisionTypeOf(NodeCollisionType type) => switch (type) {
  NodeCollisionType.active => CollisionType.active,
  NodeCollisionType.passive => CollisionType.passive,
  NodeCollisionType.inactive => CollisionType.inactive,
};

/// Sets [component]'s position, size, scale, angle and anchor to
/// [transform]'s.
void applyTransform(PositionComponent component, NodeTransform transform) {
  component
    ..position = vectorOf(transform.position)
    ..size = vectorOf(transform.size)
    ..scale = vectorOf(transform.scale)
    ..angle = transform.angle
    ..anchor = anchorOf(transform.anchor);
}

/// The component of an `entity` Node.
PyroEntity entityOf(EntityNode node) => PyroEntity(
  position: vectorOf(node.transform.position),
  size: vectorOf(node.transform.size),
  scale: vectorOf(node.transform.scale),
  angle: node.transform.angle,
  anchor: anchorOf(node.transform.anchor),
);

/// The component of a `sprite` Node, without its sprite: the image loads
/// after every Node is built (research R4), and [applySprite] sets it.
SpriteComponent spriteOf(SpriteNode node) => SpriteComponent(
  position: vectorOf(node.transform.position),
  size: vectorOf(node.transform.size),
  scale: vectorOf(node.transform.scale),
  angle: node.transform.angle,
  anchor: anchorOf(node.transform.anchor),
);

/// Sets [component]'s sprite to [node]'s image, or the region of it.
void applySprite(SpriteComponent component, SpriteNode node, Image image) {
  final region = node.region;
  component.sprite = Sprite(
    image,
    srcPosition: region == null ? null : vectorOf(region.position),
    srcSize: region == null ? null : vectorOf(region.size),
  );
}

/// The component of a `rectangleHitbox` Node. Its position and size are
/// always given, so it never fills its parent.
RectangleHitbox rectangleHitboxOf(RectangleHitboxNode node) => RectangleHitbox(
  position: vectorOf(node.position),
  size: vectorOf(node.size),
  angle: node.angle,
  anchor: anchorOf(node.anchor),
  isSolid: node.isSolid,
  collisionType: collisionTypeOf(node.collisionType),
);

/// The component of a `circleHitbox` Node. Its position and radius are
/// always given, so it never fills its parent.
CircleHitbox circleHitboxOf(CircleHitboxNode node) => CircleHitbox(
  radius: node.radius,
  position: vectorOf(node.position),
  anchor: anchorOf(node.anchor),
  isSolid: node.isSolid,
  collisionType: collisionTypeOf(node.collisionType),
);
