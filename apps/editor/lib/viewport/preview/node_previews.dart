import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
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

  @override
  Set<AssetPath> get assetPaths => {?_path};

  /// Loads [path] (or clears the image for null) unless it is the image
  /// already shown.
  void showImage(
    AssetPath? path,
    PreviewContext context, {
    bool force = false,
  }) {
    if (!force && path == _path) return;
    _path = path;
    unawaited(_load(context));
  }

  Future<void> _load(PreviewContext context) async {
    final generation = ++_generation;
    final path = _path;
    if (path == null) {
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
    _swap(null);
    super.onRemove();
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
/// an unknown kind, shows error-toned (Missing component).
class PlaceholderPreview extends PositionComponent
    with PreviewComponent, _LeasedImage {
  /// Creates the component of Node [nodeId].
  PlaceholderPreview(this.nodeId);

  @override
  final NodeId nodeId;

  /// The side of a placeholder whose Node has no size of its own.
  static const double defaultSide = 32;

  /// What the label says: the Type ID, or the unknown kind.
  String label = '';

  /// Whether the type is missing from the catalog (or the kind unknown).
  bool missing = false;

  Image? _image;
  final Vector2 _drawSize = Vector2.zero();
  String? _laidOut;
  TextPainter? _text;

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
        showImage(type?.preview, context);
      case UnknownNode():
        label = node.kind;
        missing = true;
        showImage(null, context);
      default:
        throw ArgumentError.value(node, 'node', 'not a placeholder kind');
    }
    if (size.x == 0 || size.y == 0) {
      size.setValues(defaultSide, defaultSide);
    }
  }

  @override
  void onImage(Image? image) => _image = image;

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    if (missing || failed) {
      renderError(canvas, size);
    } else if (_image case final image?) {
      _drawSize.setValues(image.width.toDouble(), image.height.toDouble());
      canvas.drawImageRect(
        image,
        _drawSize.toRect(),
        rect,
        Paint()..filterQuality = FilterQuality.none,
      );
    } else {
      canvas
        ..drawRect(rect, _fill)
        ..drawRect(rect, _stroke);
    }
    if (showLabel) _paintLabel(canvas);
  }

  void _paintLabel(Canvas canvas) {
    if (_laidOut != label) {
      _laidOut = label;
      _text = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 10,
            color: missing ? PreviewColors.error : PreviewColors.placeholder,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    _text!.paint(canvas, Offset(0, -_text!.height - 2));
  }

  @override
  void onRemove() {
    _text?.dispose();
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
