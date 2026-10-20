import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:pyro_generator/builder.dart';

import 'stubs.dart';

/// The root package's name in every test.
const gamePackage = 'game';

/// What one run of both builders produced.
final class GeneratorRun {
  GeneratorRun._(
    this.succeeded,
    this.registry,
    this.manifest,
    this.fragments,
    this.log,
  );

  /// Whether build_runner reported the build as successful.
  final bool succeeded;

  /// `lib/pyro.g.dart`, or null if it wasn't written.
  final String? registry;

  /// `lib/pyro.manifest.json`, or null if it wasn't written.
  final String? manifest;

  /// Every `.pyro.json` fragment the scan wrote, by path.
  final Map<String, String> fragments;

  /// The builders' warnings and errors, one `LEVEL message` line each.
  final List<String> log;

  /// [log] as the `log.golden` file holds it.
  String get logText => log.isEmpty ? '' : '${log.join('\n')}\n';
}

/// Reads `pyro_annotations`' real sources into `testBuilders` form.
Map<String, String> _annotationSources() {
  final root = Directory('../pyro_annotations/lib');
  return {
    for (final file in root.listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart'))
        'pyro_annotations|lib/${file.path.substring(root.path.length + 1).replaceAll(r'\', '/')}':
            file.readAsStringSync(),
  };
}

/// Runs the scan and the aggregate builders on [gameSources] (paths under
/// the `game` package, such as `lib/a.dart`) with the stand-in packages.
Future<GeneratorRun> runGenerator(
  Map<String, String> gameSources, {
  bool withRuntime = true,
}) async {
  final sources = <String, String>{
    ..._annotationSources(),
    ...flameStubs,
    if (withRuntime) ...runtimeStub,
    for (final MapEntry(:key, :value) in gameSources.entries)
      '$gamePackage|$key': value,
  };
  final log = <String>[];
  final readerWriter = TestReaderWriter(
    rootPackage: gamePackage,
    flattenOutput: true,
  );
  final result = await testBuilders(
    [pyroScan(BuilderOptions.empty), pyroAggregate(BuilderOptions.empty)],
    sources,
    rootPackage: gamePackage,
    readerWriter: readerWriter,
    isInput: (id) => id.startsWith('$gamePackage|'),
    onLog: (record) {
      // Level.WARNING and above, without depending on package:logging. The
      // aggregator also runs on the stand-in packages here (in a real build
      // it applies only to the game); their records name the package, as in
      // "PyroAggregateBuilder on flame|lib/$lib$:", and are skipped.
      final [header, ...lines] = record.message.split('\n');
      if (record.level.value >= 900 && !header.contains('|')) {
        log.add('${record.level.name} ${lines.join('\n')}');
      }
    },
  );
  // build_runner keeps generated files under .dart_tool/build/generated/ in
  // the test's in-memory file system.
  const generated = '.dart_tool/build/generated/$gamePackage/';
  final testing = result.readerWriter.testing;
  String? read(String path) {
    for (final id in [
      AssetId(gamePackage, path),
      AssetId(gamePackage, '$generated$path'),
    ]) {
      if (testing.exists(id)) return testing.readString(id);
    }
    return null;
  }

  return GeneratorRun._(
    result.succeeded,
    read('lib/pyro.g.dart'),
    read('lib/pyro.manifest.json'),
    {
      for (final id in testing.assets)
        if (id.package == gamePackage && id.path.endsWith('.pyro.json'))
          id.path.replaceFirst(generated, ''): testing.readString(id),
    },
    log,
  );
}
