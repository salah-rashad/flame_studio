import 'package:flame_studio_ui/src/foundation/number_editing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('format', () {
    test('ints have no decimals', () {
      expect(FsNumberEditing.format(10, FsNumberKind.int), '10');
      expect(FsNumberEditing.format(9.6, FsNumberKind.int), '10');
    });

    test('doubles keep at least one decimal and hide float noise', () {
      expect(FsNumberEditing.format(180, FsNumberKind.double), '180.0');
      expect(FsNumberEditing.format(9.81, FsNumberKind.double), '9.81');
      expect(FsNumberEditing.format(0.1 + 0.2, FsNumberKind.double), '0.3');
      expect(FsNumberEditing.format(-0.0, FsNumberKind.double), '0.0');
    });
  });

  group('parse', () {
    test('accepts numbers, rejects the rest', () {
      expect(FsNumberEditing.parse(' 412.5 ', FsNumberKind.double), 412.5);
      expect(FsNumberEditing.parse('-3', FsNumberKind.double), -3);
      expect(FsNumberEditing.parse('12x', FsNumberKind.double), isNull);
      expect(FsNumberEditing.parse('1e', FsNumberKind.double), isNull);
      expect(FsNumberEditing.parse('', FsNumberKind.double), isNull);
      expect(FsNumberEditing.parse('Infinity', FsNumberKind.double), isNull);
      expect(FsNumberEditing.parse('NaN', FsNumberKind.double), isNull);
    });

    test('ints round', () {
      expect(FsNumberEditing.parse('12.6', FsNumberKind.int), 13);
    });
  });

  test('default step: 1, or a hundredth of a bounded double range', () {
    expect(FsNumberEditing.defaultStep(FsNumberKind.int), 1);
    expect(FsNumberEditing.defaultStep(FsNumberKind.double), 1);
    expect(
      FsNumberEditing.defaultStep(FsNumberKind.double, min: 0, max: 1),
      0.01,
    );
    expect(FsNumberEditing.defaultStep(FsNumberKind.int, min: 0, max: 1), 1);
  });

  test('modifiers: Shift ×10, Alt ×0.1, both ×1', () {
    expect(FsNumberEditing.modifierMultiplier(shift: false, alt: false), 1);
    expect(FsNumberEditing.modifierMultiplier(shift: true, alt: false), 10);
    expect(FsNumberEditing.modifierMultiplier(shift: false, alt: true), 0.1);
    expect(FsNumberEditing.modifierMultiplier(shift: true, alt: true), 1);
  });

  group('step', () {
    test('moves by step × multiplier and clamps', () {
      expect(FsNumberEditing.step(180, 1, step: 1), 181);
      expect(FsNumberEditing.step(180, -1, step: 1, multiplier: 10), 170);
      expect(FsNumberEditing.step(0.85, 1, step: 0.01), 0.86);
      expect(FsNumberEditing.step(0.995, 1, step: 0.01, max: 1), 1);
      expect(FsNumberEditing.step(0, -1, step: 1, min: 0), 0);
    });

    test('int steps never go below 1', () {
      expect(
        FsNumberEditing.step(
          10,
          1,
          step: 1,
          multiplier: 0.1,
          kind: FsNumberKind.int,
        ),
        11,
      );
    });
  });

  group('FsScrub', () {
    test('1 step per 2px', () {
      final scrub = FsScrub(start: 10, step: 1, kind: FsNumberKind.int);
      expect(scrub.update(8), 14);
      expect(scrub.update(-12), 8);
    });

    test('keeps the fraction of the start value', () {
      final scrub = FsScrub(start: 412.5, step: 1);
      expect(scrub.update(2), 413.5);
    });

    test('Shift ×10 and Alt ×0.1', () {
      expect(FsScrub(start: 0, step: 1).update(2, multiplier: 10), 10);
      expect(FsScrub(start: 0, step: 1).update(2, multiplier: 0.1), 0.1);
      // Ints with Alt: 1 per 20px.
      final scrub = FsScrub(start: 0, step: 1, kind: FsNumberKind.int);
      expect(scrub.update(10, multiplier: 0.1), 1);
    });

    test('a modifier change mid-gesture continues without a jump', () {
      final scrub = FsScrub(start: 0, step: 1);
      expect(scrub.update(4), 2);
      expect(scrub.update(2, multiplier: 10), 12);
      expect(scrub.update(2), 13);
    });

    test('sub-step moves accumulate', () {
      final scrub = FsScrub(start: 0, step: 1);
      expect(scrub.update(0.6), 0);
      expect(scrub.update(0.6), 1); // 1.2px = 0.6 steps, rounds to 1
    });

    test('clamps, and responds at once when dragged back', () {
      final scrub = FsScrub(start: 0.9, step: 0.01, min: 0, max: 1);
      expect(scrub.update(100), 1);
      expect(scrub.update(-2), 0.99);
    });
  });
}
