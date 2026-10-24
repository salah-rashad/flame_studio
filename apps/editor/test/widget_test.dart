import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/main.dart';

void main() {
  late MemoryFileSystem fs;

  setUp(() => fs = MemoryFileSystem.test());

  /// Plants `recent_projects.json` in Pyro's support folder.
  void recent(List<String> paths) {
    final file = fs.file(
      fs.path.join(pyroSupportFolder(fs), 'recent_projects.json'),
    )..createSync(recursive: true);
    file.writeAsStringSync(
      '{"paths": [${paths.map((p) => '"$p"').join(', ')}]}',
    );
  }

  List<String> storedPaths() {
    final text = fs
        .file(fs.path.join(pyroSupportFolder(fs), 'recent_projects.json'))
        .readAsStringSync();
    return RegExp(r'"(/[^"]*)"').allMatches(text).map((m) => m[1]!).toList();
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      PyroApp(fileSystem: fs, pathVersion: () async => null),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the welcome window shows the app name and open-by-path', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Pyro'), findsOneWidget);
    expect(find.text('No recent projects'), findsOneWidget);
    expect(find.text('Open project…'), findsOneWidget);
  });

  group('recent projects (FR-001/FR-003)', () {
    testWidgets('a missing folder is marked and never opens', (tester) async {
      fs.directory('/work/pyro/example').createSync(recursive: true);
      recent(['/work/pyro/example', '/old/Tools/pyro/example']);
      await pumpApp(tester);

      expect(find.text('Folder not found'), findsOneWidget);
      // Opening it explains instead of opening.
      await tester.tap(find.text('/old/Tools/pyro/example'));
      await tester.pumpAndSettle();
      expect(find.text('Folder not found'), findsNWidgets(2));
      expect(find.textContaining('no longer exists'), findsOneWidget);

      // Keep leaves it on the list: nothing is removed automatically.
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(storedPaths(), contains('/old/Tools/pyro/example'));
      expect(find.text('/old/Tools/pyro/example'), findsOneWidget);
    });

    testWidgets('the user can remove a missing folder from the list', (
      tester,
    ) async {
      fs.directory('/work/pyro/example').createSync(recursive: true);
      recent(['/work/pyro/example', '/old/Tools/pyro/example']);
      await pumpApp(tester);

      await tester.tap(find.text('/old/Tools/pyro/example'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from list'));
      await tester.pumpAndSettle();

      expect(find.text('/old/Tools/pyro/example'), findsNothing);
      expect(find.text('Folder not found'), findsNothing);
      expect(storedPaths(), ['/work/pyro/example']);
    });

    testWidgets('same-named projects show distinct labels and full paths', (
      tester,
    ) async {
      fs.directory('/work/pyro/example').createSync(recursive: true);
      fs.directory('/old/Tools/pyro/example').createSync(recursive: true);
      recent([
        '/work/pyro/example',
        '/work/pyro/example/',
        '/old/Tools/pyro/example',
      ]);
      await pumpApp(tester);

      // The trailing-slash duplicate is one row.
      expect(find.text('/work/pyro/example'), findsOneWidget);
      expect(find.text('/old/Tools/pyro/example'), findsOneWidget);
      expect(find.text('work/pyro/example'), findsOneWidget);
      expect(find.text('Tools/pyro/example'), findsOneWidget);
      expect(find.text('example'), findsNothing);
    });

    testWidgets('open-by-path refuses a folder that does not exist', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text('Open project…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), '/nowhere/game/');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Folder not found'), findsOneWidget);
      expect(find.text('There is no folder at /nowhere/game.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // Still on the welcome window, and nothing was remembered.
      expect(find.text('No recent projects'), findsOneWidget);
    });
  });
}
