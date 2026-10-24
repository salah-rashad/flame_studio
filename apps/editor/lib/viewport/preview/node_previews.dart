import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../disk_assets.dart';
import 'preview_component.dart';

/// The preview component for [node] (FR-015).
PreviewComponent previewOf(Node node, PreviewContext context) {
  final PreviewComponent component = switch (node) {
    RootNode() => throw ArgumentError.value(
      node,
      'node',
      'the root is the world',
    ),
    EntityNode() => EntityPreview(node.id),
    SpriteNode() => SpritePreview(node.id),
    RectangleHitboxNode() => RectangleHitboxPreview(node.id),
    CircleHitboxNode() => CircleHitboxPreview(node.id),
    CustomNode() => PlaceholderPreview(node.id),
    UnknownNode() => PlaceholderPreview(node.id),
  };
  component.patch(node, context);
  return component;
}

/// An entity: an invisible positioned group its children attach under.
class EntityPreview extends PositionComponent with PreviewComponent {
  /// Creates the component of entity [nodeId].
  EntityPreview(this.nodeId);

  @override
  final NodeId nodeId;

  @override
  void patch(Node node, PreviewContext context) =>
      applyTransform(this, (node as EntityNode).transform);
}

/// Holds one image lease at a time and swaps it in place: the old image is
/// released only after the new one is drawn (*Q79*). Stale loads lose to
/// newer ones.
mixin _LeasedImage on PreviewComponent {
  ImageLease? _lease;
  AssetPath? _path;
  int _generation = 0;

  /// The image could not be read (missing or undecodable file).
  bool failed = false;

  PreviewContext? _context;
  bool _released = false;

  @override
  Set<AssetPath> get assetPaths => {?_path};

  /// Loads [path] (or clears the image for null) unless it is the image
  /// already shown.
  void showImage(
    AssetPath? path,
    PreviewContext context, {
    bool force = false,
  }) {
    _context = context;
    if (!force && path == _path) return;
    _path = path;
    unawaited(_load(context));
  }

  Future<void> _load(PreviewContext context) async {
    final generation = ++_generation;
    final path = _path;
    if (path == null) {
      failed = false;
      _swap(null);
      return;
    }
    try {
      final lease = await context.assets.leaseImage(path);
      if (generation != _generation || isRemoved) {
        lease.release();
        return;
      }
      failed = false;
      _swap(lease);
      // The end of SC-005's budget: the next frame draws it.
      developer.Timeline.instantSync(
        'Pyro image shown',
        arguments: {'path': path, 'node': nodeId},
      );
    } on Object catch (error) {
      if (generation != _generation) return;
      // The Node shows the error state (FR-021); the cause goes to the log.
      developer.log(
        'Could not read the image "$path" for Node $nodeId: $error',
        name: 'pyro.viewport',
      );
      failed = true;
      _swap(null);
    }
  }

  void _swap(ImageLease? lease) {
    final old = _lease;
    _lease = lease;
    onImage(lease?.image);
    old?.release();
  }

  /// Shows [image]; null shows the empty or error state.
  void onImage(Image? image);

  @override
  Future<void> reloadAssets(PreviewContext context) => _load(context);

  @override
  void onRemove() {
    _generation++;
    _released = true;
    _swap(null);
    super.onRemove();
  }

  /// Flame removes a component and mounts it again when it moves to another
  /// parent; the image went back on removal, so it is read again here.
  @override
  void onMount() {
    super.onMount();
    final context = _context;
    if (_released && context != null) {
      _released = false;
      unawaited(_load(context));
    }
  }
}

/// A sprite, drawn from the project's image file on disk, pixel-exact
/// (`FilterQuality.none`); an unreadable file shows the error state, never
/// a crash (FR-021). Not Flame's `SpriteComponent`, which insists on a
/// sprite at mount — disk images land later.
class SpritePreview extends PositionComponent
    with PreviewComponent, _LeasedImage {
  /// Creates the component of sprite [nodeId].
  SpritePreview(this.nodeId);

  @override
  final NodeId nodeId;

  /// The paint the sprite draws with.
  final Paint paint = Paint()..filterQuality = FilterQuality.none;

  /// The sprite shown, or null while loading or after a failure.
  Sprite? sprite;

  SpriteRegion? _region;
  Image? _image;

  @override
  void patch(Node node, PreviewContext context) {
    node as SpriteNode;
    applyTransform(this, node.transform);
    if (node.region != _region) {
      _region = node.region;
      onImage(_image);
    }
    showImage(node.image, context);
  }

  @override
  void onImage(Image? image) {
    _image = image;
    final region = _region;
    sprite = image == null
        ? null
        : Sprite(
            image,
            srcPosition: region == null ? null : vectorOf(region.position),
            srcSize: region == null ? null : vectorOf(region.size),
          );
  }

  @override
  void render(Canvas canvas) {
    if (failed) {
      renderError(canvas, size);
      return;
    }
    sprite?.render(canvas, size: size, overridePaint: paint);
  }
}

/// A rectangle hitbox's outline — also its picking shape.
class RectangleHitboxPreview extends PositionComponent with PreviewComponent {
  /// Creates the component of rectangle hitbox [nodeId].
  RectangleHitboxPreview(this.nodeId);

  @override
  final NodeId nodeId;

  static final Paint _paint = strokeOf(PreviewColors.hitbox);

  @override
  void patch(Node node, PreviewContext context) {
    node as RectangleHitboxNode;
    position.setValues(node.position.x, node.position.y);
    size.setValues(node.size.x, node.size.y);
    angle = node.angle;
    anchor = anchorOf(node.anchor);
  }

  @override
  void render(Canvas canvas) => canvas.drawRect(size.toRect(), _paint);
}

/// A circle hitbox's outline — also its picking shape.
class CircleHitboxPreview extends PositionComponent with PreviewComponent {
  /// Creates the component of circle hitbox [nodeId].
  CircleHitboxPreview(this.nodeId);

  @override
  final NodeId nodeId;

  static final Paint _paint = strokeOf(PreviewColors.hitbox);

  @override
  void patch(Node node, PreviewContext context) {
    node as CircleHitboxNode;
    position.setValues(node.position.x, node.position.y);
    size.setValues(node.radius * 2, node.radius * 2);
    anchor = anchorOf(node.anchor);
  }

  @override
  bool containsLocalPoint(Vector2 point) =>
      point.distanceTo(size / 2) <= size.x / 2;

  @override
  void render(Canvas canvas) =>
      canvas.drawCircle((size / 2).toOffset(), size.x / 2, _paint);
}

/// A Custom component as a labelled box with its Type ID, or its Manifest
/// `preview:` image (*Q6*); a type missing from the catalog, or a Node of
/// an unknown Node kind, shows error-toned (Missing component).
class PlaceholderPreview extends PositionComponent
    with PreviewComponent, _LeasedImage {
  /// Creates the component of Node [nodeId].
  PlaceholderPreview(this.nodeId);

  @override
  final NodeId nodeId;

  /// The side of a placeholder whose Node has no size of its own.
  static const double defaultSide = 32;

  /// What the label says: the Type ID, or the unknown Node kind.
  String label = '';

  /// Whether the type is missing from the catalog (or the Node kind is
  /// unknown).
  bool missing = false;

  /// The text a text component shows, when the type is one (see
  /// [textOf]); null for every other placeholder.
  String? text;

  /// The colour [text] is drawn in.
  Color textColor = _defaultTextColor;

  Image? _image;
  final Vector2 _drawSize = Vector2.zero();
  final CanvasLabel _label = CanvasLabel(fontSize: 10);
  final CanvasLabel _content = CanvasLabel(fontSize: textFontSize);

  static final Paint _imagePaint = Paint()..filterQuality = FilterQuality.none;
  static final Paint _fill = Paint()
    ..color = PreviewColors.placeholder.withValues(alpha: 0.2);
  static final Paint _stroke = strokeOf(PreviewColors.placeholder);

  @override
  void patch(Node node, PreviewContext context) {
    switch (node) {
      case CustomNode():
        applyTransform(this, node.transform);
        label = node.type;
        final type = context.catalog[node.type];
        missing = type == null;
        final shown = type == null
            ? (null, _defaultTextColor)
            : textOf(type, node.fields);
        text = shown.$1;
        textColor = shown.$2;
        // Text wins over the Manifest's preview image: it is not read, so
        // a missing image can't turn shown text into the error state.
        showImage(text == null ? type?.preview : null, context);
      case UnknownNode():
        label = node.kind;
        missing = true;
        text = null;
        showImage(null, context);
      default:
        throw ArgumentError.value(node, 'node', 'not a placeholder Node kind');
    }
    if (size.x == 0 || size.y == 0) {
      // A text component sizes itself to its text, as in the game.
      final measured = text == null ? null : _content.measure(text!, textColor);
      if (measured != null) {
        size.setValues(measured.width, measured.height);
      } else {
        size.setValues(defaultSide, defaultSide);
      }
    }
  }

  @override
  void onImage(Image? image) => _image = image;

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    if (missing || failed) {
      renderError(canvas, size);
    } else if (text case final text?) {
      _content.paint(canvas, text, color: textColor);
      return;
    } else if (_image case final image?) {
      _drawSize.setValues(image.width.toDouble(), image.height.toDouble());
      canvas.drawImageRect(image, _drawSize.toRect(), rect, _imagePaint);
    } else {
      canvas
        ..drawRect(rect, _fill)
        ..drawRect(rect, _stroke);
    }
    // Inside the box: the overlay's name label sits above it.
    if (showLabel) {
      _label.paint(
        canvas,
        label,
        color: missing ? PreviewColors.error : PreviewColors.placeholder,
        at: const Offset(2, 2),
      );
    }
  }

  @override
  void onRemove() {
    _label.dispose();
    _content.dispose();
    super.onRemove();
  }
}

final Paint _errorFill = Paint()
  ..color = PreviewColors.error.withValues(alpha: 0.25);
final Paint _errorStroke = strokeOf(PreviewColors.error);

/// The error state: an error-toned box with a cross, at [size] (or the
/// placeholder side when the Node has none).
void renderError(Canvas canvas, Vector2 size) {
  final w = size.x == 0 ? PlaceholderPreview.defaultSide : size.x;
  final h = size.y == 0 ? PlaceholderPreview.defaultSide : size.y;
  final rect = Rect.fromLTWH(0, 0, w, h);
  canvas
    ..drawRect(rect, _errorFill)
    ..drawRect(rect, _errorStroke)
    ..drawLine(rect.topLeft, rect.bottomRight, _errorStroke)
    ..drawLine(rect.topRight, rect.bottomLeft, _errorStroke);
}

/// The font size of a text component's preview: Flame's default
/// `TextPaint` size. The editor can't run the component's `onLoad`, so a
/// size the code sets itself isn't known.
const double textFontSize = 24;

const Color _defaultTextColor = Color(0xFFFFFFFF);

final RegExp _colorValue = RegExp(r'^#[0-9A-Fa-f]{8}$');

/// What a text component of [type] shows with [overrides]: the text of its
/// first `String` field and the colour of its first `Color` field, each the
/// Override or else the Manifest's default (Flame's white when it has none);
/// `(null, white)` when [type] isn't a `TextComponent` or has no text.
///
/// Preview only: the real component may compute its text in code, so this
/// is the one thing the editor can know without running it (*Q7*).
(String?, Color) textOf(TypeDescriptor type, Overrides overrides) {
  if (!type.supertypes.contains('TextComponent')) {
    return (null, _defaultTextColor);
  }
  Object? valueOf(FieldDescriptor field) => overrides.contains(field.name)
      ? overrides[field.name]
      : field.defaultValue;
  final textField = type.fields
      .where((field) => field.type == FieldType.string)
      .firstOrNull;
  final colorField = type.fields
      .where((field) => field.type == FieldType.color)
      .firstOrNull;
  final text = textField == null ? null : valueOf(textField);
  final color = colorField == null ? null : valueOf(colorField);
  return (
    text is String && text.isNotEmpty ? text : null,
    color is String && _colorValue.hasMatch(color)
        ? Color(int.parse(color.substring(1), radix: 16))
        : _defaultTextColor,
  );
}
