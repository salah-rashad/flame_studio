import 'package:flutter/material.dart';

import 'colors.dart';
import 'shadows.dart';
import 'typography.dart';

/// Builds the Studio's [ThemeData] from the design tokens.
///
/// The Studio still runs inside a `MaterialApp` (text editing, scrolling,
/// overlays), so Material widgets that slip through look roughly right. The
/// Studio's own widgets read [FsColors] and [FsShadows] from the theme, not
/// Material's colour scheme.
abstract final class FsTheme {
  /// The dark theme, the only one so far.
  static ThemeData dark() =>
      _build(Brightness.dark, FsColors.dark, FsShadows.dark);

  static ThemeData _build(
    Brightness brightness,
    FsColors c,
    FsShadows shadows,
  ) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.textOnAccent,
      secondary: c.accentText,
      onSecondary: c.bgApp,
      error: c.error,
      onError: c.bgApp,
      surface: c.surfacePanel,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surfaceInput,
      surfaceContainerLow: c.surfacePanel,
      surfaceContainer: c.surfaceRaised,
      surfaceContainerHigh: c.surfaceOverlay,
      surfaceContainerHighest: c.surfaceHover,
      outline: c.borderControl,
      outlineVariant: c.borderSubtle,
      scrim: c.scrim,
      shadow: const Color(0xFF000000),
    );
    TextStyle colored(TextStyle style, Color color) =>
        style.copyWith(color: color);

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bgApp,
      canvasColor: c.surfacePanel,
      dividerColor: c.borderSubtle,
      disabledColor: c.textDisabled,
      hoverColor: c.surfaceHover,
      focusColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      // No ripples or ink splashes anywhere (design system: Interaction).
      splashFactory: NoSplash.splashFactory,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.textPrimary,
        selectionColor: c.surfaceSelected,
        selectionHandleColor: c.accent,
      ),
      // The package-qualified name (`packages/flame_studio_ui/Inter`).
      fontFamily: FsText.body.fontFamily,
      textTheme: TextTheme(
        titleMedium: colored(FsText.title, c.textPrimary),
        titleSmall: colored(FsText.heading, c.textPrimary),
        bodyLarge: colored(FsText.bodyStrong, c.textPrimary),
        bodyMedium: colored(FsText.body, c.textPrimary),
        bodySmall: colored(FsText.small, c.textSecondary),
        labelLarge: colored(FsText.bodyStrong, c.textPrimary),
        labelMedium: colored(FsText.section, c.textSecondary),
        labelSmall: colored(FsText.caption, c.textSecondary),
      ),
      iconTheme: IconThemeData(color: c.textSecondary, size: 16),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      extensions: [c, shadows],
    );
  }
}
