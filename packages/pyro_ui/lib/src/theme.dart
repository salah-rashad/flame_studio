import 'package:flutter/material.dart';

import 'colors.dart';
import 'shadows.dart';
import 'typography.dart';

/// Builds Pyro's [ThemeData] from the design tokens.
///
/// Pyro still runs inside a `MaterialApp` (text editing, scrolling,
/// overlays), so Material widgets that slip through look roughly right. The
/// Pyro's own widgets read [PrColors] and [PrShadows] from the theme, not
/// Material's colour scheme.
abstract final class PrTheme {
  /// The dark theme, the only one so far.
  static ThemeData dark() =>
      _build(Brightness.dark, PrColors.dark, PrShadows.dark);

  static ThemeData _build(
    Brightness brightness,
    PrColors c,
    PrShadows shadows,
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
      // The package-qualified name (`packages/pyro_ui/Inter`).
      fontFamily: PrText.body.fontFamily,
      textTheme: TextTheme(
        titleMedium: colored(PrText.title, c.textPrimary),
        titleSmall: colored(PrText.heading, c.textPrimary),
        bodyLarge: colored(PrText.bodyStrong, c.textPrimary),
        bodyMedium: colored(PrText.body, c.textPrimary),
        bodySmall: colored(PrText.small, c.textSecondary),
        labelLarge: colored(PrText.bodyStrong, c.textPrimary),
        labelMedium: colored(PrText.section, c.textSecondary),
        labelSmall: colored(PrText.caption, c.textSecondary),
      ),
      iconTheme: IconThemeData(color: c.textSecondary, size: 16),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      extensions: [c, shadows],
    );
  }
}
