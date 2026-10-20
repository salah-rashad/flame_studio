// Measures `build_runner watch` latency on a generated project.
//
//   dart run bin/measure.dart --project ../sample --runs 5
//
// Starts `dart run build_runner watch`, waits for the first build, then for
// each scenario: edits a file, and times (from the moment the write returns)
// until the Manifest / Registry change on disk and until build_runner reports
// the build finished. Every edit is unique and is reverted afterwards (the
// revert build is waited for but not timed).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

late String project;
late Process watcher;
final _built = StreamController<String>.broadcast();
final _log = <String>[];
var verbose = false;

Future<void> main(List<String> args) async {
  final o = (ArgParser()
        ..addOption('project', defaultsTo: '../sample')
        ..addOption('runs', defaultsTo: '5')
        ..addOption('settle-ms', defaultsTo: '500')
        ..addFlag('verbose', abbr: 'v'))
      .parse(args);
  project = p.normalize(p.absolute(o['project'] as String));
  final runs = int.parse(o['runs'] as String);
  final settle = Duration(milliseconds: int.parse(o['settle-ms'] as String));
  verbose = o['verbose'] as bool;

  // A project generated with gen_project.dart --pyro (and built once) has
  // the real generator's files (spec 003, research R13).
  final pyro = File(p.join(project, 'lib/pyro.manifest.json')).existsSync();
  final manifest = File(
    p.join(project, pyro ? 'lib/pyro.manifest.json' : 'lib/flame_studio.manifest.json'),
  );
  final registry = File(
    p.join(project, pyro ? 'lib/pyro.g.dart' : 'lib/flame_studio.g.dart'),
  );

  final start = Stopwatch()..start();
  watcher = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'build_runner', 'watch', '--verbose-durations'],
    workingDirectory: project,
  );
  for (final s in [watcher.stdout, watcher.stderr]) {
    s.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      _log.add(line);
      if (verbose) stdout.writeln('  | $line');
      if (line.contains('Built with build_runner') ||
          line.contains('Failed to build with build_runner')) {
        _built.add(line.trim());
      }
    });
  }
  unawaited(watcher.exitCode.then((c) {
    stdout.writeln('watcher exited with $c');
  }));
  final first = await _built.stream.first.timeout(const Duration(minutes: 3));
  stdout.writeln('Watch ready after ${start.elapsedMilliseconds} ms: $first');
  await Future<void>.delayed(settle);

  final behavior = File(p.join(project, 'lib/behaviors/behavior_000.dart'));
  final core0 = File(p.join(project, 'lib/core/core_000.dart'));
  final util0 = File(p.join(project, 'lib/util/util_000.dart'));
  final results = <String, List<_Sample>>{};
  var counter = DateTime.now().millisecondsSinceEpoch % 100000;

  Future<void> scenario(
    String name, {
    required File file,
    required String Function(String original, int n) edit,
    required bool manifestChanges,
    required bool registryChanges,
    bool create = false,
    int? times,
  }) async {
    for (var r = 0; r < (times ?? runs); r++) {
      final n = counter++;
      final original = create ? null : file.readAsStringSync();
      final m0 = manifest.readAsStringSync();
      final g0 = registry.readAsStringSync();
      final builtF = _built.stream.first;

      final sw = Stopwatch();
      file.writeAsStringSync(edit(original ?? '', n), flush: true);
      sw.start();

      int? mMs, gMs, bMs;
      String? builtLine;
      unawaited(builtF.then((l) {
        bMs = sw.elapsedMilliseconds;
        builtLine = l;
      }));
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (DateTime.now().isBefore(deadline)) {
        if (mMs == null && manifest.readAsStringSync() != m0) {
          mMs = sw.elapsedMilliseconds;
        }
        if (gMs == null && registry.readAsStringSync() != g0) {
          gMs = sw.elapsedMilliseconds;
        }
        final outputsDone = (!manifestChanges || mMs != null) &&
            (!registryChanges || gMs != null);
        if (bMs != null && outputsDone) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final s = _Sample(mMs, gMs, bMs, builtLine);
      (results[name] ??= []).add(s);
      stdout.writeln('$name #${r + 1}: $s');
      if (manifestChanges != (mMs != null) ||
          registryChanges != (gMs != null)) {
        stdout.writeln('  !! unexpected output change pattern');
      }

      // Revert and wait for that build too.
      await Future<void>.delayed(settle);
      final revert = _built.stream.first;
      if (create) {
        file.deleteSync();
      } else {
        file.writeAsStringSync(original!, flush: true);
      }
      await revert.timeout(const Duration(seconds: 60));
      await Future<void>.delayed(settle);
    }
  }

  await scenario(
    '0 first edit after watch start (tooltip)',
    file: behavior,
    edit: (s, n) => s.replaceFirst("tooltip: 'Speed 0'", "tooltip: 'S$n'"),
    manifestChanges: true,
    registryChanges: false,
    times: 1,
  );
  await scenario(
    'A annotated: tooltip edit',
    file: behavior,
    edit: (s, n) => s.replaceFirst("tooltip: 'Speed 0'", "tooltip: 'S$n'"),
    manifestChanges: true,
    registryChanges: false,
  );
  await scenario(
    'B annotated: add @Editable field',
    file: behavior,
    edit: (s, n) => s.replaceFirst(
      '  @Editable()\n  Vector2 direction',
      '  @Editable()\n  int extra$n = $n;\n\n  @Editable()\n  Vector2 direction',
    ),
    manifestChanges: true,
    registryChanges: true,
  );
  await scenario(
    'C annotated: method body edit',
    file: behavior,
    edit: (s, n) => s.replaceFirst('acc = acc *', 'acc = acc + $n *'),
    manifestChanges: false,
    registryChanges: false,
  );
  await scenario(
    'D unannotated leaf edit',
    file: util0,
    edit: (s, n) => s.replaceFirst('int ticks = 0;', 'int ticks = $n;'),
    manifestChanges: false,
    registryChanges: false,
  );
  await scenario(
    'E unannotated core edit (imported by all)',
    file: core0,
    edit: (s, n) => s.replaceFirst('int ticks = 0;', 'int ticks = $n;'),
    manifestChanges: false,
    registryChanges: false,
  );
  await scenario(
    'F new annotated file',
    file: File(p.join(project, 'lib/behaviors/zz_new.dart')),
    create: true,
    edit: (_, n) => '''
${pyro ? "import 'package:pyro_annotations/pyro_annotations.dart';" : "import 'package:studio_annotations/studio_annotations.dart';"}
${File(p.join(project, 'lib/flame_stub.dart')).existsSync() ? "import 'package:sample_game/flame_stub.dart';" : "import 'package:flame_behaviors/flame_behaviors.dart';"}

@${pyro ? 'PyroBehavior' : 'StudioBehavior'}()
class NewBehavior$n extends Behavior<PositionedEntity> {
  @Editable()
  double speed = $n.0;
}
''',
    manifestChanges: true,
    registryChanges: true,
  );

  stdout.writeln('\n| Scenario | Manifest updated | Registry updated | '
      'Build done (harness) | build_runner reports |');
  stdout.writeln('|---|---|---|---|---|');
  for (final e in results.entries) {
    String med(List<int?> xs) {
      final v = xs.whereType<int>().toList()..sort();
      if (v.isEmpty) return 'unchanged';
      return '${v[v.length ~/ 2]} ms (${v.first}–${v.last})';
    }

    final reported = e.value
        .map((s) => RegExp(r'in ([\d.]+m?s)').firstMatch(s.line ?? '')?[1])
        .join(', ');
    stdout.writeln('| ${e.key} | ${med([for (final s in e.value) s.m])} | '
        '${med([for (final s in e.value) s.g])} | '
        '${med([for (final s in e.value) s.b])} | $reported |');
  }

  watcher.kill();
  await watcher.exitCode;
  exit(0);
}

class _Sample {
  final int? m, g, b;
  final String? line;
  _Sample(this.m, this.g, this.b, this.line);
  @override
  String toString() =>
      'manifest ${m ?? '-'} ms, registry ${g ?? '-'} ms, built ${b ?? '-'} ms'
      ' ($line)';
}
