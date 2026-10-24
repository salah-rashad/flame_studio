import 'dart:io' show Platform;

import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/app/shell.dart'
    show macTrafficLightsInset, plainTitleBarInset;
import 'package:pyro/project/project.dart';
import 'package:pyro_ui/pyro_ui.dart';

void main() {
  testWidgets('the title is centred and clear of the traffic lights (T012)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fs = MemoryFileSystem.test();
    final container = ProviderContainer();
    container
        .read(projectProvider.notifier)
        .open(
          const ProjectState(
            root: '/work/example',
            sdk: SdkInfo.none,
            compatibility: RuntimeCompatibility.unknown,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        theme: PrTheme.dark(),
        home: UncontrolledProviderScope(
          container: container,
          child: PyroEditorWindow(
            command: OpenSceneCommand(
              projectRoot: '/work/example',
              recoveryFolder: '/recovery',
              fileSystem: fs,
            ),
            settings: RecentProjectsStore(
              fs.file('/support/recent_projects.json'),
              fileSystem: fs,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final inset = Platform.isMacOS ? macTrafficLightsInset : plainTitleBarInset;
    final shell = tester.widget<PrEditorShell>(find.byType(PrEditorShell));
    expect(shell.titleBarLeadingInset, inset);
    final title = tester.getRect(find.text('example'));
    expect(title.left, greaterThan(inset));
    expect(title.center.dx, moreOrLessEquals(640, epsilon: 1));
    expect(title.center.dy, moreOrLessEquals(PrSizes.titlebar / 2, epsilon: 1));

    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(minutes: 1));
  });
}
