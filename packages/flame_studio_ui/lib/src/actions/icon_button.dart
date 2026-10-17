import 'package:flutter/material.dart';

import '../colors.dart';
import '../floating/tooltip.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../metrics.dart';
import 'button.dart' show FsOnTint;

/// The two icon-button sizes.
enum FsIconButtonSize {
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
///   [disabledReason] as its second line.
/// - [selected] latches it: `accent-subtle` fill, `accent-text` icon
///   (`surface-selected` on hover). For a real on/off state use
///   `FsToggleButton`.
///
/// The [tooltip] is required and is also the semantics label.
class FsIconButton extends StatelessWidget {
  /// Creates the button.
  const FsIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.shortcut,
    this.disabledReason,
    this.selected = false,
    this.size = FsIconButtonSize.regular,
    this.iconSize,
    this.focusable = true,
    this.focusNode,
    this.autofocus = false,
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
  final FsIconButtonSize size;

  /// The glyph size; 16 by default (14 in rows, where the design draws
  /// `size-icon-sm`).
  final double? iconSize;

  /// False inside roving-focus groups and rows whose list owns focus.
  final bool focusable;

  /// The focus node.
  final FocusNode? focusNode;

  /// Take focus when first built.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final extent = size == FsIconButtonSize.regular
        ? FsSizes.control
        : FsSizes.controlSm;
    final button = FsInteractive(
      onPressed: onPressed,
      selected: selected,
      focusable: focusable,
      focusNode: focusNode,
      autofocus: autofocus,
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
        } else if (FsOnTint.of(context) && !selected) {
          fill = FsOnTint.fill(c, states);
          ink = c.textPrimary;
        } else if (selected) {
          fill = pressed || hovered ? c.surfaceSelected : c.accentSubtle;
          ink = c.accentText;
        } else {
          fill = FsStateColor.resolve(states, {
            WidgetState.pressed: c.surfacePressed,
            WidgetState.hovered: c.surfaceHover,
          }, fallback: Colors.transparent);
          ink = pressed || hovered ? c.textPrimary : c.textSecondary;
        }
        return FsFocusRing.outside(
          visible: states.contains(WidgetState.focused),
          child: Container(
            width: extent,
            height: extent,
            decoration: BoxDecoration(color: fill, borderRadius: FsRadii.sm),
            child: Icon(icon, size: iconSize ?? FsSizes.icon, color: ink),
          ),
        );
      },
    );
    if (tooltip.isEmpty) return button;
    return FsTooltip(
      message: tooltip,
      shortcut: shortcut,
      details: [
        if (onPressed == null && disabledReason != null) disabledReason!,
      ],
      child: button,
    );
  }
}
