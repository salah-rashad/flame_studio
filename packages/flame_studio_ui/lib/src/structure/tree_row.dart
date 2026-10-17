import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../actions/icon_button.dart';
import '../colors.dart';
import '../foundation/debug_states.dart';
import '../foundation/editable.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../foundation/panel_focus.dart';
import '../icons.dart';
import '../metrics.dart';
import '../typography.dart';

/// Where a drag would land relative to a [FsTreeRow].
enum FsDropZone {
  /// Before the row, as its sibling.
  above,

  /// Into the row, as its last child.
  inside,

  /// After the row, as its sibling.
  below,
}

/// How a [FsTreeRow]'s name and icon are coloured.
enum FsTreeRowTone {
  /// `text-primary` name, `text-secondary` icon.
  normal,

  /// `text-disabled` name and icon: a hidden or disabled node.
  dimmed,

  /// `prefab` name and icon: a prefab instance.
  prefab,

  /// `error` name: a broken node (pair it with a badge that says why).
  error,
}

/// A row action (visibility, lock): a 20px icon button shown while the row
/// is hovered, or always when [pinned] (the state isn't the default, e.g. a
/// hidden node's eye-off).
@immutable
class FsTreeRowAction {
  /// Creates an action.
  const FsTreeRowAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.pinned = false,
  });

  /// The glyph.
  final IconData icon;

  /// Tooltip and semantics label.
  final String tooltip;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Visible without hover.
  final bool pinned;
}

/// One 22px row of a tree (the Scene tree, the Assets list): chevron, icon,
/// name, badges and hover actions.
///
/// - **Layout:** 16px indent per level plus 4px; a 16px chevron box; a 14px
///   icon; the name in `body`; 4px gaps; `radius-sm`, inset 4px from the
///   panel edges.
/// - **States:** hover `surface-hover` (actions appear), pressed
///   `surface-pressed`, selected `surface-selected` while the panel has
///   focus and `surface-selected-inactive` otherwise (`FsPanelFocus`), the
///   keyboard cursor as an inset focus ring (keyboard use only), [tone].
/// - **Inline rename:** while [renaming], a 20px field with the whole name
///   selected; Enter or clicking elsewhere calls [onRenameCommit], Esc
///   [onRenameCancel].
/// - **Drag and drop:** the row is a drag source when [dragData] is set and
///   a drop target when [canAccept] or [onAccept] is set. It works out the
///   [FsDropZone] from the pointer's height in the row (top 25% above,
///   middle 50% inside, bottom 25% below; 50/50 above/below when
///   [canHaveChildren] is false), asks [canAccept] and paints the result:
///   an insertion line, the inside fill, or a reject border with the
///   not-allowed cursor. Whether a drop makes sense (into its own child,
///   type rules) is the app's call. Resting 600ms "inside" a collapsed row
///   with children calls [onAutoExpand].
///
/// Keyboard navigation (↑ ↓ → ← Space ⇧/⌘) belongs to the app's tree view,
/// which knows siblings and parents: it owns focus, moves
/// [keyboardCursor] and handles the keys. Rows are meant for a
/// `ListView.builder` over the flattened visible tree.
///
/// Drags should use `pointerDragAnchorStrategy` (as rows do), so the drop
/// zone follows the pointer.
///
/// Parts for `FsDebugStates`: `drop-above`, `drop-inside` and `drop-below`
/// force that drop zone (any state; [WidgetState.error] makes it a
/// rejected drop).
class FsTreeRow<T extends Object> extends StatefulWidget {
  /// Creates a row.
  const FsTreeRow({
    super.key,
    required this.depth,
    required this.name,
    this.icon,
    this.hasChildren = false,
    this.expanded = false,
    this.onExpandedChanged,
    this.selected = false,
    this.keyboardCursor = false,
    this.tone = FsTreeRowTone.normal,
    this.badges = const [],
    this.actions = const [],
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTap,
    this.renaming = false,
    this.onRenameCommit,
    this.onRenameCancel,
    this.dragData,
    this.dragFeedback,
    this.canHaveChildren = true,
    this.canAccept,
    this.onAccept,
    this.onAutoExpand,
  });

  /// Nesting level; 0 for top-level rows.
  final int depth;

  /// The name, verbatim.
  final String name;

  /// The type icon, drawn at 14px.
  final IconData? icon;

  /// Shows the chevron.
  final bool hasChildren;

  /// Chevron down (expanded) or right.
  final bool expanded;

  /// Called by the chevron with the new expanded state.
  final ValueChanged<bool>? onExpandedChanged;

  /// Selected.
  final bool selected;

  /// The app's keyboard cursor is on this row: an inset focus ring while
  /// the panel has focus and the keyboard is in use.
  final bool keyboardCursor;

  /// Name and icon colours.
  final FsTreeRowTone tone;

  /// After the name ("Missing script", "Prefab", counts).
  final List<Widget> badges;

  /// Row actions at the end.
  final List<FsTreeRowAction> actions;

  /// Click (not on the chevron or an action).
  final VoidCallback? onTap;

  /// Double click.
  final VoidCallback? onDoubleTap;

  /// Right click, with the global position for a context menu.
  final ValueChanged<Offset>? onSecondaryTap;

  /// Shows the inline rename field.
  final bool renaming;

  /// The rename was confirmed with this text.
  final ValueChanged<String>? onRenameCommit;

  /// The rename was cancelled.
  final VoidCallback? onRenameCancel;

  /// What dragging this row carries; null makes it not draggable.
  final T? dragData;

  /// The widget under the pointer while dragging; a chip with the icon and
  /// name when null.
  final Widget Function()? dragFeedback;

  /// False for leaves that can't take children: zones are 50/50
  /// above/below.
  final bool canHaveChildren;

  /// Whether [data] may land in [zone]; drawn as accepted or rejected.
  final bool Function(T data, FsDropZone zone)? canAccept;

  /// [data] was dropped in an accepted [zone].
  final void Function(T data, FsDropZone zone)? onAccept;

  /// The drag rested 600ms inside this collapsed row.
  final VoidCallback? onAutoExpand;

  /// How long a drag rests "inside" before [onAutoExpand].
  static const Duration autoExpandDelay = Duration(milliseconds: 600);

  @override
  State<FsTreeRow<T>> createState() => _FsTreeRowState<T>();
}

class _FsTreeRowState<T extends Object> extends State<FsTreeRow<T>> {
  FsDropZone? _zone;
  bool _accepted = false;
  Timer? _expandTimer;
  bool _swallowPress = false;

  TextEditingController? _renameController;
  FocusNode? _renameFocus;
  bool _renameDone = false;

  @override
  void initState() {
    super.initState();
    if (widget.renaming) _startRename();
  }

  @override
  void didUpdateWidget(FsTreeRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.renaming && !oldWidget.renaming) _startRename();
    if (!widget.renaming && oldWidget.renaming) _endRename();
  }

  @override
  void dispose() {
    _expandTimer?.cancel();
    _endRename();
    super.dispose();
  }

  // Rename

  void _startRename() {
    _renameDone = false;
    _renameController = TextEditingController(text: widget.name);
    _renameFocus = FocusNode(debugLabel: 'rename')..addListener(_onRenameFocus);
  }

  void _endRename() {
    _renameDone = true;
    final focus = _renameFocus;
    final controller = _renameController;
    _renameFocus = null;
    _renameController = null;
    // The field is still in the tree until the next build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focus?.dispose();
      controller?.dispose();
    });
  }

  void _onRenameFocus() {
    final focus = _renameFocus;
    if (focus != null && !focus.hasFocus) _commitRename();
  }

  void _commitRename() {
    if (_renameDone) return;
    _renameDone = true;
    widget.onRenameCommit?.call(_renameController!.text);
  }

  void _cancelRename() {
    if (_renameDone) return;
    _renameDone = true;
    widget.onRenameCancel?.call();
  }

  // Drag and drop

  bool get _isTarget => widget.canAccept != null || widget.onAccept != null;

  FsDropZone _zoneAt(Offset globalPosition) {
    final box = context.findRenderObject()! as RenderBox;
    final f = box.globalToLocal(globalPosition).dy / box.size.height;
    if (!widget.canHaveChildren) {
      return f < 0.5 ? FsDropZone.above : FsDropZone.below;
    }
    if (f < 0.25) return FsDropZone.above;
    if (f > 0.75) return FsDropZone.below;
    return FsDropZone.inside;
  }

  void _onDragMove(T data, Offset globalPosition) {
    final zone = _zoneAt(globalPosition);
    final accepted =
        widget.canAccept?.call(data, zone) ?? widget.onAccept != null;
    if (zone != FsDropZone.inside) {
      _expandTimer?.cancel();
      _expandTimer = null;
    } else if (_expandTimer == null &&
        widget.hasChildren &&
        !widget.expanded &&
        widget.onAutoExpand != null) {
      _expandTimer = Timer(FsTreeRow.autoExpandDelay, () {
        _expandTimer = null;
        if (mounted && _zone == FsDropZone.inside) widget.onAutoExpand?.call();
      });
    }
    if (zone != _zone || accepted != _accepted) {
      setState(() {
        _zone = zone;
        _accepted = accepted;
      });
    }
  }

  void _clearDrop() {
    _expandTimer?.cancel();
    _expandTimer = null;
    if (_zone != null) setState(() => _zone = null);
  }

  void _onDrop(T data, Offset globalPosition) {
    final zone = _zoneAt(globalPosition);
    final accepted =
        widget.canAccept?.call(data, zone) ?? widget.onAccept != null;
    _clearDrop();
    if (accepted) widget.onAccept?.call(data, zone);
  }

  (FsDropZone, bool)? _forcedDrop(BuildContext context) {
    for (final (part, zone) in const [
      ('drop-above', FsDropZone.above),
      ('drop-inside', FsDropZone.inside),
      ('drop-below', FsDropZone.below),
    ]) {
      final states = FsDebugStates.of(context, part: part, exact: true);
      if (states.isNotEmpty) return (zone, !states.contains(WidgetState.error));
    }
    return null;
  }

  // Build

  void _onPressed() {
    if (_swallowPress) return;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final zone = _zone;
    final drop = zone != null ? (zone, _accepted) : _forcedDrop(context);
    final rejecting = drop != null && !drop.$2;

    Widget row = ListenableBuilder(
      listenable: FsInputModality.instance,
      builder: (context, _) => FsInteractive(
        onPressed: _onPressed,
        enabled: true,
        focusable: false,
        selected: widget.selected,
        cursor: rejecting
            ? SystemMouseCursors.forbidden
            : SystemMouseCursors.basic,
        semanticsLabel: widget.name,
        builder: (context, states) => _build(context, states, drop),
      ),
    );
    // Resets the swallow flag after the inner listeners have seen the up.
    row = Listener(
      onPointerUp: (_) => _swallowPress = false,
      onPointerCancel: (_) => _swallowPress = false,
      child: row,
    );
    if (widget.onDoubleTap != null || widget.onSecondaryTap != null) {
      row = GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTapUp: widget.onSecondaryTap == null
            ? null
            : (details) => widget.onSecondaryTap!(details.globalPosition),
        child: row,
      );
    }
    final data = widget.dragData;
    if (data != null && !widget.renaming) {
      row = Draggable<T>(
        data: data,
        maxSimultaneousDrags: 1,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        // The drag layer sits above any Material, so give the feedback a
        // text style: without one, Text falls back to the debug double
        // underline.
        feedback: DefaultTextStyle(
          style: FsText.body.copyWith(color: FsColors.of(context).textPrimary),
          child: widget.dragFeedback?.call() ?? _DragChip(row: widget),
        ),
        child: row,
      );
    }
    if (_isTarget) {
      final content = row; // the builder runs later, after `row` changes
      row = DragTarget<T>(
        onWillAcceptWithDetails: (details) {
          _onDragMove(details.data, details.offset);
          return true;
        },
        onMove: (details) => _onDragMove(details.data, details.offset),
        onLeave: (_) => _clearDrop(),
        onAcceptWithDetails: (details) => _onDrop(details.data, details.offset),
        builder: (context, candidates, rejected) => content,
      );
    }
    return Semantics(
      selected: widget.selected,
      expanded: widget.hasChildren ? widget.expanded : null,
      child: row,
    );
  }

  Widget _build(
    BuildContext context,
    Set<WidgetState> states,
    (FsDropZone, bool)? drop,
  ) {
    final c = FsColors.of(context);
    final panelFocused = FsPanelFocus.of(context);
    final hovered = states.contains(WidgetState.hovered);
    final focused =
        states.contains(WidgetState.focused) ||
        (widget.keyboardCursor &&
            panelFocused &&
            FsInputModality.instance.showsFocusRing);
    final insideAccepted =
        drop != null && drop.$1 == FsDropZone.inside && drop.$2;

    final Color? fill;
    if (insideAccepted) {
      fill = c.accentSubtle;
    } else if (widget.selected) {
      fill = panelFocused ? c.surfaceSelected : c.surfaceSelectedInactive;
    } else if (states.contains(WidgetState.pressed)) {
      fill = c.surfacePressed;
    } else if (hovered) {
      fill = c.surfaceHover;
    } else {
      fill = null;
    }

    final nameColor = switch (widget.tone) {
      FsTreeRowTone.normal => c.textPrimary,
      FsTreeRowTone.dimmed => c.textDisabled,
      FsTreeRowTone.prefab => c.prefab,
      FsTreeRowTone.error => c.error,
    };
    final iconColor = switch (widget.tone) {
      FsTreeRowTone.dimmed => c.textDisabled,
      FsTreeRowTone.prefab => c.prefab,
      _ => widget.selected ? c.textPrimary : c.textSecondary,
    };
    final chevronColor = widget.selected ? c.textPrimary : c.textSecondary;
    final indent = widget.depth * FsSpacing.s4 + FsSpacing.s1;

    final chevron = SizedBox.square(
      dimension: FsSpacing.s4,
      child: widget.hasChildren
          ? Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (event.buttons != kPrimaryButton) return;
                _swallowPress = true;
                widget.onExpandedChanged?.call(!widget.expanded);
              },
              child: Icon(
                widget.expanded ? FsIcons.chevronDown : FsIcons.chevronRight,
                size: FsSizes.iconSm,
                color: chevronColor,
              ),
            )
          : null,
    );

    final renaming = widget.renaming && _renameController != null;
    final children = <Widget>[
      chevron,
      if (widget.icon != null) ...[
        const SizedBox(width: FsSpacing.s1),
        Icon(widget.icon, size: FsSizes.iconSm, color: iconColor),
      ],
      if (renaming)
        Expanded(child: _renameField(c))
      else ...[
        const SizedBox(width: FsSpacing.s1),
        Expanded(
          child: Text(
            widget.name,
            style: FsText.body.copyWith(color: nameColor),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      for (final badge in widget.badges) ...[
        const SizedBox(width: FsSpacing.s1),
        badge,
      ],
      if (widget.actions.isNotEmpty) ...[
        const SizedBox(width: FsSpacing.s1),
        Listener(
          onPointerDown: (_) => _swallowPress = true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in widget.actions)
                Visibility.maintain(
                  visible: hovered || action.pinned,
                  child: FsIconButton(
                    size: FsIconButtonSize.small,
                    iconSize: FsSizes.iconSm,
                    icon: action.icon,
                    tooltip: action.tooltip,
                    onPressed: action.onPressed,
                    focusable: false,
                  ),
                ),
            ],
          ),
        ),
      ],
    ];

    final lineStart = indent + FsSpacing.s4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FsSpacing.s1),
      child: CustomPaint(
        foregroundPainter: drop == null
            ? null
            : FsDropPainter(
                zone: drop.$1,
                accepted: drop.$2,
                lineStart: lineStart,
                accent: c.accentText,
                error: c.error,
                ground: c.surfacePanel,
              ),
        child: FsFocusRing.inset(
          visible: focused,
          child: Container(
            height: FsSizes.rowTree,
            padding: EdgeInsetsDirectional.only(
              start: indent,
              end: FsSpacing.s1,
            ),
            decoration: BoxDecoration(color: fill, borderRadius: FsRadii.sm),
            child: Row(children: children),
          ),
        ),
      ),
    );
  }

  Widget _renameField(FsColors c) {
    return Container(
      height: FsSizes.controlSm,
      // 3px padding + 1px border keeps the text where the name was, in place
      // of the 4px gap.
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: c.surfaceInput,
        border: Border.all(color: c.focusRing),
        borderRadius: const BorderRadius.all(Radius.circular(3)),
      ),
      child: FsEditableText(
        controller: _renameController!,
        focusNode: _renameFocus!,
        autofocus: true,
        style: FsText.body.copyWith(color: c.textPrimary),
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.enter): _commitRename,
          const SingleActivator(LogicalKeyboardKey.numpadEnter): _commitRename,
          const SingleActivator(LogicalKeyboardKey.escape): _cancelRename,
        },
      ),
    );
  }
}

/// The default drag feedback: the row's icon and name on an overlay chip.
class _DragChip extends StatelessWidget {
  const _DragChip({required this.row});

  final FsTreeRow<Object> row;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    return Transform.translate(
      offset: const Offset(12, 4),
      child: Container(
        height: FsSizes.rowTree,
        padding: const EdgeInsets.symmetric(horizontal: FsSpacing.s2),
        decoration: BoxDecoration(
          color: c.surfaceOverlay,
          border: Border.all(color: c.borderOverlay),
          borderRadius: FsRadii.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (row.icon != null) ...[
              Icon(row.icon, size: FsSizes.iconSm, color: c.textSecondary),
              const SizedBox(width: FsSpacing.s1),
            ],
            Text(
              row.name,
              style: FsText.body.copyWith(
                color: c.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a drop indicator over the row: an insertion line with a ring at
/// its start (above, below), a 1px inset `accent-text` border (inside), or
/// a 1px inset `error` border (rejected).
///
/// Internal (not exported); public so tests can read what is drawn.
class FsDropPainter extends CustomPainter {
  /// Creates the painter.
  const FsDropPainter({
    required this.zone,
    required this.accepted,
    required this.lineStart,
    required this.accent,
    required this.error,
    required this.ground,
  });

  /// The zone under the pointer.
  final FsDropZone zone;

  /// Whether the app accepts the drop there.
  final bool accepted;

  /// Where the insertion line starts: the row's content indent.
  final double lineStart;

  /// `accent-text`.
  final Color accent;

  /// `error`.
  final Color error;

  /// The ring's fill (`surface-panel`).
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    if (!accepted || zone == FsDropZone.inside) {
      final rrect = FsRadii.sm.toRRect(Offset.zero & size).deflate(0.5);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = accepted ? accent : error
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      return;
    }
    final y = zone == FsDropZone.above ? 0.0 : size.height;
    canvas.drawRRect(
      RRect.fromLTRBR(
        lineStart,
        y - 1,
        size.width,
        y + 1,
        const Radius.circular(1),
      ),
      Paint()..color = accent,
    );
    final center = Offset(lineStart - 3, y);
    canvas.drawCircle(center, 3, Paint()..color = ground);
    canvas.drawCircle(
      center,
      3,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(FsDropPainter oldDelegate) =>
      zone != oldDelegate.zone ||
      accepted != oldDelegate.accepted ||
      lineStart != oldDelegate.lineStart ||
      accent != oldDelegate.accent ||
      error != oldDelegate.error ||
      ground != oldDelegate.ground;
}
