import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Spacing on the 4px grid (`spacing.tokens` in `design/tokens.json`).
///
/// Every padding, gap and size is a multiple of 4, except 1px borders and
/// 2px focus rings.
abstract final class PrSpacing {
  /// 4: icon-to-label gap, gap between toolbar buttons, padding inside menus.
  static const double s1 = 4;

  /// 8: horizontal padding of rows, fields and ghost buttons; gap between
  /// fields in a property editor.
  static const double s2 = 8;

  /// 12: horizontal padding of primary/secondary buttons; padding of banners
  /// and toasts.
  static const double s3 = 12;

  /// 16: tree indent per depth level; padding of dialog bodies.
  static const double s4 = 16;

  /// 24: padding around empty states and dialog edges.
  static const double s6 = 24;

  /// 32: gap between the empty-state icon and the rest; large layout gaps.
  static const double s8 = 32;
}

/// Corner radii (`radius.tokens` in `design/tokens.json`).
abstract final class PrRadii {
  /// 2: checkboxes, badges, colour swatches, thumbnails in slots.
  static const BorderRadius xs = BorderRadius.all(Radius.circular(2));

  /// 4: buttons, fields, segmented controls, tree-row selection, banners,
  /// tooltips.
  static const BorderRadius sm = BorderRadius.all(Radius.circular(4));

  /// 6: context menus, dropdown lists, toasts.
  static const BorderRadius md = BorderRadius.all(Radius.circular(6));

  /// 8: modal dialogs, empty-state icon tile.
  static const BorderRadius lg = BorderRadius.all(Radius.circular(8));

  /// Fully round: status dots, pills, switch tracks and knobs.
  static const BorderRadius full = BorderRadius.all(Radius.circular(9999));
}

/// Fixed heights of the dense UI (`size.tokens` in `design/tokens.json`).
///
/// Rows never grow with their content.
abstract final class PrSizes {
  /// 22: scene tree and asset list rows.
  static const double rowTree = 22;

  /// 24: inspector property rows (the field inside is [controlSm]).
  static const double rowProperty = 24;

  /// 20: fields, slots and icon buttons inside property rows and panel
  /// headers.
  static const double controlSm = 20;

  /// 24: buttons, text fields, dropdowns, segmented controls, menu items,
  /// section headers.
  static const double control = 24;

  /// 32: main toolbar and viewport toolbar.
  static const double toolbar = 32;

  /// 28: panel header and document tab strip.
  static const double tab = 28;

  /// 38: window title bar (the macOS traffic-light zone).
  static const double titlebar = 38;

  /// 22: status bar at the bottom of the window.
  static const double statusbar = 22;

  /// 16: icons in toolbars, panel headers, buttons, menus.
  static const double icon = 16;

  /// 14: icons in tree rows, slots, badges, property rows.
  static const double iconSm = 14;
}

/// Durations and curves (the design system README's Motion section).
///
/// Ease-out on enter, ease-in on exit; no bounce, no overshoot.
abstract final class PrMotion {
  /// Hover and press fills.
  static const Duration fast = Duration(milliseconds: 100);

  /// Expand/collapse and menus opening.
  static const Duration medium = Duration(milliseconds: 150);

  /// Toasts and dialogs.
  static const Duration slow = Duration(milliseconds: 200);

  /// How long work runs before a progress indicator appears.
  static const Duration progressDelay = Duration(milliseconds: 300);

  /// Curve for things appearing.
  static const Curve enter = Curves.easeOut;

  /// Curve for things leaving.
  static const Curve exit = Curves.easeIn;
}
