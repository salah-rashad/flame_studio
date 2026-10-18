import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';
import 'package:pyro_ui/src/inputs/checkbox.dart' show PrCheckMarkPainter;

import '../helpers.dart';

Widget _maybeForced(Set<WidgetState> states, Widget child) =>
    states.isEmpty ? child : PrDebugStates(states: states, child: child);

Widget _pad(Widget child) => Align(
  alignment: Alignment.topLeft,
  child: Padding(padding: const EdgeInsets.all(20), child: child),
);

Widget _checkbox({
  bool? value = false,
  bool enabled = true,
  Set<WidgetState> forced = const {},
  ValueChanged<bool>? onChanged,
}) => _pad(
  _maybeForced(
    forced,
    PrCheckbox(
      value: value,
      semanticsLabel: 'debugMode',
      onChanged: enabled ? (onChanged ?? (_) {}) : null,
    ),
  ),
);

Widget _switch({
  bool value = false,
  bool enabled = true,
  Set<WidgetState> forced = const {},
  ValueChanged<bool>? onChanged,
}) => _pad(
  _maybeForced(
    forced,
    PrSwitch(
      value: value,
      semanticsLabel: 'Pause on error',
      onChanged: enabled ? (onChanged ?? (_) {}) : null,
    ),
  ),
);

final _box = find.byType(PrCheckbox);
final _sw = find.byType(PrSwitch);

(Color?, Color) _look(WidgetTester tester, Finder of) {
  final d = decorationIn(tester, of);
  return (d.color, (d.border! as Border).top.color);
}

PrCheckMarkPainter? _mark(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(
    find.descendant(of: _box, matching: find.byType(CustomPaint)),
  );
  return paints
      .map((p) => p.painter)
      .whereType<PrCheckMarkPainter>()
      .firstOrNull;
}

Color _knob(WidgetTester tester) {
  final knob = tester.widget<DecoratedBox>(
    find.descendant(of: _sw, matching: find.byType(DecoratedBox)).last,
  );
  return (knob.decoration as BoxDecoration).color!;
}

void main() {
  group('PrCheckbox', () {
    testWidgets('14px; off, on and mixed', (tester) async {
      await pumpFs(tester, _checkbox());
      expect(tester.getSize(_box), const Size(14, 14));
      expect(_look(tester, _box), (c.surfaceInput, c.borderControl));
      expect(_mark(tester), isNull);

      await pumpFs(tester, _checkbox(value: true));
      expect(_look(tester, _box), (c.accent, c.accent));
      expect(_mark(tester)!.dash, isFalse);
      expect(_mark(tester)!.color, c.textOnAccent);

      await pumpFs(tester, _checkbox(value: null));
      expect(_look(tester, _box), (c.accent, c.accent));
      expect(_mark(tester)!.dash, isTrue);
    });

    testWidgets('hover and pressed, off and on', (tester) async {
      await pumpFs(tester, _checkbox(forced: {WidgetState.hovered}));
      expect(_look(tester, _box), (c.surfaceInput, c.borderStrong));
      await pumpFs(tester, _checkbox(forced: {WidgetState.pressed}));
      expect(_look(tester, _box), (c.surfacePressed, c.borderStrong));
      await pumpFs(
        tester,
        _checkbox(value: true, forced: {WidgetState.hovered}),
      );
      expect(_look(tester, _box), (c.accentHover, c.accentHover));
      await pumpFs(
        tester,
        _checkbox(value: true, forced: {WidgetState.pressed}),
      );
      expect(_look(tester, _box), (c.accentPressed, c.accentPressed));
    });

    testWidgets('disabled off and on', (tester) async {
      await pumpFs(tester, _checkbox(enabled: false));
      expect(_look(tester, _box), (c.surfacePanel, c.borderSubtle));
      await pumpFs(tester, _checkbox(value: true, enabled: false));
      expect(_look(tester, _box), (c.surfacePressed, c.surfacePressed));
      expect(_mark(tester)!.color, c.textDisabled);
    });

    testWidgets('click toggles; mixed becomes checked; Space toggles', (
      tester,
    ) async {
      final values = <bool>[];
      await pumpFs(tester, _checkbox(value: null, onChanged: values.add));
      await tester.tap(_box);
      expect(values, [true]);
      await pumpFs(tester, _checkbox(value: true, onChanged: values.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(values, [true, false]);
    });

    testWidgets('keyboard focus shows the ring; a click does not', (
      tester,
    ) async {
      await pumpFs(tester, _checkbox());
      bool ring() => tester
          .widget<PrFocusRing>(
            find.descendant(of: _box, matching: find.byType(PrFocusRing)),
          )
          .visible;
      await tester.tap(_box);
      await tester.pump();
      expect(ring(), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ring(), isTrue);
    });

    testWidgets('checked and mixed semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpFs(tester, _checkbox(value: true));
      expect(
        tester.getSemantics(find.bySemanticsLabel('debugMode').first),
        isSemantics(
          label: 'debugMode',
          hasCheckedState: true,
          isChecked: true,
          hasTapAction: true,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
        ),
      );
      await pumpFs(tester, _checkbox(value: null));
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('debugMode').first)
            .getSemanticsData()
            // ignore: deprecated_member_use
            .hasFlag(SemanticsFlag.isCheckStateMixed),
        isTrue,
      );
      handle.dispose();
    });
  });

  group('PrSwitch', () {
    testWidgets('28×16; off and on', (tester) async {
      await pumpFs(tester, _switch());
      expect(tester.getSize(_sw), const Size(28, 16));
      expect(_look(tester, _sw), (c.surfacePressed, c.borderControl));
      expect(_knob(tester), c.textSecondary);
      final track = tester.getTopLeft(_sw);
      expect(
        tester.getTopLeft(find.byType(AnimatedPositioned)) - track,
        const Offset(3, 3),
      );

      await pumpFs(tester, _switch(value: true));
      await tester.pumpAndSettle();
      expect(_look(tester, _sw), (c.accent, c.accent));
      expect(_knob(tester), c.textOnAccent);
      expect(
        tester.getTopLeft(find.byType(AnimatedPositioned)) -
            tester.getTopLeft(_sw),
        const Offset(15, 3),
      );
    });

    testWidgets('hover, pressed and disabled', (tester) async {
      await pumpFs(tester, _switch(forced: {WidgetState.hovered}));
      expect(_look(tester, _sw), (c.surfacePressed, c.borderStrong));
      expect(_knob(tester), c.textPrimary);
      await pumpFs(tester, _switch(value: true, forced: {WidgetState.hovered}));
      expect(_look(tester, _sw), (c.accentHover, c.accentHover));
      await pumpFs(tester, _switch(forced: {WidgetState.pressed}));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AnimatedPositioned)).width, 12);
      await pumpFs(tester, _switch(value: true, enabled: false));
      expect(_look(tester, _sw), (c.surfacePanel, c.borderSubtle));
      expect(_knob(tester), c.textDisabled);
    });

    testWidgets('click and Space flip it', (tester) async {
      final values = <bool>[];
      await pumpFs(tester, _switch(onChanged: values.add));
      await tester.tap(_sw);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(values, [true, true]);
    });
  });
}
