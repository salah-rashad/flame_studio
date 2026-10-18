import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../helpers.dart';

String _mac(SingleActivator a) =>
    PrShortcutLabel.describe(a, platform: TargetPlatform.macOS);
String _win(SingleActivator a) =>
    PrShortcutLabel.describe(a, platform: TargetPlatform.windows);
String _linux(SingleActivator a) =>
    PrShortcutLabel.describe(a, platform: TargetPlatform.linux);

void main() {
  const all = SingleActivator(
    LogicalKeyboardKey.keyD,
    control: true,
    alt: true,
    shift: true,
    meta: true,
  );

  test('macOS: ⌃⌥⇧⌘ then the key, no separators', () {
    expect(
      _mac(const SingleActivator(LogicalKeyboardKey.keyR, meta: true)),
      '⌘R',
    );
    expect(
      _mac(
        const SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true),
      ),
      '⇧⌘D',
    );
    expect(_mac(all), '⌃⌥⇧⌘D');
  });

  test('Windows and Linux: words joined with +', () {
    expect(
      _win(
        const SingleActivator(
          LogicalKeyboardKey.keyD,
          control: true,
          shift: true,
        ),
      ),
      'Ctrl+Shift+D',
    );
    expect(_win(all), 'Ctrl+Alt+Shift+Win+D');
    expect(_linux(all), 'Ctrl+Alt+Shift+Super+D');
  });

  test('named keys', () {
    for (final (key, mac, win) in [
      (LogicalKeyboardKey.backspace, '⌫', 'Backspace'),
      (LogicalKeyboardKey.delete, '⌦', 'Delete'),
      (LogicalKeyboardKey.enter, '↩', 'Enter'),
      (LogicalKeyboardKey.escape, '⎋', 'Esc'),
      (LogicalKeyboardKey.tab, '⇥', 'Tab'),
      (LogicalKeyboardKey.arrowUp, '↑', '↑'),
      (LogicalKeyboardKey.space, 'Space', 'Space'),
      (LogicalKeyboardKey.f2, 'F2', 'F2'),
      (LogicalKeyboardKey.period, '.', '.'),
      (LogicalKeyboardKey.digit1, '1', '1'),
    ]) {
      expect(_mac(SingleActivator(key)), mac);
      expect(_win(SingleActivator(key)), win);
    }
  });

  testWidgets('menu style: small text-secondary, or the given colour', (
    tester,
  ) async {
    const r = SingleActivator(LogicalKeyboardKey.keyR, meta: true);
    await pumpFs(
      tester,
      const PrShortcutLabel(r, platform: TargetPlatform.macOS),
    );
    final style = tester.widget<Text>(find.text('⌘R')).style!;
    expect(style.color, c.textSecondary);
    expect(style.fontSize, PrText.small.fontSize);

    await pumpFs(
      tester,
      PrShortcutLabel(r, platform: TargetPlatform.macOS, color: c.textOnAccent),
    );
    expect(textColor(tester, '⌘R'), c.textOnAccent);
  });

  testWidgets('key cap: 16px high on surface-pressed', (tester) async {
    await pumpFs(
      tester,
      const Align(
        alignment: Alignment.topLeft,
        child: PrShortcutLabel(
          SingleActivator(LogicalKeyboardKey.keyR, meta: true),
          style: PrShortcutStyle.keycap,
          platform: TargetPlatform.macOS,
        ),
      ),
    );
    final cap = find.byType(PrShortcutLabel);
    expect(tester.getSize(cap).height, 16);
    // As wide as "⌘R" plus 4px padding each side, not the available width.
    expect(tester.getSize(cap).width, lessThan(40));
    final box = decorationIn(tester, cap);
    expect(box.color, c.surfacePressed);
    expect(box.borderRadius, PrRadii.xs);
    expect(textColor(tester, '⌘R'), c.textSecondary);
  });

  testWidgets('inline style takes the surrounding text colour', (tester) async {
    await pumpFs(
      tester,
      DefaultTextStyle(
        style: TextStyle(color: c.textOnAccent),
        child: const PrShortcutLabel(
          SingleActivator(LogicalKeyboardKey.keyR, meta: true),
          style: PrShortcutStyle.inline,
          platform: TargetPlatform.macOS,
        ),
      ),
    );
    final style = DefaultTextStyle.of(
      tester.element(find.text('⌘R')),
    ).style.merge(tester.widget<Text>(find.text('⌘R')).style);
    expect(style.color, c.textOnAccent);
    expect(style.fontSize, PrText.caption.fontSize);
  });
}
