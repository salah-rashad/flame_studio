import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/src/scene/json/canonical_writer.dart';

void main() {
  test('uses LF, two spaces and one trailing newline', () {
    expect(
      writeCanonicalJson({
        'a': {'b': true},
      }),
      '{\n  "a": {\n    "b": true\n  }\n}\n',
    );
  });

  test('writes the given top-level keys first, then the rest sorted', () {
    expect(
      writeCanonicalJson(
        {'z': 1, 'nodes': 2, 'a': 3, 'schemaVersion': 4, 'rootId': 5},
        topLevelOrder: ['schemaVersion', 'rootId', 'nodes'],
      ),
      '{\n  "schemaVersion": 4,\n  "rootId": 5,\n  "nodes": 2,\n  "a": 3,\n'
      '  "z": 1\n}\n',
    );
  });

  test('skips top-level keys in the order that are absent', () {
    expect(
      writeCanonicalJson({'b': 1, 'a': 2}, topLevelOrder: ['x', 'b']),
      '{\n  "b": 1,\n  "a": 2\n}\n',
    );
  });

  test('sorts nested keys by UTF-16 code units', () {
    expect(
      writeCanonicalJson({
        'o': {'b': 1, 'B': 2, 'a': 3, '_': 4},
      }),
      '{\n  "o": {\n    "B": 2,\n    "_": 4,\n    "a": 3,\n    "b": 1\n  }\n}\n',
    );
  });

  test('writes empty objects and arrays as {} and []', () {
    expect(
      writeCanonicalJson({'a': <String, Object?>{}, 'b': <Object?>[]}),
      '{\n  "a": {},\n  "b": []\n}\n',
    );
  });

  test('writes number-only arrays on one line', () {
    expect(
      writeCanonicalJson({
        'p': [320, 128.5],
      }),
      '{\n  "p": [320, 128.5]\n}\n',
    );
  });

  test('writes other arrays one element per line', () {
    expect(
      writeCanonicalJson({
        'ids': ['a', 'b'],
        'mixed': [1, 'x'],
      }),
      '{\n  "ids": [\n    "a",\n    "b"\n  ],\n  "mixed": [\n    1,\n'
      '    "x"\n  ]\n}\n',
    );
  });

  group('numbers', () {
    for (final (value, written) in [
      (80, '80'),
      (80.0, '80'),
      (-3.0, '-3'),
      (1e20, '100000000000000000000'),
      (1e21, '1e+21'),
      (0.1, '0.1'),
      (1e-7, '1e-7'),
      (1.23e-18, '1.23e-18'),
      (-0.0, '0'),
      (9007199254740993, '9007199254740993'),
      (-2.5, '-2.5'),
    ]) {
      test('$value is written $written', () {
        expect(writeCanonicalJson(value), '$written\n');
      });
    }

    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      test('$value cannot be written', () {
        expect(
          () => writeCanonicalJson({
            'a': [value],
          }),
          throwsA(
            isA<UnwritableJsonValue>().having((e) => e.path, 'path', ['a', 0]),
          ),
        );
      });
    }
  });

  group('strings', () {
    test('escape quote, backslash and control characters only', () {
      expect(
        writeCanonicalJson('" \\ \b \f \n \r \t \u0001 \u001f'),
        r'"\" \\ \b \f \n \r \t \u0001 \u001f"'
        '\n',
      );
    });

    test('leave non-ASCII text, emoji and / as they are', () {
      expect(writeCanonicalJson('é 😀 / مرحبا'), '"é 😀 / مرحبا"\n');
    });
  });

  test('refuses values that are not JSON', () {
    expect(
      () => writeCanonicalJson({'a': DateTime(2026)}),
      throwsA(isA<UnwritableJsonValue>()),
    );
  });
}
