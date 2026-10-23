import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/document/src/recovery_store.dart' show RecoveryWriting;
import 'package:pyro_runtime/pyro_runtime.dart';

import 'helpers/scenes.dart';

const projectRoot = '/project';
const scenePath = '/project/assets/scenes/level.scene.json';
const recoveryFolder = '/support/recovery';

void main() {
  late MemoryFileSystem fs;
  late RecoveryStore store;
  final now = DateTime.utc(2026, 10, 19, 18, 42, 7);
  final state = SceneDocument.fromScene(smallScene());

  setUp(() {
    fs = MemoryFileSystem();
    fs.directory('/project/assets/scenes').createSync(recursive: true);
    store = RecoveryStore(
      folder: recoveryFolder,
      fileSystem: fs,
      offload: runInline,
    );
  });

  Future<T> at<T>(DateTime time, Future<T> Function() body) =>
      withClock(Clock.fixed(time), body);

  String key([String path = scenePath]) => store.keyFor(projectRoot, path);
  String sceneCopy([String path = scenePath]) =>
      '$recoveryFolder/${key(path)}.scene.json';
  String metadata([String path = scenePath]) =>
      '$recoveryFolder/${key(path)}.recovery.json';

  Future<RecoveryCheck> find([String path = scenePath]) =>
      at(now, () => store.find(projectRoot: projectRoot, scenePath: path));

  test('the key is the SHA-256 of the normalized paths', () {
    final expected = sha256
        .convert(
          utf8.encode('/project\n/project/assets/scenes/level.scene.json'),
        )
        .toString();
    expect(key(), expected);
    expect(
      store.keyFor('/project/', '/project/assets/./scenes/level.scene.json'),
      expected,
    );
  });

  test('a copy is a Scene file and a metadata file', () async {
    await at<void>(
      now,
      () => store.write(
        projectRoot: projectRoot,
        scenePath: scenePath,
        state: state,
      ),
    );
    final scene = SceneCodec.decode(fs.file(sceneCopy()).readAsStringSync());
    expect(scene.scene.nodes.length, state.nodes.length);
    final meta =
        jsonDecode(fs.file(metadata()).readAsStringSync())
            as Map<String, Object?>;
    expect(meta, {
      'formatVersion': 1,
      'projectRoot': projectRoot,
      'scenePath': scenePath,
      'writtenAt': '2026-10-19T18:42:07.000Z',
    });
  });

  test('find reports nothing, then the copy with both times', () async {
    expect(await find(), isA<NoRecovery>());
    await at<void>(
      now,
      () => store.write(
        projectRoot: projectRoot,
        scenePath: scenePath,
        state: state,
      ),
    );

    fs.file(scenePath).writeAsStringSync('{}');
    final available = await find();
    expect(available, isA<RecoveryAvailable>());
    final info = (available as RecoveryAvailable).info;
    expect(info.projectRoot, projectRoot);
    expect(info.scenePath, scenePath);
    expect(info.writtenAt, now);
    expect(info.sceneFileModifiedAt, isNotNull);

    fs.file(scenePath).deleteSync();
    final gone = await find() as RecoveryAvailable;
    expect(gone.info.sceneFileModifiedAt, isNull);
  });

  group('unreadable copies are kept and reported', () {
    Future<void> writeCopy() => at(
      now,
      () => store.write(
        projectRoot: projectRoot,
        scenePath: scenePath,
        state: state,
      ),
    );

    Future<void> expectUnreadable() async {
      final check = await find();
      expect(check, isA<RecoveryUnreadable>());
      expect((check as RecoveryUnreadable).location, contains(key()));
      expect(check.problem, isNotNull);
    }

    test('only the Scene copy', () async {
      await writeCopy();
      fs.file(metadata()).deleteSync();
      await expectUnreadable();
      expect(fs.file(sceneCopy()).existsSync(), isTrue);
    });

    test('only the metadata', () async {
      await writeCopy();
      fs.file(sceneCopy()).deleteSync();
      await expectUnreadable();
      expect(fs.file(metadata()).existsSync(), isTrue);
    });

    test('metadata that isn\'t JSON', () async {
      await writeCopy();
      fs.file(metadata()).writeAsStringSync('not json');
      await expectUnreadable();
    });

    test('a newer metadata format', () async {
      await writeCopy();
      final meta =
          jsonDecode(fs.file(metadata()).readAsStringSync())
              as Map<String, Object?>;
      fs
          .file(metadata())
          .writeAsStringSync(jsonEncode({...meta, 'formatVersion': 2}));
      await expectUnreadable();
    });

    test('metadata naming another Scene', () async {
      await writeCopy();
      final meta =
          jsonDecode(fs.file(metadata()).readAsStringSync())
              as Map<String, Object?>;
      fs
          .file(metadata())
          .writeAsStringSync(jsonEncode({...meta, 'scenePath': '/elsewhere'}));
      await expectUnreadable();
    });

    test('a Scene copy that doesn\'t decode', () async {
      await writeCopy();
      fs.file(sceneCopy()).writeAsStringSync('{"schemaVersion": 99}');
      await expectUnreadable();
      expect(fs.file(sceneCopy()).existsSync(), isTrue);
    });
  });

  group('pruning', () {
    const other = '/project/assets/scenes/other.scene.json';

    test('copies older than 30 days are deleted, newer ones kept', () async {
      await at<void>(
        now.subtract(const Duration(days: 31)),
        () => store.write(
          projectRoot: projectRoot,
          scenePath: other,
          state: state,
        ),
      );
      await at<void>(
        now.subtract(const Duration(days: 29)),
        () => store.write(
          projectRoot: projectRoot,
          scenePath: scenePath,
          state: state,
        ),
      );
      expect(await find(), isA<RecoveryAvailable>());
      expect(fs.file(sceneCopy(other)).existsSync(), isFalse);
      expect(fs.file(metadata(other)).existsSync(), isFalse);
      expect(fs.file(sceneCopy()).existsSync(), isTrue);
    });

    test('unreadable copies are pruned by file time', () async {
      await at<void>(
        now,
        () => store.write(
          projectRoot: projectRoot,
          scenePath: other,
          state: state,
        ),
      );
      fs.file(metadata(other))
        ..writeAsStringSync('broken')
        ..setLastModifiedSync(now.subtract(const Duration(days: 31)));
      fs
          .file(sceneCopy(other))
          .setLastModifiedSync(now.subtract(const Duration(days: 31)));
      expect(await find(), isA<NoRecovery>());
      expect(fs.file(metadata(other)).existsSync(), isFalse);
      expect(fs.file(sceneCopy(other)).existsSync(), isFalse);
    });

    test('a recent unreadable copy is kept', () async {
      await at<void>(
        now,
        () => store.write(
          projectRoot: projectRoot,
          scenePath: other,
          state: state,
        ),
      );
      fs.file(metadata(other)).writeAsStringSync('broken');
      expect(await find(other), isA<RecoveryUnreadable>());
      expect(fs.file(metadata(other)).existsSync(), isTrue);
    });
  });

  test('discard removes both files and tolerates missing ones', () async {
    // Declining *Restore* (US3 #6) is #1's call to discard; this is the
    // store's half.
    await at<void>(
      now,
      () => store.write(
        projectRoot: projectRoot,
        scenePath: scenePath,
        state: state,
      ),
    );
    await store.discard(projectRoot: projectRoot, scenePath: scenePath);
    expect(fs.file(sceneCopy()).existsSync(), isFalse);
    expect(fs.file(metadata()).existsSync(), isFalse);
    await store.discard(projectRoot: projectRoot, scenePath: scenePath);
  });

  test(
    'readCopy restores the copied state, dirty, against the file now',
    () async {
      await at<void>(
        now,
        () => store.write(
          projectRoot: projectRoot,
          scenePath: scenePath,
          state: state,
        ),
      );
      fs.file(scenePath).writeAsStringSync('the file now');
      final info = (await find() as RecoveryAvailable).info;
      final doc = await store.readCopy(info);
      expect(doc.isDirty, isTrue);
      expect(doc.history.canUndo, isFalse);
      expect(doc.origin, OpenedFrom.restored);
      expect(doc.path, scenePath);
      expect(doc.baseline, sha256.convert(utf8.encode('the file now')));
      expect(
        SceneCodec.encode(doc.state.toScene()),
        SceneCodec.encode(state.toScene()),
      );
    },
  );

  test('paths follow the file system\'s own style, not the host\'s', () async {
    // On Windows CI the host style differed from MemoryFileSystem's, so keys
    // and metadata came out wrong; a Windows-style file system on any host
    // catches it.
    final windows = MemoryFileSystem(style: FileSystemStyle.windows);
    const root = r'C:\project';
    const scene = r'C:\project\assets\scenes\level.scene.json';
    windows.directory(r'C:\project\assets\scenes').createSync(recursive: true);
    final windowsStore = RecoveryStore(
      folder: r'C:\support\recovery',
      fileSystem: windows,
      offload: runInline,
    );
    expect(
      windowsStore.keyFor(
        r'C:\project\.',
        r'C:\project\assets\.\scenes\level.scene.json',
      ),
      windowsStore.keyFor(root, scene),
    );
    await at<void>(
      now,
      () =>
          windowsStore.write(projectRoot: root, scenePath: scene, state: state),
    );
    final check = await at(
      now,
      () => windowsStore.find(projectRoot: root, scenePath: scene),
    );
    expect(check, isA<RecoveryAvailable>());
    expect((check as RecoveryAvailable).info.scenePath, scene);
  });
}
