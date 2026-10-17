import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _button = find.byType(FsButton);

Widget _left(Widget child) => Align(
  alignment: Alignment.topLeft,
  child: Padding(padding: const EdgeInsets.all(20), child: child),
);

Widget _maybeForced(Set<WidgetState> states, Widget child) =>
    states.isEmpty ? child : FsDebugStates(states: states, child: child);

Widget _sample(
  FsButtonVariant variant, {
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
      FsButton(
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
    await pumpFs(tester, _sample(FsButtonVariant.secondary));
    expect(tester.getSize(_button).height, 24);
    final style = tester.widget<Text>(find.text('Add component')).style!;
    expect(style.fontWeight, FontWeight.w500);
    expect(style.fontSize, 13);
    final text = tester.getRect(find.text('Add component'));
    expect(text.left - tester.getRect(_button).left, 12 + 1); // + border
    await pumpFs(tester, _sample(FsButtonVariant.ghost));
    final ghost = tester.getRect(find.text('Add component'));
    expect(ghost.left - tester.getRect(_button).left, 8 + 1);
  });

  for (final (variant, rest, hover, pressed) in [
    (
      FsButtonVariant.primary,
      (c.accent, t, c.textOnAccent),
      (c.accentHover, t, c.textOnAccent),
      (c.accentPressed, t, c.textOnAccent),
    ),
    (
      FsButtonVariant.secondary,
      (c.surfaceRaised, c.borderControl, c.textPrimary),
      (c.surfaceHover, c.borderStrong, c.textPrimary),
      (c.surfacePressed, c.borderStrong, c.textPrimary),
    ),
    (
      FsButtonVariant.ghost,
      (t, t, c.textSecondary),
      (c.surfaceHover, t, c.textPrimary),
      (c.surfacePressed, t, c.textPrimary),
    ),
    (
      FsButtonVariant.danger,
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
      FsButtonVariant.primary,
      FsButtonVariant.secondary,
      FsButtonVariant.danger,
    ]) {
      await pumpFs(
        tester,
        _sample(variant, enabled: false, forced: {WidgetState.hovered}),
      );
      expect(_look(tester), (c.surfaceRaised, c.borderSubtle, c.textDisabled));
    }
    await pumpFs(tester, _sample(FsButtonVariant.ghost, enabled: false));
    expect(_look(tester), (t, t, c.textDisabled));
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('the icon takes the label colour', (tester) async {
    await pumpFs(tester, _sample(FsButtonVariant.primary, icon: FsIcons.plus));
    // Colour and size come through the IconTheme, shared with `leading`.
    final theme = IconTheme.of(tester.element(find.byIcon(FsIcons.plus)));
    expect(theme.color, c.textOnAccent);
    expect(theme.size, 16);
  });

  testWidgets('click, Enter and Space; focus ring only from the keyboard', (
    tester,
  ) async {
    var presses = 0;
    await pumpFs(
      tester,
      _sample(FsButtonVariant.secondary, onPressed: () => presses++),
    );
    await tester.tap(_button);
    await tester.pump();
    expect(
      tester.widget<FsFocusRing>(find.byType(FsFocusRing)).visible,
      isFalse,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester.widget<FsFocusRing>(find.byType(FsFocusRing)).visible,
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
        FsButton(
          label: 'Run game',
          variant: FsButtonVariant.primary,
          leading: const FsPlayGlyph(size: 14),
          onPressed: () {},
        ),
      ),
    );
    final glyph = find.byType(FsPlayGlyph);
    expect(glyph, findsOneWidget);
    expect(IconTheme.of(tester.element(glyph)).color, c.textOnAccent);
  });

  testWidgets('the label is read once', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpFs(tester, _sample(FsButtonVariant.secondary));
    expect(find.bySemanticsLabel('Add component'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a disabled button says why in its tooltip', (tester) async {
    await pumpFs(
      tester,
      FsDebugStates(
        part: 'tooltip',
        states: const {WidgetState.hovered},
        child: _sample(
          FsButtonVariant.primary,
          enabled: false,
          disabledReason: 'Select a node first',
        ),
      ),
    );
    expect(find.text('Select a node first'), findsOneWidget);
  });

  testWidgets('small: 20px, 8px padding, a 12px medium label', (tester) async {
    await pumpFs(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: FsButton(
          label: 'Review',
          size: FsButtonSize.small,
          variant: FsButtonVariant.ghost,
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
      FsSpacing.s2 + 1,
    );
  });
}
