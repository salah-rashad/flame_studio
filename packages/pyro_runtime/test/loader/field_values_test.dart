import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_runtime/src/loader/field_values.dart';

import '../support/test_registry.dart';

final _fields = testRegistry[const TypeId('AllFields')]!.fields;

FieldConversion _convert(String field, Object? written) =>
    convertOverride(_fields[field]!, written);

Object? _value(String field, Object? written) =>
    (_convert(field, written) as ConvertedValue).value;

void main() {
  group('accepted', () {
    test('numbers', () {
      expect(_value('speed', 80), 80.0);
      expect(_value('speed', 80.5), 80.5);
      expect(_value('count', 2), 2);
      expect(_value('count', 2.0), 2);
    });

    test('booleans, strings and enum names', () {
      expect(_value('active', false), false);
      expect(_value('label', 'hi'), 'hi');
      expect(_value('mode', 'b'), Mode.b);
    });

    test('vectors and colours in either case', () {
      expect(_value('direction', [1, 0]), Vector2(1, 0));
      expect(_value('tint', '#FFFF8800'), const Color(0xFFFF8800));
      expect(_value('tint', '#ffff8800'), const Color(0xFFFF8800));
    });

    test('an ImagePath is wrapped, not loaded', () {
      expect(
        _value('icon', {'asset': 'assets/images/fx.png'}),
        const ImagePath('assets/images/fx.png'),
      );
    });

    test('assets and references are deferred', () {
      expect(
        _convert('sprite', {'asset': 'a.png'}),
        isA<AssetValue>()
            .having((v) => v.path, 'path', 'a.png')
            .having((v) => v.animation, 'animation', isNull),
      );
      expect(
        _convert('effect', {'asset': 'a.anim.json', 'animation': 'walk'}),
        isA<AssetValue>().having((v) => v.animation, 'animation', 'walk'),
      );
      expect(
        _convert('target', {'ref': 'e1'}),
        isA<ReferenceValue>().having((v) => v.target, 'target', 'e1'),
      );
    });

    test('null for a nullable field', () {
      expect(_value('maybe', null), isNull);
      expect(_value('sprite', null), isNull);
    });
  });

  group('mismatches name the value and what the field takes', () {
    final cases = <(String, Object?, String)>[
      ('count', 1.5, 'an int'),
      ('active', 'x', 'true or false'),
      ('mode', 'c', 'one of a, b'),
      ('direction', [1], '[x, y]'),
      ('direction', [1, 'a'], '[x, y]'),
      ('tint', '#FF8800', '"#AARRGGBB"'),
      ('tint', 'FFFF8800', '"#AARRGGBB"'),
      (
        'sprite',
        {'asset': 'a.anim.json', 'animation': 'walk'},
        '{"asset": path}',
      ),
      ('effect', {'asset': 'a.anim.json'}, '"animation": name'),
      ('target', 'e1', '{"ref": Node ID}'),
    ];
    for (final (field, written, expected) in cases) {
      test('$field ← $written', () {
        final mismatch = _convert(field, written) as Mismatch;
        expect(mismatch.message, contains(showValue(written)));
        expect(mismatch.message, contains(expected));
      });
    }

    test('null for a non-nullable field', () {
      final mismatch = _convert('count', null) as Mismatch;
      expect(mismatch.message, contains("isn't nullable"));
    });

    test('long values are cut at 80 characters', () {
      final shown = showValue('x' * 200);
      expect(shown, hasLength(80));
      expect(shown, endsWith('…'));
    });
  });
}
