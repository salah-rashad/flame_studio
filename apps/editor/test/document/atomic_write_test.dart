import 'dart:io' as io;

import 'package:file/local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'helpers/failing_file_system.dart';
import 'helpers/fixtures.dart';
import 'helpers/scenes.dart';

const folder = '/project/assets/scenes';
const path = '$folder/level.scene.json';

void main() {
  final oldBytes = readFixtureBytes('canonical/all_kinds.scene.json');

  // Opens the fixture on [fs] and adds a Node, ready to save.
  Future<(SceneFiles, OpenDocument)> prepare(FailingFileSystem fs) async {
    fs.inner.directory(folder).createSync(recursive: true);
    fs.inner.file(path).writeAsBytesSync(oldBytes);
    final files = SceneFiles(fileSystem: fs, offload: runInline);
    final doc = (await files.open(
      path,
    )).transact('Add', (d) => d.addNode(entity('x'), parentId: d.rootId));
    fs.operationCount = 0;
    fs.operations.clear();
    return (files, doc);
  }

  test(
    'a save failing at any operation leaves the old or the new file',
    () async {
      final probe = FailingFileSystem();
      final (probeFiles, probeDoc) = await prepare(probe);
      await probeFiles.save(
        probeDoc,
        runtimeReadsUpTo: Scene.currentSchemaVersion,
      );
      final newBytes = probe.inner.file(path).readAsBytesSync();
      final steps = probe.operationCount;
      expect(steps, greaterThanOrEqualTo(3), reason: '${probe.operations}');

      for (var failAt = 1; failAt <= steps; failAt++) {
        final fs = FailingFileSystem();
        final (files, doc) = await prepare(fs);
        fs.failAt = failAt;
        await expectLater(
          files.save(doc, runtimeReadsUpTo: Scene.currentSchemaVersion),
          throwsA(isA<SaveFailed>().having((e) => e.path, 'path', path)),
          reason: 'failing at ${probe.operations[failAt - 1]}',
        );
        final after = fs.inner.file(path).readAsBytesSync();
        expect(
          after,
          anyOf(equals(oldBytes), equals(newBytes)),
          reason: 'failing at ${probe.operations[failAt - 1]}',
        );
        final leftovers = fs.inner
            .directory(folder)
            .listSync()
            .where((entity) => entity.path.endsWith('.pyro-tmp'));
        expect(leftovers, isEmpty, reason: 'failing at $failAt');
      }
    },
  );

  test('rename replaces an existing file on the real file system', () async {
    final dir = await io.Directory.systemTemp.createTemp('pyro_atomic_');
    addTearDown(() => dir.delete(recursive: true));
    const fs = LocalFileSystem();
    final target = fs.path.join(dir.path, 'level.scene.json');
    fs.file(target).writeAsStringSync('old');
    await writeAtomically(fs, target, 'new'.codeUnits);
    expect(fs.file(target).readAsStringSync(), 'new');
    expect(
      fs.directory(dir.path).listSync().map((e) => fs.path.basename(e.path)),
      ['level.scene.json'],
    );
  });
}
