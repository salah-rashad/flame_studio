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
///   `FsIconButton`s, `FsIconButtonSize.small`) and the ⋯ [overflow] menu
///   at the end.
/// - **Body:** `surface-panel`. Panels are separated by 1px of `bg-app`,
///   which is the layout's job, never a shadow.
/// - **Focused** (keyboard focus anywhere inside): title and icon
///   `text-primary` and a 2px `accent-text` line on the header's top edge.
///   **Unfocused:** `text-secondary`, no line.
///
/// The panel inserts an `FsPanelFocus`, so rows inside choose
/// `surface-selected` or `surface-selected-inactive`. A pointer down
/// anywhere in the panel gives it focus (back to its last focused widget,
/// or the panel itself). Panel cycling (⌃Tab, ⌘1–⌘4) is the app's: it
/// keeps each panel's [focusNode] and requests focus on it.
///
/// [headerProgress] (an `FsProgressBar`) is drawn over the top of the body,
/// right under the header, so showing it never moves the body.
///
/// Parts for `FsDebugStates`: `panel` ([WidgetState.focused] draws the
/// panel focused, also for the rows inside) and `overflow` (the ⋯ button's
/// states, exact).
class FsPanel extends StatefulWidget {
  /// Creates a panel.
  const FsPanel({
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

  /// Header actions, at most three `FsIconButton`s
  /// (`FsIconButtonSize.small`); the rest go in [overflow].
  final List<Widget> actions;

  /// The ⋯ menu's lines; no ⋯ button when empty.
  final List<FsMenuEntry<void>> overflow;

  /// The ⋯ button's tooltip and semantics label ("More").
  final String? overflowTooltip;

  /// The content, below the header.
  final Widget body;

  /// A progress bar under the header (`FsProgressBar`); null for none.
  final Widget? headerProgress;

  /// The panel's focus scope, for the app's panel cycling; one is created
  /// when null. Create it with `FsPanelFocus.createNode` so Tab can leave
  /// the panel and skips it when empty.
  final FocusScopeNode? focusNode;

  /// The header's height.
  static const double headerHeight = FsSizes.tab;

  @override
  State<FsPanel> createState() => _FsPanelState();
}

class _FsPanelState extends State<FsPanel> {
  FocusScopeNode? _ownNode;

  FocusScopeNode get _node =>
      widget.focusNode ??
      (_ownNode ??= FsPanelFocus.createNode(debugLabel: 'FsPanel'));

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
    final c = FsColors.of(context);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: FsPanelFocus(
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

  final FsPanel panel;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final focused = FsPanelFocus.of(context);
    final ink = focused ? c.textPrimary : c.textSecondary;
    final overflowStates = FsDebugStates.of(
      context,
      part: 'overflow',
      exact: true,
    );
    return Container(
      height: FsPanel.headerHeight,
      padding: const EdgeInsetsDirectional.only(
        start: FsSpacing.s2,
        end: FsSpacing.s1,
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
            Icon(panel.icon, size: FsSizes.icon, color: ink),
            const SizedBox(width: FsSpacing.s1),
          ],
          Expanded(
            child: Text(
              panel.title,
              style: FsText.heading.copyWith(color: ink),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final action in panel.actions) ...[
            const SizedBox(width: FsSpacing.s1),
            action,
          ],
          if (panel.overflow.isNotEmpty) ...[
            const SizedBox(width: FsSpacing.s1),
            FsMenuButton<void>(
              entries: panel.overflow,
              builder: (context, controller) => FsDebugStates(
                states: overflowStates,
                child: FsIconButton(
                  icon: FsIcons.more,
                  iconSize: FsSizes.iconSm,
                  size: FsIconButtonSize.small,
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
