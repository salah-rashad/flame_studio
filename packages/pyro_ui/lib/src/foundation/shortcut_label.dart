import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../metrics.dart';
import '../typography.dart';

/// How a [PrShortcutLabel] is drawn.
enum PrShortcutStyle {
  /// Menu items: `small` (12/16) in `text-secondary`, slightly spaced.
  menu,

  /// Tooltips: a 16px key cap, `caption` (11/14 500) on `surface-pressed`.
  keycap,

  /// Inside buttons: `caption` in the surrounding text colour.
  inline,
}

/// A keyboard shortcut as text: `⌘⇧D` on macOS, `Ctrl+Shift+D` elsewhere.
///
/// It is a widget so menus, tooltips and buttons can take an
/// `PrShortcutLabel?` and draw it; [describe] gives the text alone.
/// Shortcuts that differ by platform (⌘ on macOS, Ctrl elsewhere) are the
/// app's choice of [activator].
class PrShortcutLabel extends StatelessWidget {
  /// The label for [activator].
  const PrShortcutLabel(
    this.activator, {
    super.key,
    this.style = PrShortcutStyle.menu,
    this.color,
    this.platform,
  });

  /// The shortcut.
  final SingleActivator activator;

  /// Menu text, key cap or inline.
  final PrShortcutStyle style;

  /// Overrides the text colour (`text-on-accent` on a highlighted menu
  /// item).
  final Color? color;

  /// The platform whose notation to use; [defaultTargetPlatform] when null.
  final TargetPlatform? platform;

  /// The text for [activator]: modifiers in the platform's order, then the
  /// key. macOS: `⌃⌥⇧⌘` and symbols, no separators (`⌘⇧D`, `⌫`, `↩`).
  /// Windows and Linux: words joined with `+` (`Ctrl+Shift+D`).
  static String describe(
    SingleActivator activator, {
    TargetPlatform? platform,
  }) {
    final target = platform ?? defaultTargetPlatform;
    final mac = _isApple(target);
    final parts = <String>[
      if (activator.control) mac ? '⌃' : 'Ctrl',
      if (activator.alt) mac ? '⌥' : 'Alt',
      if (activator.shift) mac ? '⇧' : 'Shift',
      if (activator.meta)
        mac
            ? '⌘'
            : switch (target) {
                TargetPlatform.windows => 'Win',
                TargetPlatform.linux => 'Super',
                _ => 'Meta',
              },
      _keyName(activator.trigger, mac),
    ];
    return parts.join(mac ? '' : '+');
  }

  static bool _isApple(TargetPlatform platform) =>
      platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;

  static String _keyName(LogicalKeyboardKey key, bool mac) {
    final named = _names[key];
    if (named != null) return mac ? named.$1 : named.$2;
    final label = key.keyLabel;
    return label.length == 1 ? label.toUpperCase() : label;
  }

  static final Map<LogicalKeyboardKey, (String, String)> _names = {
    LogicalKeyboardKey.enter: ('↩', 'Enter'),
    LogicalKeyboardKey.numpadEnter: ('⌤', 'Enter'),
    LogicalKeyboardKey.backspace: ('⌫', 'Backspace'),
    LogicalKeyboardKey.delete: ('⌦', 'Delete'),
    LogicalKeyboardKey.escape: ('⎋', 'Esc'),
    LogicalKeyboardKey.tab: ('⇥', 'Tab'),
    LogicalKeyboardKey.space: ('Space', 'Space'),
    LogicalKeyboardKey.arrowUp: ('↑', '↑'),
    LogicalKeyboardKey.arrowDown: ('↓', '↓'),
    LogicalKeyboardKey.arrowLeft: ('←', '←'),
    LogicalKeyboardKey.arrowRight: ('→', '→'),
    LogicalKeyboardKey.home: ('↖', 'Home'),
    LogicalKeyboardKey.end: ('↘', 'End'),
    LogicalKeyboardKey.pageUp: ('⇞', 'PgUp'),
    LogicalKeyboardKey.pageDown: ('⇟', 'PgDn'),
  };

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final text = describe(activator, platform: platform);
    switch (style) {
      case PrShortcutStyle.menu:
        return Text(
          text,
          maxLines: 1,
          style: PrText.small.copyWith(
            color: color ?? c.textSecondary,
            letterSpacing: 0.48, // .04em
          ),
        );
      case PrShortcutStyle.inline:
        return Text(
          text,
          maxLines: 1,
          style: PrText.caption.copyWith(color: color),
        );
      case PrShortcutStyle.keycap:
        return Container(
          height: PrSizes.icon,
          padding: const EdgeInsets.symmetric(horizontal: PrSpacing.s1),
          decoration: BoxDecoration(
            color: c.surfacePressed,
            borderRadius: PrRadii.xs,
          ),
          // As wide as the text: a Container with an alignment would fill
          // the width it is given.
          child: Center(
            widthFactor: 1,
            child: Text(
              text,
              maxLines: 1,
              style: PrText.caption.copyWith(color: color ?? c.textSecondary),
            ),
          ),
        );
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('shortcut', describe(activator)));
  }
}
