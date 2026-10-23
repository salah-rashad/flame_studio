import 'dart:async';
import 'dart:io'
    show
        FileSystemCreateEvent,
        FileSystemDeleteEvent,
        FileSystemEvent,
        FileSystemModifyEvent,
        FileSystemMoveEvent;

import 'package:fake_async/fake_async.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/process/src/scene_watcher.dart';

import 'fake_process.dart';

const scenes = '$projectPath/assets/scenes';

void main() {
  // A broadcast stream the test drives; nothing to release.
  // ignore: close_sinks
  late StreamController<FileSystemEvent> changes;
  late List<Set<String>> batches;
  late List<String> notes;

  setUp(() {
    changes = StreamController<FileSystemEvent>.broadcast();
    batches = [];
    notes = [];
  });

  SceneWatcher watcher(MemoryFileSystem fs) => SceneWatcher(
    fileSystem: fs,
    projectPath: projectPath,
    watch: (_) => changes.stream,
    quietPeriod: const Duration(milliseconds: 150),
    onChanges: batches.add,
    onNote: notes.add,
  )..start();

  void modify(String path) =>
      changes.add(FileSystemModifyEvent(path, false, true));

  test('counts only Scene files under assets/scenes/', () {
    fakeAsync((async) {
      watcher(projectFileSystem());
      for (final path in [
        '$scenes/level1.scene.json.tmp',
        '$scenes/.level1.scene.json.swp',
        '$scenes/level1.scene.json~',
        '$projectPath/lib/main.dart',
        '$projectPath/assets/other/x.scene.json',
      ]) {
        modify(path);
      }
      async.elapse(const Duration(seconds: 1));
      expect(batches, isEmpty);

      modify('$scenes/level1.scene.json');
      modify('$scenes/extra/level2.scene.json');
      async.elapse(const Duration(seconds: 1));
      expect(batches, [
        {
          'assets/scenes/level1.scene.json',
          'assets/scenes/extra/level2.scene.json',
        },
      ]);
    });
  });

  test('an atomic save counts the rename target', () {
    fakeAsync((async) {
      watcher(projectFileSystem());
      changes
        ..add(FileSystemCreateEvent('$scenes/level1.scene.json.tmp', false))
        ..add(
          FileSystemMoveEvent(
            '$scenes/level1.scene.json.tmp',
            false,
            '$scenes/level1.scene.json',
          ),
        );
      async.elapse(const Duration(milliseconds: 150));
      expect(batches, [
        {'assets/scenes/level1.scene.json'},
      ]);
    });
  });

  test('a delete is passed on', () {
    fakeAsync((async) {
      watcher(projectFileSystem());
      changes.add(FileSystemDeleteEvent('$scenes/level1.scene.json', false));
      async.elapse(const Duration(milliseconds: 150));
      expect(batches, hasLength(1));
    });
  });

  test('waits for 150 ms of quiet and folds a burst', () {
    fakeAsync((async) {
      watcher(projectFileSystem());
      for (var i = 0; i < 10; i++) {
        modify('$scenes/level1.scene.json');
        async.elapse(const Duration(milliseconds: 100));
      }
      expect(batches, isEmpty);
      async.elapse(const Duration(milliseconds: 49));
      expect(batches, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(batches, [
        {'assets/scenes/level1.scene.json'},
      ]);
    });
  });

  test('a project without assets/scenes/ is noted once and not watched', () {
    fakeAsync((async) {
      watcher(projectFileSystem(scenes: false));
      expect(changes.hasListener, isFalse);
      expect(notes.single, contains('No assets/scenes/ folder'));
    });
  });

  test('close() stops watching and drops a waiting batch', () {
    fakeAsync((async) {
      final w = watcher(projectFileSystem());
      modify('$scenes/level1.scene.json');
      w.close();
      async.elapse(const Duration(seconds: 1));
      expect(batches, isEmpty);
      expect(changes.hasListener, isFalse);
    });
  });
}
