import 'dart:ui';

import 'package:flame/components.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../disk_assets.dart';

/// What every preview component reads besides its Node: the project's
/// files and types. Never the project's code (FR-016, *Q7*).
final class PreviewContext {
  /// Creates the context.
  const PreviewContext({required this.assets, required this.catalog});

  /// The project's files.
  final DiskAssetSource assets;

  /// The project's types, for placeholders and Missing states.
  final TypeCatalog catalog;
}

/// The colours the preview world draws its own shapes in: hitbox outlines,
/// placeholders and error states (no `BuildContext` reaches the game, so
/// these are the dark theme's values).
abstract final class PreviewColors {
  /// Hitbox outlines.
  static const Color hitbox = Color(0xFF3DD68C);

  /// Placeholder boxes of Custom components.
  static const Color placeholder = Color(0xFF7C9CF5);

  /// Missing types, unknown kinds and unreadable images.
  static const Color error = Color(0xFFE5484D);
}

/// The component one Node shows as in the viewport (FR-015). It never runs
/// game logic: the reconciler patches it from the document, and the file
/// watcher reloads what it read.
mixin PreviewComponent on PositionComponent {
  /// The Node this component shows.
  NodeId get nodeId;

  /// The project files this component read, so a change to one of them
  /// reloads only this component (FR-021).
  Set<AssetPath> get assetPaths => const {};

  /// Updates this component in place to show [node] — same Node ID, new
  /// values. Never re-creates it.
  void patch(Node node, PreviewContext context);

  /// Reads this component's files again after they changed on disk.
  Future<void> reloadAssets(PreviewContext context) async {}

  /// Whether the Type ID label shows (selected or hovered placeholders;
  /// text layout per Node per frame would cost the frame budget).
  bool showLabel = false;
}

/// Flame's [Anchor] for [anchor].
Anchor anchorOf(NodeAnchor anchor) => Anchor(anchor.x, anchor.y);

/// Flame's [Vector2] for [value].
Vector2 vectorOf(Vec2 value) => Vector2(value.x, value.y);

/// Sets [component]'s position, size, scale, angle and anchor to
/// [transform]'s — the runtime's mapping, so the preview matches the game.
void applyTransform(PositionComponent component, NodeTransform transform) {
  component
    ..position.setValues(transform.position.x, transform.position.y)
    ..size.setValues(transform.size.x, transform.size.y)
    ..scale.setValues(transform.scale.x, transform.scale.y)
    ..angle = transform.angle
    ..anchor = anchorOf(transform.anchor);
}

/// An outline paint in [color], one world unit wide (constant on-screen
/// widths are the overlay's job).
Paint strokeOf(Color color) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1
  ..color = color;
