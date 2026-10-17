import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _toggle = find.byType(FsToggleButton);

Widget _maybeForced(Set<WidgetState> states, Widget child) =>
    states.isEmpty ? child : FsDebugStates(states: states, child: child);

Widget _sample({
  bool text = false,
  bool value = false,
  bool enabled = true,
  Set<WidgetState> forced = const {},
  ValueChanged<bool>? onChanged,
}) => Align(
  alignment: Alignment.topLeft,
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: _maybeForced(
      forced,
      FsToggleButton(
        icon: text ? FsIcons.magnet : FsIcons.grid,
        label: text ? 'Snap' : null,
        value: value,
        tooltip: 'Show grid',
        onChanged: enabled ? (onChanged ?? (_) {}) : null,
      ),
    ),
  ),
);

(Color?, Color?, Color?) _look(WidgetTester tester) {
  final d = decorationIn(tester, _toggle);
  final icon = tester.widget<Icon>(
    find.descendant(of: _toggle, matching: find.byType(Icon)),
  );
  return (d.color, (d.border! as Border).top.color, icon.color);
}

void main() {
  const t = Colors.transparent;

  testWidgets('icon form: like an icon button, on = accent-subtle', (
    tester,
  ) async {
    await pumpFs(tester, _sample());
    expect(tester.getSize(_toggle), const Size(24, 24));
    expect(_look(tester), (t, t, c.textSecondary));
    await pumpFs(tester, _sample(forced: {WidgetState.hovered}));
    expect(_look(tester), (c.surfaceHover, t, c.textPrimary));
    await pumpFs(tester, _sample(value: true));
    expect(_look(tester), (c.accentSubtle, t, c.accentText));
    await pumpFs(tester, _sample(value: true, forced: {WidgetState.hovered}));
    expect(_look(tester), (c.surfaceSelected, t, c.accentText));
    await pumpFs(tester, _sample(enabled: false));
    expect(_look(tester), (t, t, c.textDisabled));
  });

  testWidgets('text form: raised with an edge; on adds an accent edge', (
    tester,
  ) async {
    await pumpFs(tester, _sample(text: true));
    expect(_look(tester), (c.surfaceRaised, c.borderControl, c.textSecondary));
    expect(textColor(tester, 'Snap'), c.textSecondary);
    expect(tester.widget<Icon>(find.byIcon(FsIcons.magnet)).size, 14);
    await pumpFs(tester, _sample(text: true, forced: {WidgetState.pressed}));
    expect(_look(tester), (c.surfacePressed, c.borderControl, c.textPrimary));
    await pumpFs(tester, _sample(text: true, value: true));
    expect(_look(tester), (c.accentSubtle, c.accentText, c.accentText));
    expect(textColor(tester, 'Snap'), c.accentText);
    await pumpFs(tester, _sample(text: true, enabled: false));
    expect(_look(tester), (c.surfaceRaised, c.borderSubtle, c.textDisabled));
  });

  testWidgets('click and Space flip the value', (tester) async {
    final values = <bool>[];
    await pumpFs(tester, _sample(onChanged: values.add));
    await tester.tap(_toggle);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(values, [true, true]); // the widget is controlled: value stays off
  });

  testWidgets('toggled semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpFs(tester, _sample(value: true));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Show grid').first),
      isSemantics(
        label: 'Show grid',
        isButton: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
