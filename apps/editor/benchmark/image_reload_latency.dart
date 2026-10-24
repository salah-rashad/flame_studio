// Times a changed image reaching the viewport (SC-005, quickstart §5):
// `dart run benchmark/image_reload_latency.dart <ws-uri> <image-path>` while
// Pyro runs with `flutter run --profile` and a Scene drawing that image is
// open. Flips the image on disk with `sips` (run it twice to flip it back),
// then reads the "Pyro asset changed" / "Pyro image shown" timeline markers
// and the next raster.
import 'dart:io';
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  final s = await vmServiceConnectUri(args[0]);
  await s.setVMTimelineFlags(['Dart', 'Embedder']);
  await s.clearVMTimeline();
  await Future<void>.delayed(const Duration(milliseconds: 300));
  final t0 = (await s.getVMTimelineMicros()).timestamp!;
  await Process.run('sips', ['-f', 'vertical', args[1]]);
  final t1 = (await s.getVMTimelineMicros()).timestamp!;
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  final events = [
    for (final e in (await s.getVMTimeline()).traceEvents!) e.json!,
  ];
  double ms(num ts) => (ts - t0) / 1000;
  num? first(String name, [num after = 0]) {
    num? best;
    for (final e in events) {
      final ts = e['ts'] as num?;
      if (ts == null || e['name'] != name || ts < after) continue;
      if (best == null || ts < best) best = ts;
    }
    return best;
  }

  final shown = [
    for (final e in events)
      if (e['name'] == 'Pyro image shown') e['ts'] as num,
  ]..sort();
  final changed = first('Pyro asset changed', t0);
  stdout.writeln('file written:        ${ms(t1).toStringAsFixed(1)} ms');
  stdout.writeln(
    'watcher fired:       ${changed == null ? '-' : ms(changed).toStringAsFixed(1)} ms',
  );
  if (shown.isNotEmpty) {
    final raster = first('Rasterizer::DoDraw', shown.last);
    stdout.writeln(
      'first sprite swapped: ${ms(shown.first).toStringAsFixed(1)} ms',
    );
    stdout.writeln(
      'last sprite swapped:  ${ms(shown.last).toStringAsFixed(1)} ms (${shown.length} sprites)',
    );
    stdout.writeln(
      'next raster after:    ${raster == null ? '-' : ms(raster).toStringAsFixed(1)} ms',
    );
  }
  await s.dispose();
}
