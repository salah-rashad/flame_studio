import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/process/src/daemon_message.dart';

void main() {
  group('parseDaemonLine', () {
    test('reads an event', () {
      final [message] = parseDaemonLine(
        '[{"event":"app.started","params":{"appId":"app-1"}}]',
      );
      expect(
        message,
        isA<DaemonEvent>().having((e) => e.name, 'name', 'app.started').having(
          (e) => e.params,
          'params',
          {'appId': 'app-1'},
        ),
      );
    });

    test('reads an event without params', () {
      final [message] = parseDaemonLine('[{"event":"daemon.ping"}]');
      expect(
        message,
        isA<DaemonEvent>().having((e) => e.params, 'params', isEmpty),
      );
    });

    test('reads a response with a result and one with an error', () {
      final [ok] = parseDaemonLine('[{"id":1,"result":{"code":0}}]');
      expect(
        ok,
        isA<DaemonResponse>()
            .having((r) => r.id, 'id', 1)
            .having((r) => r.result, 'result', {'code': 0})
            .having((r) => r.error, 'error', isNull),
      );
      final [failed] = parseDaemonLine('[{"id":2,"error":"no app"}]');
      expect(
        failed,
        isA<DaemonResponse>().having((r) => r.error, 'error', 'no app'),
      );
    });

    test('reads a batch of two messages', () {
      final messages = parseDaemonLine(
        '[{"event":"app.log","params":{"log":"a"}},{"id":3,"result":true}]',
      );
      expect(messages, [isA<DaemonEvent>(), isA<DaemonResponse>()]);
    });

    test('keeps anything else as one raw line', () {
      const lines = [
        'Launching lib/main.dart on macOS in debug mode...',
        '[{not json}]',
        '[{"neither":"event nor id"}]',
        '',
      ];
      for (final line in lines) {
        expect(parseDaemonLine(line), [
          isA<RawLine>().having((r) => r.text, 'text', line),
        ], reason: line);
      }
    });

    test('reads an unknown event as an event', () {
      final [message] = parseDaemonLine(
        '[{"event":"app.somethingNew","params":{}}]',
      );
      expect(message, isA<DaemonEvent>());
    });

    test('never throws on any transcript line', () {
      final files = Directory(
        'test/fixtures/daemon',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.txt'));
      expect(files, isNotEmpty);
      for (final file in files) {
        for (final line in file.readAsLinesSync()) {
          expect(() => parseDaemonLine(line), returnsNormally, reason: line);
        }
      }
    });
  });
}
