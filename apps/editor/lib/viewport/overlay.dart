import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart' show PrColors;

import 'editor_game.dart';
import 'node_position.dart';
import 'preview/preview_component.dart';
import 'preview_tree.dart';

/// The overlay layer (FR-022): selection outline, hover highlight with the
/// Node's name, and the move gizmo. It lives among the camera viewfinder's
/// children — drawn in front of the world in world coordinates, hit-tested
/// before it (research §4) — and is never part of the document.
class ViewportOverlay extends Component with HasGameReference<EditorGame> {
  /// Creates the overlay of [tree]'s components.
  ViewportOverlay({required this.tree, required MoveNode onMove}) {
    gizmo = MoveGizmo(overlay: this, onMove: onMove);
  }

  /// The components it outlines.
  final PreviewTree tree;

  /// The move gizmo on the selected Node.
  late final MoveGizmo gizmo;

  /// The selected Node, or null.
  NodeId? selected;

  NodeId? _hovered;
  String? _labelText;
  TextPainter? _label;

  /// The Node under the pointer, or null.
  NodeId? get hovered => _hovered;
  set hovered(NodeId? id) {
    if (id == _hovered) return;
    final previous = _hovered == null ? null : tree.componentOf(_hovered!);
    if (previous != null && previous.nodeId != selected) {
      previous.showLabel = false;
    }
    _hovered = id;
    final next = id == null ? null : tree.componentOf(id);
    next?.showLabel = true;
  }

  /// Selects [id] (from any panel, FR-011): only the label and outline
  /// follow; nothing in the document changes.
  void select(NodeId? id) {
    if (selected == id) return;
    final previous = selected == null ? null : tree.componentOf(selected!);
    if (previous != null && previous.nodeId != _hovered) {
      previous.showLabel = false;
    }
    selected = id;
    final next = id == null ? null : tree.componentOf(id);
    next?.showLabel = true;
  }

  /// The selection colour: the theme's accent.
  static final Color selectionColor = PrColors.dark.accent;

  /// The hover colour.
  static const Color hoverColor = Color(0x99FFFFFF);

  final Paint _selectionPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = selectionColor;
  final Paint _hoverPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = hoverColor;

  double get _zoom => game.camera.viewfinder.zoom;

  @override
  FutureOr<void> onLoad() => add(gizmo);

  @override
  void update(double dt) {
    final component = selected == null ? null : tree.componentOf(selected!);
    gizmo.follow(component, _zoom);
  }

  @override
  void render(Canvas canvas) {
    final px = 1 / _zoom;
    final hovered = _hovered == null ? null : tree.componentOf(_hovered!);
    if (hovered != null && hovered.nodeId != selected) {
      _hoverPaint.strokeWidth = px;
      _outline(canvas, hovered, _hoverPaint);
      _name(canvas, hovered, px);
    }
    final selection = selected == null ? null : tree.componentOf(selected!);
    if (selection != null) {
      _selectionPaint.strokeWidth = 2 * px;
      _outline(canvas, selection, _selectionPaint);
    }
  }

  /// [component]'s box in world coordinates, rotation and scale included;
  /// a Node without a size (an entity group) shows as a cross on its
  /// anchor.
  void _outline(Canvas canvas, PreviewComponent component, Paint paint) {
    final size = component.size;
    if (size.x == 0 || size.y == 0) {
      final at = component.absolutePosition.toOffset();
      final arm = 6 / _zoom;
      canvas
        ..drawLine(at.translate(-arm, 0), at.translate(arm, 0), paint)
        ..drawLine(at.translate(0, -arm), at.translate(0, arm), paint);
      return;
    }
    final corners = [
      component.absolutePositionOf(Vector2.zero()),
      component.absolutePositionOf(Vector2(size.x, 0)),
      component.absolutePositionOf(size),
      component.absolutePositionOf(Vector2(0, size.y)),
    ];
    canvas.drawPath(
      Path()..addPolygon([for (final c in corners) c.toOffset()], true),
      paint,
    );
  }

  /// The hovered Node's name above its top-left corner, at a constant
  /// screen size; laid out once per hover change, never per frame.
  void _name(Canvas canvas, PreviewComponent component, double px) {
    final node = tree.document?.node(component.nodeId);
    final text = switch (node) {
      NamedNode(:final name?) => name,
      _ => component.nodeId,
    };
    if (_labelText != text) {
      _labelText = text;
      _label?.dispose();
      _label = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontSize: 11, color: Color(0xFFFFFFFF)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final corner = component.absolutePositionOf(Vector2.zero());
    canvas
      ..save()
      ..translate(corner.x, corner.y)
      ..scale(px);
    _label!.paint(canvas, Offset(0, -_label!.height - 2));
    canvas.restore();
  }

  @override
  void onRemove() {
    _label?.dispose();
    super.onRemove();
  }
}

/// Which way a gizmo handle moves its Node.
enum GizmoAxis {
  /// Along the world's x axis only.
  x,

  /// Along the world's y axis only.
  y,

  /// Freely (the centre square).
  free,
}

/// The move gizmo (FR-020): two axis arrows and a free centre square on
/// the selected Node's anchor, a constant size on screen (`scale =
/// 1/zoom`). A drag writes each update through the document with one
/// gesture key, so the whole drag is one undo step; the moved component
/// follows through the reconciler — the production path (contract, "Live
/// dragging").
class MoveGizmo extends PositionComponent {
  /// Creates the gizmo.
  MoveGizmo({required this.overlay, required this.onMove});

  @override
  FutureOr<void> onLoad() => addAll([
    _GizmoHandle(
      this,
      GizmoAxis.x,
      position: Vector2(8, -5),
      size: Vector2(40, 10),
      color: const Color(0xFFE5484D),
    ),
    _GizmoHandle(
      this,
      GizmoAxis.y,
      position: Vector2(-5, -48),
      size: Vector2(10, 40),
      color: const Color(0xFF3DD68C),
    ),
    _GizmoHandle(
      this,
      GizmoAxis.free,
      position: Vector2(-6, -6),
      size: Vector2(12, 12),
      color: ViewportOverlay.selectionColor,
    ),
  ]);

  /// The overlay it belongs to.
  final ViewportOverlay overlay;

  /// Writes a move.
  final MoveNode onMove;

  PreviewComponent? _target;

  /// Whether a Node is selected, so the gizmo shows and takes drags.
  bool get active => _target != null;

  GizmoAxis? _axis;
  Object? _gesture;
  Vec2? _startPosition;
  final Vector2 _startWorld = Vector2.zero();
  final Vector2 _dragged = Vector2.zero();

  /// Puts the gizmo on [component]'s anchor at a constant screen size.
  void follow(PreviewComponent? component, double zoom) {
    _target = component;
    if (component == null) return;
    position.setFrom(component.absolutePosition);
    scale.setAll(1 / zoom);
  }

  /// Starts a drag along [axis]: one new gesture, one future undo step.
  void beginDrag(GizmoAxis axis) {
    final target = _target;
    final node = target == null
        ? null
        : overlay.tree.document?.node(target.nodeId);
    final start = node == null ? null : positionOf(node);
    if (start == null) return;
    _axis = axis;
    _gesture = Object();
    _startPosition = start;
    _startWorld.setFrom(position);
    _dragged.setZero();
  }

  /// Moves the dragged Node by [worldDelta] more, constrained to the
  /// drag's axis, converted into its parent's coordinates.
  void dragBy(Vector2 worldDelta) {
    final target = _target;
    final start = _startPosition;
    final gesture = _gesture;
    if (target == null || start == null || gesture == null) return;
    _dragged.add(worldDelta);
    final constrained = switch (_axis!) {
      GizmoAxis.x => Vector2(_dragged.x, 0),
      GizmoAxis.y => Vector2(0, _dragged.y),
      GizmoAxis.free => _dragged.clone(),
    };
    final parent = target.parent;
    final Vector2 local;
    if (parent is PositionComponent) {
      local =
          parent.absoluteToLocal(_startWorld + constrained) -
          parent.absoluteToLocal(_startWorld);
    } else {
      local = constrained;
    }
    onMove(target.nodeId, Vec2(start.x + local.x, start.y + local.y), gesture);
  }

  /// Ends the drag.
  void endDrag() {
    _axis = null;
    _gesture = null;
    _startPosition = null;
  }

  @override
  void renderTree(Canvas canvas) {
    if (active) super.renderTree(canvas);
  }
}

class _GizmoHandle extends PositionComponent with DragCallbacks {
  _GizmoHandle(
    this.gizmo,
    this.axis, {
    required super.position,
    required super.size,
    required Color color,
  }) : _paint = Paint()..color = color;

  final MoveGizmo gizmo;
  final GizmoAxis axis;
  final Paint _paint;

  @override
  bool containsLocalPoint(Vector2 point) =>
      gizmo.active && super.containsLocalPoint(point);

  @override
  void render(Canvas canvas) => canvas.drawRect(size.toRect(), _paint);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    gizmo.beginDrag(axis);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    gizmo.dragBy(event.canvasDelta / gizmo.overlay.game.camera.viewfinder.zoom);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    gizmo.endDrag();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    gizmo.endDrag();
  }
}
