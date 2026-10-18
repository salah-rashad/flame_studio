import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'fixtures.dart';

SceneReadResult _decode(String name) =>
    SceneCodec.decode(readFixture('version/$name.scene.json'));

void main() {
  test('a newer file is refused, naming both versions (FR-019)', () {
    // The newer file's Nodes are invalid for this version: the version gate
    // must run before any Node is read.
    expect(
      () => _decode('newer'),
      throwsA(
        isA<UnsupportedSchemaVersion>()
            .having((e) => e.found, 'found', 2)
            .having((e) => e.supported, 'supported', 1)
            .having(
              (e) => e.toString(),
              'toString()',
              allOf(contains('schemaVersion 2'), contains('schemaVersion 1')),
            ),
      ),
    );
  });

  group('a missing or invalid version is refused (FR-020)', () {
    test('missing', () {
      expect(
        () => _decode('missing'),
        throwsA(
          isA<InvalidSchemaVersion>().having(
            (e) => e.isMissing,
            'isMissing',
            isTrue,
          ),
        ),
      );
    });

    for (final (name, found) in <(String, Object?)>[
      ('zero', 0),
      ('negative', -1),
      ('string', '1'),
      ('fraction', 1.5),
      ('null', null),
    ]) {
      test(name, () {
        expect(
          () => _decode(name),
          throwsA(
            isA<InvalidSchemaVersion>()
                .having((e) => e.isMissing, 'isMissing', isFalse)
                .having((e) => e.found, 'found', found),
          ),
        );
      });
    }
  });

  test('the current version is read, also when written as 1.0', () {
    expect(_decode('current').scene.root.id, const NodeId('root'));
    expect(_decode('current_as_float').scene.root.id, const NodeId('root'));
  });

  test('every written Scene starts with the current version (FR-018)', () {
    final output = SceneCodec.encode(_decode('current_as_float').scene);
    expect(output, startsWith('{\n  "schemaVersion": 1,\n'));
    expect(Scene.currentSchemaVersion, 1);
  });
}
