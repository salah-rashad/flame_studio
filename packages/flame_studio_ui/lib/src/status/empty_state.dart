import 'package:flutter/material.dart';

import '../actions/button.dart';
import '../colors.dart';
import '../metrics.dart';
import '../typography.dart';

/// What a panel shows when it has nothing to show: an icon, a title, one
/// line and one action. No illustrations.
///
/// Centred, 24px padding: a 48px tile (`surface-raised`, 1px
/// `border-subtle`, `radius-lg`) with a 24px `text-secondary` icon, the
/// [title] in `title`, the [message] in `small` `text-secondary` at most
/// 280px wide, the [action], and an optional [shortcutHint] under it.
///
/// Use a primary [action] for what fills the panel ("New scene", "Run
/// game") and a secondary one for recovery ("Clear search").
class FsEmptyState extends StatelessWidget {
  /// Creates the empty state.
  const FsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    this.shortcutHint,
  });

  /// The panel's kind of content (layers for a scene, a terminal for the
  /// console).
  final IconData icon;

  /// What is missing: "No scene open".
  final String title;

  /// One line on how to fill it.
  final String message;

  /// The one button.
  final FsButton action;

  /// A line under the button: "or press ⌘N" (build the keys with
  /// `FsShortcutLabel.describe`).
  final String? shortcutHint;

  /// The icon tile's edge.
  static const double tileSize = 48;

  /// The message's widest line.
  static const double messageWidth = 280;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(FsSpacing.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: FsSpacing.s2,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: FsSpacing.s2),
            child: Container(
              width: tileSize,
              height: tileSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surfaceRaised,
                border: Border.all(color: c.borderSubtle),
                borderRadius: FsRadii.lg,
              ),
              child: Icon(icon, size: 24, color: c.textSecondary),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: FsText.title.copyWith(color: c.textPrimary),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: FsSpacing.s2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: messageWidth),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: FsText.small.copyWith(color: c.textSecondary),
              ),
            ),
          ),
          action,
          if (shortcutHint != null)
            Padding(
              padding: const EdgeInsets.only(top: FsSpacing.s1),
              child: Text(
                shortcutHint!,
                textAlign: TextAlign.center,
                style: FsText.caption.copyWith(
                  fontWeight: FontWeight.w400,
                  color: c.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
