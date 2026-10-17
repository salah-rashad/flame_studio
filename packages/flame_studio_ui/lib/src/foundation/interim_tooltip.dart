import 'package:flutter/material.dart';

import '../colors.dart';
import '../metrics.dart';
import '../shadows.dart';
import '../typography.dart';

/// A Material [Tooltip] dressed in the tooltip tokens, used until `FsTooltip`
/// (with its 0ms hand-off between neighbours) is built.
///
/// Internal. `surface-overlay`, 1px `border-overlay`, `radius-sm`,
/// `shadow-tooltip`, 4×8 padding, `small` text, 500ms delay.
class FsInterimTooltip extends StatelessWidget {
  /// Wraps [child]; returns it unchanged when [message] is null.
  const FsInterimTooltip({
    super.key,
    required this.message,
    this.error = false,
    required this.child,
  });

  /// The text.
  final String? message;

  /// Error tooltips use an `error-border` edge and `error` text.
  final bool error;

  /// The anchor.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message == null || message.isEmpty) return child;
    final c = FsColors.of(context);
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 500),
      verticalOffset: 14,
      padding: const EdgeInsets.symmetric(
        horizontal: FsSpacing.s2,
        vertical: FsSpacing.s1,
      ),
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
        color: c.surfaceOverlay,
        border: Border.all(color: error ? c.errorBorder : c.borderOverlay),
        borderRadius: FsRadii.sm,
        boxShadow: FsShadows.of(context).tooltip,
      ),
      textStyle: FsText.small.copyWith(color: error ? c.error : c.textPrimary),
      child: child,
    );
  }
}
