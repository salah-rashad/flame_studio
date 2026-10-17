import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Widget _row({
  bool? value = false,
  bool mixed = false,
  FsBoolStyle style = FsBoolStyle.checkbox,
  FsValueSource source = FsValueSource.codeDefault,
  VoidCallback? onReset,
  bool enabled = true,
  ValueChanged<bool>? onChanged,
}) => FsBoolProperty(
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
    expect(tester.getSize(find.byType(FsBoolProperty)).height, 24);
    final box = tester.getTopLeft(find.byType(FsCheckbox));
    // 16 padding + 160 label + 4 gap.
    expect(box.dx, 180);
    expect(tester.getSize(find.byType(FsCheckbox)), const Size(14, 14));
    expect(tester.widget<FsCheckbox>(find.byType(FsCheckbox)).value, isTrue);
  });

  testWidgets('switch style', (tester) async {
    await pumpFs(tester, _row(value: true, style: FsBoolStyle.toggle));
    expect(find.byType(FsCheckbox), findsNothing);
    expect(tester.widget<FsSwitch>(find.byType(FsSwitch)).value, isTrue);
  });

  testWidgets('clicking the label toggles; Space on the box toggles', (
    tester,
  ) async {
    final values = <bool>[];
    await pumpFs(tester, _row(onChanged: values.add));
    await tester.tap(find.text('debugMode'));
    expect(values, [true]);
    await tester.tap(find.byType(FsCheckbox));
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
    expect(tester.widget<FsCheckbox>(find.byType(FsCheckbox)).value, isNull);
    await tester.tap(find.text('debugMode'));
    expect(values, [true]);
  });

  testWidgets('disabled: label and box disabled, clicks ignored', (
    tester,
  ) async {
    await pumpFs(tester, _row(value: true, enabled: false));
    expect(textColor(tester, 'debugMode'), c.textDisabled);
    await tester.tap(find.text('debugMode'));
    await tester.tap(find.byType(FsCheckbox));
    // Nothing to observe but no callback: the row has none.
    expect(
      tester.widget<FsCheckbox>(find.byType(FsCheckbox)).onChanged,
      isNull,
    );
  });

  testWidgets('overridden: bar and reset', (tester) async {
    var resets = 0;
    await pumpFs(
      tester,
      _row(
        value: true,
        source: FsValueSource.overridden,
        onReset: () => resets++,
      ),
    );
    expect(textColor(tester, 'debugMode'), c.textPrimary);
    await tester.tap(find.byIcon(FsIcons.reset));
    expect(resets, 1);
  });
}
