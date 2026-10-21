// Times SceneCodec on a 1,000-Node Scene (SC-006: median under 100 ms each
// for decode and encode, AOT, on the reference Mac).
//
//   dart run benchmark/scene_codec_benchmark.dart
//   dart compile exe benchmark/scene_codec_benchmark.dart -o /tmp/scene_bench
//   /tmp/scene_bench
//
// Imports only the pure-Dart scene format (research R5), so it runs outside
// Flutter.
import 'dart:io';

import 'package:pyro_runtime/src/scene/scene_codec.dart';

import 'support/benchmark_scene.dart';

const int _warmUp = 10;
const int _runs = 50;

void main() {
  final text = SceneCodec.encode(benchmarkScene());
  final scene = SceneCodec.decode(text).scene;
  stdout.writeln(
    'Scene: ${scene.nodes.length} Nodes, '
    '${(text.length / 1024).toStringAsFixed(1)} KB',
  );

  _report('decode', () => SceneCodec.decode(text));
  _report('encode', () => SceneCodec.encode(scene));
}

void _report(String name, void Function() run) {
  for (var i = 0; i < _warmUp; i++) {
    run();
  }
  final times = <double>[];
  final stopwatch = Stopwatch();
  for (var i = 0; i < _runs; i++) {
    stopwatch
      ..reset()
      ..start();
    run();
    stopwatch.stop();
    times.add(stopwatch.elapsedMicroseconds / 1000);
  }
  times.sort();
  final median = times[times.length ~/ 2];
  final p95 = times[(times.length * 0.95).floor() - 1];
  stdout.writeln(
    '$name: median ${median.toStringAsFixed(2)} ms, '
    'p95 ${p95.toStringAsFixed(2)} ms ($_runs runs)',
  );
}
