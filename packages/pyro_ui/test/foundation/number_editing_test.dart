import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/src/foundation/number_editing.dart';

void main() {
  group('format', () {
    test('ints have no decimals', () {
      expect(PrNumberEditing.format(10, PrNumberKind.int), '10');
      expect(PrNumberEditing.format(9.6, PrNumberKind.int), '10');
    });

    test('doubles keep at least one decimal and hide float noise', () {
      expect(PrNumberEditing.format(180, PrNumberKind.double), '180.0');
      expect(PrNumberEditing.format(9.81, PrNumberKind.double), '9.81');
      expect(PrNumberEditing.format(0.1 + 0.2, PrNumberKind.double), '0.3');
      expect(PrNumberEditing.format(-0.0, PrNumberKind.double), '0.0');
    });
  });

  group('evaluate', () {
    double? eval(String text, [double? current]) =>
        PrNumberEditing.evaluate(text, current);

    test('arithmetic with precedence, unary signs and parentheses', () {
      expect(eval('32*2'), 64);
      expect(eval('1 + 2 * 3'), 7);
      expect(eval('(1 + 2) * 3'), 9);
      expect(eval('10 / 4'), 2.5);
      expect(eval('-(2 + 3)'), -5);
      expect(eval('2 * -3'), -6);
      expect(eval('.5 + 1e2'), 100.5);
      expect(eval('8 - 2 - 1'), 5);
      expect(eval('16 / 4 / 2'), 2);
    });

    test('compound assignment applies to the current value', () {
      expect(eval('+=8', 32), 40);
      expect(eval('-= 2', 10), 8);
      expect(eval('*=1.5', 4), 6);
      expect(eval('/=4', 10), 2.5);
      expect(eval('+=8'), isNull); // no current value (mixed)
    });

    test('rejects what is not an expression', () {
      expect(eval('12x'), isNull);
      expect(eval('(1 + 2'), isNull);
      expect(eval('1 +'), isNull);
      expect(eval('* 2'), isNull);
      expect(eval(''), isNull);
      expect(eval('1 / 0'), isNull);
      expect(eval('1..2'), isNull);
    });
  });

  group('parse', () {
    test('evaluates expressions; ints round the result', () {
      expect(PrNumberEditing.parse('32*2', PrNumberKind.double), 64);
      expect(PrNumberEditing.parse('10/4', PrNumberKind.int), 3);
      expect(
        PrNumberEditing.parse('+=8', PrNumberKind.double, current: 32),
        40,
      );
    });

    test('accepts numbers, rejects the rest', () {
      expect(PrNumberEditing.parse(' 412.5 ', PrNumberKind.double), 412.5);
      expect(PrNumberEditing.parse('-3', PrNumberKind.double), -3);
      expect(PrNumberEditing.parse('12x', PrNumberKind.double), isNull);
      expect(PrNumberEditing.parse('1e', PrNumberKind.double), isNull);
      expect(PrNumberEditing.parse('', PrNumberKind.double), isNull);
      expect(PrNumberEditing.parse('Infinity', PrNumberKind.double), isNull);
      expect(PrNumberEditing.parse('NaN', PrNumberKind.double), isNull);
    });

    test('ints round', () {
      expect(PrNumberEditing.parse('12.6', PrNumberKind.int), 13);
    });
  });

  test('default step: 1, or a hundredth of a bounded double range', () {
    expect(PrNumberEditing.defaultStep(PrNumberKind.int), 1);
    expect(PrNumberEditing.defaultStep(PrNumberKind.double), 1);
    expect(
      PrNumberEditing.defaultStep(PrNumberKind.double, min: 0, max: 1),
      0.01,
    );
    expect(PrNumberEditing.defaultStep(PrNumberKind.int, min: 0, max: 1), 1);
  });

  test('modifiers: Shift ×10, Alt ×0.1, both ×1', () {
    expect(PrNumberEditing.modifierMultiplier(shift: false, alt: false), 1);
    expect(PrNumberEditing.modifierMultiplier(shift: true, alt: false), 10);
    expect(PrNumberEditing.modifierMultiplier(shift: false, alt: true), 0.1);
    expect(PrNumberEditing.modifierMultiplier(shift: true, alt: true), 1);
  });

  group('step', () {
    test('moves by step × multiplier and clamps', () {
      expect(PrNumberEditing.step(180, 1, step: 1), 181);
      expect(PrNumberEditing.step(180, -1, step: 1, multiplier: 10), 170);
      expect(PrNumberEditing.step(0.85, 1, step: 0.01), 0.86);
      expect(PrNumberEditing.step(0.995, 1, step: 0.01, max: 1), 1);
      expect(PrNumberEditing.step(0, -1, step: 1, min: 0), 0);
    });

    test('int steps never go below 1', () {
      expect(
        PrNumberEditing.step(
          10,
          1,
          step: 1,
          multiplier: 0.1,
          kind: PrNumberKind.int,
        ),
        11,
      );
    });
  });

  group('PrScrub', () {
    test('1 step per 2px', () {
      final scrub = PrScrub(start: 10, step: 1, kind: PrNumberKind.int);
      expect(scrub.update(8), 14);
      expect(scrub.update(-12), 8);
    });

    test('keeps the fraction of the start value', () {
      final scrub = PrScrub(start: 412.5, step: 1);
      expect(scrub.update(2), 413.5);
    });

    test('Shift ×10 and Alt ×0.1', () {
      expect(PrScrub(start: 0, step: 1).update(2, multiplier: 10), 10);
      expect(PrScrub(start: 0, step: 1).update(2, multiplier: 0.1), 0.1);
      // Ints with Alt: 1 per 20px.
      final scrub = PrScrub(start: 0, step: 1, kind: PrNumberKind.int);
      expect(scrub.update(10, multiplier: 0.1), 1);
    });

    test('a modifier change mid-gesture continues without a jump', () {
      final scrub = PrScrub(start: 0, step: 1);
      expect(scrub.update(4), 2);
      expect(scrub.update(2, multiplier: 10), 12);
      expect(scrub.update(2), 13);
    });

    test('sub-step moves accumulate', () {
      final scrub = PrScrub(start: 0, step: 1);
      expect(scrub.update(0.6), 0);
      expect(scrub.update(0.6), 1); // 1.2px = 0.6 steps, rounds to 1
    });

    test('clamps, and responds at once when dragged back', () {
      final scrub = PrScrub(start: 0.9, step: 0.01, min: 0, max: 1);
      expect(scrub.update(100), 1);
      expect(scrub.update(-2), 0.99);
    });
  });
}
