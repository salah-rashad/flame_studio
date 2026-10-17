import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _peach = Color(0xFFFFD7A8);

final _changes = <Color>[];
final _commits = <Color>[];

class _Harness extends StatefulWidget {
  const _Harness({
    this.initial = _peach,
    this.mixed = false,
    this.enabled = true,
  });

  final Color? initial;
  final bool mixed;
  final bool enabled;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late Color? value = widget.initial;
  late bool mixed = widget.mixed;

  @override
  Widget build(BuildContext context) => FsColorProperty(
    label: 'tint',
    value: value,
    mixed: mixed,
    enabled: widget.enabled,
    onReset: () {},
    resetTooltip: 'Reset to default',
    onChanged: (v) {
      _changes.add(v);
      setState(() {
        value = v;
        mixed = false;
      });
    },
    onCommit: _commits.add,
  );
}

/// The swatch: the 28×16 box whose decoration is the colour.
final _swatch = find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.constraints?.maxWidth == 28 &&
      w.constraints?.maxHeight == 16,
);

Color? _swatchColor(WidgetTester tester) =>
    (tester.widget<Container>(_swatch).decoration! as BoxDecoration).color;

Future<void> _click(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(
    tester.getCenter(finder),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.up();
  await gesture.removePointer();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    _changes.clear();
    _commits.clear();
  });

  testWidgets('swatch, hex and a 52px alpha field', (tester) async {
    await pumpFs(tester, const _Harness(), width: 400);
    expect(tester.getSize(_swatch), const Size(28, 16));
    expect(_swatchColor(tester), _peach);
    expect(fieldText(tester, 0), 'FFD7A8');
    expect(fieldText(tester, 1), '100');
    final alpha = find.byType(FsNumberField);
    expect(tester.getSize(alpha).width, 52);
    // The inner white-15% edge.
    final edge = tester.widget<Container>(_swatch).foregroundDecoration!;
    expect(
      ((edge as BoxDecoration).border! as Border).top.color.a,
      closeTo(0.15, 0.01),
    );
    // Default from code: values in text-secondary.
    expect(fieldTextColor(tester, 0), c.textSecondary);
  });

  testWidgets('the swatch is opaque; transparency shows in the % field', (
    tester,
  ) async {
    await pumpFs(
      tester,
      _Harness(initial: _peach.withValues(alpha: 0.3)),
      width: 400,
    );
    expect(_swatchColor(tester)!.a, 1);
    expect(fieldText(tester, 1), '30');
  });

  testWidgets('hex: commits with the alpha kept', (tester) async {
    await pumpFs(
      tester,
      _Harness(initial: _peach.withValues(alpha: 0.5)),
      width: 400,
    );
    final hex = find.byType(EditableText).first;
    await tester.tap(hex);
    await tester.pump();
    await tester.enterText(hex, '#3366cc');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_commits.single.toARGB32() & 0xFFFFFF, 0x3366CC);
    expect(_commits.single.a, closeTo(0.5, 0.01));
    expect(fieldText(tester, 0), '3366CC');
  });

  testWidgets('invalid hex: error border; the swatch keeps the colour', (
    tester,
  ) async {
    await pumpFs(tester, const _Harness(), width: 400);
    final hex = find.byType(EditableText).first;
    await tester.tap(hex);
    await tester.pump();
    await tester.enterText(hex, 'FFD7A');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_commits, isEmpty);
    expect(fieldBorder(tester, find.byType(FsFieldBox).first), c.error);
    expect(_swatchColor(tester), _peach);
    expect(fieldText(tester, 0), 'FFD7A');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(fieldText(tester, 0), 'FFD7A8');
  });

  testWidgets('alpha: a typed percentage', (tester) async {
    await pumpFs(tester, const _Harness(), width: 400);
    final alpha = find.byType(EditableText).last;
    await tester.tap(alpha);
    await tester.pump();
    await tester.enterText(alpha, '40');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_commits.single.a, closeTo(0.4, 0.01));
  });

  testWidgets('the swatch opens the picker; outside click and Esc close '
      'it', (tester) async {
    await pumpFs(tester, const _Harness(), width: 400);
    await _click(tester, _swatch);
    expect(find.byType(FsColorPicker), findsOneWidget);
    // Below the swatch.
    expect(
      tester.getTopLeft(find.byType(FsColorPicker)).dy,
      greaterThan(tester.getBottomLeft(_swatch).dy),
    );
    await tester.tapAt(const Offset(390, 590));
    await tester.pumpAndSettle();
    expect(find.byType(FsColorPicker), findsNothing);

    await _click(tester, _swatch);
    expect(find.byType(FsColorPicker), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FsColorPicker), findsNothing);
  });

  testWidgets('a pick in the popover reaches the row', (tester) async {
    await pumpFs(tester, const _Harness(), width: 400);
    await _click(tester, _swatch);
    final pickerHex = find.descendant(
      of: find.byType(FsColorPicker),
      matching: find.byType(EditableText),
    );
    await tester.tap(pickerHex.first);
    await tester.pump();
    await tester.enterText(pickerHex.first, '6CC04A');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_commits.single.toARGB32() & 0xFFFFFF, 0x6CC04A);
    expect(_swatchColor(tester)!.toARGB32() & 0xFFFFFF, 0x6CC04A);
  });

  testWidgets('mixed: "—" everywhere; a hex sets a colour', (tester) async {
    await pumpFs(
      tester,
      const _Harness(initial: null, mixed: true),
      width: 400,
    );
    expect(
      find.descendant(of: _swatch, matching: find.text('—')),
      findsOneWidget,
    );
    expect(fieldText(tester, 0), '—');
    expect(fieldText(tester, 1), '—');
    final hex = find.byType(EditableText).first;
    await tester.tap(hex);
    await tester.pump();
    await tester.enterText(hex, 'FFFFFF');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_commits.single.toARGB32(), 0xFFFFFFFF);
  });

  testWidgets('disabled: flat fields, the swatch does not open', (
    tester,
  ) async {
    await pumpFs(tester, const _Harness(enabled: false), width: 400);
    expect(fieldFill(tester, find.byType(FsFieldBox).first), c.surfacePanel);
    expect(textColor(tester, 'tint'), c.textDisabled);
    await _click(tester, _swatch);
    expect(find.byType(FsColorPicker), findsNothing);
  });
}
