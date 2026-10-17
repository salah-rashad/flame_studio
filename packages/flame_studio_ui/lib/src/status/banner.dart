import 'package:flutter/material.dart';

import '../actions/button.dart';
import '../actions/icon_button.dart';
import '../colors.dart';
import '../foundation/debug_states.dart';
import '../icons.dart';
import '../metrics.dart';
import '../typography.dart';

/// The status a [FsBanner] describes, which sets its colours and icon.
enum FsStatusKind {
  /// `info` on `info-subtle`, with the info icon (a prefab instance).
  info,

  /// `warning` on `warning-subtle`, with the triangle.
  warning,

  /// `error` on `error-subtle`, with the alert circle (a missing
  /// reference).
  error,

  /// `success` on `success-subtle`, with the check (a finished migration).
  success,
}

/// A [FsBanner]'s button.
@immutable
class FsBannerAction {
  /// Creates the action.
  const FsBannerAction({required this.label, required this.onPressed});

  /// A verb: "Open prefab", "Review", "Locate…".
  final String label;

  /// Runs it; null disables the button.
  final VoidCallback? onPressed;
}

/// An inline, persistent message inside a panel: a state that lasts until
/// fixed (prefab notices, missing references, migrations). Use a toast for
/// events.
///
/// Fill `*-subtle`, 1px `*-border`, `radius-sm`, 8px padding, a 16px icon
/// in the kind's colour, the [message] in `small` `text-primary`. At most
/// one [action] (a 20px ghost button) and a dismiss × ([onDismiss]); both
/// draw `text-primary` with a white wash on hover, over the tint.
///
/// Inline in a panel, full width minus 8px margins (the caller's padding).
///
/// Parts for `FsDebugStates` (exact): `action` and `dismiss`.
class FsBanner extends StatelessWidget {
  /// Creates the banner.
  const FsBanner({
    super.key,
    required this.kind,
    required this.message,
    this.action,
    this.onDismiss,
    this.dismissTooltip,
  });

  /// Colours and icon.
  final FsStatusKind kind;

  /// One sentence; the caller bolds the subject with a `TextSpan` style
  /// (`FontWeight.w600`).
  final InlineSpan message;

  /// The one action.
  final FsBannerAction? action;

  /// Shows the dismiss ×.
  final VoidCallback? onDismiss;

  /// The ×'s tooltip and semantics label ("Dismiss").
  final String? dismissTooltip;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final (fill, edge, ink, icon) = switch (kind) {
      FsStatusKind.info => (c.infoSubtle, c.infoBorder, c.info, FsIcons.info),
      FsStatusKind.warning => (
        c.warningSubtle,
        c.warningBorder,
        c.warning,
        FsIcons.alertTriangle,
      ),
      FsStatusKind.error => (
        c.errorSubtle,
        c.errorBorder,
        c.error,
        FsIcons.alertCircle,
      ),
      FsStatusKind.success => (
        c.successSubtle,
        c.successBorder,
        c.success,
        FsIcons.checkCircle,
      ),
    };
    Widget part(String name, Widget child) => FsDebugStates(
      states: FsDebugStates.of(context, part: name, exact: true),
      child: child,
    );
    final hasControls = action != null || onDismiss != null;
    // The controls are 20px and reach 2px past the 8px padding (the CSS
    // -2px margins): the box pads 6 and the text and icon add 2 back.
    return Container(
      padding: EdgeInsets.fromLTRB(
        FsSpacing.s2,
        6,
        hasControls ? 6 : FsSpacing.s2,
        6,
      ),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: edge),
        borderRadius: FsRadii.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: FsSpacing.s2,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: FsSizes.icon, color: ink),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text.rich(
                message,
                style: FsText.small.copyWith(color: c.textPrimary),
              ),
            ),
          ),
          if (hasControls)
            FsOnTint(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  if (action case final action?)
                    part(
                      'action',
                      FsButton(
                        label: action.label,
                        variant: FsButtonVariant.ghost,
                        size: FsButtonSize.small,
                        onPressed: action.onPressed,
                      ),
                    ),
                  if (onDismiss != null)
                    part(
                      'dismiss',
                      FsIconButton(
                        icon: FsIcons.x,
                        iconSize: FsSizes.iconSm,
                        size: FsIconButtonSize.small,
                        tooltip: dismissTooltip ?? '',
                        onPressed: onDismiss,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
