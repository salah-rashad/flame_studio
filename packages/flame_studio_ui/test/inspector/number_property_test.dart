import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flame_studio_ui/src/inspector/range_slider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// A NumberProperty whose value follows its callbacks, recording them.
class _Harness extends StatefulWidget {
  const _Harness({
    this.initial = 10,
    this.kind = FsNumberKind.int,
    this.min,
    this.max,
    this.mixed = false,
    this.enabled = true,
    this.validator,
    this.slider = false,
  });

  final bool slider;
  final double? initial;
  final FsNumberKind kind;
  final double? min;
  final double? max;
  final bool mixed;
  final bool enabled;
  final String? Function(double)? validator;

  @override
  State<_Harness> createState() => _HarnessState();
}

final changes = <double>[];
final commits = <double>[];

class _HarnessState extends State<_Harness> {
  late double? value = widget.initial;
  late bool mixed = widget.mixed;

  @override
  Widget build(BuildContext context) => FsNumberProperty(
    label: 'priority',
    value: value,
    mixed: mixed,
    kind: widget.kind,
    min: widget.min,
    max: widget.max,
    unit: 'px',
    enabled: widget.enabled,
    validator: widget.validator,
    slider: widget.slider,
    invalidMessage: 'Expected a number',
    onChanged: (v) {
      changes.add(v);
      setState(() {
        value = v;
        mixed = false;
      });
    },
    onCommit: commits.add,
  );
}

final _field = find.byType(FsFieldBox);
final _label = find.text('priority');

void main() {
  setUp(() {
    changes.clear();
    commits.clear();
  });

  group('scrub', () {
    testWidgets('1 step per 2px, onChanged continuous, one onCommit', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness());
      await mouseDrag(tester, _label, 20, steps: 4);
      // 5px moves are 2.5 steps each; ints round.
      expect(changes, [13, 15, 18, 20]);
      expect(commits, [20]);
      expect(fieldText(tester), '20');
    });

    testWidgets('Shift ×10, Alt ×0.1', (tester) async {
      await pumpFs(
        tester,
        const _Harness(initial: 0, kind: FsNumberKind.double),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await mouseDrag(tester, _label, 4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(commits.last, 20);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await mouseDrag(tester, _label, 4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      expect(commits.last, 20.2);
      expect(commits, hasLength(2));
    });

    testWidgets('clamps to min and max', (tester) async {
      await pumpFs(tester, const _Harness(min: 0, max: 15));
      await mouseDrag(tester, _label, 40);
      expect(commits, [15]);
      await mouseDrag(tester, _label, -100);
      expect(commits, [15, 0]);
    });

    testWidgets('label and field turn accent-text while scrubbing', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness());
      final g = await tester.startGesture(
        tester.getCenter(_label),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(10, 0));
      await tester.pump();
      expect(textColor(tester, 'priority'), c.accentText);
      expect(fieldBorder(tester, _field), c.accentText);
      await g.up();
      await tester.pump();
      expect(fieldBorder(tester, _field), isNot(c.accentText));
    });

    testWidgets('a click on the label without a drag commits nothing', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness());
      await tester.tap(_label);
      await tester.pump();
      expect(commits, isEmpty);
    });

    testWidgets('disabled rows do not scrub', (tester) async {
      await pumpFs(tester, const _Harness(enabled: false));
      await mouseDrag(tester, _label, 20);
      expect(changes, isEmpty);
    });
  });

  group('edit', () {
    testWidgets('click selects the value; Enter commits once', (tester) async {
      await pumpFs(tester, const _Harness());
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      final controller = tester
          .widget<EditableText>(find.byType(EditableText))
          .controller;
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 2),
      );
      expect(fieldBorder(tester, _field), c.focusRing);

      await tester.enterText(find.byType(EditableText), '42');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(commits, [42]);
      expect(changes, [42]);
      expect(fieldText(tester), '42');
    });

    testWidgets('Esc reverts and leaves the field', (tester) async {
      await pumpFs(tester, const _Harness());
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), '99');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(fieldText(tester), '10');
      expect(commits, isEmpty);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse,
      );
    });

    testWidgets('Tab commits and moves on', (tester) async {
      final next = FocusNode();
      addTearDown(next.dispose);
      await pumpFs(
        tester,
        Column(
          children: [
            const _Harness(),
            Focus(focusNode: next, child: const SizedBox(height: 10)),
          ],
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), '7');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(commits, [7]);
      expect(next.hasFocus, isTrue);
    });

    testWidgets('↑/↓ step and commit; Shift ×10', (tester) async {
      await pumpFs(tester, const _Harness());
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(commits, [11, 1]);
      expect(fieldText(tester), '1');
    });

    testWidgets('invalid text keeps the error and the text until Esc', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness());
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), '12x');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(commits, isEmpty);
      expect(textColor(tester, 'priority'), c.error);
      expect(fieldBorder(tester, _field), c.error);
      expect(fieldText(tester), '12x');

      // Clicking elsewhere keeps the error.
      await tester.tapAt(const Offset(10, 500));
      await tester.pump();
      expect(fieldText(tester), '12x');
      expect(fieldBorder(tester, _field), c.error);

      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(fieldText(tester), '10');
      expect(textColor(tester, 'priority'), c.textSecondary);
    });

    testWidgets('out of range and validator failures are errors', (
      tester,
    ) async {
      await pumpFs(
        tester,
        _Harness(
          kind: FsNumberKind.double,
          initial: 0.85,
          min: 0,
          max: 1,
          validator: (v) => v == 0.5 ? 'Not 0.5' : null,
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), '1.4');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(fieldBorder(tester, _field), c.error);
      await tester.enterText(find.byType(EditableText), '0.5');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(fieldBorder(tester, _field), c.error);
      expect(commits, isEmpty);
      await tester.enterText(find.byType(EditableText), '0.25');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(commits, [0.25]);
    });
  });

  group('states', () {
    testWidgets('default from code: value in text-secondary', (tester) async {
      await pumpFs(tester, const _Harness());
      expect(fieldTextColor(tester), c.textSecondary);
      expect(fieldBorder(tester, _field), c.borderControl);
    });

    testWidgets('overridden: value in text-primary', (tester) async {
      await pumpFs(
        tester,
        FsNumberProperty(
          label: 'priority',
          value: 10,
          source: FsValueSource.overridden,
          onChanged: (_) {},
          onCommit: (_) {},
        ),
      );
      expect(fieldTextColor(tester), c.textPrimary);
    });

    testWidgets('mixed: "—" in text-secondary, typing writes a value', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness(initial: null, mixed: true));
      expect(fieldText(tester), '—');
      expect(fieldTextColor(tester), c.textSecondary);
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(fieldText(tester), '');
      await tester.enterText(find.byType(EditableText), '5');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(commits, [5]);
    });

    testWidgets('mixed rows do not scrub', (tester) async {
      await pumpFs(tester, const _Harness(initial: null, mixed: true));
      await mouseDrag(tester, _label, 20);
      expect(changes, isEmpty);
    });

    testWidgets('hovering the row strengthens the field border', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness());
      final m = await mouse(tester);
      await hover(tester, m, _label);
      expect(fieldBorder(tester, _field), c.borderStrong);
    });

    testWidgets('disabled: flat field, disabled label and value', (
      tester,
    ) async {
      await pumpFs(tester, const _Harness(enabled: false));
      expect(fieldFill(tester, _field), c.surfacePanel);
      expect(fieldBorder(tester, _field), c.borderSubtle);
      expect(fieldTextColor(tester), c.textDisabled);
      expect(textColor(tester, 'priority'), c.textDisabled);
    });

    testWidgets('forced scrubbing and focus for the gallery', (tester) async {
      await pumpFs(
        tester,
        const FsDebugStates(states: {WidgetState.dragged}, child: _Harness()),
      );
      expect(textColor(tester, 'priority'), c.accentText);
      expect(fieldBorder(tester, _field), c.accentText);

      await pumpFs(
        tester,
        const FsDebugStates(
          part: 'field',
          states: {WidgetState.focused},
          child: _Harness(),
        ),
      );
      expect(fieldBorder(tester, _field), c.focusRing);
      expect(textColor(tester, 'priority'), c.textSecondary);
    });
  });

  group('expressions', () {
    Future<void> type(WidgetTester tester, String text) async {
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), text);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
    }

    testWidgets('evaluated on commit', (tester) async {
      await pumpFs(tester, const _Harness(initial: 32));
      await type(tester, '32*2');
      expect(commits, [64]);
      expect(fieldText(tester), '64');
      await type(tester, '+=8');
      expect(commits, [64, 72]);
      await type(tester, '(10 + 6) / 4');
      expect(commits, [64, 72, 4]);
    });

    testWidgets('a bad expression is an error', (tester) async {
      await pumpFs(tester, const _Harness());
      await type(tester, '2 * (3');
      expect(commits, isEmpty);
      expect(fieldBorder(tester, _field), c.error);
    });

    testWidgets('mixed: += has nothing to add to', (tester) async {
      await pumpFs(tester, const _Harness(initial: null, mixed: true));
      await type(tester, '+=8');
      expect(commits, isEmpty);
      expect(fieldBorder(tester, _field), c.error);
    });
  });

  group('range slider', () {
    const harness = _Harness(
      initial: 0.85,
      kind: FsNumberKind.double,
      min: 0,
      max: 1,
      slider: true,
    );
    final slider = find.byType(FsRangeSlider);

    testWidgets('a slider before a 56px field', (tester) async {
      await pumpFs(tester, harness, width: 420);
      expect(tester.getSize(_field).width, 56);
      expect(tester.getSize(slider).height, 20);
      expect(tester.getTopRight(slider).dx + 4, tester.getTopLeft(_field).dx);
      expect(fieldText(tester), '0.85');
    });

    testWidgets('a press jumps, a drag follows, one commit', (tester) async {
      await pumpFs(tester, harness, width: 420);
      final rect = tester.getRect(slider);
      final gesture = await tester.startGesture(
        rect.centerLeft + const Offset(6, 0), // the thumb's leftmost centre
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(changes, [0]);
      await gesture.moveTo(rect.center);
      await tester.pump();
      expect(changes.last, 0.5);
      await gesture.moveTo(rect.centerRight + const Offset(40, 0));
      await tester.pump();
      expect(changes.last, 1);
      expect(fieldText(tester), '1.0');
      await gesture.up();
      await tester.pump();
      expect(commits, [1]);
    });

    testWidgets('← → step when focused', (tester) async {
      await pumpFs(tester, harness, width: 420);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // the slider
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(commits, [0.86]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(commits, [0.86, 0.85, 0.84]);
    });

    testWidgets('label scrubbing moves the slider too', (tester) async {
      await pumpFs(tester, harness, width: 420);
      await mouseDrag(tester, _label, -10);
      expect(commits, [0.8]);
      expect(tester.widget<FsRangeSlider>(slider).value, 0.8);
    });

    testWidgets('mixed and disabled', (tester) async {
      await pumpFs(
        tester,
        const _Harness(
          initial: null,
          mixed: true,
          kind: FsNumberKind.double,
          min: 0,
          max: 1,
          slider: true,
        ),
        width: 420,
      );
      expect(tester.widget<FsRangeSlider>(slider).value, isNull);
      await pumpFs(
        tester,
        const _Harness(
          initial: 0.5,
          enabled: false,
          kind: FsNumberKind.double,
          min: 0,
          max: 1,
          slider: true,
        ),
        width: 420,
      );
      await tester.tap(slider);
      expect(changes, isEmpty);
    });
  });
}
