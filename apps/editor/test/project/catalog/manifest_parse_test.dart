import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/project/catalog/manifest_parse.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../../helpers/fixtures.dart';

void main() {
  group('readManifest (T018, FR-012)', () {
    test('the example Manifest parses into its two types', () {
      final read = readManifest(readExampleManifest());
      final parsed = switch (read) {
        ManifestParsed() => read,
        _ => fail('expected a parsed Manifest, got $read'),
      };
      expect(parsed.problems, isEmpty);

      final banner = parsed.types.singleWhere(
        (t) => t.id == const TypeId('Banner'),
      );
      expect(banner.role, TypeRole.component);
      expect(banner.label, 'Banner');
      expect(banner.source, 'lib/components/banner.dart');
      expect(banner.doc, startsWith('A line of text'));
      expect(banner.parentType, isNull);
      expect(banner.acceptsBehaviors, isFalse);
      expect(banner.builtIn, isFalse);
      expect(banner.supertypes, {
        'TextComponent',
        'PositionComponent',
        'Component',
      });
      final message = banner.fields[0];
      expect(message.name, 'message');
      expect(message.type, FieldType.string);
      expect(message.nullable, isFalse);
      expect(message.defaultValue, 'Pyro');
      final color = banner.fields[1];
      expect(color.name, 'color');
      expect(color.type, FieldType.color);
      expect(color.defaultValue, isNull);
      expect(color.defaultSource, 'const Color(0xFFFFFFFF)');

      final spin = parsed.types.singleWhere(
        (t) => t.id == const TypeId('Spin'),
      );
      expect(spin.role, TypeRole.behavior);
      expect(spin.parentType, const TypeId('PyroEntity'));
      final turns = spin.fields[0];
      expect(turns.type, FieldType.double);
      expect(turns.min, 0);
      expect(turns.max, 4);
      expect(turns.defaultValue, 0.25);
      final clockwise = spin.fields[1];
      expect(clockwise.type, FieldType.bool);
      expect(clockwise.defaultValue, isTrue);
    });

    test('errors fail the read and carry every problem', () {
      final read = readManifest(manifestWithProblems);
      final failed = switch (read) {
        ManifestFailed() => read,
        _ => fail('expected a failed Manifest, got $read'),
      };
      final error = failed.problems.singleWhere((p) => !p.isWarning);
      expect(error.code, 'PYRO_NON_CONST_DEFAULT');
      expect(error.message, contains('speed'));
      expect(error.file, 'lib/components/ship.dart');
      expect(error.line, 14);
      expect(error.className, 'Ship');
      expect(error.field, 'speed');
      expect(error.location, 'lib/components/ship.dart:14 Ship.speed');
      final warning = failed.problems.singleWhere((p) => p.isWarning);
      expect(warning.code, 'PYRO_MISSING_DOC');
      expect(warning.location, 'lib/components/ship.dart:6 Ship');
    });

    test('a newer manifestVersion is refused (Q105)', () {
      expect(readManifest(manifestNewerVersion), isA<ManifestNewer>());
      expect(
        (readManifest(manifestNewerVersion) as ManifestNewer).manifestVersion,
        2,
      );
    });

    test('broken JSON is unreadable, not a crash', () {
      final read = readManifest(manifestBrokenJson);
      expect(read, isA<ManifestUnreadable>());
      expect((read as ManifestUnreadable).message, contains('valid JSON'));
    });

    test('unknown keys at every level are ignored', () {
      const text = '''
{
  "manifestVersion": 1,
  "futureKey": {"nested": true},
  "types": [
    {
      "id": "Ship",
      "role": "component",
      "label": "Ship",
      "futureTypeKey": 1,
      "supertypes": ["PositionComponent"],
      "fields": [
        {
          "name": "speed",
          "type": "double",
          "nullable": false,
          "default": 1.5,
          "label": "Speed",
          "refType": null,
          "declaredIn": "Ship",
          "futureFieldKey": []
        }
      ]
    }
  ],
  "errors": [],
  "warnings": []
}
''';
      final parsed = readManifest(text) as ManifestParsed;
      expect(parsed.types, hasLength(1));
      expect(parsed.types.single.fields.single.name, 'speed');
    });

    test('a type without its required keys is unreadable', () {
      const text =
          '{"manifestVersion": 1, "types": [{"role": "component"}],'
          ' "errors": [], "warnings": []}';
      final read = readManifest(text);
      expect(read, isA<ManifestUnreadable>());
      expect((read as ManifestUnreadable).message, contains('no id'));
    });

    test('warnings alone keep the read successful', () {
      const text =
          '{"manifestVersion": 1, "types": [], "errors": [],'
          ' "warnings": [{"code": "defaultOutOfRange",'
          ' "message": "The default is outside [min, max]."}]}';
      final parsed = readManifest(text) as ManifestParsed;
      expect(parsed.problems, hasLength(1));
      expect(parsed.problems.single.isWarning, isTrue);
      expect(parsed.problems.single.location, isNull);
    });

    test('a missing manifestVersion is unreadable', () {
      const text = '{"types": [], "errors": [], "warnings": []}';
      expect(readManifest(text), isA<ManifestUnreadable>());
    });
  });
}
