import 'package:flutter/painting.dart';

/// The text styles of the Flame Studio design system (`type` in
/// `design/tokens.json`).
///
/// Styles carry no colour: the widget picks a text colour from `FsColors`.
/// Hierarchy is weight, not size; nothing in the chrome is below 11px
/// ([caption]). Mono is set 1px smaller than UI text so the x-heights match.
abstract final class FsText {
  /// The UI typeface.
  ///
  /// Not bundled yet, so it falls back to the platform UI font unless Inter is
  /// installed.
  static const String uiFamily = 'Inter';

  /// The monospace typeface: numbers in fields, paths, the Console.
  ///
  /// Not bundled yet, so it falls back to the platform monospace font unless
  /// JetBrains Mono is installed.
  static const String monoFamily = 'JetBrains Mono';

  static const List<String> _uiFallback = ['.AppleSystemUIFont', 'Segoe UI'];
  static const List<String> _monoFallback = ['Menlo', 'Consolas', 'monospace'];

  /// Dialog titles and empty-state titles. The largest text in the chrome.
  static const TextStyle title = TextStyle(
    fontFamily: uiFamily,
    fontFamilyFallback: _uiFallback,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
  );

  /// Panel titles, toast titles.
  static const TextStyle heading = TextStyle(
    fontFamily: uiFamily,
    fontFamilyFallback: _uiFallback,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w600,
  );

  /// Default UI text: tree rows, property labels, menu items, field values
  /// that are words.
  static const TextStyle body = TextStyle(
    fontFamily: uiFamily,
    fontFamilyFallback: _uiFallback,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );

  /// Button labels, active tab, overridden property labels.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: uiFamily,
    fontFamilyFallback: _uiFallback,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );

  /// Collapsible section headers in the inspector.
  static const TextStyle section = TextStyle(
    fontFamily: uiFamily,
    fontFamilyFallback: _uiFallback,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  /// Secondary lines: tooltips, banner and toast messages, empty-state
  /// explanation, device chips, status bar.
  static const TextStyle small = TextStyle(
    fontFamily: uiFamily,
    fontFamilyFallback: _uiFallback,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Badges and pills. The minimum size.
  static const TextStyle caption = TextStyle(
    fontFamily: uiFamily,
    fontFamilyFallback: _uiFallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w500,
  );

  /// Numbers in property fields, hex colours, file names in asset slots.
  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: _monoFallback,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Console output and stack traces, file paths.
  static const TextStyle monoConsole = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: _monoFallback,
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
  );

  /// Counts inside badges, coordinates and fps in the status bar.
  static const TextStyle monoSmall = TextStyle(
    fontFamily: monoFamily,
    fontFamilyFallback: _monoFallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w500,
  );
}
