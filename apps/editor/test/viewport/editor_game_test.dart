import 'dart:io' show FileSystemEvent;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file/memory.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro/viewport/viewport.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../document/helpers/scenes.dart';

/// root → a (scaled ×2, at 100,0) → hitbox h (10×10 at 0,0); b (10×10 hitbox
/// at 0,0, on top of nothing).
SceneDocument layered() => SceneDocument.fromScene(
  Scene(
    rootId: const NodeId('root'),
    nodes: {
      const NodeId('root'): RootNode(
        id: const NodeId('root'),
        childIds: const [NodeId('a'), NodeId('low'), NodeId('high')],
      ),
      const NodeId('a'): EntityNode(
        id: const NodeId('a'),
        name: 'a',
        childIds: const [NodeId('h')],
        transform: NodeTransform(
          position: const Vec2(100, 0),
          scale: const Vec2(2, 2),
        ),
      ),
      const NodeId('h'): RectangleHitboxNode(
        id: const NodeId('h'),
        size: const Vec2(10, 10),
      ),
      const NodeId('low'): RectangleHitboxNode(
        id: const NodeId('low'),
        position: const Vec2(-50, -50),
        size: const Vec2(20, 20),
      ),
      const NodeId('high'): RectangleHitboxNode(
        id: const NodeId('high'),
        position: const Vec2(-45, -45),
        size: const Vec2(20, 20),
      ),
    },
  ),
);

void main() {
  late List<NodeId?> selected;
  late List<(NodeId, Vec2, Object)> moves;
  late List<EditorCamera> cameras;

  EditorGame create() {
    selected = [];
    moves = [];
    cameras = [];
    return EditorGame(
      assets: DiskAssetSource(
        fileSystem: MemoryFileSystem.test(),
        root: '/project',
        watch: (_) => const Stream<FileSystemEvent>.empty(),
      ),
      catalog: TypeCatalog(
        types: IMap({for (final type in builtInTypes) type.id: type}),
        problems: const IList.empty(),
        origin: const ManifestAbsent(),
      ),
      onSelect: selected.add,
      onMove: (id, position, gesture) => moves.add((id, position, gesture)),
      onCamera: cameras.add,
    );
  }

  Future<void> seed(EditorGame game, SceneDocument doc) async {
    game.tree.apply(reconcile(null, doc), doc);
    await game.ready();
  }

  testWithGame<EditorGame>(
    'the tree builds, moves and removes components',
    create,
    (game) async {
      final doc = SceneDocument.fromScene(smallScene());
      await seed(game, doc);
      expect(game.tree.length, 3);
      final a1 = game.tree.componentOf(const NodeId('a1'))!;
      expect(a1.parent, game.tree.componentOf(const NodeId('a')));

      final moved = doc.moveNode(
        const NodeId('a1'),
        parentId: const NodeId('b'),
      );
      game.tree.apply(reconcile(doc, moved), moved);
      await game.ready();
      expect(
        identical(game.tree.componentOf(const NodeId('a1')), a1),
        isTrue,
        reason: 'a reparent keeps the component',
      );
      expect(a1.parent, game.tree.componentOf(const NodeId('b')));

      final removed = moved.removeNode(const NodeId('b'));
      game.tree.apply(reconcile(moved, removed), removed);
      await game.ready();
      expect(game.tree.componentOf(const NodeId('a1')), isNull);
      expect(game.tree.length, 1);
    },
  );

  testWithGame<EditorGame>(
    'later children draw on top, in childIds order',
    create,
    (game) async {
      final doc = layered();
      await seed(game, doc);
      final reordered = doc.moveNode(
        const NodeId('high'),
        parentId: doc.rootId,
        index: 0,
      );
      game.tree.apply(reconcile(doc, reordered), reordered);
      await game.ready();
      expect(game.tree.componentOf(const NodeId('high'))!.priority, 0);
      expect(game.tree.componentOf(const NodeId('a'))!.priority, 1);
      expect(game.tree.componentOf(const NodeId('low'))!.priority, 2);
    },
  );

  testWithGame<EditorGame>('picking finds the topmost Node, or none', create, (
    game,
  ) async {
    await seed(game, layered());
    expect(game.pick(Vector2(-40, -40)), const NodeId('high'));
    expect(game.pick(Vector2(-48, -48)), const NodeId('low'));
    expect(
      game.pick(Vector2(115, 15)),
      const NodeId('h'),
      reason: 'inside the scaled parent',
    );
    expect(game.pick(Vector2(500, 500)), isNull);
  });

  testWithGame<EditorGame>('zooming keeps the point under the cursor', create, (
    game,
  ) async {
    await game.ready();
    final cursor = Vector2(600, 150);
    final before = game.camera.globalToLocal(cursor);
    game.zoomAt(cursor, 2.5);
    expect(game.camera.viewfinder.zoom, 2.5);
    final after = game.camera.globalToLocal(cursor);
    expect(after.x, closeTo(before.x, 1e-9));
    expect(after.y, closeTo(before.y, 1e-9));
    game.zoomAt(cursor, 1e6);
    expect(game.camera.viewfinder.zoom, EditorCamera.maxZoom);
    expect(cameras, isNotEmpty);
  });

  testWithGame<EditorGame>(
    'panning moves the camera against the drag',
    create,
    (game) async {
      await game.ready();
      game.zoomAt(game.size / 2, 2);
      game.panBy(Vector2(20, -10));
      expect(game.camera.viewfinder.position, Vector2(-10, 5));
      expect(cameras.last.position, const Vec2(-10, 5));
    },
  );

  testWithGame<EditorGame>(
    'a gizmo drag is one gesture, constrained to its axis',
    create,
    (game) async {
      await seed(game, layered());
      game.overlay.select(const NodeId('low'));
      game.update(0);
      final gizmo = game.overlay.gizmo;
      expect(gizmo.active, isTrue);
      expect(gizmo.position, Vector2(-50, -50));

      gizmo
        ..beginDrag(GizmoAxis.x)
        ..dragBy(Vector2(5, 7))
        ..dragBy(Vector2(5, 7))
        ..endDrag();
      expect(moves.map((m) => m.$2), [
        const Vec2(-45, -50),
        const Vec2(-40, -50),
      ]);
      expect(
        moves.map((m) => m.$3).toSet(),
        hasLength(1),
        reason: 'one coalesceKey per drag',
      );

      gizmo
        ..beginDrag(GizmoAxis.free)
        ..dragBy(Vector2(1, 2));
      expect(moves.last.$2, const Vec2(-49, -48));
      expect(
        identical(moves.last.$3, moves.first.$3),
        isFalse,
        reason: 'a new drag is a new gesture',
      );
    },
  );

  testWithGame<EditorGame>(
    'a gizmo drag under a scaled parent moves in its '
    'parent\'s units',
    create,
    (game) async {
      await seed(game, layered());
      game.overlay.select(const NodeId('h'));
      game.update(0);
      game.overlay.gizmo
        ..beginDrag(GizmoAxis.y)
        ..dragBy(Vector2(0, 20));
      expect(moves.single.$2, const Vec2(0, 10));
    },
  );

  testWithGame<EditorGame>('no selection, no gizmo', create, (game) async {
    await seed(game, layered());
    game.overlay.select(null);
    game.update(0);
    expect(game.overlay.gizmo.active, isFalse);
  });
}
