import 'package:pyro_runtime/pyro_runtime.dart';

/// The canonical text of a Scene made of [nodes], whose one [RootNode] is
/// the root, so tests never write Scene JSON by hand.
String sceneJson(Iterable<Node> nodes) {
  final byId = {for (final node in nodes) node.id: node};
  final root = byId.values.whereType<RootNode>().single;
  return SceneCodec.encode(Scene(rootId: root.id, nodes: byId));
}

/// A transform at [x], [y] with size [w] × [h].
NodeTransform at(double x, double y, {double w = 0, double h = 0}) =>
    NodeTransform(position: Vec2(x, y), size: Vec2(w, h));
