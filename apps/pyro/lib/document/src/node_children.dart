import 'package:pyro_runtime/pyro_runtime.dart';

/// [node] with its children replaced by [childIds].
///
/// The Runtime's `Node` has no `copyWith`, so this switches over the sealed
/// Node kinds; a new kind breaks the build here instead of losing children
/// (spec 002, research R6).
Node withChildIds(Node node, List<NodeId> childIds) => switch (node) {
  RootNode() => node.copyWith(childIds: childIds),
  EntityNode() => node.copyWith(childIds: childIds),
  SpriteNode() => node.copyWith(childIds: childIds),
  RectangleHitboxNode() => node.copyWith(childIds: childIds),
  CircleHitboxNode() => node.copyWith(childIds: childIds),
  CustomNode() => node.copyWith(childIds: childIds),
  UnknownNode() => node.copyWith(childIds: childIds),
};
