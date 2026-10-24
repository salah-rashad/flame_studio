import 'package:pyro_runtime/pyro_runtime.dart';

/// [node]'s position in its parent, or null for kinds without one (the
/// root, unknown kinds).
Vec2? positionOf(Node node) => switch (node) {
  EntityNode() => node.transform.position,
  SpriteNode() => node.transform.position,
  CustomNode() => node.transform.position,
  RectangleHitboxNode() => node.position,
  CircleHitboxNode() => node.position,
  RootNode() || UnknownNode() => null,
};

/// [node] moved to [position] in its parent; kinds without a position come
/// back unchanged.
Node withPosition(Node node, Vec2 position) => switch (node) {
  EntityNode() => node.copyWith(
    transform: node.transform.copyWith(position: position),
  ),
  SpriteNode() => node.copyWith(
    transform: node.transform.copyWith(position: position),
  ),
  CustomNode() => node.copyWith(
    transform: node.transform.copyWith(position: position),
  ),
  RectangleHitboxNode() => node.copyWith(position: position),
  CircleHitboxNode() => node.copyWith(position: position),
  RootNode() || UnknownNode() => node,
};
