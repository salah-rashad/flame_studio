import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart' show PrColors;

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

/// The colours the viewport draws its own shapes in — previews and the
/// overlay — from the dark theme's tokens (no `BuildContext` reaches the
/// game).
abstract final class PreviewColors {
  static const PrColors _theme = PrColors.dark;

  /// Hitbox outlines.
  static final Color hitbox = _theme.success;

  /// Placeholder boxes of Custom components.
  static final Color placeholder = _theme.info;

  /// Missing types, unknown Node kinds and unreadable images.
  static final Color error = _theme.error;

  /// The selection outline and the gizmo's free handle.
  static final Color selection = _theme.accent;

  /// The hover highlight and its name label.
  static final Color hover = _theme.textPrimary;

  /// The gizmo's x handle.
  static final Color axisX = _theme.axisX;

  /// The gizmo's y handle.
  static final Color axisY = _theme.axisY;
}

/// One line of text drawn on the canvas, laid out again only when its text
/// or colour changes — text layout per Node per frame would cost the frame
/// budget (research §4).
final class CanvasLabel {
  /// Creates a label of [fontSize] logical pixels.
  CanvasLabel({required this.fontSize});

  /// The font size.
  final double fontSize;

  String? _text;
  Color? _color;
  TextPainter? _painter;

  /// The size [text] takes in [color].
  Size measure(String text, Color color) => _layout(text, color).size;

  /// Draws [text] in [color] with its top-left corner at [at], or with its
  /// bottom-left there when [above].
  void paint(
    Canvas canvas,
    String text, {
    required Color color,
    Offset at = Offset.zero,
    bool above = false,
  }) {
    final painter = _layout(text, color);
    painter.paint(canvas, above ? at.translate(0, -painter.height) : at);
  }

  TextPainter _layout(String text, Color color) {
    if (text != _text || color != _color) {
      _text = text;
      _color = color;
      _painter?.dispose();
      _painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: fontSize, color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    return _painter!;
  }

  /// Frees the layout. The label stays usable: Flame removes a component
  /// from the tree when it moves to another parent, then reuses it, so the
  /// next [paint] lays the text out again.
  void dispose() {
    _painter?.dispose();
    _painter = null;
    _text = null;
    _color = null;
  }
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

  /// Whether the Type ID label shows: only for the selected or hovered
  /// Node (see [CanvasLabel]).
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
