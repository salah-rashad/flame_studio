import 'package:flutter/material.dart';

import '../colors.dart';
import '../metrics.dart';
import 'focus_ring.dart';
import 'interactive.dart';
import 'interim_tooltip.dart';

/// The 20px icon button inside rows (property reset, tree row actions).
///
/// Internal, until `FsIconButton` (small size) replaces it. Rest
/// `text-secondary`; hover `surface-hover` and `text-primary`; pressed
/// `surface-pressed`; latched [selected] `accent-subtle` and `accent-text`
/// (`surface-selected` on hover); disabled `text-disabled`; keyboard focus
/// ring outside.
class FsRowIconButton extends StatelessWidget {
  /// Creates the button.
  const FsRowIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.focusable = true,
  });

  /// The glyph, drawn at 14px.
  final IconData icon;

  /// Tooltip and semantics label.
  final String tooltip;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Latched look.
  final bool selected;

  /// Whether Tab stops here.
  final bool focusable;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    return FsInterimTooltip(
      message: tooltip,
      child: FsInteractive(
        onPressed: onPressed,
        selected: selected,
        focusable: focusable,
        semanticsLabel: tooltip,
        builder: (context, states) {
          final disabled = states.contains(WidgetState.disabled);
          final hovered = states.contains(WidgetState.hovered);
          final Color fill;
          final Color ink;
          if (disabled) {
            fill = Colors.transparent;
            ink = c.textDisabled;
          } else if (selected) {
            fill = hovered ? c.surfaceSelected : c.accentSubtle;
            ink = c.accentText;
          } else {
            fill = FsStateColor.resolve(states, {
              WidgetState.pressed: c.surfacePressed,
              WidgetState.hovered: c.surfaceHover,
            }, fallback: Colors.transparent);
            ink = states.contains(WidgetState.pressed) || hovered
                ? c.textPrimary
                : c.textSecondary;
          }
          return FsFocusRing.outside(
            visible: states.contains(WidgetState.focused),
            child: Container(
              width: FsSizes.controlSm,
              height: FsSizes.controlSm,
              decoration: BoxDecoration(color: fill, borderRadius: FsRadii.sm),
              child: Icon(icon, size: FsSizes.iconSm, color: ink),
            ),
          );
        },
      ),
    );
  }
}
