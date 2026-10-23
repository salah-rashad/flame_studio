import 'dart:convert';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'helpers/failing_file_system.dart';
import 'helpers/fixtures.dart';
import 'helpers/scenes.dart';

const folder = '/project/assets/scenes';
const path = '$folder/level.scene.json';
const reads = Scene.currentSchemaVersion;

void main() {
  late MemoryFileSystem fs;
  late SceneFiles files;

  setUp(() {
    fs = MemoryFileSystem();
    fs.directory(folder).createSync(recursive: true);
    files = SceneFiles(fileSystem: fs, offload: runInline);
  });

  void writeFixture(String relative, [String to = path]) =>
      fs.file(to).writeAsBytesSync(readFixtureBytes(relative));

  OpenDocument addEntity(OpenDocument doc, String id) =>
      doc.transact('Add $id', (d) => d.addNode(entity(id), parentId: d.rootId));

  group('open', () {
    Matcher openFailed({Object? cause}) => throwsA(
      isA<SceneOpenFailed>()
          .having((e) => e.path, 'path', path)
          .having((e) => e.cause, 'cause', cause ?? anything),
    );

    test('a missing file', () {
      expect(files.open(path), openFailed());
    });

    test('bytes that aren\'t UTF-8', () {
      fs.file(path).writeAsBytesSync([0x7b, 0xff, 0xfe, 0x7d]);
      expect(files.open(path), openFailed(cause: isA<FormatException>()));
    });

    for (final name in fixtureNames('invalid')) {
      test('invalid $name', () {
        writeFixture('invalid/$name');
        expect(
          files.open(path),
          openFailed(cause: isA<SceneFormatException>()),
        );
      });
    }

    for (final name in fixtureNames('version')) {
      test('version $name opens exactly when the Scene format reads it', () {
        writeFixture('version/$name');
        final text = utf8.decode(readFixtureBytes('version/$name'));
        Object? decodeError;
        try {
          SceneCodec.decode(text);
        } on SceneFormatException catch (error) {
          decodeError = error;
        }
        if (decodeError == null) {
          expect(files.open(path), completes);
        } else {
          expect(
            files.open(path),
            openFailed(cause: isA<SceneFormatException>()),
          );
        }
      });
    }

    test('a repaired Scene opens dirty with its report', () async {
      writeFixture('damaged/multiple_parents.scene.json');
      final before = fs.file(path).readAsBytesSync();
      final doc = await files.open(path);
      expect(doc.isDirty, isTrue);
      expect(doc.origin, OpenedFrom.repaired);
      expect(doc.repairs.isEmpty, isFalse);
      expect(doc.history.canUndo, isFalse);
      expect(fs.file(path).readAsBytesSync(), before);
    });

    test('a healthy Scene opens clean from its file', () async {
      writeFixture('canonical/entity.scene.json');
      final doc = await files.open(path);
      expect(doc.isDirty, isFalse);
      expect(doc.origin, OpenedFrom.file);
      expect(doc.path, path);
      expect(doc.repairs.isEmpty, isTrue);
    });
  });

  group('save', () {
    test(
      'writes the edited state, and reopening gives the same text',
      () async {
        writeFixture('canonical/entity.scene.json');
        final doc = addEntity(await files.open(path), 'x');
        final result = await files.save(doc, runtimeReadsUpTo: reads);
        expect(identical(result.state, doc.state), isTrue);
        expect(result.path, path);
        final text = fs.file(path).readAsStringSync();
        expect(text, contains('"x"'));
        final reopened = await files.open(path);
        expect(SceneCodec.encode(reopened.state.toScene()), text);
        expect(
          reopened.markSaved(result).isDirty,
          isTrue,
          reason: 'other state',
        );
        expect(doc.markSaved(result).isDirty, isFalse);
      },
    );

    test('a new Scene needs a path', () async {
      final doc = createDocument(newId: counterIds());
      await expectLater(
        files.save(doc, runtimeReadsUpTo: reads),
        throwsA(isA<SavePathRequired>()),
      );
      final result = await files.save(
        doc,
        runtimeReadsUpTo: reads,
        saveAs: '$folder/new.scene.json',
      );
      expect(result.path, '$folder/new.scene.json');
      expect(fs.file('$folder/new.scene.json').existsSync(), isTrue);
    });

    test('refuses when the file changed on disk, unless forced', () async {
      writeFixture('canonical/entity.scene.json');
      final doc = addEntity(await files.open(path), 'x');
      writeFixture('canonical/sprite.scene.json');
      final theirs = fs.file(path).readAsBytesSync();
      await expectLater(
        files.save(doc, runtimeReadsUpTo: reads),
        throwsA(isA<SceneChangedOnDisk>().having((e) => e.path, 'path', path)),
      );
      expect(fs.file(path).readAsBytesSync(), theirs);
      await files.save(doc, runtimeReadsUpTo: reads, overwrite: true);
      expect(fs.file(path).readAsStringSync(), contains('"x"'));
    });

    test('refuses when the file was deleted, unless forced', () async {
      writeFixture('canonical/entity.scene.json');
      final doc = addEntity(await files.open(path), 'x');
      fs.file(path).deleteSync();
      await expectLater(
        files.save(doc, runtimeReadsUpTo: reads),
        throwsA(isA<SceneChangedOnDisk>()),
      );
      expect(fs.file(path).existsSync(), isFalse);
      await files.save(doc, runtimeReadsUpTo: reads, overwrite: true);
      expect(fs.file(path).existsSync(), isTrue);
    });

    test('saves when the file was rewritten with identical bytes', () async {
      writeFixture('canonical/entity.scene.json');
      final doc = addEntity(await files.open(path), 'x');
      writeFixture('canonical/entity.scene.json');
      await files.save(doc, runtimeReadsUpTo: reads);
      expect(fs.file(path).readAsStringSync(), contains('"x"'));
    });

    test(
      '"Save as" onto another existing file is refused unless forced',
      () async {
        writeFixture('canonical/entity.scene.json');
        const other = '$folder/other.scene.json';
        writeFixture('canonical/sprite.scene.json', other);
        final doc = await files.open(path);
        await expectLater(
          files.save(doc, runtimeReadsUpTo: reads, saveAs: other),
          throwsA(isA<SaveTargetExists>().having((e) => e.path, 'path', other)),
        );
        await files.save(
          doc,
          runtimeReadsUpTo: reads,
          saveAs: other,
          overwrite: true,
        );
        expect(
          fs.file(other).readAsBytesSync(),
          readFixtureBytes('canonical/entity.scene.json'),
        );
      },
    );

    test('a missing folder fails naming the path', () async {
      final doc = createDocument(newId: counterIds());
      const target = '/project/nowhere/new.scene.json';
      await expectLater(
        files.save(doc, runtimeReadsUpTo: reads, saveAs: target),
        throwsA(isA<SaveFailed>().having((e) => e.path, 'path', target)),
      );
      expect(fs.directory('/project/nowhere').existsSync(), isFalse);
    });

    test('open, edit and save through a real isolate', () async {
      final isolated = SceneFiles(fileSystem: fs);
      writeFixture('canonical/all_kinds.scene.json');
      final doc = addEntity(await isolated.open(path), 'x');
      final result = await isolated.save(doc, runtimeReadsUpTo: reads);
      expect(identical(result.state, doc.state), isTrue);
      expect(fs.file(path).readAsStringSync(), contains('"x"'));
    });
  });

  group('schemaVersion gate', () {
    late FailingFileSystem failing;
    late SceneFiles gated;
    late OpenDocument doc;

    setUp(() async {
      failing = FailingFileSystem();
      failing.inner.directory(folder).createSync(recursive: true);
      failing.inner
          .file(path)
          .writeAsBytesSync(readFixtureBytes('canonical/entity.scene.json'));
      gated = SceneFiles(fileSystem: failing, offload: runInline);
      doc = addEntity(await gated.open(path), 'x');
      failing.operations.clear();
      failing.operationCount = 0;
    });

    test('writes when the Runtime reads the version Pyro writes', () async {
      await gated.save(doc, runtimeReadsUpTo: Scene.currentSchemaVersion);
      expect(failing.inner.file(path).readAsStringSync(), contains('"x"'));
    });

    test('refuses an older Runtime and touches nothing', () async {
      final before = failing.inner.file(path).readAsBytesSync();
      await expectLater(
        gated.save(doc, runtimeReadsUpTo: 0),
        throwsA(
          isA<RuntimeTooOld>()
              .having((e) => e.reads, 'reads', 0)
              .having((e) => e.writes, 'writes', Scene.currentSchemaVersion)
              .having(
                (e) => e.toString(),
                'message',
                contains('Upgrade pyro_runtime'),
              ),
        ),
      );
      expect(failing.operationCount, 0);
      expect(failing.inner.file(path).readAsBytesSync(), before);
      expect(doc.isDirty, isTrue);
      expect(doc.state.contains(const NodeId('x')), isTrue);
    });

    test('refuses while the Runtime\'s version is unknown', () async {
      await expectLater(
        gated.save(doc, runtimeReadsUpTo: null),
        throwsA(
          isA<RuntimeVersionUnknown>().having((e) => e.path, 'path', path),
        ),
      );
      expect(failing.operationCount, 0);
    });

    test('is checked before the path and the changed-on-disk check', () async {
      final fresh = createDocument(newId: counterIds());
      await expectLater(
        gated.save(fresh, runtimeReadsUpTo: null),
        throwsA(isA<RuntimeVersionUnknown>()),
      );
      failing.inner.file(path).writeAsStringSync('changed elsewhere');
      await expectLater(
        gated.save(doc, runtimeReadsUpTo: 0),
        throwsA(isA<RuntimeTooOld>()),
      );
    });
  });
}
