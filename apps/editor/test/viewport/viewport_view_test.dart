import 'dart:io' show FileSystemEvent;

import 'package:file/memory.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro/viewport/viewport.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../document/helpers/scenes.dart';

void main() {
  testWidgets('the game is clipped to its panel (FR-015)', (tester) async {
    final fs = MemoryFileSystem.test();
    fs.directory('/proj/assets/scenes').createSync(recursive: true);
    fs.directory('/recovery').createSync(recursive: true);
    fs
        .file('/proj/assets/scenes/level1.scene.json')
        .writeAsStringSync(SceneCodec.encode(smallScene()));
    final session = await DocumentSession.open(
      '/proj/assets/scenes/level1.scene.json',
      services: SessionServices(
        files: SceneFiles(fileSystem: fs, offload: runInline),
        recovery: RecoveryStore(
          folder: '/recovery',
          fileSystem: fs,
          offload: runInline,
        ),
        projectRoot: '/proj',
        newId: counterIds(),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        assetFileSystemProvider.overrideWithValue(fs),
        assetWatchProvider.overrideWithValue(
          (_) => const Stream<FileSystemEvent>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
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
    container
        .read(sessionRegistryProvider.notifier)
        .register('level1', session);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: UncontrolledProviderScope(
          container: container,
          child: const SizedBox(
            width: 300,
            height: 200,
            child: SceneViewport(sceneId: 'level1', visible: true),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(ClipRect),
        matching: find.byType(GameWidget<EditorGame>),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await session.discardAndClose();
    await tester.pump(const Duration(seconds: 1));
  });
}
