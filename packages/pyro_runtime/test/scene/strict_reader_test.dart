import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/src/scene/errors.dart';
import 'package:pyro_runtime/src/scene/json/strict_reader.dart';

void main() {
  group('duplicate keys', () {
    test('are refused with key, path, line and column', () {
      const text =
          '{\n  "nodes": {\n    "a1": {\n      "transform": {\n'
          '        "angle": 0,\n        "angle": 1\n      }\n    }\n  }\n}';
      expect(
        () => readStrictJson(text),
        throwsA(
          isA<DuplicateKey>()
              .having((e) => e.key, 'key', 'angle')
              .having((e) => e.path, 'path', 'nodes.a1.transform')
              .having((e) => e.line, 'line', 6)
              .having((e) => e.column, 'column', 9),
        ),
      );
    });

    test('at the top level have an empty path', () {
      expect(
        () => readStrictJson('{"a": 1, "a": 2}'),
        throwsA(isA<DuplicateKey>().having((e) => e.path, 'path', '')),
      );
    });

    test('inside arrays name the index in the path', () {
      expect(
        () => readStrictJson('{"b": [{"type": "A", "type": "B"}]}'),
        throwsA(isA<DuplicateKey>().having((e) => e.path, 'path', 'b[0]')),
      );
    });
  });

  group('malformed input', () {
    for (final (name, text, line, column) in [
      ('trailing comma', '{"a": [1, 2,]}', 1, 13),
      ('unterminated string', '{"a": "abc', 1, 11),
      ('bare word', '{"a": abc}', 1, 7),
      ('trailing garbage', '{"a": 1} x', 1, 10),
      ('error on a later line', '{\n  "a": 1,\n  "b": ?\n}', 3, 8),
      ('empty input', '', 1, 1),
      ('raw control character in a string', '{"a": "x\ty"}', 1, 9),
      ('leading zero', '{"a": 01}', 1, 8),
    ]) {
      test(name, () {
        expect(
          () => readStrictJson(text),
          throwsA(
            isA<MalformedJson>()
                .having((e) => e.line, 'line', line)
                .having((e) => e.column, 'column', column),
          ),
        );
      });
    }

    test('reports the offset', () {
      expect(
        () => readStrictJson('[1, 2,]'),
        throwsA(isA<MalformedJson>().having((e) => e.offset, 'offset', 6)),
      );
    });
  });

  test('accepts a leading byte-order mark', () {
    expect(readStrictJson('﻿{"a": 1}'), {'a': 1});
  });

  test('accepts CRLF line endings', () {
    expect(readStrictJson('{\r\n  "a": [\r\n    1\r\n  ]\r\n}\r\n'), {
      'a': [1],
    });
  });

  test('reads whole numbers as int and others as double', () {
    final value = readStrictJson('[80, 80.0, -3, 1e2, 0.25, -0]')! as List;
    expect(value[0], isA<int>());
    expect(value[1], isA<double>());
    expect(value[2], -3);
    expect(value[3], isA<double>());
    expect(value[3], 100.0);
    expect(value[4], 0.25);
    expect(value[5], 0);
  });

  test('decodes string escapes', () {
    expect(
      readStrictJson(r'"\" \\ \/ \b \f \n \r \t é 😀"'),
      '" \\ / \b \f \n \r \t é 😀',
    );
  });

  test('keeps non-ASCII text as written', () {
    expect(readStrictJson('"مرحبا 😀"'), 'مرحبا 😀');
  });

  test('reads true, false and null', () {
    expect(readStrictJson('[true, false, null]'), [true, false, null]);
  });

  test('returns unmodifiable maps and lists', () {
    final value =
        readStrictJson('{"a": [1], "b": {}}')! as Map<String, Object?>;
    expect(() => value['c'] = 1, throwsUnsupportedError);
    expect(() => (value['a']! as List<Object?>).add(2), throwsUnsupportedError);
    expect(
      () => (value['b']! as Map<String, Object?>)['x'] = 1,
      throwsUnsupportedError,
    );
  });

  test('keeps object keys in file order', () {
    final value = readStrictJson('{"b": 1, "a": 2}')! as Map<String, Object?>;
    expect(value.keys, ['b', 'a']);
  });

  test('parses 500 levels of nesting', () {
    final text = '${'[' * 500}${']' * 500}';
    expect(readStrictJson(text), isA<List<Object?>>());
  });
}
