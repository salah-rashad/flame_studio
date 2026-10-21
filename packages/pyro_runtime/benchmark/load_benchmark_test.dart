// Times the loader on the 1,000-Node benchmark Scene (spec 004 SC-004):
// median under 50 ms for a load without image decoding, 5 ms for a Hot-swap
// check that finds nothing changed, 100 ms for a rebuild; and records the
// longest synchronous pause of the isolate during a load and a rebuild,
// whose limit is set once measured on the reference Mac (T043).
//
//   flutter test benchmark/load_benchmark_test.dart
//
// flutter test runs JIT with asserts, so these numbers bound a profile
// build from above.
import 'dart:async' as async;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_runtime/src/loader/hot_swap.dart';

import '../test/support/images.dart';
import '../test/support/memory_asset_source.dart';
import 'support/benchmark_scene.dart';

const String _path = 'assets/scenes/benchmark.scene.json';
const int _warmUp = 5;
const int _runs = 20;

enum _Mode { pingPong, loop }

class _Patrol extends Behavior<PositionedEntity> {
  double speed = 0;
  _Mode mode = _Mode.loop;
  Component? target;
}

final _registry = PyroRegistry([
  RegistryType(
    id: const TypeId('Patrol'),
    role: TypeRole.behavior,
    create: _Patrol.new,
    acceptsParent: (parent) => parent is PositionedEntity,
    fields: {
      'speed': RegistryField(
        name: 'speed',
        type: FieldType.double,
        nullable: false,
        accepts: (v) => v is double,
        set: (t, v) => (t as _Patrol).speed = v! as double,
      ),
      'mode': RegistryField(
        name: 'mode',
        type: FieldType.enumeration,
        nullable: false,
        values: _Mode.values,
        accepts: (v) => v is _Mode,
        set: (t, v) => (t as _Patrol).mode = v! as _Mode,
      ),
      'target': RegistryField(
        name: 'target',
        type: FieldType.entityRef,
        nullable: true,
        accepts: (v) => v == null || v is Component,
        set: (t, v) => (t as _Patrol).target = v as Component?,
      ),
    },
  ),
]);

/// Runs [run] [_warmUp] + [_runs] times; returns the timed runs in ms and
/// the longest gap between event-loop turns seen during them: the longest
/// stretch the isolate couldn't run anything else, such as a frame. With a
/// memory source nothing waits on I/O, so a run that never yields shows up
/// whole.
Future<({List<double> times, double longestPause})> _measure(
  Future<void> Function() run,
) async {
  for (var i = 0; i < _warmUp; i++) {
    await run();
  }
  final times = <double>[];
  var longestPause = 0.0;
  final total = Stopwatch();
  final tick = Stopwatch()..start();
  final probe = async.Timer.periodic(Duration.zero, (_) {
    final gap = tick.elapsedMicroseconds / 1000;
    if (gap > longestPause) longestPause = gap;
    tick.reset();
  });
  for (var i = 0; i < _runs; i++) {
    // Let the probe tick, so each gap it sees lies within one run.
    await Future<void>.delayed(Duration.zero);
    tick.reset();
    total
      ..reset()
      ..start();
    await run();
    total.stop();
    times.add(total.elapsedMicroseconds / 1000);
    await Future<void>.delayed(Duration.zero);
  }
  probe.cancel();
  times.sort();
  return (times: times, longestPause: longestPause);
}

double _median(List<double> sorted) => sorted[sorted.length ~/ 2];

double _p95(List<double> sorted) => sorted[(sorted.length * 0.95).floor() - 1];

String _row(String name, ({List<double> times, double longestPause}) m) =>
    '| $name | ${_median(m.times).toStringAsFixed(2)} | '
    '${_p95(m.times).toStringAsFixed(2)} | '
    '${m.longestPause.toStringAsFixed(2)} |';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SC-004 on the 1,000-Node benchmark Scene', () async {
    final text = SceneCodec.encode(benchmarkScene());
    // The rebuild moves the Node at this position; if a writer or fixture
    // change removed it, the "rebuild" would silently measure a no-op.
    const moved = '"position": [0, 0]';
    expect(text, contains(moved), reason: 'the rebuild must change the text');
    var reloads = 0;
    final image = await makeImage(256, 32);
    final source = MemoryAssetSource(
      texts: {_path: text},
      images: <String, Image>{
        for (var n = 0; n < 10; n++) benchmarkImage(n): image,
      },
    );

    final load = await _measure(
      () => PyroScene.load(_path, registry: _registry, assets: source),
    );

    final scene = await PyroScene.load(
      _path,
      registry: _registry,
      assets: source,
      onReloaded: (_) => reloads++,
    );
    final texts = {const AssetPath(_path): text};
    final check = await _measure(() async {
      await contentChanged(source, texts);
    });

    final game = await initializeFlameGame();
    await game.ensureAdd(scene);
    var x = 0;
    final rebuild = await _measure(() async {
      // A one-character change, as when a Node is moved in Pyro.
      source.texts[_path] = text.replaceFirst(moved, '"position": [${++x}, 0]');
      game.onHotReload();
      // ignore: invalid_use_of_visible_for_testing_member, a benchmark drives the Hot-swap the way the tests do.
      await scene.pendingCheck;
    });
    expect(reloads, _warmUp + _runs, reason: 'every run must rebuild');

    // ignore: avoid_print, a benchmark reports to the console.
    print(
      '| | median ms | p95 ms | longest pause ms |\n'
      '|---|---|---|---|\n'
      '${_row('load (no image decoding)', load)}\n'
      '${_row('Hot-swap check, nothing changed', check)}\n'
      '${_row('Hot-swap rebuild', rebuild)}',
    );
    expect(_median(load.times), lessThan(50));
    expect(_median(check.times), lessThan(5));
    expect(_median(rebuild.times), lessThan(100));
  });
}
