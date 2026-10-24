import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart' show PrColors;

import 'disk_assets.dart';
import 'overlay.dart';
import 'preview/preview_component.dart';
import 'preview_tree.dart';

/// The viewport's camera: editor state outside the document (*Q25*), so
/// panning and zooming never dirty the Scene (FR-018).
final class EditorCamera {
  /// Creates the camera at [position] (the world point at the viewport's
  /// centre) and [zoom].
  const EditorCamera({this.position = Vec2.zero, this.zoom = 1});

  /// The world point at the viewport's centre.
  final Vec2 position;

  /// Screen pixels per world unit.
  final double zoom;

  /// The farthest out the wheel zooms.
  static const double minZoom = 0.05;

  /// The farthest in the wheel zooms.
  static const double maxZoom = 32;

  @override
  bool operator ==(Object other) =>
      other is EditorCamera && other.position == position && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(position, zoom);
}

/// Moves Node [id] to [position] in its parent, as one step of a drag:
/// every step of one drag shares [coalesceKey], so the drag is one undo
/// step (FR-020).
typedef MoveNode = void Function(NodeId id, Vec2 position, Object coalesceKey);

/// One open Scene's preview world (FR-016): Pyro's own Flame, drawing only
/// what the document, the catalog and the files on disk say — it never
/// imports or ticks the project's code (*Q7*).
///
/// Pan by dragging empty space or a Node, zoom with the wheel towards the
/// cursor, click to select the topmost Node (FR-018, FR-019); the move
/// gizmo lives in the [overlay] (FR-020, FR-022).
class EditorGame extends FlameGame<EditorWorld> {
  /// Creates the game of one Scene.
  EditorGame({
    required DiskAssetSource assets,
    required TypeCatalog catalog,
    required this.onSelect,
    required this.onMove,
    this.onCamera,
    EditorCamera camera = const EditorCamera(),
  }) : _initialCamera = camera,
       super(world: EditorWorld()) {
    tree = PreviewTree(world, assets: assets, catalog: catalog);
    overlay = ViewportOverlay(tree: tree, onMove: onMove);
  }

  /// The Scene's preview components.
  late final PreviewTree tree;

  /// The selection outline, hover highlight and move gizmo.
  late final ViewportOverlay overlay;

  /// Selects a Node, or nothing for null (FR-019).
  final void Function(NodeId? id) onSelect;

  /// Writes a gizmo move through the document (FR-020).
  final MoveNode onMove;

  /// Reports camera changes to the per-scene camera state.
  final void Function(EditorCamera camera)? onCamera;

  final EditorCamera _initialCamera;

  /// The editor canvas behind the world: the theme's viewport colour (no
  /// `BuildContext` reaches the game).
  static final Color canvasColor = PrColors.dark.bgViewport;

  @override
  Color backgroundColor() => canvasColor;

  @override
  Future<void> onLoad() async {
    showCamera(_initialCamera);
    camera.viewfinder.add(overlay);
  }

  /// The camera now.
  EditorCamera get editorCamera {
    final viewfinder = camera.viewfinder;
    return EditorCamera(
      position: Vec2(viewfinder.position.x, viewfinder.position.y),
      zoom: viewfinder.zoom,
    );
  }

  /// Puts the camera at [value] without reporting it.
  void showCamera(EditorCamera value) {
    camera.viewfinder
      ..position = Vector2(value.position.x, value.position.y)
      ..zoom = value.zoom.clamp(EditorCamera.minZoom, EditorCamera.maxZoom);
  }

  /// Pans by [canvasDelta] screen pixels: the world follows the pointer.
  void panBy(Vector2 canvasDelta) {
    camera.viewfinder.position -= canvasDelta / camera.viewfinder.zoom;
    onCamera?.call(editorCamera);
  }

  /// Zooms by [factor] keeping the world point under [canvasPoint] where it
  /// is (zoom-to-cursor), clamped to the zoom range.
  void zoomAt(Vector2 canvasPoint, double factor) {
    final viewfinder = camera.viewfinder;
    final before = camera.globalToLocal(canvasPoint);
    viewfinder.zoom = (viewfinder.zoom * factor).clamp(
      EditorCamera.minZoom,
      EditorCamera.maxZoom,
    );
    final after = camera.globalToLocal(canvasPoint);
    viewfinder.position += before - after;
    onCamera?.call(editorCamera);
  }

  /// The topmost Node under [worldPoint], or null. An entity group has no
  /// area of its own, so a click lands on what it draws (its sprite or
  /// hitbox); the hierarchy selects the entity itself.
  NodeId? pick(Vector2 worldPoint) {
    for (final component in world.componentsAtPoint(worldPoint)) {
      if (component is PreviewComponent) return component.nodeId;
    }
    return null;
  }
}

/// The world of an [EditorGame]: it takes the pointer wherever the overlay
/// doesn't — clicks select, drags pan, the wheel zooms, hovering
/// highlights.
class EditorWorld extends World
    with
        HasGameReference<EditorGame>,
        TapCallbacks,
        DragCallbacks,
        ScrollCallbacks,
        PointerMoveCallbacks {
  /// How strongly one wheel pixel zooms.
  static const double wheelZoomRate = 0.002;

  @override
  void onTapUp(TapUpEvent event) {
    game.onSelect(game.pick(event.localPosition));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    game.panBy(event.canvasDelta);
  }

  @override
  void onScroll(ScrollEvent event) {
    game.zoomAt(
      event.canvasPosition,
      math.exp(-event.scrollDelta.y * wheelZoomRate),
    );
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    game.overlay.hovered = game.pick(event.localPosition);
  }
}
