import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../foundation/anchored_overlay.dart';
import '../foundation/debug_states.dart';
import '../foundation/interactive.dart';
import '../foundation/shortcut_label.dart';
import '../icons.dart';
import '../metrics.dart';
import '../shadows.dart';
import '../typography.dart';

/// One line of a menu: an item, a separator or a section header.
sealed class PrMenuEntry<T> {
  const PrMenuEntry();
}

/// A command in a menu.
///
/// Choosing it closes the menu, then calls [onSelected] and passes [value]
/// to the menu's `onSelected`. An item with a [submenu] opens it instead
/// (after 150ms of hover, or →).
class PrMenuItem<T> extends PrMenuEntry<T> {
  /// Creates an item.
  const PrMenuItem({
    required this.label,
    this.icon,
    this.shortcut,
    this.enabled = true,
    this.checked = false,
    this.destructive = false,
    this.value,
    this.onSelected,
    this.submenu,
  });

  /// The command, sentence case.
  final String label;

  /// A 16px icon; the icon column is reserved either way.
  final IconData? icon;

  /// Shown on the right in the platform's notation. The app binds it.
  final SingleActivator? shortcut;

  /// False shows the item in `text-disabled` and skips it.
  final bool enabled;

  /// A check in the icon column (in place of [icon]).
  final bool checked;

  /// `error` label and icon, `error-border` highlight.
  final bool destructive;

  /// Passed to the menu's `onSelected`.
  final T? value;

  /// Called when the item is chosen.
  final VoidCallback? onSelected;

  /// Entries of a submenu.
  final List<PrMenuEntry<T>>? submenu;
}

/// A 1px `border-overlay` line across the menu.
class PrMenuSeparator<T> extends PrMenuEntry<T> {
  /// Creates a separator.
  const PrMenuSeparator();
}

/// A section header in `caption` `text-secondary`.
class PrMenuHeader<T> extends PrMenuEntry<T> {
  /// Creates a header.
  const PrMenuHeader(this.label);

  /// The header text.
  final String label;
}

/// The menu's box: `surface-overlay`, 1px `border-overlay`, `radius-md`,
/// `shadow-popover`, 4px padding, 248px wide by default; 24px items with a
/// reserved 16px icon column and right-aligned shortcuts.
///
/// - Hover and keyboard focus look the same: `accent` fill with
///   `text-on-accent`. Pressed `accent-pressed`. Disabled items show no
///   highlight. Destructive items are `error`, highlighted with
///   `error-border`. Checked items show a check in `accent-text`. The parent
///   of an open submenu keeps `surface-pressed`.
/// - ↑ ↓ move between items, → opens a submenu, ← and Esc close one level,
///   Enter and Space choose.
///
/// Usually shown by [PrContextMenuRegion], [PrMenuButton] or
/// [showFsContextMenu]; it can also be placed directly (an inline menu).
/// For the gallery, an `PrDebugStates` whose part is an item's label forces
/// that item's states ([WidgetState.selected] draws an open submenu).
class PrMenuPanel<T> extends StatefulWidget {
  /// Creates a panel.
  const PrMenuPanel({
    super.key,
    required this.entries,
    this.onSelected,
    this.width = defaultWidth,
    this.autofocus = false,
    this.focusFirst = false,
    this.onBack,
  });

  /// The lines.
  final List<PrMenuEntry<T>> entries;

  /// Called with the chosen item's value, when it has one.
  final ValueChanged<T>? onSelected;

  /// The width; at least [minWidth].
  final double width;

  /// Takes focus when shown, so the keyboard works at once.
  final bool autofocus;

  /// Focuses the first item when shown (a submenu opened with →).
  final bool focusFirst;

  /// ← or Esc in a submenu: close it and go back to the parent item.
  final VoidCallback? onBack;

  /// The design's menu width.
  static const double defaultWidth = 248;

  /// The narrowest a menu gets.
  static const double minWidth = 180;

  @override
  State<PrMenuPanel<T>> createState() => _FsMenuPanelState<T>();
}

class _FsMenuPanelState<T> extends State<PrMenuPanel<T>> {
  final _scope = FocusScopeNode(debugLabel: 'PrMenuPanel');
  final Map<int, FocusNode> _nodes = {};
  final Map<int, MenuController> _submenus = {};
  Timer? _hoverTimer;
  int? _keyboardOpened;

  List<int> get _focusable => [
    for (final (i, e) in widget.entries.indexed)
      if (e is PrMenuItem<T> && e.enabled) i,
  ];

  // Keys are handled on the item's own node, before the arrow-key
  // shortcuts RawMenuAnchor puts around submenu items.
  FocusNode _node(int i) =>
      _nodes[i] ??= FocusNode(debugLabel: 'menu item $i', onKeyEvent: _onKey);

  MenuController _submenu(int i) => _submenus[i] ??= MenuController();

  @override
  void initState() {
    super.initState();
    // Explicit, not FocusScope.autofocus: that one gives way to whatever is
    // focused already, and a menu must take the keyboard when it opens.
    if (widget.autofocus && !widget.focusFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scope.requestFocus();
      });
    }
    if (widget.focusFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final first = _focusable.firstOrNull;
        if (first != null) _node(first).requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    for (final node in _nodes.values) {
      node.dispose();
    }
    _scope.dispose();
    super.dispose();
  }

  int? get _focusedIndex {
    for (final MapEntry(:key, :value) in _nodes.entries) {
      if (value.hasFocus) return key;
    }
    return null;
  }

  void _closeSubmenus({int? except}) {
    for (final MapEntry(:key, :value) in _submenus.entries) {
      if (key != except && value.isOpen) value.close();
    }
  }

  void _openSubmenu(int i, {bool keyboard = false}) {
    _closeSubmenus(except: i);
    setState(() => _keyboardOpened = keyboard ? i : null);
    _submenu(i).open();
  }

  void _hover(int i) {
    final entry = widget.entries[i] as PrMenuItem<T>;
    if (entry.enabled) _node(i).requestFocus();
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (entry.submenu != null && entry.enabled) {
        if (!_submenu(i).isOpen) _openSubmenu(i);
      } else {
        _closeSubmenus();
      }
    });
  }

  void _activate(int i) {
    final entry = widget.entries[i] as PrMenuItem<T>;
    if (!entry.enabled) return;
    if (entry.submenu != null) {
      _openSubmenu(i, keyboard: true);
      return;
    }
    final root = _MenuRoot.maybeOf<T>(context);
    if (root != null) {
      root.choose(entry);
    } else {
      entry.onSelected?.call();
      final value = entry.value;
      if (value != null) widget.onSelected?.call(value);
    }
  }

  void _move(int by) {
    final items = _focusable;
    if (items.isEmpty) return;
    final current = _focusedIndex;
    final at = current == null ? -1 : items.indexOf(current);
    final next = current == null
        ? (by > 0 ? items.first : items.last)
        : items[(at + by) % items.length];
    _node(next).requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      final i = _focusedIndex;
      final entry = i == null ? null : widget.entries[i];
      if (i == null || entry is! PrMenuItem<T> || entry.submenu == null) {
        return KeyEventResult.ignored;
      }
      _openSubmenu(i, keyboard: true);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.escape) {
      final back = widget.onBack;
      if (back != null) {
        back();
      } else if (key == LogicalKeyboardKey.escape) {
        final root = _MenuRoot.maybeOf<T>(context);
        if (root == null) return KeyEventResult.ignored;
        root.close();
      } else {
        return KeyEventResult.ignored;
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final children = <Widget>[];
    for (final (i, entry) in widget.entries.indexed) {
      children.add(switch (entry) {
        PrMenuSeparator<T>() => Padding(
          padding: const EdgeInsets.symmetric(vertical: PrSpacing.s1),
          child: SizedBox(height: 1, child: ColoredBox(color: c.borderOverlay)),
        ),
        PrMenuHeader<T>(:final label) => Container(
          height: PrSizes.rowTree,
          padding: const EdgeInsets.symmetric(horizontal: PrSpacing.s3),
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            label,
            maxLines: 1,
            style: PrText.caption.copyWith(color: c.textSecondary),
          ),
        ),
        final PrMenuItem<T> item => Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrSpacing.s1),
          child: _item(i, item),
        ),
      });
    }
    return FocusScope(
      node: _scope,
      onKeyEvent: _onKey,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: PrMotion.medium,
        curve: PrMotion.enter,
        builder: (context, t, child) => Opacity(opacity: t, child: child),
        child: Container(
          width: widget.width < PrMenuPanel.minWidth
              ? PrMenuPanel.minWidth
              : widget.width,
          padding: const EdgeInsets.symmetric(vertical: PrSpacing.s1),
          decoration: BoxDecoration(
            color: c.surfaceOverlay,
            border: Border.all(color: c.borderOverlay),
            borderRadius: PrRadii.md,
            boxShadow: PrShadows.of(context).popover,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _item(int i, PrMenuItem<T> item) {
    final node = _node(i);
    Widget row(MenuController? submenu) => MouseRegion(
      onEnter: (_) => _hover(i),
      child: ListenableBuilder(
        listenable: node,
        builder: (context, _) => PrInteractive(
          onPressed: item.enabled ? () => _activate(i) : null,
          focusNode: node,
          focusable: item.enabled,
          semanticsLabel: item.label,
          builder: (context, states) => _MenuItemRow<T>(
            item: item,
            states: {
              ...states,
              ...PrDebugStates.of(context, part: item.label, exact: true),
            },
            focused: node.hasFocus,
            open: submenu?.isOpen ?? false,
          ),
        ),
      ),
    );
    final entries = item.submenu;
    if (entries == null) return row(null);
    final controller = _submenu(i);
    return RawMenuAnchor(
      controller: controller,
      overlayBuilder: (context, info) => CustomSingleChildLayout(
        delegate: _BesideLayout(info.anchorRect),
        child: TapRegion(
          groupId: info.tapRegionGroupId,
          child: PrMenuPanel<T>(
            entries: entries,
            width: widget.width,
            focusFirst: _keyboardOpened == i,
            onBack: () {
              controller.close();
              node.requestFocus();
            },
          ),
        ),
      ),
      builder: (context, controller, _) => row(controller),
    );
  }
}

/// One item row; its look comes from [states], [focused] and [open].
class _MenuItemRow<T> extends StatelessWidget {
  const _MenuItemRow({
    required this.item,
    required this.states,
    required this.focused,
    required this.open,
  });

  final PrMenuItem<T> item;
  final Set<WidgetState> states;
  final bool focused;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final enabled = item.enabled && !states.contains(WidgetState.disabled);
    final pressed = states.contains(WidgetState.pressed);
    final highlighted =
        enabled && (focused || pressed || states.contains(WidgetState.hovered));
    final isOpen = open || states.contains(WidgetState.selected);

    Color? fill;
    var ink = item.destructive ? c.error : c.textPrimary;
    var quiet = c.textSecondary;
    var iconInk = item.destructive ? c.error : c.textSecondary;
    if (!enabled) {
      ink = quiet = iconInk = c.textDisabled;
    } else if (highlighted && item.destructive) {
      fill = c.errorBorder;
      ink = quiet = iconInk = c.textPrimary;
    } else if (highlighted) {
      fill = pressed ? c.accentPressed : c.accent;
      ink = quiet = iconInk = c.textOnAccent;
    } else if (isOpen) {
      fill = c.surfacePressed;
      ink = quiet = iconInk = c.textPrimary;
    }
    if (item.checked && enabled && !highlighted && !isOpen) {
      iconInk = c.accentText;
    }
    final icon = item.checked ? PrIcons.check : item.icon;

    return Container(
      height: PrSizes.control,
      padding: const EdgeInsets.symmetric(horizontal: PrSpacing.s2),
      decoration: BoxDecoration(
        color: fill ?? Colors.transparent,
        borderRadius: PrRadii.sm,
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: PrSizes.icon,
            child: icon == null
                ? null
                : Icon(icon, size: PrSizes.icon, color: iconInk),
          ),
          const SizedBox(width: PrSpacing.s2),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: PrText.body.copyWith(color: ink),
            ),
          ),
          if (item.shortcut != null) ...[
            const SizedBox(width: PrSpacing.s2),
            PrShortcutLabel(item.shortcut!, color: quiet),
          ],
          if (item.submenu != null) ...[
            const SizedBox(width: PrSpacing.s2),
            Icon(PrIcons.chevronRight, size: PrSizes.iconSm, color: quiet),
          ],
        ],
      ),
    );
  }
}

/// Places a submenu beside its parent item: its first item level with the
/// parent (4px padding + 1px border above it), flipped to the left when
/// there's no room on the right.
class _BesideLayout extends SingleChildLayoutDelegate {
  _BesideLayout(this.anchor);

  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      PrOverlayPlacement.placeBeside(
        anchor: anchor,
        size: childSize,
        bounds: size,
        gap: 1,
        dy: -2,
      );

  @override
  bool shouldRelayout(_BesideLayout oldDelegate) =>
      anchor != oldDelegate.anchor;
}

/// What the items of an open menu need from its anchor: closing the whole
/// menu and reporting the choice.
class _MenuRoot<T> extends InheritedWidget {
  const _MenuRoot({
    required this.choose,
    required this.close,
    required super.child,
  });

  final void Function(PrMenuItem<T> item) choose;
  final VoidCallback close;

  static _MenuRoot<T>? maybeOf<T>(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_MenuRoot<T>>();

  @override
  bool updateShouldNotify(_MenuRoot<T> oldWidget) => false;
}

/// A [RawMenuAnchor] that shows an [PrMenuPanel]: below its child, or at
/// the position given to `controller.open`.
class _FsMenuAnchor<T> extends StatefulWidget {
  const _FsMenuAnchor({
    super.key,
    required this.controller,
    required this.entries,
    this.onSelected,
    this.onClose,
    this.width = PrMenuPanel.defaultWidth,
    this.builder,
    this.child,
  });

  final MenuController controller;
  final List<PrMenuEntry<T>> Function() entries;
  final ValueChanged<T>? onSelected;
  final VoidCallback? onClose;
  final double width;
  final RawMenuAnchorChildBuilder? builder;
  final Widget? child;

  @override
  State<_FsMenuAnchor<T>> createState() => _FsMenuAnchorState<T>();
}

class _FsMenuAnchorState<T> extends State<_FsMenuAnchor<T>> {
  List<PrMenuEntry<T>> _entries = const [];
  FocusNode? _previousFocus;

  void _onOpen() {
    _previousFocus = FocusManager.instance.primaryFocus;
    setState(() => _entries = widget.entries());
  }

  void _onClose() {
    final previous = _previousFocus;
    _previousFocus = null;
    if (previous != null && previous.context != null) previous.requestFocus();
    widget.onClose?.call();
  }

  void _choose(PrMenuItem<T> item) {
    widget.controller.close();
    item.onSelected?.call();
    final value = item.value;
    if (value != null) widget.onSelected?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return RawMenuAnchor(
      controller: widget.controller,
      onOpen: _onOpen,
      onClose: _onClose,
      overlayBuilder: (context, info) {
        final position = info.position;
        final anchor = position == null
            ? info.anchorRect
            : Rect.fromLTWH(
                info.anchorRect.left + position.dx,
                info.anchorRect.top + position.dy,
                0,
                0,
              );
        return CustomSingleChildLayout(
          delegate: PrAnchoredLayout(
            anchor: anchor,
            gap: position == null ? PrSpacing.s1 : 0,
            flipHorizontally: position != null,
          ),
          child: TapRegion(
            groupId: info.tapRegionGroupId,
            onTapOutside: (_) => widget.controller.close(),
            child: _MenuRoot<T>(
              choose: _choose,
              close: widget.controller.close,
              child: PrMenuPanel<T>(
                entries: _entries,
                width: widget.width,
                autofocus: true,
              ),
            ),
          ),
        );
      },
      builder: widget.builder,
      child: widget.child,
    );
  }
}

/// Opens a context menu on right click anywhere in [child], at the pointer.
///
/// Entries are built when the menu opens, so they can reflect the current
/// selection. A click outside the menu, Esc, a scroll or a resize closes
/// it; focus goes back where it was.
class PrContextMenuRegion<T> extends StatefulWidget {
  /// Creates the region.
  const PrContextMenuRegion({
    super.key,
    required this.entries,
    this.onSelected,
    this.width = PrMenuPanel.defaultWidth,
    required this.child,
  });

  /// The menu's lines, built on each right click.
  final List<PrMenuEntry<T>> Function() entries;

  /// Called with the chosen item's value.
  final ValueChanged<T>? onSelected;

  /// The menu width.
  final double width;

  /// The area that answers right clicks.
  final Widget child;

  @override
  State<PrContextMenuRegion<T>> createState() => _FsContextMenuRegionState<T>();
}

class _FsContextMenuRegionState<T> extends State<PrContextMenuRegion<T>> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    // The anchor is a point at the region's top-left corner, so clicks on
    // the region itself still count as outside the menu.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (details) =>
          _controller.open(position: details.localPosition),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned(
            left: 0,
            top: 0,
            child: _FsMenuAnchor<T>(
              controller: _controller,
              entries: widget.entries,
              onSelected: widget.onSelected,
              width: widget.width,
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// A trigger that opens a menu below itself: ⋯ menus, split-button carets,
/// dropdown-like triggers. [builder] builds the trigger and gets the
/// [MenuController] to open, close or toggle it.
class PrMenuButton<T> extends StatefulWidget {
  /// Creates the trigger and its menu.
  const PrMenuButton({
    super.key,
    required this.entries,
    this.onSelected,
    this.width = PrMenuPanel.defaultWidth,
    required this.builder,
  });

  /// The menu's lines.
  final List<PrMenuEntry<T>> entries;

  /// Called with the chosen item's value.
  final ValueChanged<T>? onSelected;

  /// The menu width.
  final double width;

  /// Builds the trigger.
  final Widget Function(BuildContext context, MenuController controller)
  builder;

  @override
  State<PrMenuButton<T>> createState() => _FsMenuButtonState<T>();
}

class _FsMenuButtonState<T> extends State<PrMenuButton<T>> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) => _FsMenuAnchor<T>(
    controller: _controller,
    entries: () => widget.entries,
    onSelected: widget.onSelected,
    width: widget.width,
    builder: (context, controller, _) => widget.builder(context, controller),
  );
}

/// Shows a context menu at [position] (global coordinates) and completes
/// with the chosen item's value, or null when it closes without a choice.
Future<T?> showFsContextMenu<T>(
  BuildContext context, {
  required Offset position,
  required List<PrMenuEntry<T>> entries,
  String? header,
  double width = PrMenuPanel.defaultWidth,
}) {
  final overlay = Overlay.of(context);
  final box = overlay.context.findRenderObject()! as RenderBox;
  final local = box.globalToLocal(position);
  final completer = Completer<T?>();
  final controller = MenuController();
  T? chosen;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: local.dx,
      top: local.dy,
      child: _FsMenuAnchor<T>(
        controller: controller,
        entries: () => [
          if (header != null) PrMenuHeader<T>(header),
          ...entries,
        ],
        onSelected: (value) => chosen = value,
        onClose: () {
          // After the item's callbacks, which run right after the close.
          scheduleMicrotask(() {
            if (!completer.isCompleted) completer.complete(chosen);
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (entry.mounted) entry.remove();
          });
        },
        width: width,
        child: const SizedBox.shrink(),
      ),
    ),
  );
  overlay.insert(entry);
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => controller.open(position: Offset.zero),
  );
  return completer.future;
}
