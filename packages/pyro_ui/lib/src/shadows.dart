import 'package:flutter/material.dart';

/// The shadow tokens of the Pyro design system (`shadow.tokens` in
/// `design/tokens.json`).
///
/// Only floating layers cast a shadow; panels and controls are flat. Each
/// shadow is a single [BoxShadow].
@immutable
class PrShadows extends ThemeExtension<PrShadows> {
  /// Creates a shadow set. Use [PrShadows.dark] unless you are adding a theme.
  const PrShadows({
    required this.tooltip,
    required this.popover,
    required this.dialog,
    required this.focus,
    required this.focusInset,
  });

  /// The dark theme, the only one so far.
  static const dark = PrShadows(
    tooltip: [
      BoxShadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 6),
    ],
    popover: [
      BoxShadow(color: Color(0x7A000000), offset: Offset(0, 6), blurRadius: 16),
    ],
    dialog: [
      BoxShadow(
        color: Color(0xA3000000),
        offset: Offset(0, 16),
        blurRadius: 40,
      ),
    ],
    focus: [BoxShadow(color: Color(0xFFFFA66E), spreadRadius: 2)],
    focusInset: BorderSide(color: Color(0xFFFFA66E), width: 2),
  );

  /// The shadows of the nearest [Theme].
  ///
  /// Throws if the theme has no [PrShadows]: build it with `PrTheme`.
  static PrShadows of(BuildContext context) =>
      Theme.of(context).extension<PrShadows>()!;

  /// Tooltips.
  final List<BoxShadow> tooltip;

  /// Context menus, dropdown lists, toasts.
  final List<BoxShadow> popover;

  /// Modal dialogs.
  final List<BoxShadow> dialog;

  /// Focus ring on buttons and standalone controls: 2px of `focusRing`
  /// outside the edge, following the radius.
  final List<BoxShadow> focus;

  /// Focus ring on rows and cells inside scrolling lists, where an outer ring
  /// would be clipped.
  ///
  /// The token is an inset shadow, which [BoxShadow] can't draw; paint it as
  /// a `Border.all` from this side in a foreground decoration.
  final BorderSide focusInset;

  @override
  PrShadows copyWith({
    List<BoxShadow>? tooltip,
    List<BoxShadow>? popover,
    List<BoxShadow>? dialog,
    List<BoxShadow>? focus,
    BorderSide? focusInset,
  }) {
    return PrShadows(
      tooltip: tooltip ?? this.tooltip,
      popover: popover ?? this.popover,
      dialog: dialog ?? this.dialog,
      focus: focus ?? this.focus,
      focusInset: focusInset ?? this.focusInset,
    );
  }

  @override
  PrShadows lerp(PrShadows? other, double t) {
    if (other == null) return this;
    return PrShadows(
      tooltip: BoxShadow.lerpList(tooltip, other.tooltip, t)!,
      popover: BoxShadow.lerpList(popover, other.popover, t)!,
      dialog: BoxShadow.lerpList(dialog, other.dialog, t)!,
      focus: BoxShadow.lerpList(focus, other.focus, t)!,
      focusInset: BorderSide.lerp(focusInset, other.focusInset, t),
    );
  }
}
