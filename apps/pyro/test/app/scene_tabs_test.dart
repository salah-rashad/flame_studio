import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../document/helpers/scenes.dart';

const scenePath = '/proj/assets/scenes/level1.scene.json';

void main() {
  late MemoryFileSystem fs;
  late ProviderContainer container;
  late OpenSceneCommand command;

  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/proj/assets/scenes').createSync(recursive: true);
    fs.directory('/recovery').createSync(recursive: true);
    fs.file(scenePath).writeAsStringSync(SceneCodec.encode(smallScene()));
    command = OpenSceneCommand(
      projectRoot: '/proj',
      recoveryFolder: '/recovery',
      fileSystem: fs,
      offload: runInline,
    );
    container = ProviderContainer();
    container
        .read(projectProvider.notifier)
        .open(
          const ProjectState(
            root: '/proj',
            sdk: SdkInfo.none,
            compatibility: RuntimeCompatibility(
              status: RuntimeCompatStatus.ok,
              foundVersion: '0.0.1',
              readsUpTo: 1,
            ),
          ),
        );
    addTearDown(container.dispose);
  });

  Future<void> pumpTabs(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: PrTheme.dark(),
      home: UncontrolledProviderScope(
        container: container,
        child: Material(
          color: PrColors.dark.surfacePanel,
          child: SceneTabs(command: command),
        ),
      ),
    ),
  );

  /// Opens level1 dirty and returns nothing; the tab is selected.
  Future<void> openDirty() async {
    final session = await command.open(scenePath);
    command.register(
      container,
      sceneId: scenePath,
      session: session,
      displayName: 'level1',
      path: scenePath,
    );
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

  /// Closes every session inside the test body, so no recovery timer's
  /// FakeTimer outlives the binding's pending-timer check.
  Future<void> closeAll() async {
    for (final session in container.read(sessionRegistryProvider).values) {
      if (!session.isClosed) await session.discardAndClose();
    }
  }

  testWidgets('a clean scene closes without a dialog', (tester) async {
    final session = await command.open(scenePath);
    command.register(
      container,
      sceneId: scenePath,
      session: session,
      displayName: 'level1',
      path: scenePath,
    );
    container.listen(documentProvider(scenePath), (_, _) {});
    await pumpTabs(tester);
    expect(find.text('level1'), findsOneWidget);

    await tester.tap(find.byIcon(PrIcons.x));
    await tester.pumpAndSettle();

    expect(find.text('Save changes'), findsNothing);
    expect(find.text('No scene open'), findsOneWidget);
    expect(session.isClosed, isTrue);
  });

  testWidgets('a dirty scene asks, and Discard closes it (FR-007)', (
    tester,
  ) async {
    await openDirty();
    await pumpTabs(tester);

    await tester.tap(find.byIcon(PrIcons.x));
    await tester.pumpAndSettle();
    expect(find.text('Save changes to "level1"?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('No scene open'), findsOneWidget);
    expect(
      container.read(sessionRegistryProvider).containsKey(scenePath),
      isFalse,
    );
    // The project stays open (spec Edge Cases): the tab model is empty,
    // the window is not.
    expect(container.read(projectProvider), isNotNull);
    await closeAll();
  });

  testWidgets('Cancel keeps the dirty scene open', (tester) async {
    await openDirty();
    await pumpTabs(tester);

    await tester.tap(find.byIcon(PrIcons.x));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('level1'), findsOneWidget);
    expect(container.read(documentProvider(scenePath)).isDirty, isTrue);
    await closeAll();
  });

  testWidgets('Save saves and closes the tab', (tester) async {
    await openDirty();
    await pumpTabs(tester);

    await tester.tap(find.byIcon(PrIcons.x));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('No scene open'), findsOneWidget);
    expect(fs.file(scenePath).readAsStringSync(), contains('extra'));
    expect(
      container.read(sessionRegistryProvider).containsKey(scenePath),
      isFalse,
    );
  });
}
