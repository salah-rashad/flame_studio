import 'package:flutter/material.dart';

import '../actions/icon_button.dart';
import '../colors.dart';
import '../floating/context_menu.dart';
import '../foundation/debug_states.dart';
import '../foundation/panel_focus.dart';
import '../icons.dart';
import '../metrics.dart';
import '../typography.dart';

/// A docked container (Scene, Inspector, Console, Assets): a 28px header
/// with the title and up to three actions, then the body.
///
/// - **Header:** `surface-raised` with a 1px `bg-app` bottom edge; a 16px
///   [icon] and the [title] in `heading`; [actions] (20px
///   `PrIconButton`s, `PrIconButtonSize.small`) and the ⋯ [overflow] menu
///   at the end.
/// - **Body:** `surface-panel`. Panels are separated by 1px of `bg-app`,
///   which is the layout's job, never a shadow.
/// - **Focused** (keyboard focus anywhere inside): title and icon
///   `text-primary` and a 2px `accent-text` line on the header's top edge.
///   **Unfocused:** `text-secondary`, no line.
///
/// The panel inserts a `PrPanelFocus`, so rows inside choose
/// `surface-selected` or `surface-selected-inactive`. A pointer down
/// anywhere in the panel gives it focus (back to its last focused widget,
/// or the panel itself). Panel cycling (⌃Tab, ⌘1–⌘4) is the app's: it
/// keeps each panel's [focusNode] and requests focus on it.
///
/// [headerProgress] (a `PrProgressBar`) is drawn over the top of the body,
/// right under the header, so showing it never moves the body.
///
/// Parts for `PrDebugStates`: `panel` ([WidgetState.focused] draws the
/// panel focused, also for the rows inside) and `overflow` (the ⋯ button's
/// states, exact).
class PrPanel extends StatefulWidget {
  /// Creates a panel.
  const PrPanel({
    super.key,
    required this.title,
    this.icon,
    this.actions = const [],
    this.overflow = const [],
    this.overflowTooltip,
    required this.body,
    this.headerProgress,
    this.focusNode,
  }) : assert(actions.length <= 3, 'At most 3 header actions; use overflow');

  /// The panel's name.
  final String title;

  /// Drawn before the title at 16px.
  final IconData? icon;

  /// Header actions, at most three `PrIconButton`s
  /// (`PrIconButtonSize.small`); the rest go in [overflow].
  final List<Widget> actions;

  /// The ⋯ menu's lines; no ⋯ button when empty.
  final List<PrMenuEntry<void>> overflow;

  /// The ⋯ button's tooltip and semantics label ("More").
  final String? overflowTooltip;

  /// The content, below the header.
  final Widget body;

  /// A progress bar under the header (`PrProgressBar`); null for none.
  final Widget? headerProgress;

  /// The panel's focus scope, for the app's panel cycling; one is created
  /// when null. Create it with `PrPanelFocus.createNode` so Tab can leave
  /// the panel and skips it when empty.
  final FocusScopeNode? focusNode;

  /// The header's height.
  static const double headerHeight = PrSizes.tab;

  @override
  State<PrPanel> createState() => _FsPanelState();
}

class _FsPanelState extends State<PrPanel> {
  FocusScopeNode? _ownNode;

  FocusScopeNode get _node =>
      widget.focusNode ??
      (_ownNode ??= PrPanelFocus.createNode(debugLabel: 'PrPanel'));

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    final node = _node;
    if (!node.hasFocus) node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: PrPanelFocus(
        node: _node,
        child: ColoredBox(
          color: c.surfacePanel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(panel: widget),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.body,
                    if (widget.headerProgress != null)
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        child: widget.headerProgress!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.panel});

  final PrPanel panel;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final focused = PrPanelFocus.of(context);
    final ink = focused ? c.textPrimary : c.textSecondary;
    final overflowStates = PrDebugStates.of(
      context,
      part: 'overflow',
      exact: true,
    );
    return Container(
      height: PrPanel.headerHeight,
      padding: const EdgeInsetsDirectional.only(
        start: PrSpacing.s2,
        end: PrSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        border: Border(bottom: BorderSide(color: c.bgApp)),
      ),
      // Always a decoration, so focus changes never rebuild the header's
      // subtree (an action's hover or an open menu would be lost).
      foregroundDecoration: BoxDecoration(
        border: Border(
          top: focused
              ? BorderSide(color: c.accentText, width: 2)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          if (panel.icon != null) ...[
            Icon(panel.icon, size: PrSizes.icon, color: ink),
            const SizedBox(width: PrSpacing.s1),
          ],
          Expanded(
            child: Text(
              panel.title,
              style: PrText.heading.copyWith(color: ink),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final action in panel.actions) ...[
            const SizedBox(width: PrSpacing.s1),
            action,
          ],
          if (panel.overflow.isNotEmpty) ...[
            const SizedBox(width: PrSpacing.s1),
            PrMenuButton<void>(
              entries: panel.overflow,
              builder: (context, controller) => PrDebugStates(
                states: overflowStates,
                child: PrIconButton(
                  icon: PrIcons.more,
                  iconSize: PrSizes.iconSm,
                  size: PrIconButtonSize.small,
                  tooltip: panel.overflowTooltip ?? '',
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
    );
  }
}
