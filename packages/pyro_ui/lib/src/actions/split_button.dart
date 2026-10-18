import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../floating/context_menu.dart';
import '../floating/tooltip.dart';
import '../foundation/debug_states.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../icons.dart';
import '../metrics.dart';
import '../typography.dart';
import 'button.dart';

/// A main action plus a caret that opens related variants: Play, Export.
///
/// - **Main part:** a 24px button (12px padding, `body-strong` label, an
///   optional 14px icon); Enter or Space runs [onPressed]; keyboard focus
///   draws the ring around it.
/// - **Caret:** 20px wide, its own hover and pressed states; a click
///   toggles the menu. While the menu is open the caret keeps the pressed
///   fill (`accent-pressed` for primary).
/// - **Divider:** 1px `accent-pressed` (primary) or `border-control`
///   (secondary); `border-subtle` while disabled.
/// - **Menu:** [menuItems] in an `PrMenuPanel` below the button, left
///   aligned; ↓ or Alt+↓ on the focused button opens it. Mark the current
///   default with `PrMenuItem.checked`. "The main action repeats the last
///   choice" is the app's rule: it passes the matching [label] and
///   [onPressed].
///
/// Variants: [PrButtonVariant.primary] or [PrButtonVariant.secondary], in
/// the button colours. Null [onPressed] disables both parts (the tooltip
/// still shows, with [disabledReason]).
///
/// Parts for `PrDebugStates`: unparted states reach the main part only;
/// `caret` (exact) forces the caret's states; `open` (exact) draws the
/// open caret.
class PrSplitButton<T> extends StatelessWidget {
  /// Creates the split button.
  const PrSplitButton({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    required this.onPressed,
    required this.menuItems,
    this.onSelected,
    this.variant = PrButtonVariant.primary,
    this.tooltip,
    this.shortcut,
    this.menuTooltip,
    this.disabledReason,
    this.menuWidth = PrMenuPanel.defaultWidth,
    this.focusNode,
    this.autofocus = false,
  }) : assert(
         variant == PrButtonVariant.primary ||
             variant == PrButtonVariant.secondary,
         'A split button is primary or secondary',
       );

  /// The main action's verb ("Play", "Export").
  final String label;

  /// A 14px icon before the label.
  final IconData? icon;

  /// A custom glyph in place of [icon] (`PrPlayGlyph(size: 14)`); drawn in
  /// the label colour through the [IconTheme].
  final Widget? leading;

  /// The main action. Null disables the whole button.
  final VoidCallback? onPressed;

  /// The caret menu's lines.
  final List<PrMenuEntry<T>> menuItems;

  /// Called with the chosen item's value.
  final ValueChanged<T>? onSelected;

  /// Primary or secondary.
  final PrButtonVariant variant;

  /// The main part's tooltip; with a [shortcut] it shows the key cap.
  final String? tooltip;

  /// Shown in the main part's tooltip. The app binds the shortcut itself.
  final SingleActivator? shortcut;

  /// The caret's tooltip and semantics label ("Play options").
  final String? menuTooltip;

  /// Why the button is disabled; the tooltip's second line while it is.
  final String? disabledReason;

  /// The menu's width.
  final double menuWidth;

  /// The main part's focus node (the button's one Tab stop).
  final FocusNode? focusNode;

  /// Take focus when first built.
  final bool autofocus;

  /// The caret's width, divider included.
  static const double caretWidth = 20;

  static const _mainRadius = BorderRadius.horizontal(left: Radius.circular(4));
  static const _caretRadius = BorderRadius.horizontal(
    right: Radius.circular(4),
  );

  @override
  Widget build(BuildContext context) {
    return PrMenuButton<T>(
      entries: menuItems,
      onSelected: onSelected,
      width: menuWidth,
      builder: (context, controller) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        final open =
            controller.isOpen ||
            PrDebugStates.of(
              context,
              part: 'open',
              exact: true,
            ).contains(WidgetState.selected);
        return _build(context, toggle, controller.open, open);
      },
    );
  }

  Widget _build(
    BuildContext context,
    VoidCallback toggle,
    VoidCallback openMenu,
    bool open,
  ) {
    final c = PrColors.of(context);
    final enabled = onPressed != null;
    final primary = variant == PrButtonVariant.primary;
    final reason = enabled ? null : disabledReason;

    Widget main = PrInteractive(
      onPressed: onPressed,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticsLabel: label,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): _OpenMenuIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown, alt: true):
            _OpenMenuIntent(),
      },
      actions: {
        _OpenMenuIntent: CallbackAction<_OpenMenuIntent>(
          onInvoke: (_) {
            if (enabled) openMenu();
            return null;
          },
        ),
      },
      builder: (context, states) {
        final (fill, edge, ink) = _colors(c, states, open: false);
        return PrFocusRing.outside(
          visible: states.contains(WidgetState.focused),
          borderRadius: _mainRadius,
          child: Container(
            height: PrSizes.control,
            padding: const EdgeInsets.symmetric(horizontal: PrSpacing.s3),
            decoration: BoxDecoration(
              color: fill,
              border: Border(
                left: BorderSide(color: edge),
                top: BorderSide(color: edge),
                bottom: BorderSide(color: edge),
              ),
              borderRadius: _mainRadius,
            ),
            // The label comes from semanticsLabel, not twice.
            child: IconTheme.merge(
              data: IconThemeData(color: ink, size: PrSizes.iconSm),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading != null || icon != null) ...[
                      leading ?? Icon(icon),
                      const SizedBox(width: PrSpacing.s1),
                    ],
                    Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: PrText.bodyStrong.copyWith(color: ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    final mainTip = tooltip ?? (reason != null ? label : null);
    if (mainTip != null) {
      main = PrTooltip(
        message: mainTip,
        shortcut: shortcut,
        details: [?reason],
        child: main,
      );
    }

    Widget caret = PrDebugStates(
      states: PrDebugStates.of(context, part: 'caret', exact: true),
      child: PrInteractive(
        onPressed: enabled ? toggle : null,
        focusable: false,
        semanticsLabel: menuTooltip,
        builder: (context, states) {
          final (fill, edge, ink) = _colors(c, states, open: open);
          return Container(
            width: caretWidth - 1,
            height: PrSizes.control,
            decoration: BoxDecoration(
              color: fill,
              border: Border(
                top: BorderSide(color: edge),
                right: BorderSide(color: edge),
                bottom: BorderSide(color: edge),
              ),
              borderRadius: _caretRadius,
            ),
            child: Icon(PrIcons.chevronDown, size: PrSizes.iconSm, color: ink),
          );
        },
      ),
    );
    if (menuTooltip != null) {
      caret = PrTooltip(
        message: menuTooltip!,
        details: [?reason],
        child: caret,
      );
    }

    final divider = !enabled
        ? c.borderSubtle
        : primary
        ? c.accentPressed
        : c.borderControl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        main,
        Container(width: 1, height: PrSizes.control, color: divider),
        caret,
      ],
    );
  }

  /// Fill, edge and ink of one part.
  (Color, Color, Color) _colors(
    PrColors c,
    Set<WidgetState> states, {
    required bool open,
  }) {
    if (states.contains(WidgetState.disabled)) {
      return (c.surfaceRaised, c.borderSubtle, c.textDisabled);
    }
    final pressed = open || states.contains(WidgetState.pressed);
    final hovered = pressed || states.contains(WidgetState.hovered);
    if (variant == PrButtonVariant.primary) {
      return (
        pressed
            ? c.accentPressed
            : hovered
            ? c.accentHover
            : c.accent,
        Colors.transparent,
        c.textOnAccent,
      );
    }
    return (
      pressed
          ? c.surfacePressed
          : hovered
          ? c.surfaceHover
          : c.surfaceRaised,
      hovered && !open ? c.borderStrong : c.borderControl,
      c.textPrimary,
    );
  }
}

class _OpenMenuIntent extends Intent {
  const _OpenMenuIntent();
}
