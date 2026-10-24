import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file/memory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro/viewport/viewport.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../document/helpers/scenes.dart';

/// A world that records what the wiring applies.
final class RecordingWorld implements PreviewWorld {
  final List<PreviewOp> ops = [];
  int clears = 0;
  int catalogs = 0;

  @override
  void apply(IList<PreviewOp> ops, SceneDocument document) =>
      this.ops.addAll(ops);

  @override
  void clear() {
    clears++;
    ops.clear();
  }

  @override
  void catalogChanged(TypeCatalog catalog) => catalogs++;

  @override
  void assetsChanged(Set<AssetPath> paths) {}
}

void main() {
  late ProviderContainer container;
  late RecordingWorld world;
  late PreviewBinding binding;
  late DocumentNotifier document;
  const level = 'level1';

  setUp(() async {
    final fs = MemoryFileSystem.test();
    fs.directory('/proj/assets/scenes').createSync(recursive: true);
    fs.directory('/recovery').createSync(recursive: true);
    fs
        .file('/proj/assets/scenes/level1.scene.json')
        .writeAsStringSync(SceneCodec.encode(smallScene()));
    final services = SessionServices(
      files: SceneFiles(fileSystem: fs, offload: runInline),
      recovery: RecoveryStore(
        folder: '/recovery',
        fileSystem: fs,
        offload: runInline,
      ),
      projectRoot: '/proj',
      newId: counterIds(),
    );
    container = ProviderContainer();
    addTearDown(container.dispose);
    final session = await DocumentSession.open(
      '/proj/assets/scenes/level1.scene.json',
      services: services,
    );
    container.read(sessionRegistryProvider.notifier).register(level, session);
    world = RecordingWorld();
    binding = PreviewBinding(level, world);
    document = container.read(documentProvider(level).notifier);
  });

  SceneDocument current() => container.read(documentProvider(level)).document;

  ProviderSubscription<void> watch() =>
      container.listen(previewSyncProvider(binding), (_, _) {});

  test('the first listen seeds the world from the current document', () {
    watch();
    expect(world.ops, [
      AddNode(
        current().node(const NodeId('a'))!,
        parentId: const NodeId('root'),
        index: 0,
      ),
      AddNode(
        current().node(const NodeId('b'))!,
        parentId: const NodeId('root'),
        index: 1,
      ),
    ]);
  });

  test('a patch, a move and a remove each reach the world as one op', () {
    watch();
    world.ops.clear();
    document.transact('Rename', (doc) {
      final a = doc.node(const NodeId('a'))! as EntityNode;
      return doc.replaceNode(a.copyWith(name: 'A'));
    });
    expect(world.ops, [const PatchNode(NodeId('a'))]);
    world.ops.clear();
    document.transact(
      'Move',
      (doc) => doc.moveNode(const NodeId('b'), parentId: const NodeId('a')),
    );
    expect(world.ops, [
      const ReparentNode(NodeId('b'), parentId: NodeId('a'), index: 1),
    ]);
    world.ops.clear();
    document.transact('Delete', (doc) => doc.removeNode(const NodeId('a')));
    expect(world.ops, [const RemoveNode(NodeId('a'))]);
  });

  test('disposing clears the world; invalidating re-seeds it', () async {
    final subscription = watch();
    container.invalidate(previewSyncProvider(binding));
    container.read(previewSyncProvider(binding));
    expect(world.clears, 1);
    expect(world.ops.whereType<AddNode>(), hasLength(2));
    subscription.close();
    await container.pump(); // autoDispose runs after the frame
    expect(world.clears, 2);
  });

  test('a drag — transacts sharing one coalesceKey — is one undo step '
      '(SC-009)', () {
    watch();
    world.ops.clear();
    final before = current();
    final coalesceKey = Object();
    for (var x = 1; x <= 5; x++) {
      document.transact('Move a', (doc) {
        final a = doc.node(const NodeId('a'))!;
        return doc.replaceNode(withPosition(a, Vec2(x * 10.0, 0)));
      }, coalesceKey: coalesceKey);
    }
    expect(positionOf(current().node(const NodeId('a'))!), const Vec2(50, 0));
    expect(world.ops, everyElement(const PatchNode(NodeId('a'))));
    document.undo();
    expect(identical(current(), before), isTrue);
    expect(container.read(documentProvider(level)).canUndo, isFalse);
  });

  test('moving the camera never dirties the Scene (FR-018, Q25)', () {
    watch();
    container
        .read(editorCameraProvider(level).notifier)
        .set(const EditorCamera(position: Vec2(100, 50), zoom: 2));
    expect(
      container.read(editorCameraProvider(level)),
      const EditorCamera(position: Vec2(100, 50), zoom: 2),
    );
    expect(container.read(documentProvider(level)).isDirty, isFalse);
  });
}
