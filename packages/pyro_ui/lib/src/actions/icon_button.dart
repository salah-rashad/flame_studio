import 'package:flutter/material.dart';

import '../colors.dart';
import '../floating/tooltip.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../metrics.dart';
import 'button.dart' show PrOnTint;

/// The two icon-button sizes.
enum PrIconButtonSize {
  /// 24px: toolbars.
  regular,

  /// 20px: panel headers and rows.
  small,
}

/// A square, icon-only ghost button for toolbars, panel headers and row
/// actions.
///
/// - Rest: no fill, `text-secondary` icon. Hover `surface-hover` and
///   `text-primary`; pressed `surface-pressed`; keyboard focus ring outside.
/// - Disabled: no fill, `text-disabled`; the tooltip still shows, with
///   [disabledReason] as its second line. Skipped by Tab unless
///   [focusableWhenDisabled].
/// - [selected] latches it: `accent-subtle` fill, `accent-text` icon
///   (`surface-selected` on hover). For a real on/off state use
///   `PrToggleButton`.
///
/// The [tooltip] is required and is also the semantics label.
class PrIconButton extends StatelessWidget {
  /// Creates the button.
  const PrIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.shortcut,
    this.disabledReason,
    this.selected = false,
    this.size = PrIconButtonSize.regular,
    this.iconSize,
    this.focusable = true,
    this.focusNode,
    this.autofocus = false,
    this.focusableWhenDisabled = false,
  });

  /// The glyph.
  final IconData icon;

  /// The action's name; tooltip and semantics label.
  final String tooltip;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Shown in the tooltip's key cap. The app binds the shortcut itself.
  final SingleActivator? shortcut;

  /// Why the button is disabled; the tooltip's second line while it is.
  final String? disabledReason;

  /// Latched look.
  final bool selected;

  /// 24 or 20.
  final PrIconButtonSize size;

  /// The glyph size; 16 by default (14 in rows, where the design draws
  /// `size-icon-sm`).
  final double? iconSize;

  /// False inside roving-focus groups and rows whose list owns focus.
  final bool focusable;

  /// The focus node.
  final FocusNode? focusNode;

  /// Take focus when first built.
  final bool autofocus;

  /// Keep the Tab stop while disabled, so keyboard users reach the tooltip
  /// and [disabledReason]. Off by default; see
  /// `PrInteractive.focusableWhenDisabled` for when to use it.
  final bool focusableWhenDisabled;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final extent = size == PrIconButtonSize.regular
        ? PrSizes.control
        : PrSizes.controlSm;
    final button = PrInteractive(
      onPressed: onPressed,
      selected: selected,
      focusable: focusable,
      focusNode: focusNode,
      autofocus: autofocus,
      focusableWhenDisabled: focusableWhenDisabled,
      semanticsLabel: tooltip,
      builder: (context, states) {
        final disabled = states.contains(WidgetState.disabled);
        final hovered = states.contains(WidgetState.hovered);
        final pressed = states.contains(WidgetState.pressed);
        final Color fill;
        final Color ink;
        if (disabled) {
          fill = Colors.transparent;
          ink = c.textDisabled;
        } else if (PrOnTint.of(context) && !selected) {
          fill = PrOnTint.fill(c, states);
          ink = c.textPrimary;
        } else if (selected) {
          fill = pressed || hovered ? c.surfaceSelected : c.accentSubtle;
          ink = c.accentText;
        } else {
          fill = PrStateColor.resolve(states, {
            WidgetState.pressed: c.surfacePressed,
            WidgetState.hovered: c.surfaceHover,
          }, fallback: Colors.transparent);
          ink = pressed || hovered ? c.textPrimary : c.textSecondary;
        }
        return PrFocusRing.outside(
          visible: states.contains(WidgetState.focused),
          child: Container(
            width: extent,
            height: extent,
            decoration: BoxDecoration(color: fill, borderRadius: PrRadii.sm),
            child: Icon(icon, size: iconSize ?? PrSizes.icon, color: ink),
          ),
        );
      },
    );
    if (tooltip.isEmpty) return button;
    return PrTooltip(
      message: tooltip,
      shortcut: shortcut,
      details: [
        if (onPressed == null && disabledReason != null) disabledReason!,
      ],
      child: button,
    );
  }
}
