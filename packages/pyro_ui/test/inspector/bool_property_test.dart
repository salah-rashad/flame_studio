import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../helpers.dart';

Widget _row({
  bool? value = false,
  bool mixed = false,
  PrBoolStyle style = PrBoolStyle.checkbox,
  PrValueSource source = PrValueSource.codeDefault,
  VoidCallback? onReset,
  bool enabled = true,
  ValueChanged<bool>? onChanged,
}) => PrBoolProperty(
  label: 'debugMode',
  value: value,
  mixed: mixed,
  style: style,
  source: source,
  onReset: onReset,
  resetTooltip: 'Reset to default',
  onChanged: enabled ? (onChanged ?? (_) {}) : null,
);

void main() {
  testWidgets('a checkbox at the start of the editor column', (tester) async {
    await pumpFs(tester, _row(value: true), width: 420);
    expect(tester.getSize(find.byType(PrBoolProperty)).height, 24);
    final box = tester.getTopLeft(find.byType(PrCheckbox));
    // 16 padding + 160 label + 4 gap.
    expect(box.dx, 180);
    expect(tester.getSize(find.byType(PrCheckbox)), const Size(14, 14));
    expect(tester.widget<PrCheckbox>(find.byType(PrCheckbox)).value, isTrue);
  });

  testWidgets('switch style', (tester) async {
    await pumpFs(tester, _row(value: true, style: PrBoolStyle.toggle));
    expect(find.byType(PrCheckbox), findsNothing);
    expect(tester.widget<PrSwitch>(find.byType(PrSwitch)).value, isTrue);
  });

  testWidgets('clicking the label toggles; Space on the box toggles', (
    tester,
  ) async {
    final values = <bool>[];
    await pumpFs(tester, _row(onChanged: values.add));
    await tester.tap(find.text('debugMode'));
    expect(values, [true]);
    await tester.tap(find.byType(PrCheckbox));
    expect(values, [true, true]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(values, [true, true, true]);
  });

  testWidgets('mixed: a dash; clicking sets true', (tester) async {
    final values = <bool>[];
    await pumpFs(
      tester,
      _row(value: false, mixed: true, onChanged: values.add),
    );
    expect(tester.widget<PrCheckbox>(find.byType(PrCheckbox)).value, isNull);
    await tester.tap(find.text('debugMode'));
    expect(values, [true]);
  });

  testWidgets('disabled: label and box disabled, clicks ignored', (
    tester,
  ) async {
    await pumpFs(tester, _row(value: true, enabled: false));
    expect(textColor(tester, 'debugMode'), c.textDisabled);
    await tester.tap(find.text('debugMode'));
    await tester.tap(find.byType(PrCheckbox));
    // Nothing to observe but no callback: the row has none.
    expect(
      tester.widget<PrCheckbox>(find.byType(PrCheckbox)).onChanged,
      isNull,
    );
  });

  testWidgets('overridden: bar and reset', (tester) async {
    var resets = 0;
    await pumpFs(
      tester,
      _row(
        value: true,
        source: PrValueSource.overridden,
        onReset: () => resets++,
      ),
    );
    expect(textColor(tester, 'debugMode'), c.textPrimary);
    await tester.tap(find.byIcon(PrIcons.reset));
    expect(resets, 1);
  });
}
