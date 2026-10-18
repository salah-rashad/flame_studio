import 'json/json_equality.dart';

/// The stable identifier of a Node within its Scene. It never changes when
/// the Node is renamed, moved or edited. Pyro uses UUIDs; any non-empty
/// string is accepted.
extension type const NodeId(String value) implements String {}

/// The Type ID of a Behavior or Custom component: its class name, or the
/// explicit `id:` from its annotation (*Q45*).
extension type const TypeId(String value) implements String {}

/// An asset path relative to the project root, the same key the game
/// declares in `pubspec.yaml`, such as `assets/images/goblin.png`.
extension type const AssetPath(String value) implements String {}

/// A 2D vector, written to a Scene as `[x, y]`.
///
/// The Scene format doesn't use Flame's `Vector2`, so it never depends on a
/// Flame version.
final class Vec2 {
  /// Creates the vector ([x], [y]).
  const Vec2(this.x, this.y);

  /// (0, 0).
  static const Vec2 zero = Vec2(0, 0);

  /// (1, 1).
  static const Vec2 one = Vec2(1, 1);

  /// The horizontal component.
  final double x;

  /// The vertical component.
  final double y;

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}

/// Where a positioned Node's origin sits within its size: one of Flame's
/// nine named anchors, or a custom point in fractions of the size.
final class NodeAnchor {
  const NodeAnchor._named(this.name, this.x, this.y);

  /// A custom anchor at ([x], [y]), as fractions of the size.
  const NodeAnchor.custom(this.x, this.y) : name = null;

  /// The top-left corner (0, 0), Flame's default.
  static const NodeAnchor topLeft = NodeAnchor._named('topLeft', 0, 0);

  /// The middle of the top edge (0.5, 0).
  static const NodeAnchor topCenter = NodeAnchor._named('topCenter', 0.5, 0);

  /// The top-right corner (1, 0).
  static const NodeAnchor topRight = NodeAnchor._named('topRight', 1, 0);

  /// The middle of the left edge (0, 0.5).
  static const NodeAnchor centerLeft = NodeAnchor._named('centerLeft', 0, 0.5);

  /// The centre (0.5, 0.5).
  static const NodeAnchor center = NodeAnchor._named('center', 0.5, 0.5);

  /// The middle of the right edge (1, 0.5).
  static const NodeAnchor centerRight = NodeAnchor._named(
    'centerRight',
    1,
    0.5,
  );

  /// The bottom-left corner (0, 1).
  static const NodeAnchor bottomLeft = NodeAnchor._named('bottomLeft', 0, 1);

  /// The middle of the bottom edge (0.5, 1).
  static const NodeAnchor bottomCenter = NodeAnchor._named(
    'bottomCenter',
    0.5,
    1,
  );

  /// The bottom-right corner (1, 1).
  static const NodeAnchor bottomRight = NodeAnchor._named('bottomRight', 1, 1);

  /// The nine named anchors.
  static const List<NodeAnchor> named = [
    topLeft,
    topCenter,
    topRight,
    centerLeft,
    center,
    centerRight,
    bottomLeft,
    bottomCenter,
    bottomRight,
  ];

  /// The named anchor called [name], or null if there is none.
  static NodeAnchor? byName(String name) {
    for (final anchor in named) {
      if (anchor.name == name) return anchor;
    }
    return null;
  }

  /// The anchor's name, or null for a custom anchor. A custom anchor at a
  /// named anchor's point stays custom, so the file round-trips as written.
  final String? name;

  /// The horizontal fraction of the size.
  final double x;

  /// The vertical fraction of the size.
  final double y;

  @override
  bool operator ==(Object other) =>
      other is NodeAnchor && other.name == name && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(name, x, y);

  @override
  String toString() => name ?? 'NodeAnchor.custom($x, $y)';
}

/// The position, size, scale, angle and anchor of a positioned Node, always
/// written in full (FR-013).
final class NodeTransform {
  /// Creates a transform. The defaults are Flame's `PositionComponent`
  /// defaults; [extra] holds keys this version doesn't know, written back
  /// unchanged.
  NodeTransform({
    this.position = Vec2.zero,
    this.size = Vec2.zero,
    this.scale = Vec2.one,
    this.angle = 0,
    this.anchor = NodeAnchor.topLeft,
    Map<String, Object?> extra = const {},
  }) : extra = Map.unmodifiable(extra);

  /// The position relative to the parent.
  final Vec2 position;

  /// The size before scaling.
  final Vec2 size;

  /// The scale factors.
  final Vec2 scale;

  /// The rotation in radians, as Flame stores it.
  final double angle;

  /// The anchor.
  final NodeAnchor anchor;

  /// Unknown keys inside `transform`, kept and written back (FR-017).
  final Map<String, Object?> extra;

  /// A copy with the given fields replaced.
  NodeTransform copyWith({
    Vec2? position,
    Vec2? size,
    Vec2? scale,
    double? angle,
    NodeAnchor? anchor,
    Map<String, Object?>? extra,
  }) => NodeTransform(
    position: position ?? this.position,
    size: size ?? this.size,
    scale: scale ?? this.scale,
    angle: angle ?? this.angle,
    anchor: anchor ?? this.anchor,
    extra: extra ?? this.extra,
  );

  @override
  bool operator ==(Object other) =>
      other is NodeTransform &&
      other.position == position &&
      other.size == size &&
      other.scale == scale &&
      other.angle == angle &&
      other.anchor == anchor &&
      jsonEquals(other.extra, extra);

  @override
  int get hashCode =>
      Object.hash(position, size, scale, angle, anchor, jsonHash(extra));

  @override
  String toString() =>
      'NodeTransform(position: $position, size: $size, scale: $scale, '
      'angle: $angle, anchor: $anchor)';
}

/// The source rectangle of a sprite within its image, in pixels.
final class SpriteRegion {
  /// Creates the region at [position] with [size].
  const SpriteRegion({required this.position, required this.size});

  /// The top-left corner in the image.
  final Vec2 position;

  /// The width and height.
  final Vec2 size;

  @override
  bool operator ==(Object other) =>
      other is SpriteRegion && other.position == position && other.size == size;

  @override
  int get hashCode => Object.hash(position, size);

  @override
  String toString() => 'SpriteRegion($position, $size)';
}

/// How a hitbox takes part in collision detection, with Flame's
/// `CollisionType` names.
enum NodeCollisionType {
  /// Collides with other active and passive hitboxes.
  active,

  /// Collides only with active hitboxes.
  passive,

  /// Takes no part in collision detection.
  inactive,
}
