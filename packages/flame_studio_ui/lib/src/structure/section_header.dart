import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../actions/icon_button.dart';
import '../colors.dart';
import '../floating/context_menu.dart';
import '../foundation/debug_states.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../icons.dart';
import '../inputs/checkbox.dart';
import '../metrics.dart';
import '../typography.dart';

/// The 24px collapsible header of one component's properties in the
/// Inspector: chevron, the component checkbox, icon, title, subtitle,
/// actions and the ⋯ menu.
///
/// - **Look:** `surface-raised`, a 1px `bg-app` top edge and a 1px
///   `border-subtle` bottom edge; the title in `section`, the [subtitle]
///   after an em dash in `small` `text-secondary`.
/// - **States:** hover `surface-hover`, pressed `surface-pressed`, keyboard
///   focus as an inset ring; expanded (chevron down) or collapsed (chevron
///   right).
/// - **Disabled component** ([enabled] false): chevron, icon and title in
///   `text-disabled` and the checkbox unchecked. Only the look changes: the
///   header and the properties below stay editable.
/// - **[error]:** the icon becomes the alert circle in `error`; say why in
///   [subtitle] ("compile error").
///
/// A click anywhere outside the checkbox and buttons, or Space or Enter
/// while focused, calls [onExpandedChanged]. With Alt held it calls
/// [onToggleAll] instead (when set): the app expands or collapses every
/// section. Animate the properties with `FsCollapsible`.
///
/// States forced by an `FsDebugStates` without a part reach the header only,
/// not its checkbox and buttons.
class FsSectionHeader extends StatefulWidget {
  /// Creates a section header.
  const FsSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    required this.expanded,
    required this.onExpandedChanged,
    this.onToggleAll,
    this.enabled,
    this.onEnabledChanged,
    this.enabledLabel,
    this.actions = const [],
    this.menu = const [],
    this.menuTooltip,
    this.error = false,
    this.focusNode,
  });

  /// The component's type name.
  final String title;

  /// Drawn before the title at 14px; replaced by the alert circle while
  /// [error].
  final IconData? icon;

  /// After the title, following an em dash: a file name, "off", what is
  /// wrong.
  final String? subtitle;

  /// Chevron down and the body shown.
  final bool expanded;

  /// Called with the new expanded state.
  final ValueChanged<bool> onExpandedChanged;

  /// Alt-click (or Alt+Space/Enter): toggle every section. Null makes
  /// Alt-click a plain click.
  final VoidCallback? onToggleAll;

  /// The component checkbox; null shows none. False draws the header
  /// disabled.
  final bool? enabled;

  /// Called by the checkbox with the new value; null disables the checkbox.
  final ValueChanged<bool>? onEnabledChanged;

  /// The checkbox's semantics label ("Enabled").
  final String? enabledLabel;

  /// Extra buttons before the ⋯ menu (Help): `FsIconButton`s,
  /// `FsIconButtonSize.small`.
  final List<Widget> actions;

  /// The ⋯ menu's lines (Reset, Copy values, Remove); no ⋯ button when
  /// empty.
  final List<FsMenuEntry<void>> menu;

  /// The ⋯ button's tooltip and semantics label.
  final String? menuTooltip;

  /// The component is broken: alert-circle icon in `error`.
  final bool error;

  /// The header's focus node.
  final FocusNode? focusNode;

  @override
  State<FsSectionHeader> createState() => _FsSectionHeaderState();
}

class _FsSectionHeaderState extends State<FsSectionHeader> {
  // Set when a press starts on the checkbox or a button, so the header
  // doesn't also toggle.
  bool _swallowPress = false;

  void _onPressed() {
    if (_swallowPress) return;
    final toggleAll = widget.onToggleAll;
    if (toggleAll != null && HardwareKeyboard.instance.isAltPressed) {
      toggleAll();
    } else {
      widget.onExpandedChanged(!widget.expanded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = FsInteractive(
      onPressed: _onPressed,
      focusNode: widget.focusNode,
      semanticsLabel: [widget.title, ?widget.subtitle].join(', '),
      builder: _build,
    );
    // Resets the swallow flag after the inner listeners have seen the up.
    return Semantics(
      expanded: widget.expanded,
      child: Listener(
        onPointerUp: (_) => _swallowPress = false,
        onPointerCancel: (_) => _swallowPress = false,
        child: header,
      ),
    );
  }

  Widget _controls(Widget child) => Listener(
    onPointerDown: (_) => _swallowPress = true,
    // Forced header states stop here.
    child: FsDebugStates(states: const {}, child: child),
  );

  Widget _build(BuildContext context, Set<WidgetState> states) {
    final c = FsColors.of(context);
    final off = widget.enabled == false;
    final fill = FsStateColor.resolve(states, {
      WidgetState.pressed: c.surfacePressed,
      WidgetState.hovered: c.surfaceHover,
    }, fallback: c.surfaceRaised);
    final titleInk = off ? c.textDisabled : c.textPrimary;
    final chevronInk = off ? c.textDisabled : c.textSecondary;
    final icon = widget.error ? FsIcons.alertCircle : widget.icon;
    final iconInk = widget.error ? c.error : titleInk;
    final enabled = widget.enabled;

    return FsFocusRing.inset(
      visible: states.contains(WidgetState.focused),
      borderRadius: BorderRadius.zero,
      child: Container(
        height: FsSizes.control,
        padding: const EdgeInsets.symmetric(horizontal: FsSpacing.s1),
        decoration: BoxDecoration(
          color: fill,
          border: Border(
            top: BorderSide(color: c.bgApp),
            bottom: BorderSide(color: c.borderSubtle),
          ),
        ),
        child: Row(
          children: [
            Icon(
              widget.expanded ? FsIcons.chevronDown : FsIcons.chevronRight,
              size: FsSizes.iconSm,
              color: chevronInk,
            ),
            if (enabled != null) ...[
              const SizedBox(width: FsSpacing.s1),
              _controls(
                FsCheckbox(
                  value: enabled,
                  onChanged: widget.onEnabledChanged,
                  semanticsLabel: widget.enabledLabel,
                ),
              ),
            ],
            if (icon != null) ...[
              const SizedBox(width: FsSpacing.s1),
              Icon(icon, size: FsSizes.iconSm, color: iconInk),
            ],
            const SizedBox(width: FsSpacing.s1),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: widget.title,
                  style: FsText.section.copyWith(color: titleInk),
                  children: [
                    if (widget.subtitle != null)
                      TextSpan(
                        text: ' — ${widget.subtitle}',
                        style: FsText.small.copyWith(color: c.textSecondary),
                      ),
                  ],
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final action in widget.actions) ...[
              const SizedBox(width: FsSpacing.s1),
              _controls(action),
            ],
            if (widget.menu.isNotEmpty) ...[
              const SizedBox(width: FsSpacing.s1),
              _controls(
                FsMenuButton<void>(
                  entries: widget.menu,
                  builder: (context, controller) => FsIconButton(
                    icon: FsIcons.more,
                    iconSize: FsSizes.iconSm,
                    size: FsIconButtonSize.small,
                    tooltip: widget.menuTooltip ?? '',
                    selected: controller.isOpen,
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows [child] while [expanded] and animates its height open and closed
/// in 150ms (`FsMotion.medium`; ease-out opening, ease-in closing): the
/// properties under an `FsSectionHeader`.
///
/// The child stays built while collapsed, so its state survives; it takes
/// no space, no pointer input and no focus then.
class FsCollapsible extends StatefulWidget {
  /// Creates the collapsible body.
  const FsCollapsible({
    super.key,
    required this.expanded,
    this.duration = FsMotion.medium,
    required this.child,
  });

  /// Open or closed.
  final bool expanded;

  /// How long opening or closing takes.
  final Duration duration;

  /// The body.
  final Widget child;

  @override
  State<FsCollapsible> createState() => _FsCollapsibleState();
}

class _FsCollapsibleState extends State<FsCollapsible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.expanded ? 1 : 0,
  )..addStatusListener((_) => setState(() {}));

  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: FsMotion.enter,
    reverseCurve: FsMotion.exit,
  );

  @override
  void didUpdateWidget(FsCollapsible oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.expanded != oldWidget.expanded) {
      unawaited(
        widget.expanded ? _controller.forward() : _controller.reverse(),
      );
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final closed = _controller.isDismissed;
    return ClipRect(
      child: SizeTransition(
        sizeFactor: _curve,
        alignment: AlignmentDirectional.topStart,
        child: ExcludeFocus(
          excluding: !widget.expanded,
          child: Visibility(
            visible: !closed,
            maintainState: true,
            maintainAnimation: true,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
