import 'package:flutter/material.dart';

import '../colors.dart';
import '../floating/tooltip.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../metrics.dart';
import '../typography.dart';

/// The four button styles.
enum FsButtonVariant {
  /// The one thing a view is for (at most one per view): `accent` fill,
  /// `text-on-accent` label.
  primary,

  /// Everything else: `surface-raised` fill, `border-control` edge.
  secondary,

  /// Inside dense surfaces: no fill or edge, `text-secondary` label.
  ghost,

  /// Destructive confirmations: `error` label, `error` edge on hover.
  danger,
}

/// A text button for commands, 24px high, label in `body-strong`.
///
/// | Variant | Fill (rest → hover → pressed) | Edge | Label |
/// |---|---|---|---|
/// | primary | accent → accent-hover → accent-pressed | none | text-on-accent |
/// | secondary | surface-raised → surface-hover → surface-pressed | border-control → border-strong | text-primary |
/// | ghost | none → surface-hover → surface-pressed | none | text-secondary → text-primary |
/// | danger | surface-raised → error-subtle → error-border | border-control → error | error (pressed: text-primary) |
///
/// Disabled: `surface-raised`, `border-subtle`, `text-disabled` (ghost:
/// no fill or edge), never opacity; the tooltip still shows and says why
/// with [disabledReason]. Keyboard focus draws the ring outside. Buttons
/// have no selected or error state: use `FsToggleButton`, and put errors
/// on the field.
class FsButton extends StatelessWidget {
  /// Creates the button.
  const FsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = FsButtonVariant.secondary,
    this.icon,
    this.tooltip,
    this.shortcut,
    this.disabledReason,
    this.focusNode,
    this.autofocus = false,
  });

  /// A verb, sentence case: "Add component", "Don't save".
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Primary, secondary, ghost or danger.
  final FsButtonVariant variant;

  /// A 16px leading icon.
  final IconData? icon;

  /// A tooltip; with a [shortcut] it shows the key cap.
  final String? tooltip;

  /// Shown in the tooltip. The app binds the shortcut itself.
  final SingleActivator? shortcut;

  /// Why the button is disabled; the tooltip's second line while it is.
  final String? disabledReason;

  /// The focus node.
  final FocusNode? focusNode;

  /// Take focus when first built.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final button = FsInteractive(
      onPressed: onPressed,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticsLabel: label,
      builder: (context, states) {
        final (fill, edge, ink) = _colors(c, states);
        return FsFocusRing.outside(
          visible: states.contains(WidgetState.focused),
          child: Container(
            height: FsSizes.control,
            padding: EdgeInsets.symmetric(
              horizontal: variant == FsButtonVariant.ghost
                  ? FsSpacing.s2
                  : FsSpacing.s3,
            ),
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: edge),
              borderRadius: FsRadii.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: FsSizes.icon, color: ink),
                  const SizedBox(width: FsSpacing.s1),
                ],
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: FsText.bodyStrong.copyWith(color: ink),
                ),
              ],
            ),
          ),
        );
      },
    );
    final reason = onPressed == null ? disabledReason : null;
    final message = tooltip ?? (reason != null ? label : null);
    if (message == null) return button;
    return FsTooltip(
      message: message,
      shortcut: shortcut,
      details: [?reason],
      child: button,
    );
  }

  /// Fill, edge and label colour for [states].
  (Color, Color, Color) _colors(FsColors c, Set<WidgetState> states) {
    const none = Colors.transparent;
    final pressed = states.contains(WidgetState.pressed);
    final hovered = pressed || states.contains(WidgetState.hovered);
    if (states.contains(WidgetState.disabled)) {
      return variant == FsButtonVariant.ghost
          ? (none, none, c.textDisabled)
          : (c.surfaceRaised, c.borderSubtle, c.textDisabled);
    }
    return switch (variant) {
      FsButtonVariant.primary => (
        pressed
            ? c.accentPressed
            : hovered
            ? c.accentHover
            : c.accent,
        none,
        c.textOnAccent,
      ),
      FsButtonVariant.secondary => (
        pressed
            ? c.surfacePressed
            : hovered
            ? c.surfaceHover
            : c.surfaceRaised,
        hovered ? c.borderStrong : c.borderControl,
        c.textPrimary,
      ),
      FsButtonVariant.ghost => (
        pressed
            ? c.surfacePressed
            : hovered
            ? c.surfaceHover
            : none,
        none,
        hovered ? c.textPrimary : c.textSecondary,
      ),
      FsButtonVariant.danger => (
        pressed
            ? c.errorBorder
            : hovered
            ? c.errorSubtle
            : c.surfaceRaised,
        hovered ? c.error : c.borderControl,
        pressed ? c.textPrimary : c.error,
      ),
    };
  }
}
