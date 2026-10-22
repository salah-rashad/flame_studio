import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/process/process.dart';

void main() {
  group('redactAuthCodes', () {
    test('masks the VM service URL the engine prints on desktop', () {
      expect(
        redactAuthCodes(
          'flutter: The Dart VM service is listening on '
          'http://127.0.0.1:50300/AbCdEf123456=/',
        ),
        'flutter: The Dart VM service is listening on '
        'http://127.0.0.1:50300/<auth-code>=/',
      );
    });

    test('masks a WebSocket URI', () {
      expect(
        redactAuthCodes('ws://127.0.0.1:50300/AbCdEf123456=/ws'),
        'ws://127.0.0.1:50300/<auth-code>=/ws',
      );
    });

    test("masks the tooling daemon's URI at the end of a line", () {
      expect(
        redactAuthCodes('DTD at ws://127.0.0.1:1235/AbCdEf123456='),
        'DTD at ws://127.0.0.1:1235/<auth-code>=',
      );
    });

    test('masks a code followed by a closing delimiter', () {
      const lines = [
        '(ws://127.0.0.1:1/AbCdEf123456=)',
        "'ws://127.0.0.1:1/AbCdEf123456='",
        'ws://127.0.0.1:1/AbCdEf123456=,',
        'ws://127.0.0.1:1/AbCdEf123456=.',
      ];
      for (final line in lines) {
        expect(
          redactAuthCodes(line),
          line.replaceAll('AbCdEf123456=', '<auth-code>='),
        );
      }
    });

    test('masks a URI inside JSON quotes', () {
      expect(
        redactAuthCodes('{"wsUri":"ws://127.0.0.1:50300/AbCdEf123456=/ws"}'),
        '{"wsUri":"ws://127.0.0.1:50300/<auth-code>=/ws"}',
      );
    });

    test('leaves lines without a code alone', () {
      const lines = [
        'Launching lib/main.dart on macOS in debug mode...',
        'See https://flutter.dev/to/add-desktop-support to learn more.',
        'http://127.0.0.1:8080/index.html',
      ];
      for (final line in lines) {
        expect(redactAuthCodes(line), line);
      }
    });
  });
}
