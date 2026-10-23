import 'dart:io';

import 'package:file/memory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/open_scene.dart';
import 'package:pyro/app/providers.dart';
import 'package:pyro/app/shell.dart';
import 'package:pyro/project/project.dart';

import '../helpers/fixtures.dart';
import '../helpers/pump.dart';

void main() {
  // A project whose Manifest carries one error and one warning — the
  // catalog's problems fixture (FR-014, T022).
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pyro-catalog-status');
    addTearDown(() => root.deleteSync(recursive: true));
    final lib = Directory('${root.path}/lib')..createSync();
    File(
      '${lib.path}/pyro.manifest.json',
    ).writeAsStringSync(manifestWithProblems);
  });

  Future<void> pumpWindow(WidgetTester tester, ProviderContainer container) =>
      pumpPyro(
        tester,
        UncontrolledProviderScope(
          container: container,
          child: PyroEditorWindow(
            command: OpenSceneCommand(
              projectRoot: root.path,
              recoveryFolder: '${root.path}/recovery',
              fileSystem: MemoryFileSystem.test(),
            ),
            settings: RecentProjectsStore(
              MemoryFileSystem.test().file('/settings.json'),
              fileSystem: MemoryFileSystem.test(),
            ),
          ),
        ),
        width: 900,
      );

  testWidgets('the status bar shows the errors and opens their dialog', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(projectProvider.notifier)
        .open(
          ProjectState(
            root: root.path,
            sdk: SdkInfo.none,
            compatibility: RuntimeCompatibility.unknown,
          ),
        );

    await pumpWindow(tester, container);
    await tester.pumpAndSettle();

    // The catalog is stale with one error counted, never "no types".
    expect(find.textContaining('Types stale'), findsOneWidget);
    expect(find.textContaining('1 error'), findsOneWidget);
    expect(find.textContaining('up to date'), findsNothing);

    await tester.tap(find.textContaining('Types stale'));
    await tester.pumpAndSettle();

    // Every problem, with its code and location (FR-014).
    expect(find.text('PYRO_NON_CONST_DEFAULT'), findsOneWidget);
    expect(find.text('PYRO_MISSING_DOC'), findsOneWidget);
    expect(
      find.text("The default of 'speed' isn't a const expression."),
      findsOneWidget,
    );
    expect(find.text('lib/components/ship.dart:14 Ship.speed'), findsOneWidget);
    expect(find.text('lib/components/ship.dart:6 Ship'), findsOneWidget);
    // The stale reason is spelled out too (Q105).
    expect(find.textContaining('last good types'), findsOneWidget);
  });

  testWidgets('a clean Manifest reports up to date', (tester) async {
    File(
      '${root.path}/lib/pyro.manifest.json',
    ).writeAsStringSync(readExampleManifest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(projectProvider.notifier)
        .open(
          ProjectState(
            root: root.path,
            sdk: SdkInfo.none,
            compatibility: RuntimeCompatibility.unknown,
          ),
        );

    await pumpWindow(tester, container);
    await tester.pumpAndSettle();

    expect(find.text('Types up to date'), findsOneWidget);
    await tester.tap(find.text('Types up to date'));
    await tester.pumpAndSettle();
    expect(find.text('All types are up to date.'), findsOneWidget);
  });
}
