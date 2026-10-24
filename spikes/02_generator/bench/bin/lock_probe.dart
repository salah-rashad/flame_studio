// Probes build_runner's process lock the way the Studio would (Q48, §9.2).
//
//   dart run bin/lock_probe.dart <project>            one probe
//   dart run bin/lock_probe.dart <project> --poll     print every change
//   dart run bin/lock_probe.dart <project> --studio   play the Studio's part
//
// build_runner ≥ 2.14 holds an exclusive lock on
// `.dart_tool/build/lock/build_runner.lock` for as long as a command runs
// (and a shared lock on `build_runner.workspace.lock` at the workspace root
// when the package is in a pub workspace). A second command that fails to
// take it writes `<lock>.requested`, which makes a running `watch` finish its
// build and exit. The probe must never do that: it takes the lock
// non-blocking and releases it straight away, and never writes `.requested`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

enum LockState {
  /// No lock file: build_runner ≥ 2.14 has never run here.
  none,

  /// Lock file exists and nobody holds it.
  free,

  /// Another process holds it: a `watch`, `serve` or one-off `build` is
  /// running.
  held,
}

LockState probe(String project, {String? workspaceRoot}) {
  final pkg = _tryLock(
    p.join(project, '.dart_tool/build/lock/build_runner.lock'),
    FileLock.exclusive,
  );
  if (pkg == LockState.held) return pkg;
  if (workspaceRoot != null) {
    // A whole-workspace build holds this exclusively; package builds share
    // it. Probing shared only reports the former.
    final ws = _tryLock(
      p.join(
        workspaceRoot,
        '.dart_tool/build/lock/build_runner.workspace.lock',
      ),
      FileLock.shared,
    );
    if (ws == LockState.held) return ws;
  }
  return pkg;
}

LockState _tryLock(String path, FileLock mode) {
  final file = File(path);
  if (!file.existsSync()) return LockState.none;
  // append, not write: don't truncate or create anything.
  final raf = file.openSync(mode: FileMode.append);
  try {
    raf.lockSync(mode);
    raf.unlockSync();
    return LockState.free;
  } on FileSystemException {
    return LockState.held;
  } finally {
    raf.closeSync();
  }
}

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('poll', help: 'Probe every 200 ms and print changes')
    ..addFlag('studio', help: 'Simulate the Studio policy')
    ..addOption('workspace-root');
  final o = parser.parse(args);
  if (o.rest.length != 1) {
    stderr.writeln('usage: lock_probe <project> [--poll|--studio]');
    exit(64);
  }
  final project = p.normalize(p.absolute(o.rest.single));
  final ws = o['workspace-root'] as String?;
  final requested = File(
    p.join(project, '.dart_tool/build/lock/build_runner.lock.requested'),
  );

  if (o['studio'] as bool) return _studio(project, ws);

  final sw = Stopwatch()..start();
  final first = probe(project, workspaceRoot: ws);
  stdout.writeln(
    '${first.name} (probe took ${sw.elapsedMicroseconds} µs, '
    '.requested exists: ${requested.existsSync()})',
  );
  if (!(o['poll'] as bool)) return;

  var last = first;
  final t0 = DateTime.now();
  Timer.periodic(const Duration(milliseconds: 200), (_) {
    final s = probe(project, workspaceRoot: ws);
    if (s != last) {
      final t = DateTime.now().difference(t0).inMilliseconds;
      stdout.writeln(
        '+$t ms: ${last.name} -> ${s.name} '
        '(.requested exists: ${requested.existsSync()})',
      );
      last = s;
    }
  });
}

/// The Studio's policy from §9.2, plus what this spike found: when its own
/// watcher exits, re-probe; held → external, free → restart its own.
Future<void> _studio(String project, String? ws) async {
  final manifest = File(p.join(project, 'lib/flame_studio.manifest.json'));
  final t0 = DateTime.now();
  void log(String m) => stdout.writeln(
    '[studio +${DateTime.now().difference(t0).inMilliseconds} ms] $m',
  );

  String? lastManifest = manifest.existsSync()
      ? manifest.readAsStringSync()
      : null;
  Timer.periodic(const Duration(milliseconds: 250), (_) {
    final now = manifest.existsSync() ? manifest.readAsStringSync() : null;
    if (now != lastManifest) {
      lastManifest = now;
      log('Manifest changed -> re-parse catalog');
    }
  });

  while (true) {
    final state = probe(project, workspaceRoot: ws);
    if (state == LockState.held) {
      log('lock held -> status "External build_runner"');
      while (probe(project, workspaceRoot: ws) == LockState.held) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      log('lock released -> external watcher gone');
      continue;
    }
    log('lock ${state.name} -> starting own `build_runner watch`');
    final proc = await Process.start(Platform.resolvedExecutable, [
      'run',
      'build_runner',
      'watch',
    ], workingDirectory: project);
    log('own watcher pid ${proc.pid}');
    for (final s in [proc.stdout, proc.stderr]) {
      s.transform(utf8.decoder).transform(const LineSplitter()).listen((l) {
        if (l.trim().isEmpty) return;
        if (l.contains('Built with') ||
            l.contains('Failed') ||
            l.contains('Waiting') ||
            l.contains('stop') ||
            l.contains('request') ||
            l.contains('exit')) {
          log('  watcher: ${l.trim()}');
        }
      });
    }
    final code = await proc.exitCode;
    log('own watcher exited with $code -> re-probe');
    // The process that took over may not have its lock yet; give it a moment.
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}
