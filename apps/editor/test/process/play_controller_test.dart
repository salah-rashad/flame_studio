import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/process/process.dart';

import 'fake_process.dart';

/// A controller over a fake `flutter run` that replays recordings.
final class Harness {
  Harness({this.block}) {
    controller = PlayController(
      projectPath: projectPath,
      console: console,
      block: block,
      start: (path) {
        starts++;
        return PlayClient(
          startProcess: starter.call,
          fileSystem: fs,
          watchDirectory: (_) => const Stream.empty(),
        ).start(path);
      },
    );
    controller.phases.listen(phases.add);
    controller.notices.listen(notices.add);
  }

  final PlayBlock? block;
  final fs = projectFileSystem();
  final process = FakeProcess();
  late final starter = FakeStarter(process);
  final console = ConsoleBuffer();
  late final PlayController controller;
  final phases = <PlayPhase>[];
  final notices = <PlayNotice>[];
  var starts = 0;

  /// Answers every daemon request with success; `app.stop` also ends the
  /// process the way the recording did.
  void answerRequests() {
    process.onRequest = (request) {
      process.emitLine(
        jsonEncode([
          {'id': request['id'], 'result': true},
        ]),
      );
      if (request['method'] == 'app.stop') {
        process.emitLine('Application finished.');
        process.exit(0);
      }
    };
  }

  /// Replays [name] up to and including its `app.started` event.
  void startedFrom(String name) {
    process.queueLines(recorded(name));
    process.emitUntil((line) => line.contains('"app.started"'));
  }

  Iterable<ConsoleLine> linesFrom(ConsoleSource source) =>
      console.lines.where((line) => line.source == source);
}

void main() {
  test('goes stopped → starting → running → stopping → stopped', () {
    fakeAsync((async) {
      final h = Harness()..answerRequests();
      expect(h.controller.phase, PlayPhase.stopped);
      unawaited(h.controller.play());
      async.flushMicrotasks();
      expect(h.controller.phase, PlayPhase.starting);
      h.startedFrom('run-scene-save.txt');
      async.flushMicrotasks();
      expect(h.controller.phase, PlayPhase.running);
      unawaited(h.controller.stop());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      expect(h.controller.phase, PlayPhase.stopped);
      expect(h.phases, [
        PlayPhase.starting,
        PlayPhase.running,
        PlayPhase.stopping,
        PlayPhase.stopped,
      ]);
      expect(h.notices, isEmpty, reason: 'a requested stop is no notice');
    });
  });

  test('play() while starting, running or stopping starts nothing more', () {
    fakeAsync((async) {
      final h = Harness()..answerRequests();
      unawaited(h.controller.play());
      async.flushMicrotasks();
      unawaited(h.controller.play());
      async.flushMicrotasks();
      h.startedFrom('run-scene-save.txt');
      async.flushMicrotasks();
      unawaited(h.controller.play());
      async.flushMicrotasks();
      h.process.onRequest = null; // app.stop goes unanswered
      unawaited(h.controller.stop());
      async.flushMicrotasks();
      expect(h.controller.phase, PlayPhase.stopping);
      unawaited(h.controller.play());
      async.flushMicrotasks();
      expect(h.starts, 1);
      h.process.exit(0);
      async.elapse(const Duration(seconds: 2));
      expect(h.controller.phase, PlayPhase.stopped);
    });
  });

  test('a build that fails ends stopped and never shows running', () {
    fakeAsync((async) {
      final h = Harness();
      unawaited(h.controller.play());
      async.flushMicrotasks();
      h.process
        ..queueLines(recorded('build-failure.txt'))
        ..emitAll()
        ..emitStderr(
          "lib/code_marker.dart:5:20: Error: A value of type 'String' can't "
          "be assigned to a variable of type 'int'.",
        )
        ..exit(1);
      async.elapse(const Duration(seconds: 2));
      expect(h.phases, [PlayPhase.starting, PlayPhase.stopped]);
      expect(h.notices, isEmpty);
      final errors = h.console.lines.where(
        (line) => line.severity == ConsoleSeverity.error,
      );
      expect(
        errors.map((line) => line.text),
        contains(contains('lib/code_marker.dart:5:20: Error')),
      );
      expect(
        h.linesFrom(ConsoleSource.pyro).map((line) => line.text),
        contains(contains("couldn't start")),
      );
    });
  });

  test(
    'a game that exits on its own ends stopped with a GameStopped notice',
    () {
      fakeAsync((async) {
        final h = Harness();
        unawaited(h.controller.play());
        async.flushMicrotasks();
        h.startedFrom('exit-without-stop.txt');
        async.flushMicrotasks();
        h.process
          ..emitAll()
          ..exit(0);
        async.elapse(const Duration(seconds: 2));
        expect(h.controller.phase, PlayPhase.stopped);
        expect(h.notices, [isA<GameStopped>()]);
        expect(
          h.linesFrom(ConsoleSource.pyro).map((line) => line.text),
          contains('Game stopped.'),
        );
      });
    },
  );

  test('stop() ends stopped even when app.stop is ignored', () {
    fakeAsync((async) {
      final h = Harness();
      unawaited(h.controller.play());
      async.flushMicrotasks();
      h.startedFrom('run-scene-save.txt');
      async.flushMicrotasks();
      var stopped = false;
      unawaited(h.controller.stop().then((_) => stopped = true));
      async.elapse(PlayDefaults.stopTimeout);
      expect(h.process.signals, [ProcessSignal.sigterm]);
      async.elapse(const Duration(seconds: 2));
      expect(h.process.signals, [ProcessSignal.sigterm, ProcessSignal.sigkill]);
      h.process.exit(-9);
      async.elapse(const Duration(seconds: 2));
      expect(stopped, isTrue);
      expect(h.controller.phase, PlayPhase.stopped);
      expect(h.notices, isEmpty);
    });
  });

  test('a block makes play() start nothing', () {
    fakeAsync((async) {
      final h = Harness(
        block: PlayBlock.of(
          projectError: null,
          hasSdk: true,
          runtimeProblem: null,
          hasMacosFolder: false,
        ),
      );
      unawaited(h.controller.play());
      async.flushMicrotasks();
      expect(h.starts, 0);
      expect(h.controller.phase, PlayPhase.stopped);
      expect(h.phases, isEmpty);
    });
  });

  test("a project flutter can't start goes back to stopped", () {
    fakeAsync((async) {
      final console = ConsoleBuffer();
      final controller = PlayController(
        projectPath: projectPath,
        console: console,
        start: (path) async =>
            throw PlayStartException(path, 'could not start "flutter".'),
      );
      unawaited(controller.play());
      async.flushMicrotasks();
      expect(controller.phase, PlayPhase.stopped);
      expect(
        console.lines.last.text,
        "Can't play $projectPath: could not start \"flutter\".",
      );
      expect(console.lines.last.severity, ConsoleSeverity.error);
    });
  });

  test('lifecycle events are pyro lines, game output game lines', () {
    fakeAsync((async) {
      final h = Harness()..answerRequests();
      unawaited(h.controller.play());
      async.flushMicrotasks();
      h.startedFrom('run-scene-save.txt');
      async.flushMicrotasks();
      h.process.emitAll();
      async.flushMicrotasks();
      expect(
        h.linesFrom(ConsoleSource.game).map((line) => line.text),
        contains(
          'flutter: [pyro] Scene loaded: assets/scenes/level1.scene.json',
        ),
      );
      final pyro = h.linesFrom(ConsoleSource.pyro).map((line) => line.text);
      expect(pyro, contains(startsWith('Starting the game')));
      expect(pyro, contains(startsWith('The game is running')));
      expect(
        h.linesFrom(ConsoleSource.game).map((line) => line.text),
        isNot(contains(startsWith('[{'))),
        reason: 'daemon messages are parsed, not printed',
      );
      unawaited(h.controller.stop());
      async.elapse(const Duration(seconds: 2));
    });
  });

  test('dispose() stops a running game', () {
    fakeAsync((async) {
      final h = Harness()..answerRequests();
      unawaited(h.controller.play());
      async.flushMicrotasks();
      h.startedFrom('run-scene-save.txt');
      async.flushMicrotasks();
      unawaited(h.controller.dispose());
      async.elapse(const Duration(seconds: 2));
      expect(
        h.process.requests.map((request) => request['method']),
        contains('app.stop'),
      );
      expect(h.process.exited, isTrue);
    });
  });
}
