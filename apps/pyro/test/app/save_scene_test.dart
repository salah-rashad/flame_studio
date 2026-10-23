import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../document/helpers/scenes.dart';
import '../helpers/fixtures.dart';

const scenePath = '/proj/assets/scenes/level1.scene.json';

void main() {
  late MemoryFileSystem fs;
  late ProviderContainer container;
  late OpenSceneCommand command;

  RuntimeCompatibility compatibilityFor(RuntimeCompatStatus status) =>
      RuntimeCompatibility(
        status: status,
        foundVersion: '0.0.1',
        readsUpTo: status == RuntimeCompatStatus.ok ? 1 : null,
      );

  String activeSceneId() => container.read(openScenesProvider).active!;

  ProviderContainer openProject({RuntimeCompatibility? compatibility}) {
    final c = ProviderContainer();
    c
        .read(projectProvider.notifier)
        .open(
          ProjectState(
            root: '/proj',
            sdk: SdkInfo.none,
            compatibility:
                compatibility ?? compatibilityFor(RuntimeCompatStatus.ok),
          ),
        );
    return c;
  }

  Future<void> pumpHost(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: PrTheme.dark(),
      home: UncontrolledProviderScope(
        container: container,
        child: Material(color: PrColors.dark.surfacePanel, child: child),
      ),
    ),
  );

  /// The button the tests drive `saveScene` through.
  Widget saveButton() => Builder(
    builder: (context) => TextButton(
      onPressed: () => saveScene(
        context,
        container,
        sceneId: activeSceneId(),
        command: command,
        fileSystem: fs,
      ),
      child: const Text('save'),
    ),
  );

  Future<void> openLevel1() async {
    final session = await command.open(scenePath);
    command.register(
      container,
      sceneId: scenePath,
      session: session,
      displayName: 'level1',
      path: scenePath,
    );
    // Keeps the autoDispose family alive for the test's duration.
    container.listen(documentProvider(scenePath), (_, _) {});
    session.transact('Add entity', (doc) {
      return doc.addNode(
        EntityNode(
          id: const NodeId('extra'),
          name: 'extra',
          transform: NodeTransform(),
        ),
        parentId: doc.rootId,
      );
    });
  }

  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/proj/assets/scenes').createSync(recursive: true);
    fs.directory('/recovery').createSync(recursive: true);
    fs.file('/proj/pubspec.yaml').writeAsStringSync(pubspecDeclaredFolders);
    fs.file(scenePath).writeAsStringSync(SceneCodec.encode(smallScene()));
    command = OpenSceneCommand(
      projectRoot: '/proj',
      recoveryFolder: '/recovery',
      fileSystem: fs,
      offload: runInline,
    );
  });

  /// Closes every open session *inside the test body*: each session's
  /// recovery timer must be cancelled before the binding's end-of-test
  /// pending-timer check, which runs before `tearDown`.
  Future<void> closeAll() async {
    for (final session in container.read(sessionRegistryProvider).values) {
      if (!session.isClosed) await session.discardAndClose();
    }
  }

  tearDown(() => container.dispose());

  testWidgets('saves a named scene and clears the dirty mark', (tester) async {
    container = openProject();
    await openLevel1();
    await pumpHost(tester, saveButton());

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(container.read(documentProvider(scenePath)).isDirty, isFalse);
    expect(fs.file(scenePath).readAsStringSync(), contains('extra'));
    await closeAll();
  });

  testWidgets('a first save asks for name and folder (FR-008)', (tester) async {
    container = openProject();
    final session = command.create();
    command.register(
      container,
      sceneId: 'new-1',
      session: session,
      displayName: 'untitled',
    );
    container.listen(documentProvider('new-1'), (_, _) {});
    await pumpHost(tester, saveButton());

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    expect(find.text('New Scene'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(PrTextField, 'Scene name'),
      'bonus',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    const saved = '/proj/assets/scenes/bonus.scene.json';
    expect(fs.file(saved).existsSync(), isTrue);
    // The tab moved to the saved path as its sceneId.
    expect(container.read(openScenesProvider).active, saved);
    expect(container.read(openScenesProvider).scenes.first.path, saved);
    expect(container.read(documentProvider(saved)).isDirty, isFalse);
    await closeAll();
  });

  testWidgets('a first save rename keeps the session alive (⌘S/⌘Z)', (
    tester,
  ) async {
    container = openProject();
    final session = command.create();
    command.register(
      container,
      sceneId: 'new-1',
      session: session,
      displayName: 'untitled',
    );
    session.transact('Add entity', (doc) {
      return doc.addNode(
        EntityNode(
          id: const NodeId('extra'),
          name: 'extra',
          transform: NodeTransform(),
        ),
        parentId: doc.rootId,
      );
    });
    // The tab strip's watch on the untitled key; the rename moves it to
    // the saved path, so this key's provider is the one left to dispose.
    final link = container.listen(documentProvider('new-1'), (_, _) {});
    await pumpHost(tester, saveButton());

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(PrTextField, 'Scene name'),
      'bonus2',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // The last watch on the untitled key goes; its provider's last-resort
    // close must not reach the session now living under the saved path.
    link.close();
    await tester.pumpAndSettle();

    // The exact calls the ⌘Z and ⌘S shortcuts make on the renamed tab:
    // both threw "Scene … is closed" before the registry-owns guard.
    const saved = '/proj/assets/scenes/bonus2.scene.json';
    expect(container.read(documentProvider(saved)).canUndo, isTrue);
    container.read(documentProvider(saved).notifier).undo();
    expect(container.read(documentProvider(saved)).isDirty, isTrue);
    expect(
      () => container.read(documentProvider(saved).notifier).session,
      returnsNormally,
    );
    await closeAll();
  });

  testWidgets('a changed-on-disk refusal offers Overwrite (*Q95*)', (
    tester,
  ) async {
    container = openProject();
    await openLevel1();
    fs
        .file(scenePath)
        .writeAsStringSync(
          SceneCodec.encode(smallScene()).replaceAll('"b"', '"b-changed"'),
        );
    await pumpHost(tester, saveButton());

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    expect(find.text('The Scene file changed on disk'), findsOneWidget);

    await tester.tap(find.text('Overwrite'));
    await tester.pumpAndSettle();

    expect(container.read(documentProvider(scenePath)).isDirty, isFalse);
    expect(fs.file(scenePath).readAsStringSync(), contains('extra'));
    await closeAll();
  });

  testWidgets('an unknown Runtime blocks the save (*Q98*)', (tester) async {
    container = openProject(
      compatibility: compatibilityFor(RuntimeCompatStatus.unknown),
    );
    await openLevel1();
    await pumpHost(tester, saveButton());

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(find.text('The Scene was not saved'), findsOneWidget);
    expect(find.textContaining("isn't known yet"), findsOneWidget);
    expect(container.read(documentProvider(scenePath)).isDirty, isTrue);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await closeAll();
  });
}
