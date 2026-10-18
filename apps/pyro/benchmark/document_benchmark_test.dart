// The Document model's budgets (spec 002, SC-005 and SC-006). Run by hand:
//
//   flutter test --enable-vmservice benchmark/document_benchmark_test.dart
//
// It lives outside test/, so CI's `flutter test` never runs it. Numbers are
// JIT, so an upper bound for the release build.
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:vm_service/vm_service.dart'
    show HeapSnapshotGraph, HeapSnapshotObject;
import 'package:vm_service/vm_service_io.dart';

import '../test/document/helpers/scenes.dart';

const path = '/project/assets/scenes/big.scene.json';

void main() {
  // Memory first, while the heap holds nothing else of this test.
  test('memory of a 200-step history (SC-006)', _measureHistory);

  test('time on a 1,000-Node Scene (SC-005)', () async {
    final scene = generatedScene(1000);
    final fs = MemoryFileSystem();
    fs.directory('/project/assets/scenes').createSync(recursive: true);
    fs.file(path).writeAsStringSync(SceneCodec.encode(scene));
    final services = SessionServices(
      files: SceneFiles(fileSystem: fs),
      recovery: RecoveryStore(folder: '/recovery', fileSystem: fs),
      projectRoot: '/project',
    );

    final openWatch = Stopwatch()..start();
    final (session, openPause) = await _longestPause(
      () => DocumentSession.open(path, services: services),
    );
    openWatch.stop();
    final ids = [
      for (final node in session.state.state.nodes.values)
        if (node is EntityNode) node.id,
    ];

    var step = 0;
    void moveOne() {
      final id = ids[step % ids.length];
      step++;
      session.transact('Move', (d) {
        final node = d.node(id)! as EntityNode;
        return d.replaceNode(
          node.copyWith(
            transform: node.transform.copyWith(
              position: Vec2(step.toDouble(), 0),
            ),
          ),
        );
      });
    }

    for (var i = 0; i < 100; i++) {
      moveOne();
    }
    final transact = _time(1000, moveOne);
    final undo = _time(200, session.undo);
    final redo = _time(200, session.redo);

    final saveWatch = Stopwatch()..start();
    final (_, savePause) = await _longestPause(
      () => session.save(runtimeReadsUpTo: Scene.currentSchemaVersion),
    );
    saveWatch.stop();

    stdout
      ..writeln('Nodes: ${session.state.state.nodes.length}')
      ..writeln('transact: ${transact.describe()}')
      ..writeln('undo:     ${undo.describe()}')
      ..writeln('redo:     ${redo.describe()}')
      ..writeln(
        'open: ${openWatch.elapsedMilliseconds} ms, longest pause of the calling '
        'isolate ${openPause.inMilliseconds} ms (decode in Isolate.run)',
      )
      ..writeln(
        'save: ${saveWatch.elapsedMilliseconds} ms, longest pause of the calling '
        'isolate ${savePause.inMilliseconds} ms (encode in Isolate.run)',
      );
    await session.close();
  });
}

// One instance each, so the heap snapshot can find them by class name.
class _SceneHolder {
  _SceneHolder(this.scene);
  final Scene scene;
}

class _OpenedHolder {
  _OpenedHolder(this.opened);
  final SceneDocument opened;
}

class _HistoryHolder {
  _HistoryHolder(this.history);
  final DocumentHistory history;
}

/// SC-006: the bytes a 200-step history holds that neither the Scene nor
/// the opening state reaches (budget: under 2 MB), next to the bytes the
/// Scene reaches. Counted
/// in a full heap snapshot, as DevTools does, so garbage doesn't skew it.
Future<void> _measureHistory() async {
  final uri = (await Service.getInfo()).serverWebSocketUri;
  if (uri == null) {
    stdout.writeln('memory: skipped; run with --enable-vmservice');
    return;
  }
  final vm = await vmServiceConnectUri(uri.toString());
  final isolateId = Service.getIsolateId(Isolate.current)!;

  final scene = _SceneHolder(generatedScene(1000));
  final opened = _OpenedHolder(SceneDocument.fromScene(scene.scene));
  final ids = [
    for (final node in scene.scene.nodes.values)
      if (node is EntityNode) node.id,
  ];
  final history = _HistoryHolder(_twoHundredSteps(opened.opened, ids));

  final isolateRef = (await vm.getVM()).isolates!.firstWhere(
    (ref) => ref.id == isolateId,
  );
  final graph = await HeapSnapshotGraph.getSnapshot(
    vm,
    isolateRef,
    calculateReferrers: false,
    decodeExternalProperties: false,
    decodeIdentityHashCodes: false,
  );
  final objects = graph.objects;
  int find(String className) {
    for (var i = 1; i < objects.length; i++) {
      if (objects[i].klass.name == className) return i;
    }
    throw StateError('$className not in the snapshot');
  }

  // Program structure (classes, code, functions, types, closures) is shared
  // by everything and isn't data, so the walk doesn't enter it. VM-internal
  // objects have no library.
  const structure = {'_Type', '_FunctionType', '_RecordType', '_Closure'};
  bool isData(HeapSnapshotObject object) =>
      object.klass.libraryUri.toString().isNotEmpty &&
      !structure.contains(object.klass.name);

  Set<int> reach(int start, [Set<int> stop = const {}]) {
    final seen = <int>{start};
    final stack = [start];
    while (stack.isNotEmpty) {
      for (final next in objects[stack.removeLast()].references) {
        if (next == 0 || stop.contains(next) || !seen.add(next)) continue;
        if (isData(objects[next])) stack.add(next);
      }
    }
    return seen;
  }

  int bytes(Iterable<int> ids) =>
      ids.fold(0, (sum, id) => sum + objects[id].shallowSize);

  final sceneObjects = reach(find('_SceneHolder'));
  final openedObjects = reach(find('_OpenedHolder'), sceneObjects);
  final historyObjects = reach(find('_HistoryHolder'), {
    ...sceneObjects,
    ...openedObjects,
  });
  final sceneBytes = bytes(sceneObjects);
  final openedBytes = bytes(openedObjects.difference(sceneObjects));
  final historyBytes = bytes(
    historyObjects.difference(sceneObjects).difference(openedObjects),
  );
  stdout.writeln(
    'reached: Scene ${sceneObjects.length}, opening ${openedObjects.length}, '
    'history ${historyObjects.length} objects',
  );
  stdout.writeln(
    'memory: Scene ${_kb(sceneBytes)}, opening document beyond it '
    '${_kb(openedBytes)}, 200-step history beyond both ${_kb(historyBytes)} '
    '(${(100 * historyBytes / sceneBytes).toStringAsFixed(0)}% of the Scene; '
    'budget < 2 MB; ${history.history.entries.length} entries)',
  );
  await vm.dispose();
}

// In its own function, so no local outlives it and only the history holds
// the states it made.
DocumentHistory _twoHundredSteps(SceneDocument opened, List<NodeId> ids) {
  var history = DocumentHistory.opened(opened, clean: true);
  var state = opened;
  for (var i = 0; i < DocumentHistory.maxSteps; i++) {
    final node = state.node(ids[i % ids.length])! as EntityNode;
    state = state.replaceNode(
      node.copyWith(
        transform: node.transform.copyWith(position: Vec2(i.toDouble(), 1)),
      ),
    );
    history = history.apply('Move', state);
  }
  return history;
}

/// Runs [work] and returns its result with the longest gap between ticks of
/// a 1 ms timer meanwhile: how long the calling isolate couldn't run a frame.
Future<(T, Duration)> _longestPause<T>(Future<T> Function() work) async {
  var longest = Duration.zero;
  final watch = Stopwatch()..start();
  var last = watch.elapsed;
  final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
    final now = watch.elapsed;
    if (now - last > longest) longest = now - last;
    last = now;
  });
  final result = await work();
  timer.cancel();
  final tail = watch.elapsed - last;
  return (result, tail > longest ? tail : longest);
}

String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(0)} KB';

({List<int> micros}) _time(int runs, void Function() body) {
  final micros = <int>[];
  final watch = Stopwatch();
  for (var i = 0; i < runs; i++) {
    watch
      ..reset()
      ..start();
    body();
    watch.stop();
    micros.add(watch.elapsedMicroseconds);
  }
  return (micros: micros..sort());
}

extension on ({List<int> micros}) {
  String describe() {
    final median = micros[micros.length ~/ 2];
    final p95 = micros[(micros.length * 0.95).floor()];
    return 'median $median µs, p95 $p95 µs (${micros.length} runs)';
  }
}
