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

/// The two button heights.
enum FsButtonSize {
  /// 24px, label in `body-strong`.
  regular,

  /// 20px, a 12px label (weight 500) and 8px padding: inside banners.
  small,
}

/// A text button for commands, 24px high (20 with [FsButtonSize.small]),
/// label in `body-strong`.
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
    this.size = FsButtonSize.regular,
    this.icon,
    this.leading,
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

  /// 24 or 20.
  final FsButtonSize size;

  /// A 16px leading icon.
  final IconData? icon;

  /// A custom glyph in place of [icon] (`FsPlayGlyph` for "Run game"); it
  /// takes the label colour and icon size through the [IconTheme].
  final Widget? leading;

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
        final (fill, edge, ink) = _colors(
          c,
          FsOnTint.of(context),
          FsGhostEmphasis.of(context),
          states,
        );
        final small = size == FsButtonSize.small;
        return FsFocusRing.outside(
          visible: states.contains(WidgetState.focused),
          child: Container(
            height: small ? FsSizes.controlSm : FsSizes.control,
            padding: EdgeInsets.symmetric(
              horizontal: small || variant == FsButtonVariant.ghost
                  ? FsSpacing.s2
                  : FsSpacing.s3,
            ),
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: edge),
              borderRadius: FsRadii.sm,
            ),
            // The label comes from semanticsLabel; excluded here so screen
            // readers don't read it twice.
            child: IconTheme.merge(
              data: IconThemeData(
                color: ink,
                size: small ? FsSizes.iconSm : FsSizes.icon,
              ),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading != null || icon != null) ...[
                      leading ?? Icon(icon),
                      const SizedBox(width: FsSpacing.s1),
                    ],
                    Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style:
                          (small
                                  ? FsText.small.copyWith(
                                      fontWeight: FontWeight.w500,
                                    )
                                  : FsText.bodyStrong)
                              .copyWith(color: ink),
                    ),
                  ],
                ),
              ),
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
  (Color, Color, Color) _colors(
    FsColors c,
    bool onTint,
    bool emphasis,
    Set<WidgetState> states,
  ) {
    const none = Colors.transparent;
    final pressed = states.contains(WidgetState.pressed);
    final hovered = pressed || states.contains(WidgetState.hovered);
    if (onTint &&
        variant == FsButtonVariant.ghost &&
        !states.contains(WidgetState.disabled)) {
      return (FsOnTint.fill(c, states), none, c.textPrimary);
    }
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
        hovered || emphasis ? c.textPrimary : c.textSecondary,
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

/// Marks ghost buttons and icon buttons that sit on a tinted fill (a
/// banner's `*-subtle`): their ink is `text-primary` and hover and press
/// lay a white wash over the tint instead of the opaque `surface-hover`.
///
/// Internal to the package (FsBanner uses it).
class FsOnTint extends InheritedWidget {
  /// Marks [child].
  const FsOnTint({super.key, required super.child});

  /// Whether [context] sits on a tint.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FsOnTint>() != null;

  /// The wash for [states]: `text-primary` at 8% on hover (the design's
  /// `#ffffff14`, which has no token) and 12% pressed; none at rest.
  static Color fill(FsColors c, Set<WidgetState> states) =>
      FsStateColor.resolve(states, {
        WidgetState.pressed: c.textPrimary.withValues(alpha: 0.12),
        WidgetState.hovered: c.textPrimary.withValues(alpha: 0.08),
      }, fallback: Colors.transparent);

  @override
  bool updateShouldNotify(FsOnTint oldWidget) => false;
}

/// Marks the ghost button below it as the emphasised one of a group: its
/// label is `text-primary` at rest, not `text-secondary` (a toast's first
/// action, as preview.html draws it).
///
/// Internal; hidden from the package export.
class FsGhostEmphasis extends InheritedWidget {
  /// Marks [child].
  const FsGhostEmphasis({super.key, required super.child});

  /// Whether [context] sits under an emphasis marker.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FsGhostEmphasis>() != null;

  @override
  bool updateShouldNotify(FsGhostEmphasis oldWidget) => false;
}
