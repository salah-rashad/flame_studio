import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'helpers/fixtures.dart';
import 'helpers/scenes.dart';
import 'helpers/text_diff.dart';

const path = '/project/assets/scenes/level.scene.json';

void main() {
  late MemoryFileSystem fs;
  late SceneFiles files;

  setUp(() {
    fs = MemoryFileSystem();
    fs.directory('/project/assets/scenes').createSync(recursive: true);
    files = SceneFiles(fileSystem: fs, offload: runInline);
  });

  for (final name in fixtureNames('canonical')) {
    test('canonical $name saves byte for byte', () async {
      final bytes = readFixtureBytes('canonical/$name');
      fs.file(path).writeAsBytesSync(bytes);
      final doc = await files.open(path);
      expect(doc.isDirty, isFalse);
      await files.save(doc, runtimeReadsUpTo: Scene.currentSchemaVersion);
      expectSameBytes(fs.file(path).readAsBytesSync(), bytes, reason: name);
    });
  }

  for (final name in fixtureNames('non_canonical')) {
    test('non-canonical $name opens clean and saves canonical', () async {
      fs.file(path).writeAsBytesSync(readFixtureBytes('non_canonical/$name'));
      final doc = await files.open(path);
      expect(doc.isDirty, isFalse);
      await files.save(doc, runtimeReadsUpTo: Scene.currentSchemaVersion);
      final expected = readFixtureBytes(
        'non_canonical/${name.replaceAll('.scene.json', '.expected.scene.json')}',
      );
      expectSameBytes(fs.file(path).readAsBytesSync(), expected, reason: name);
    });
  }

  test('edit, undo to the saved state, save is byte-identical', () async {
    final bytes = readFixtureBytes('canonical/all_kinds.scene.json');
    fs.file(path).writeAsBytesSync(bytes);
    var doc = await files.open(path);
    final root = doc.state.rootId;
    doc = doc
        .transact('Add', (d) => d.addNode(entity('extra'), parentId: root))
        .undo();
    expect(doc.isDirty, isFalse);
    await files.save(doc, runtimeReadsUpTo: Scene.currentSchemaVersion);
    expectSameBytes(fs.file(path).readAsBytesSync(), bytes);
  });
}
