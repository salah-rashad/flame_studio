import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _changes = <double>[];
final _commits = <double>[];

/// A NumberField whose value follows its callbacks, recording them.
class _Harness extends StatefulWidget {
  const _Harness({
    this.initial = 16,
    this.mixed = false,
    this.enabled = true,
    this.unit,
    this.size = FsFieldSize.regular,
  });

  final double? initial;
  final bool mixed;
  final bool enabled;
  final String? unit;
  final FsFieldSize size;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late double? value = widget.initial;
  late bool mixed = widget.mixed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: FsNumberField(
        value: value,
        mixed: mixed,
        kind: FsNumberKind.int,
        unit: widget.unit,
        size: widget.size,
        width: 120,
        invalidMessage: 'Expected a number',
        onChanged: widget.enabled
            ? (v) {
                _changes.add(v);
                setState(() {
                  value = v;
                  mixed = false;
                });
              }
            : null,
        onCommit: widget.enabled ? _commits.add : null,
      ),
    ),
  );
}

final _field = find.byType(FsFieldBox);

Future<void> _click(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(
    tester.getCenter(finder),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
}

void main() {
  setUp(() {
    _changes.clear();
    _commits.clear();
  });

  testWidgets('24px with a stepper; dense 20px; unit', (tester) async {
    await pumpFs(tester, const _Harness(unit: 'px'));
    expect(tester.getSize(_field), const Size(120, 24));
    expect(fieldText(tester), '16');
    expect(
      DefaultTextStyle.of(tester.element(find.text('px'))).style.color,
      c.textSecondary,
    );
    expect(find.byIcon(FsIcons.chevronDown), findsNWidgets(2));
    expect(fieldBorder(tester, _field), c.borderControl);
    // Not in a property row: the value is text-primary.
    expect(fieldTextColor(tester), c.textPrimary);
    await pumpFs(tester, const _Harness(size: FsFieldSize.dense));
    expect(tester.getSize(_field).height, 20);
  });

  testWidgets('forced states', (tester) async {
    Future<void> pump(Set<WidgetState> states) => pumpFs(
      tester,
      FsDebugStates(states: states, part: 'field', child: const _Harness()),
    );
    await pump({WidgetState.hovered});
    expect(fieldBorder(tester, _field), c.borderStrong);
    await pump({WidgetState.dragged});
    expect(fieldBorder(tester, _field), c.accentText);
    await pump({WidgetState.focused});
    expect(fieldBorder(tester, _field), c.focusRing);
    await pump({WidgetState.error});
    expect(fieldBorder(tester, _field), c.error);
  });

  testWidgets('dragging the value scrubs: 1 step per 2px, one commit', (
    tester,
  ) async {
    await pumpFs(tester, const _Harness());
    final text = find.byType(EditableText);
    final gesture = await tester.startGesture(
      tester.getCenter(text),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(20, 0)); // past the slop
    await tester.pump();
    expect(fieldBorder(tester, _field), c.accentText);
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(_changes, isNotEmpty);
    expect(_changes.last, greaterThan(16));
    expect(_commits, [_changes.last]);
    // The mouse is still over it: hover, no longer the accent edge.
    expect(fieldBorder(tester, _field), c.borderStrong);
    // Scrubbing doesn't focus the field.
    expect(tester.widget<EditableText>(text).focusNode.hasFocus, isFalse);
  });

  testWidgets('a click edits with the value selected; Enter commits', (
    tester,
  ) async {
    await pumpFs(tester, const _Harness());
    await _click(tester, find.byType(EditableText));
    await tester.pump();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.selection.extentOffset, 2);
    expect(fieldBorder(tester, _field), c.focusRing);
    await tester.enterText(find.byType(EditableText), '24');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_commits, [24]);
  });

  testWidgets('the stepper steps and commits', (tester) async {
    await pumpFs(tester, const _Harness());
    final arrows = find.byIcon(FsIcons.chevronDown);
    await _click(tester, arrows.first);
    expect(_commits, [17]);
    await _click(tester, arrows.last);
    await _click(tester, arrows.last);
    expect(_commits, [17, 16, 15]);
  });

  testWidgets('invalid text: error border and the message in a tooltip', (
    tester,
  ) async {
    await pumpFs(tester, const _Harness());
    await _click(tester, find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), '1.6.0');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(fieldBorder(tester, _field), c.error);
    expect(find.byType(FsTooltip), findsOneWidget);
    expect(_commits, isEmpty);
    // The editor survived the tooltip wrapping it.
    expect(fieldText(tester), '1.6.0');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(fieldText(tester), '16');
    expect(fieldBorder(tester, _field), c.borderControl);
  });

  testWidgets('mixed: "—", no scrub', (tester) async {
    await pumpFs(tester, const _Harness(initial: null, mixed: true));
    expect(fieldText(tester), '—');
    await mouseDrag(tester, find.byType(EditableText), 40, steps: 4);
    expect(_changes, isEmpty);
  });

  testWidgets('disabled: flat, no scrub, no edit', (tester) async {
    await pumpFs(tester, const _Harness(enabled: false));
    expect(fieldFill(tester, _field), c.surfacePanel);
    await mouseDrag(tester, find.byType(EditableText), 40, steps: 4);
    await _click(tester, find.byType(EditableText));
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
    expect(_changes, isEmpty);
  });
}
