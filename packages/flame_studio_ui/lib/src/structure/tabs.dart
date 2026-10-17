import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../floating/tooltip.dart';
import '../foundation/debug_states.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../foundation/panel_focus.dart';
import '../icons.dart';
import '../metrics.dart';
import '../typography.dart';

/// Where an [FsTabs] strip sits, which decides whether tabs can close.
enum FsTabsStyle {
  /// Document tabs above the viewport: closable tabs show × on hover and
  /// on the selected tab, dirty tabs a dot.
  document,

  /// Panel tabs in a dock (Console, Assets): never closable, so no ×,
  /// whatever [FsTab.closable] says (a dirty dot still shows).
  dock,
}

/// One tab of an [FsTabs] strip.
@immutable
class FsTab<T> {
  /// Creates a tab.
  const FsTab({
    required this.value,
    required this.label,
    this.icon,
    this.dirty = false,
    this.closable = true,
    this.badges = const [],
    this.error = false,
    this.enabled = true,
  });

  /// Passed to `onSelect` and `onClose`.
  final T value;

  /// The tab's name ("level_1.scene", "Console").
  final String label;

  /// Drawn before the label at 14px.
  final IconData? icon;

  /// Unsaved changes: an 8px dot that becomes × on hover.
  final bool dirty;

  /// Shows × (on hover and while selected) in document strips.
  final bool closable;

  /// Count badges after the label (`FsBadge`s with their icons).
  final List<Widget> badges;

  /// Label and icon in `error`.
  final bool error;

  /// False draws the tab in `text-disabled` and ignores clicks.
  final bool enabled;
}

/// A 28px strip of tabs: document tabs above the viewport, panel tabs in
/// docks.
///
/// - **Strip:** `bg-app` with 1px gaps between tabs; scrolls sideways when
///   the tabs don't fit.
/// - **Tab:** `surface-raised`, label in `body` `text-secondary`, 12px
///   left padding, 14px icon. Hover `surface-hover` and `text-primary`;
///   pressed `surface-pressed`; keyboard focus as an inset ring; disabled
///   `text-disabled`; [FsTab.error] in `error`.
/// - **Selected:** `surface-panel` (it merges with the panel below; hover
///   and press don't change it), `text-primary` in `bodyStrong`, and a 2px
///   top edge: `accent-text`
///   while the panel has focus (`FsPanelFocus`), `text-secondary` when not.
/// - **Closing:** a closable tab shows × on hover and while selected; a
///   dirty tab shows a dot instead, which becomes × on hover. ×, a
///   middle click and ⌘W (Ctrl+W elsewhere; while a tab has focus) call
///   [onClose]. ⌃Tab / ⌃⇧Tab cycling is the app's shortcut: it calls
///   [onSelect].
///
/// Parts for `FsDebugStates`: a tab's label forces that tab's states;
/// `close` (exact) the × buttons' states. Unparted forced states reach the
/// tabs only, not ×.
class FsTabs<T> extends StatelessWidget {
  /// Creates a tab strip.
  const FsTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
    this.onClose,
    this.closeTooltip,
    this.style = FsTabsStyle.document,
  });

  /// The tabs, in order.
  final List<FsTab<T>> tabs;

  /// The selected tab's value.
  final T selected;

  /// A tab was clicked or activated with Enter or Space.
  final ValueChanged<T> onSelect;

  /// A tab's × was clicked, it was middle-clicked, or ⌘W was pressed on
  /// the selected tab; null hides × everywhere.
  final ValueChanged<T>? onClose;

  /// The × button's tooltip and semantics label ("Close").
  final String? closeTooltip;

  /// Document or dock.
  final FsTabsStyle style;

  bool _canClose(FsTab<T> tab) =>
      style == FsTabsStyle.document && tab.closable && onClose != null;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final onClose = this.onClose;
    final current = tabs.where((t) => t.value == selected).firstOrNull;
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyW, meta: mac, control: !mac): () {
          if (current != null && _canClose(current)) onClose!(current.value);
        },
      },
      child: Container(
        height: FsSizes.tab,
        decoration: BoxDecoration(
          color: c.bgApp,
          border: Border(bottom: BorderSide(color: c.bgApp)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final tab in tabs)
                _Tab<T>(
                  key: ValueKey(tab.value),
                  tab: tab,
                  selected: tab.value == selected,
                  onSelect: onSelect,
                  onClose: _canClose(tab) ? onClose : null,
                  closeTooltip: closeTooltip,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab<T> extends StatefulWidget {
  const _Tab({
    super.key,
    required this.tab,
    required this.selected,
    required this.onSelect,
    required this.onClose,
    required this.closeTooltip,
  });

  final FsTab<T> tab;
  final bool selected;
  final ValueChanged<T> onSelect;
  final ValueChanged<T>? onClose;
  final String? closeTooltip;

  @override
  State<_Tab<T>> createState() => _TabState<T>();
}

class _TabState<T> extends State<_Tab<T>> {
  // Set when a press starts on ×, so the tab isn't also selected.
  bool _swallowPress = false;
  int? _middlePointer;

  void _onPressed() {
    if (_swallowPress) return;
    widget.onSelect(widget.tab.value);
  }

  void _close() => widget.onClose?.call(widget.tab.value);

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kMiddleMouseButton) _middlePointer = event.pointer;
      },
      onPointerUp: (event) {
        _swallowPress = false;
        if (event.pointer != _middlePointer) return;
        _middlePointer = null;
        final box = context.findRenderObject()! as RenderBox;
        if ((Offset.zero & box.size).contains(
          box.globalToLocal(event.position),
        )) {
          _close();
        }
      },
      onPointerCancel: (_) {
        _swallowPress = false;
        _middlePointer = null;
      },
      child: FsInteractive(
        onPressed: tab.enabled ? _onPressed : null,
        selected: widget.selected,
        error: tab.error,
        semanticsLabel: tab.label,
        builder: _build,
      ),
    );
  }

  Widget _build(BuildContext context, Set<WidgetState> own) {
    final c = FsColors.of(context);
    final tab = widget.tab;
    final states = {
      ...own,
      ...FsDebugStates.of(context, part: tab.label, exact: true),
    };
    final selected = widget.selected;
    final disabled = states.contains(WidgetState.disabled);
    final hovered = states.contains(WidgetState.hovered);
    final pressed = states.contains(WidgetState.pressed);

    final Color fill;
    if (disabled) {
      fill = c.surfaceRaised;
    } else if (selected) {
      fill = c.surfacePanel;
    } else if (pressed) {
      fill = c.surfacePressed;
    } else if (hovered) {
      fill = c.surfaceHover;
    } else {
      fill = c.surfaceRaised;
    }
    final Color ink;
    if (disabled) {
      ink = c.textDisabled;
    } else if (tab.error) {
      ink = c.error;
    } else if (selected || hovered) {
      ink = c.textPrimary;
    } else {
      ink = c.textSecondary;
    }
    final edge = FsPanelFocus.of(context) ? c.accentText : c.textSecondary;

    final canClose = widget.onClose != null && !disabled;
    final dot = tab.dirty;
    final hasSlot = canClose || dot;
    final showClose = canClose && (hovered || (selected && !dot));
    final showDot = dot && !showClose;

    return FsFocusRing.inset(
      visible: states.contains(WidgetState.focused),
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: EdgeInsetsDirectional.only(
          start: FsSpacing.s3,
          end: hasSlot ? FsSpacing.s1 : FsSpacing.s3,
        ),
        decoration: BoxDecoration(
          color: fill,
          border: BorderDirectional(end: BorderSide(color: c.bgApp)),
        ),
        // Always a decoration, so selecting never rebuilds the subtree.
        foregroundDecoration: BoxDecoration(
          border: Border(
            top: selected ? BorderSide(color: edge, width: 2) : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tab.icon != null) ...[
              Icon(tab.icon, size: FsSizes.iconSm, color: ink),
              const SizedBox(width: FsSpacing.s1),
            ],
            Text(
              tab.label,
              style: (selected ? FsText.bodyStrong : FsText.body).copyWith(
                color: ink,
              ),
              maxLines: 1,
              softWrap: false,
            ),
            for (final (i, badge) in tab.badges.indexed) ...[
              SizedBox(width: i == 0 ? FsSpacing.s1 + 2 : FsSpacing.s1),
              badge,
            ],
            if (hasSlot) ...[
              const SizedBox(width: FsSpacing.s1),
              SizedBox.square(
                dimension: FsSizes.icon,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Visibility.maintain(
                      visible: showDot,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.textSecondary,
                          borderRadius: FsRadii.full,
                        ),
                      ),
                    ),
                    Visibility.maintain(
                      visible: showClose,
                      child: Listener(
                        onPointerDown: (_) => _swallowPress = true,
                        child: FsDebugStates(
                          states: FsDebugStates.of(
                            context,
                            part: 'close',
                            exact: true,
                          ),
                          child: _CloseButton(
                            onPressed: canClose ? _close : null,
                            tooltip: widget.closeTooltip,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The 16px × on a tab: `text-secondary`; on hover `surface-pressed` and
/// `text-primary`.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed, required this.tooltip});

  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final button = FsInteractive(
      onPressed: onPressed,
      focusable: false,
      semanticsLabel: tooltip,
      builder: (context, states) {
        final hot =
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed);
        return Container(
          width: FsSizes.icon,
          height: FsSizes.icon,
          decoration: BoxDecoration(
            color: hot ? c.surfacePressed : Colors.transparent,
            borderRadius: FsRadii.xs,
          ),
          child: Icon(
            FsIcons.x,
            size: 12,
            color: hot ? c.textPrimary : c.textSecondary,
          ),
        );
      },
    );
    final tip = tooltip;
    return tip == null ? button : FsTooltip(message: tip, child: button);
  }
}
