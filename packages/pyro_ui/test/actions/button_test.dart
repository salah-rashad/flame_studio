import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../helpers.dart';

final _button = find.byType(PrButton);

Widget _left(Widget child) => Align(
  alignment: Alignment.topLeft,
  child: Padding(padding: const EdgeInsets.all(20), child: child),
);

Widget _maybeForced(Set<WidgetState> states, Widget child) =>
    states.isEmpty ? child : PrDebugStates(states: states, child: child);

Widget _sample(
  PrButtonVariant variant, {
  Set<WidgetState> forced = const {},
  bool enabled = true,
  IconData? icon,
  VoidCallback? onPressed,
  String? disabledReason,
}) => Align(
  alignment: Alignment.topLeft,
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: _maybeForced(
      forced,
      PrButton(
        label: 'Add component',
        variant: variant,
        icon: icon,
        disabledReason: disabledReason,
        onPressed: enabled ? (onPressed ?? () {}) : null,
      ),
    ),
  ),
);

(Color?, Color?, Color?) _look(WidgetTester tester) {
  final d = decorationIn(tester, _button);
  return (
    d.color,
    (d.border! as Border).top.color,
    textColor(tester, 'Add component'),
  );
}

void main() {
  const t = Colors.transparent;

  testWidgets('24px high, body-strong label, 12px padding (ghost 8)', (
    tester,
  ) async {
    await pumpFs(tester, _sample(PrButtonVariant.secondary));
    expect(tester.getSize(_button).height, 24);
    final style = tester.widget<Text>(find.text('Add component')).style!;
    expect(style.fontWeight, FontWeight.w500);
    expect(style.fontSize, 13);
    final text = tester.getRect(find.text('Add component'));
    expect(text.left - tester.getRect(_button).left, 12 + 1); // + border
    await pumpFs(tester, _sample(PrButtonVariant.ghost));
    final ghost = tester.getRect(find.text('Add component'));
    expect(ghost.left - tester.getRect(_button).left, 8 + 1);
  });

  for (final (variant, rest, hover, pressed) in [
    (
      PrButtonVariant.primary,
      (c.accent, t, c.textOnAccent),
      (c.accentHover, t, c.textOnAccent),
      (c.accentPressed, t, c.textOnAccent),
    ),
    (
      PrButtonVariant.secondary,
      (c.surfaceRaised, c.borderControl, c.textPrimary),
      (c.surfaceHover, c.borderStrong, c.textPrimary),
      (c.surfacePressed, c.borderStrong, c.textPrimary),
    ),
    (
      PrButtonVariant.ghost,
      (t, t, c.textSecondary),
      (c.surfaceHover, t, c.textPrimary),
      (c.surfacePressed, t, c.textPrimary),
    ),
    (
      PrButtonVariant.danger,
      (c.surfaceRaised, c.borderControl, c.error),
      (c.errorSubtle, c.error, c.error),
      (c.errorBorder, c.error, c.textPrimary),
    ),
  ]) {
    testWidgets('${variant.name}: rest, hover, pressed', (tester) async {
      await pumpFs(tester, _sample(variant));
      expect(_look(tester), rest);
      await pumpFs(tester, _sample(variant, forced: {WidgetState.hovered}));
      expect(_look(tester), hover);
      await pumpFs(tester, _sample(variant, forced: {WidgetState.pressed}));
      expect(_look(tester), pressed);
    });
  }

  testWidgets('disabled: raised, border-subtle, text-disabled; ghost bare', (
    tester,
  ) async {
    for (final variant in [
      PrButtonVariant.primary,
      PrButtonVariant.secondary,
      PrButtonVariant.danger,
    ]) {
      await pumpFs(
        tester,
        _sample(variant, enabled: false, forced: {WidgetState.hovered}),
      );
      expect(_look(tester), (c.surfaceRaised, c.borderSubtle, c.textDisabled));
    }
    await pumpFs(tester, _sample(PrButtonVariant.ghost, enabled: false));
    expect(_look(tester), (t, t, c.textDisabled));
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('the icon takes the label colour', (tester) async {
    await pumpFs(tester, _sample(PrButtonVariant.primary, icon: PrIcons.plus));
    // Colour and size come through the IconTheme, shared with `leading`.
    final theme = IconTheme.of(tester.element(find.byIcon(PrIcons.plus)));
    expect(theme.color, c.textOnAccent);
    expect(theme.size, 16);
  });

  testWidgets('click, Enter and Space; focus ring only from the keyboard', (
    tester,
  ) async {
    var presses = 0;
    await pumpFs(
      tester,
      _sample(PrButtonVariant.secondary, onPressed: () => presses++),
    );
    await tester.tap(_button);
    await tester.pump();
    expect(
      tester.widget<PrFocusRing>(find.byType(PrFocusRing)).visible,
      isFalse,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester.widget<PrFocusRing>(find.byType(PrFocusRing)).visible,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(presses, 3);
  });

  testWidgets('leading takes a custom glyph in the label colour', (
    tester,
  ) async {
    await pumpFs(
      tester,
      _left(
        PrButton(
          label: 'Run game',
          variant: PrButtonVariant.primary,
          leading: const PrPlayGlyph(size: 14),
          onPressed: () {},
        ),
      ),
    );
    final glyph = find.byType(PrPlayGlyph);
    expect(glyph, findsOneWidget);
    expect(IconTheme.of(tester.element(glyph)).color, c.textOnAccent);
  });

  testWidgets('the label is read once', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpFs(tester, _sample(PrButtonVariant.secondary));
    expect(find.bySemanticsLabel('Add component'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a disabled button says why in its tooltip', (tester) async {
    await pumpFs(
      tester,
      PrDebugStates(
        part: 'tooltip',
        states: const {WidgetState.hovered},
        child: _sample(
          PrButtonVariant.primary,
          enabled: false,
          disabledReason: 'Select a node first',
        ),
      ),
    );
    expect(find.text('Select a node first'), findsOneWidget);
  });

  testWidgets('focusableWhenDisabled: Tab reaches it and shows the reason', (
    tester,
  ) async {
    await pumpFs(
      tester,
      const Padding(
        padding: EdgeInsets.all(40),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrButton(
              label: 'Add component',
              onPressed: null,
              disabledReason: 'Select a node first',
            ),
            PrButton(
              label: 'Run game',
              onPressed: null,
              disabledReason: 'No device connected',
              focusableWhenDisabled: true,
            ),
          ],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(PrTooltip.delay);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Select a node first'), findsNothing);
    expect(find.text('No device connected'), findsOneWidget);
  });

  testWidgets('small: 20px, 8px padding, a 12px medium label', (tester) async {
    await pumpFs(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: PrButton(
          label: 'Review',
          size: PrButtonSize.small,
          variant: PrButtonVariant.ghost,
          onPressed: () {},
        ),
      ),
    );
    expect(tester.getSize(_button).height, 20);
    final style = tester.widget<Text>(find.text('Review')).style!;
    expect(style.fontSize, 12);
    expect(style.fontWeight, FontWeight.w500);
    expect(
      tester.getTopLeft(find.text('Review')).dx - tester.getTopLeft(_button).dx,
      PrSpacing.s2 + 1,
    );
  });
}
