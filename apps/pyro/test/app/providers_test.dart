import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file/memory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../document/helpers/scenes.dart';

void main() {
  late MemoryFileSystem fs;
  late ProviderContainer container;
  late SessionServices services;

  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/proj/assets/scenes').createSync(recursive: true);
    fs.directory('/recovery').createSync(recursive: true);
    fs
        .file('/proj/assets/scenes/level1.scene.json')
        .writeAsStringSync(SceneCodec.encode(smallScene()));
    services = SessionServices(
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
  });

  Future<DocumentNotifier> open() async {
    final session = await DocumentSession.open(
      '/proj/assets/scenes/level1.scene.json',
      services: services,
    );
    // The open-scene command's registration, before the first read.
    container
        .read(sessionRegistryProvider.notifier)
        .register('level1', session);
    container
        .read(openScenesProvider.notifier)
        .open(
          const OpenScene(
            sceneId: 'level1',
            path: '/proj/assets/scenes/level1.scene.json',
            displayName: 'level1',
          ),
        );
    return container.read(documentProvider('level1').notifier);
  }

  group('documentProvider (T010, FR-002, FR-006)', () {
    test('open → transact → dirty → undo → clean', () async {
      final notifier = await open();
      final view = container.read(documentProvider('level1'));
      expect(view.isDirty, isFalse);
      expect(view.canUndo, isFalse);

      final entity = view.document.node(view.document.rootId)!;
      notifier.transact('Add entity', (doc) {
        return doc.addNode(
          EntityNode(
            id: const NodeId('new-entity'),
            name: 'new entity',
            transform: NodeTransform(),
          ),
          parentId: doc.rootId,
        );
      });
      final dirty = container.read(documentProvider('level1'));
      expect(dirty.isDirty, isTrue);
      expect(dirty.canUndo, isTrue);
      expect(dirty.document.contains(const NodeId('new-entity')), isTrue);
      expect(
        identical(dirty.document.node(view.document.rootId), entity),
        isFalse,
      ); // the root gained a child

      notifier.undo();
      final undone = container.read(documentProvider('level1'));
      expect(undone.isDirty, isFalse);
      expect(undone.document.contains(const NodeId('new-entity')), isFalse);
    });

    test('opening an already-open scene focuses its tab', () async {
      await open();
      final before = container.read(openScenesProvider).scenes.length;
      container
          .read(openScenesProvider.notifier)
          .open(
            const OpenScene(
              sceneId: 'level1',
              path: '/proj/assets/scenes/level1.scene.json',
              displayName: 'level1',
            ),
          );
      expect(container.read(openScenesProvider).scenes.length, before);
      expect(container.read(openScenesProvider).active, 'level1');
    });

    test(
      'the session closes when the provider disposes (close flow)',
      () async {
        final notifier = await open();
        final subscription = container.listen(
          documentProvider('level1'),
          (_, _) {},
        );
        final session = notifier.session;
        expect(session.isClosed, isFalse);
        // The tab widget unmounting and nothing pinning the provider: the
        // subscription is the last listener.
        subscription.close();
        await pumpEventQueue();
        expect(session.isClosed, isTrue);
      },
    );

    test('a sceneId without a session fails with a named error', () {
      expect(
        () => container.read(documentProvider('missing')),
        throwsA(
          predicate((e) => '$e'.contains('No session registered for scene')),
        ),
      );
    });

    test(
      'selectionProvider holds one NodeId outside the document (FR-011)',
      () async {
        await open();
        final selection = container.read(selectionProvider('level1').notifier);
        expect(container.read(selectionProvider('level1')), isNull);
        selection.select(const NodeId('a'));
        expect(container.read(selectionProvider('level1')), const NodeId('a'));
        // The document was never touched.
        expect(container.read(documentProvider('level1')).isDirty, isFalse);
      },
    );

    test(
      'nodeProvider returns the Node itself and skips unchanged rows',
      () async {
        final notifier = await open();
        final doc = container.read(documentProvider('level1')).document;
        final a = doc.node(const NodeId('a'))!;
        expect(
          container.read(nodeProvider(('level1', const NodeId('a')))),
          same(a),
        );
        // An edit far from `a` still yields the identical Node instance
        // (structural sharing), so == filtering skips its listeners.
        notifier.transact('Rename b', (d) {
          final b = d.node(const NodeId('b'))! as EntityNode;
          return d.replaceNode(b.copyWith(name: 'renamed'));
        });
        expect(
          container.read(nodeProvider(('level1', const NodeId('a')))),
          same(a),
        );
      },
    );
  });

  group('OpenScenesState.close (T013, FR-008)', () {
    OpenScene tab(String id) => OpenScene(
      sceneId: id,
      path: null,
      displayName: id,
    );

    OpenScenesState openabc() =>
        const OpenScenesState(scenes: IList<OpenScene>.empty())
            .open(tab('a'))
            .open(tab('b'))
            .open(tab('c'));

    test('closing the active tab activates its left neighbour', () {
      final state = openabc().focus('b').close('b');
      expect(state.scenes.map((s) => s.sceneId), ['a', 'c']);
      expect(state.active, 'a');
    });

    test('closing the active first tab activates the new first', () {
      final state = openabc().focus('a').close('a');
      expect(state.active, 'b');
    });

    test('closing the last tab clears the active', () {
      final state = openabc().focus('b').close('a').close('b').close('c');
      expect(state.scenes, isEmpty);
      expect(state.active, isNull);
    });

    test('closing an inactive tab keeps the active', () {
      final state = openabc().focus('c').close('a');
      expect(state.active, 'c');
    });
  });
}
