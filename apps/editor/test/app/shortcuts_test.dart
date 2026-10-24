import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../document/helpers/scenes.dart';

void main() {
  late MemoryFileSystem fs;
  late ProviderContainer container;
  late OpenSceneCommand command;

  setUp(() {
    fs = MemoryFileSystem.test();
    fs.directory('/proj/assets/scenes').createSync(recursive: true);
    fs.directory('/recovery').createSync(recursive: true);
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
            compatibility: RuntimeCompatibility.unknown,
          ),
        );
    addTearDown(container.dispose);
  });

  /// Pumps the editor window as `PyroApp` hosts it, with nothing clicked
  /// or tabbed to afterwards.
  Future<void> pumpWindow(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PrTheme.dark(),
        home: UncontrolledProviderScope(
          container: container,
          child: PyroEditorWindow(
            command: command,
            settings: RecentProjectsStore(
              fs.file('/support/recent_projects.json'),
              fileSystem: fs,
            ),
            tabs: SceneTabs(command: command),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Unmounts the window and drops the container inside the test body, so
  /// the sessions' and the catalog's timers are cancelled before the
  /// binding checks for pending ones.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(minutes: 1));
  }

  Future<void> commandN(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
  }

  group('PyroShortcuts focus (T016, FR-007)', () {
    testWidgets('⌘N works as soon as the window shows', (tester) async {
      await pumpWindow(tester);

      await commandN(tester);

      final scenes = container.read(openScenesProvider);
      expect(scenes.scenes.map((s) => s.displayName), ['untitled']);
      expect(find.text('untitled'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a click on empty space keeps the shortcuts working', (
      tester,
    ) async {
      await pumpWindow(tester);
      // Drop focus out of the window's content, as a click that clears it
      // would, then click the empty title bar.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tapAt(const Offset(400, 10));
      await tester.pumpAndSettle();

      await commandN(tester);

      expect(
        container.read(openScenesProvider).scenes.map((s) => s.displayName),
        ['untitled'],
      );
      await finish(tester);
    });

    testWidgets('F6 still cycles the panels from the root focus', (
      tester,
    ) async {
      await pumpWindow(tester);
      final hierarchy = find.byWidgetPredicate(
        (w) => w is FocusScope && w.focusNode?.debugLabel == 'hierarchy',
      );
      final node = tester.widget<FocusScope>(hierarchy).focusNode!;
      expect(node.hasFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.f6);
      await tester.pump();

      expect(node.hasFocus, isTrue);
      await finish(tester);
    });
  });
}
