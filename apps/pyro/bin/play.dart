// Plays a Flame game from the command line: starts it with
// `flutter run --machine` on macOS and Hot-swaps its Scenes when they are
// saved. It is the vertical slice's entry point until the Play button
// (spec 005, contracts/play-cli.md); the work is done by lib/process/.
//
// Usage, from apps/pyro:
//   dart run bin/play.dart <project> [--flutter <path>] [--record <file>]
//
// Type `r` + Enter to hot-reload, `q` + Enter (or Ctrl-C) to stop.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pyro/process/process.dart';

const _usage =
    'Usage: dart run bin/play.dart <project> [--flutter <path>] '
    '[--record <file>]';

Future<void> main(List<String> args) async {
  String? project;
  var flutter = 'flutter';
  String? record;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--flutter' when i + 1 < args.length:
        flutter = args[++i];
      case '--record' when i + 1 < args.length:
        record = args[++i];
      case _ when !arg.startsWith('-') && project == null:
        project = arg;
      default:
        stderr.writeln('Unexpected argument: $arg\n$_usage');
        exit(64);
    }
  }
  if (project == null) {
    stderr.writeln(_usage);
    exit(64);
  }
  exit(await _play(project, flutter: flutter, recordPath: record));
}

Future<int> _play(
  String project, {
  required String flutter,
  String? recordPath,
}) async {
  final clock = Stopwatch()..start();
  void say(Object event) {
    final seconds = (clock.elapsedMilliseconds / 1000).toStringAsFixed(3);
    stdout.writeln('${'+${seconds}s'.padRight(9)} $event');
  }

  // A transcript for the client's tests (research R6); lines arrive
  // already redacted.
  final record = recordPath == null ? null : File(recordPath).openWrite();
  final PlaySession session;
  try {
    session = await PlayClient(
      flutter: flutter,
    ).start(project, onStdoutLine: record?.writeln);
  } on PlayStartException catch (error) {
    stderr.writeln(error);
    await record?.close();
    return 1;
  }

  final keys = stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        switch (line.trim()) {
          case 'r':
            // Future.sync: reload() throws synchronously when the game
            // isn't running yet, and that throw must reach onError too.
            unawaited(
              Future.sync(session.reload).then<void>(
                (_) {},
                onError: (Object error) => say('no reload: $error'),
              ),
            );
          case 'q':
            unawaited(session.stop());
          case '':
            break;
          default:
            say('keys: r = hot reload, q = stop');
        }
      });
  final signals = [
    ProcessSignal.sigint.watch(),
    if (!Platform.isWindows) ProcessSignal.sigterm.watch(),
  ].map((signal) => signal.listen((_) => unawaited(session.stop()))).toList();

  var failed = false;
  var status = 0;
  await for (final event in session.events) {
    say(event);
    switch (event) {
      case PlayFailed():
        failed = true;
      case PlayStopped(:final exitCode, :final requested):
        status = requested ? 0 : exitCode;
      default:
        break;
    }
  }
  await keys.cancel();
  for (final signal in signals) {
    await signal.cancel();
  }
  await record?.close();
  return failed ? 1 : status;
}
