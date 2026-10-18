import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

const _samples = [
  SingleActivator(LogicalKeyboardKey.keyR, meta: true),
  SingleActivator(LogicalKeyboardKey.period, meta: true),
  SingleActivator(LogicalKeyboardKey.keyD, meta: true),
  SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
  SingleActivator(LogicalKeyboardKey.keyK, meta: true, alt: true),
  SingleActivator(LogicalKeyboardKey.tab, control: true),
  SingleActivator(LogicalKeyboardKey.backspace),
  SingleActivator(LogicalKeyboardKey.enter),
  SingleActivator(LogicalKeyboardKey.f2),
  SingleActivator(LogicalKeyboardKey.keyW),
];

class ShortcutLabelPage extends StatelessWidget {
  const ShortcutLabelPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget cell(SingleActivator a, PrShortcutStyle style, TargetPlatform p) =>
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PrSpacing.s2,
            vertical: PrSpacing.s1,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: PrShortcutLabel(a, style: style, platform: p),
          ),
        );
    return GalleryPage(
      title: 'PrShortcutLabel',
      note:
          'Shortcuts in the platform\'s notation: symbols in ⌃⌥⇧⌘ order on '
          'macOS, words joined with + elsewhere. Menu style for menu items, '
          'key caps for tooltips, inline for buttons. Which activator a '
          'platform uses (⌘ or Ctrl) is the app\'s choice; the Windows column '
          'shows the same activators.',
      children: [
        StateGrid(
          columns: const [
            'menu · macOS',
            'keycap · macOS',
            'inline · macOS',
            'menu · Windows',
          ],
          cellWidth: 160,
          labelWidth: 40,
          rows: [
            for (final (i, a) in _samples.indexed)
              GridRow('${i + 1}', [
                cell(a, PrShortcutStyle.menu, TargetPlatform.macOS),
                cell(a, PrShortcutStyle.keycap, TargetPlatform.macOS),
                cell(a, PrShortcutStyle.inline, TargetPlatform.macOS),
                cell(a, PrShortcutStyle.menu, TargetPlatform.windows),
              ]),
          ],
        ),
      ],
    );
  }
}
