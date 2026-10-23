import 'package:file/memory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/document/src/recovery_store.dart' show RecoveryWriting;
import 'package:pyro_runtime/pyro_runtime.dart';

import '../document/helpers/fixtures.dart';
import '../document/helpers/scenes.dart';

void main() {
  const projectRoot = '/proj';
  const scenePath = '/proj/assets/scenes/level1.scene.json';

  late MemoryFileSystem fs;
  late ProviderContainer container;
  late OpenSceneCommand command;

  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/proj/assets/scenes').createSync(recursive: true);
    fs.directory('/recovery').createSync(recursive: true);
    fs.file(scenePath).writeAsStringSync(SceneCodec.encode(smallScene()));
    command = OpenSceneCommand(
      projectRoot: projectRoot,
      recoveryFolder: '/recovery',
      fileSystem: fs,
      offload: runInline,
    );
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> register(String sceneId, DocumentSession session) async {
    command.register(
      container,
      sceneId: sceneId,
      session: session,
      displayName: 'level1',
      path: scenePath,
    );
    // Reading the family builds the provider around the session.
    container.listen(documentProvider(sceneId), (_, _) {});
    await pumpEventQueue();
  }

  test('a planted recovery copy is offered before opening (FR-009)', () async {
    expect(await command.checkRecovery(scenePath), isA<NoRecovery>());

    final dirty = SceneDocument.fromScene(smallScene()).replaceNode(
      (smallScene().nodes[const NodeId('b')]! as EntityNode).copyWith(
        name: 'renamed',
      ),
    );
    await command.services.recovery.write(
      projectRoot: projectRoot,
      scenePath: scenePath,
      state: dirty,
    );

    final check = await command.checkRecovery(scenePath);
    expect(check, isA<RecoveryAvailable>());
    expect((check as RecoveryAvailable).info.scenePath, scenePath);
  });

  test('restore opens the recovery copy dirty (FR-028)', () async {
    final dirty = SceneDocument.fromScene(smallScene()).replaceNode(
      (smallScene().nodes[const NodeId('b')]! as EntityNode).copyWith(
        name: 'renamed',
      ),
    );
    await command.services.recovery.write(
      projectRoot: projectRoot,
      scenePath: scenePath,
      state: dirty,
    );
    final info =
        (await command.checkRecovery(scenePath) as RecoveryAvailable).info;

    final session = await command.open(scenePath, restore: info);
    expect(session.state.origin, OpenedFrom.restored);
    expect(session.state.isDirty, isTrue);
    expect(
      (session.state.state.node(const NodeId('b')) as EntityNode).name,
      'renamed',
    );
  });

  test('a hand-broken tree opens dirty with a repair report (*Q96*)', () async {
    fs
        .file(scenePath)
        .writeAsBytesSync(
          readFixtureBytes('damaged/cycle_reachable.scene.json'),
        );
    final session = await command.open(scenePath);
    expect(session.state.origin, OpenedFrom.repaired);
    expect(session.state.isDirty, isTrue);
    expect(session.state.repairs.isEmpty, isFalse);
    expect(session.state.repairs.describe(), isNotEmpty);
  });

  test('a newer schemaVersion names the required version (*Q49*)', () async {
    fs
        .file(scenePath)
        .writeAsBytesSync(readFixtureBytes('version/newer.scene.json'));
    await expectLater(
      command.open(scenePath),
      throwsA(
        isA<SceneOpenFailed>().having(
          (e) => e.cause,
          'cause',
          isA<UnsupportedSchemaVersion>(),
        ),
      ),
    );
  });

  test('register opens the tab and re-registering focuses it', () async {
    final session = await command.open(scenePath);
    await register(scenePath, session);
    expect(container.read(openScenesProvider).active, scenePath);

    command.register(
      container,
      sceneId: scenePath,
      session: session,
      displayName: 'level1',
      path: scenePath,
    );
    expect(container.read(openScenesProvider).scenes.length, 1);
    expect(container.read(openScenesProvider).active, scenePath);
  });

  test('create starts a clean untitled Scene with one root Node (FR-008)', () {
    final session = command.create();
    expect(session.state.origin, OpenedFrom.created);
    expect(session.state.isDirty, isFalse);
    expect(session.state.path, isNull);
    final doc = session.state.state;
    expect(doc.nodes.length, 1);
    expect(doc.node(doc.rootId), isA<RootNode>());
  });
}
