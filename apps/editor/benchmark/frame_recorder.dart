// Records a running Pyro's frame times for the SC-004 budget check
// (quickstart §5): `dart run benchmark/frame_recorder.dart <ws-uri> <seconds>`
// while the app runs with `flutter run --profile`. Reads the `Flutter.Frame`
// events the framework posts in profile mode; prints build and raster
// percentiles and the frames over 16 ms.
import 'dart:async';
import 'dart:io';

import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  final service = await vmServiceConnectUri(args[0]);
  final seconds = int.parse(args.length > 1 ? args[1] : '10');
  final build = <int>[];
  final raster = <int>[];
  await service.streamListen('Extension');
  final sub = service.onExtensionEvent.listen((event) {
    if (event.extensionKind != 'Flutter.Frame') return;
    final data = event.extensionData!.data;
    build.add((data['build'] as num).toInt());
    raster.add((data['raster'] as num).toInt());
  });
  stdout.writeln('recording for ${seconds}s…');
  await Future<void>.delayed(Duration(seconds: seconds));
  await sub.cancel();
  await service.dispose();
  String ms(int us) => (us / 1000).toStringAsFixed(2);
  String stats(List<int> v) {
    if (v.isEmpty) return 'no frames';
    final s = [...v]..sort();
    int p(double q) => s[((s.length - 1) * q).round()];
    return 'p50 ${ms(p(.5))} ms, p90 ${ms(p(.9))} ms, p99 ${ms(p(.99))} ms, '
        'max ${ms(s.last)} ms';
  }

  var over = 0;
  for (var i = 0; i < build.length; i++) {
    if (build[i] > 16667 || raster[i] > 16667) over++;
  }
  stdout
    ..writeln('frames: ${build.length}')
    ..writeln('build:  ${stats(build)}')
    ..writeln('raster: ${stats(raster)}')
    ..writeln('frames over 16 ms (build or raster): $over');
}
