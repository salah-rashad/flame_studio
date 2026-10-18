import 'package:flutter/material.dart';

import '../colors.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../icons.dart';
import '../metrics.dart';
import '../typography.dart';

/// What a [PrBadge] says, which sets its colours and default icon.
enum PrBadgeKind {
  /// `warning` on `warning-subtle`, with the triangle.
  warning,

  /// `error` on `error-subtle`, with the alert circle.
  error,

  /// A missing asset or script: like [error] (pass the word, "Missing").
  missing,

  /// A prefab instance: `prefab` on `prefab-subtle`. A category, not a
  /// status.
  prefab,

  /// `info` on `info-subtle` ("Running").
  info,

  /// `success` on `success-subtle`, with the check.
  success,

  /// A plain count on `surface-pressed`.
  neutral,

  /// `accent-text` on `accent-subtle` ("Modified").
  accent,
}

/// A small label or count: warning and error counts, "Missing", "Prefab".
///
/// 16px, `radius-xs` ([pill]: fully round), 4px padding, `caption` text;
/// a [count] without a [label] is set in mono. Status kinds carry their
/// icon (warning → triangle, error and missing → alert circle, success →
/// check), so colour never carries the meaning alone; [icon] replaces it.
class PrBadge extends StatelessWidget {
  /// Creates a badge with a [label], a [count], or both.
  const PrBadge({
    super.key,
    required this.kind,
    this.label,
    this.count,
    this.icon,
    this.showIcon = true,
    this.pill = false,
  }) : assert(label != null || count != null, 'Give a label or a count');

  /// Colours and default icon.
  final PrBadgeKind kind;

  /// The word.
  final String? label;

  /// The number.
  final int? count;

  /// Replaces the kind's icon.
  final IconData? icon;

  /// False drops the icon, where the words beside the badge already say
  /// what it counts (a "Warnings" filter segment).
  final bool showIcon;

  /// Fully round, 6px padding.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final (fill, ink, defaultIcon) = switch (kind) {
      PrBadgeKind.warning => (
        c.warningSubtle,
        c.warning,
        PrIcons.alertTriangle,
      ),
      PrBadgeKind.error => (c.errorSubtle, c.error, PrIcons.alertCircle),
      PrBadgeKind.missing => (c.errorSubtle, c.error, PrIcons.alertCircle),
      PrBadgeKind.prefab => (c.prefabSubtle, c.prefab, null),
      PrBadgeKind.info => (c.infoSubtle, c.info, null),
      PrBadgeKind.success => (c.successSubtle, c.success, PrIcons.check),
      PrBadgeKind.neutral => (c.surfacePressed, c.textPrimary, null),
      PrBadgeKind.accent => (c.accentSubtle, c.accentText, null),
    };
    final glyph = showIcon ? icon ?? defaultIcon : null;
    final words = [?label, if (count != null) '$count'].join(' ');
    final style = (label == null ? PrText.monoSmall : PrText.caption).copyWith(
      color: ink,
    );
    return Semantics(
      label: words,
      excludeSemantics: true,
      child: Container(
        height: PrSizes.icon,
        padding: EdgeInsets.symmetric(horizontal: pill ? 6 : PrSpacing.s1),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: pill ? PrRadii.full : PrRadii.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != null) ...[
              Icon(glyph, size: 12, color: ink),
              const SizedBox(width: 2),
            ],
            Text(words, maxLines: 1, softWrap: false, style: style),
          ],
        ),
      ),
    );
  }
}

/// A run-target chip: a device icon, its name and a detail ("852×393",
/// "offline").
///
/// 24px, `surface-raised`, 1px `border-subtle`, `radius-sm`; name in
/// `small`, detail in mono `text-secondary`. Hover `surface-hover` with a
/// `border-control` edge, pressed `surface-pressed`, keyboard focus ring
/// outside; [selected] (the current target) `accent-subtle` with an
/// `accent-text` edge and icon; [error] (offline) an `error` edge and the
/// alert icon in place of the device icon. Null [onPressed] disables it.
///
/// The app maps its device model to [icon], [label] and [detail].
class PrDeviceChip extends StatelessWidget {
  /// Creates the chip.
  const PrDeviceChip({
    super.key,
    required this.icon,
    required this.label,
    this.detail,
    this.selected = false,
    this.error = false,
    this.chevron = false,
    this.onPressed,
  });

  /// The device kind (smartphone, monitor).
  final IconData icon;

  /// The device name.
  final String label;

  /// The resolution or the state, in mono.
  final String? detail;

  /// The current target.
  final bool selected;

  /// The device is unavailable.
  final bool error;

  /// A trailing 12px chevron: the chip opens a device list (the main
  /// toolbar's target chip).
  final bool chevron;

  /// Picks the device; null disables the chip.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    return PrInteractive(
      onPressed: onPressed,
      selected: selected,
      error: error,
      semanticsLabel: [label, ?detail].join(', '),
      builder: (context, states) {
        final disabled = states.contains(WidgetState.disabled);
        final pressed = states.contains(WidgetState.pressed);
        final hovered = pressed || states.contains(WidgetState.hovered);
        final Color fill;
        final Color edge;
        Color iconInk = c.textSecondary;
        Color ink = c.textPrimary;
        Color quiet = c.textSecondary;
        if (disabled) {
          fill = c.surfaceRaised;
          edge = c.borderSubtle;
          iconInk = ink = quiet = c.textDisabled;
        } else {
          // The selected look wins over hover and press, as in the design.
          fill = selected
              ? c.accentSubtle
              : pressed
              ? c.surfacePressed
              : hovered
              ? c.surfaceHover
              : c.surfaceRaised;
          edge = error
              ? c.error
              : selected
              ? c.accentText
              : hovered
              ? c.borderControl
              : c.borderSubtle;
          if (error) {
            iconInk = c.error;
          } else if (selected) {
            iconInk = c.accentText;
          }
        }
        return PrFocusRing.outside(
          visible: states.contains(WidgetState.focused),
          child: Container(
            height: PrSizes.control,
            padding: const EdgeInsets.symmetric(horizontal: PrSpacing.s2),
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: edge),
              borderRadius: PrRadii.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  error && !disabled ? PrIcons.alertCircle : icon,
                  size: PrSizes.iconSm,
                  color: iconInk,
                ),
                const SizedBox(width: PrSpacing.s1),
                // A long name gives way first when the chip is squeezed.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: PrText.small.copyWith(color: ink),
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(width: PrSpacing.s1),
                  Text(
                    detail!,
                    maxLines: 1,
                    softWrap: false,
                    style: PrText.monoSmall.copyWith(
                      color: quiet,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                if (chevron) ...[
                  const SizedBox(width: PrSpacing.s1),
                  Icon(PrIcons.chevronDown, size: 12, color: quiet),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
