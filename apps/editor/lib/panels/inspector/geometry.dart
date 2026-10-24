import 'package:pyro_runtime/pyro_runtime.dart';

/// What the transform section shows of a Node: the five transform
/// properties that kind has. Entities, sprites and Custom components carry
/// a `NodeTransform`; a rectangle hitbox has no scale, and a circle hitbox
/// a radius instead of a size and no angle.
final class Geometry {
  /// Creates the view; a property the kind lacks is null.
  const Geometry({
    required this.position,
    required this.anchor,
    this.size,
    this.scale,
    this.angle,
    this.radius,
  });

  /// The position in the parent.
  final Vec2 position;

  /// The anchor.
  final NodeAnchor anchor;

  /// The size before scaling.
  final Vec2? size;

  /// The scale factors.
  final Vec2? scale;

  /// The rotation in radians, as the file stores it.
  final double? angle;

  /// A circle hitbox's radius.
  final double? radius;
}

/// [node]'s geometry, or null for the root and unknown kinds.
Geometry? geometryOf(Node node) => switch (node) {
  EntityNode(:final transform) ||
  SpriteNode(:final transform) ||
  CustomNode(:final transform) => Geometry(
    position: transform.position,
    size: transform.size,
    scale: transform.scale,
    angle: transform.angle,
    anchor: transform.anchor,
  ),
  RectangleHitboxNode() => Geometry(
    position: node.position,
    size: node.size,
    angle: node.angle,
    anchor: node.anchor,
  ),
  CircleHitboxNode() => Geometry(
    position: node.position,
    radius: node.radius,
    anchor: node.anchor,
  ),
  RootNode() || UnknownNode() => null,
};

/// [node] with the given geometry properties replaced; those its kind
/// lacks are ignored.
Node withGeometry(
  Node node, {
  Vec2? position,
  Vec2? size,
  Vec2? scale,
  double? angle,
  NodeAnchor? anchor,
  double? radius,
}) {
  NodeTransform moved(NodeTransform t) => t.copyWith(
    position: position,
    size: size,
    scale: scale,
    angle: angle,
    anchor: anchor,
  );
  return switch (node) {
    EntityNode() => node.copyWith(transform: moved(node.transform)),
    SpriteNode() => node.copyWith(transform: moved(node.transform)),
    CustomNode() => node.copyWith(transform: moved(node.transform)),
    RectangleHitboxNode() => node.copyWith(
      position: position,
      size: size,
      angle: angle,
      anchor: anchor,
    ),
    CircleHitboxNode() => node.copyWith(
      position: position,
      radius: radius,
      anchor: anchor,
    ),
    RootNode() || UnknownNode() => node,
  };
}
