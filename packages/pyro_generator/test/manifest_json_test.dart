import 'package:pyro_generator/src/manifest_json.dart';
import 'package:test/test.dart';

void main() {
  test('sorts keys at every level, two-space indent, LF, trailing newline', () {
    expect(
      canonicalJson({
        'b': 1,
        'a': {'d': true, 'c': null},
      }),
      '{\n'
      '  "a": {\n'
      '    "c": null,\n'
      '    "d": true\n'
      '  },\n'
      '  "b": 1\n'
      '}\n',
    );
  });

  test('writes empty collections inline and arrays one element per line', () {
    expect(
      canonicalJson({'a': <Object?>[], 'b': <String, Object?>{}}),
      '{\n  "a": [],\n  "b": {}\n}\n',
    );
    expect(canonicalJson(['x', 'y']), '[\n  "x",\n  "y"\n]\n');
  });

  test('writes numbers in the Scene format form (Q92)', () {
    expect(canonicalJson(50.0), '50\n');
    expect(canonicalJson(-3.0), '-3\n');
    expect(canonicalJson(0.1), '0.1\n');
    expect(canonicalJson(-0.5), '-0.5\n');
    expect(canonicalJson(7), '7\n');
  });

  test('escapes strings as dart:convert does', () {
    expect(canonicalJson('a "q"\n\\'), '"a \\"q\\"\\n\\\\"\n');
  });

  test('refuses non-JSON values', () {
    expect(() => canonicalJson(double.nan), throwsArgumentError);
    expect(() => canonicalJson(Object()), throwsArgumentError);
  });
}
