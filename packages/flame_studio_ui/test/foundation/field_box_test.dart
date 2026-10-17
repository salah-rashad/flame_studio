import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flame_studio_ui/src/foundation/focus_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<void> _pump(
  WidgetTester tester, {
  Set<WidgetState> states = const {},
  bool readOnly = false,
  bool accentEdge = false,
  FsFieldSize size = FsFieldSize.regular,
}) => pumpFs(
  tester,
  FsFieldBox(
    states: states,
    readOnly: readOnly,
    accentEdge: accentEdge,
    size: size,
    trailing: const Text('px'),
    child: const Text('180.0'),
  ),
);

void main() {
  final box = find.byType(FsFieldBox);

  testWidgets('heights: regular 24, dense 20', (tester) async {
    await _pump(tester);
    expect(tester.getSize(box).height, 24);
    await _pump(tester, size: FsFieldSize.dense);
    expect(tester.getSize(box).height, 20);
  });

  testWidgets('default: surface-input, border-control', (tester) async {
    await _pump(tester);
    expect(fieldFill(tester, box), c.surfaceInput);
    expect(fieldBorder(tester, box), c.borderControl);
    expect(textColor(tester, '180.0'), isNull); // from DefaultTextStyle
    expect(hasPainter<FsEdgePainter>(tester, box), isFalse);
  });

  testWidgets('hover: border-strong', (tester) async {
    await _pump(tester, states: {WidgetState.hovered});
    expect(fieldBorder(tester, box), c.borderStrong);
  });

  testWidgets('focus: focus-ring border plus a 1px outer ring', (tester) async {
    await _pump(tester, states: {WidgetState.focused, WidgetState.hovered});
    expect(fieldBorder(tester, box), c.focusRing);
    final ring = tester
        .widgetList<CustomPaint>(
          find.descendant(of: box, matching: find.byType(CustomPaint)),
        )
        .map((p) => p.foregroundPainter)
        .whereType<FsEdgePainter>()
        .single;
    expect(ring.color, c.focusRing);
    expect(ring.width, 1);
    expect(ring.outside, isTrue);
  });

  testWidgets('error: error border, error ring when focused', (tester) async {
    await _pump(tester, states: {WidgetState.error, WidgetState.hovered});
    expect(fieldBorder(tester, box), c.error);
    await _pump(tester, states: {WidgetState.error, WidgetState.focused});
    final ring = tester
        .widgetList<CustomPaint>(
          find.descendant(of: box, matching: find.byType(CustomPaint)),
        )
        .map((p) => p.foregroundPainter)
        .whereType<FsEdgePainter>()
        .single;
    expect(ring.color, c.error);
  });

  testWidgets('disabled: flat surface-panel, border-subtle, no opacity', (
    tester,
  ) async {
    await _pump(tester, states: {WidgetState.disabled, WidgetState.hovered});
    expect(fieldFill(tester, box), c.surfacePanel);
    expect(fieldBorder(tester, box), c.borderSubtle);
    expect(find.byType(Opacity), findsNothing);
    final style = DefaultTextStyle.of(tester.element(find.text('180.0'))).style;
    expect(style.color, c.textDisabled);
  });

  testWidgets('read-only: flat, text keeps its colour', (tester) async {
    await _pump(tester, readOnly: true);
    expect(fieldFill(tester, box), c.surfacePanel);
    expect(fieldBorder(tester, box), c.borderSubtle);
    final style = DefaultTextStyle.of(tester.element(find.text('180.0'))).style;
    expect(style.color, c.textPrimary);
  });

  testWidgets('accent edge (scrubbing) wins over focus', (tester) async {
    await _pump(tester, states: {WidgetState.focused}, accentEdge: true);
    expect(fieldBorder(tester, box), c.accentText);
    expect(hasPainter<FsEdgePainter>(tester, box), isFalse);
  });

  testWidgets('the unit is small text-secondary', (tester) async {
    await _pump(tester);
    final style = DefaultTextStyle.of(tester.element(find.text('px'))).style;
    expect(style.color, c.textSecondary);
    expect(style.fontSize, FsText.small.fontSize);
  });
}
