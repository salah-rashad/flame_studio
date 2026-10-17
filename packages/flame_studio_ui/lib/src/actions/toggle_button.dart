import 'package:flutter/material.dart';

import '../colors.dart';
import '../floating/tooltip.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../metrics.dart';
import '../typography.dart';

/// A button that stays on: view toggles (grid, hitboxes, snap) and
/// filters.
///
/// - **Icon form** (no [label]): looks like a 24px `FsIconButton`; on is
///   `accent-subtle` with an `accent-text` icon.
/// - **Text form** ([label], optionally with a 14px [icon]): a 24px
///   `surface-raised` button with a `border-control` edge and a
///   `text-secondary` label; on adds the `accent-subtle` fill and an
///   `accent-text` edge and label.
/// - Hover `surface-hover` (on: `surface-selected`), pressed
///   `surface-pressed`, keyboard focus ring outside; disabled
///   `text-disabled`.
///
/// Exposes toggled semantics. When exactly one of several options must be
/// on, use a segmented control instead.
class FsToggleButton extends StatelessWidget {
  /// Creates the toggle. At least one of [icon] and [label] is needed.
  const FsToggleButton({
    super.key,
    this.icon,
    this.label,
    required this.value,
    required this.onChanged,
    required this.tooltip,
    this.shortcut,
    this.disabledReason,
    this.focusable = true,
    this.focusNode,
  }) : assert(icon != null || label != null, 'Give an icon, a label or both');

  /// The glyph: 16px alone, 14px next to a label.
  final IconData? icon;

  /// The text form's label.
  final String? label;

  /// On or off.
  final bool value;

  /// Called with the new value; null disables the toggle.
  final ValueChanged<bool>? onChanged;

  /// Tooltip and semantics label.
  final String tooltip;

  /// Shown in the tooltip's key cap. The app binds the shortcut itself.
  final SingleActivator? shortcut;

  /// Why the toggle is disabled; the tooltip's second line while it is.
  final String? disabledReason;

  /// False inside roving-focus groups.
  final bool focusable;

  /// The focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final onChanged = this.onChanged;
    final textForm = label != null;
    final toggle = FsInteractive(
      onPressed: onChanged == null ? null : () => onChanged(!value),
      selected: value,
      focusable: focusable,
      focusNode: focusNode,
      semanticsLabel: tooltip,
      semanticsToggled: value,
      builder: (context, states) {
        final disabled = states.contains(WidgetState.disabled);
        final pressed = states.contains(WidgetState.pressed);
        final hovered = pressed || states.contains(WidgetState.hovered);
        final Color fill;
        final Color ink;
        Color edge = Colors.transparent;
        if (disabled) {
          fill = textForm ? c.surfaceRaised : Colors.transparent;
          ink = c.textDisabled;
          if (textForm) edge = c.borderSubtle;
        } else if (value) {
          fill = hovered ? c.surfaceSelected : c.accentSubtle;
          ink = c.accentText;
          if (textForm) edge = c.accentText;
        } else {
          fill = pressed
              ? c.surfacePressed
              : hovered
              ? c.surfaceHover
              : (textForm ? c.surfaceRaised : Colors.transparent);
          ink = hovered ? c.textPrimary : c.textSecondary;
          if (textForm) edge = c.borderControl;
        }
        final Widget content = textForm
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: FsSizes.iconSm, color: ink),
                    const SizedBox(width: FsSpacing.s1),
                  ],
                  Text(
                    label!,
                    maxLines: 1,
                    softWrap: false,
                    style: FsText.bodyStrong.copyWith(color: ink),
                  ),
                ],
              )
            : Icon(icon, size: FsSizes.icon, color: ink);
        return FsFocusRing.outside(
          visible: states.contains(WidgetState.focused),
          child: Container(
            width: textForm ? null : FsSizes.control,
            height: FsSizes.control,
            padding: textForm
                ? const EdgeInsets.symmetric(horizontal: FsSpacing.s2)
                : null,
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: edge),
              borderRadius: FsRadii.sm,
            ),
            child: content,
          ),
        );
      },
    );
    return FsTooltip(
      message: tooltip,
      shortcut: shortcut,
      details: [
        if (onChanged == null && disabledReason != null) disabledReason!,
      ],
      child: toggle,
    );
  }
}
