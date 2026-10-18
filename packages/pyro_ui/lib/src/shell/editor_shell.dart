import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../colors.dart';
import '../foundation/debug_states.dart';
import '../metrics.dart';
import '../typography.dart';

/// The widths of the side docks and the height of the bottom dock of an
/// [PrEditorShell], as the user left them.
@immutable
class PrShellSizes {
  /// Creates a set of dock sizes.
  const PrShellSizes({this.left = 260, this.right = 320, this.bottom = 220});

  /// The defaults: 260 / 320 / 220.
  static const standard = PrShellSizes();

  /// The left dock's width (Scene / Hierarchy).
  final double left;

  /// The right dock's width (Inspector).
  final double right;

  /// The bottom dock's height (Console / Assets), when expanded.
  final double bottom;

  /// A copy with the given sizes replaced.
  PrShellSizes copyWith({double? left, double? right, double? bottom}) =>
      PrShellSizes(
        left: left ?? this.left,
        right: right ?? this.right,
        bottom: bottom ?? this.bottom,
      );

  @override
  bool operator ==(Object other) =>
      other is PrShellSizes &&
      other.left == left &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, right, bottom);

  @override
  String toString() => 'PrShellSizes($left, $right, $bottom)';
}

/// How far the docks of an [PrEditorShell] may be dragged, and the room the
/// centre keeps.
@immutable
class PrShellLimits {
  /// Creates a set of limits.
  const PrShellLimits({
    this.minLeft = 180,
    this.maxLeft = 480,
    this.minRight = 240,
    this.maxRight = 560,
    this.minBottom = 120,
    this.maxBottom = 480,
    this.minCenterWidth = 750,
    this.minCenterHeight = 520,
  });

  /// The defaults. At the 1280×800 minimum window the centre keeps
  /// 750 × 520, which shrinks the default docks to about 237 / 291 / 187.
  static const standard = PrShellLimits();

  /// The left dock's narrowest width.
  final double minLeft;

  /// The left dock's widest width.
  final double maxLeft;

  /// The right dock's narrowest width.
  final double minRight;

  /// The right dock's widest width.
  final double maxRight;

  /// The bottom dock's lowest expanded height.
  final double minBottom;

  /// The bottom dock's tallest height.
  final double maxBottom;

  /// The centre column's narrowest width: the side docks shrink (and stop
  /// growing) to keep it.
  final double minCenterWidth;

  /// The centre's lowest height above the bottom dock: the dock shrinks
  /// (and stops growing) to keep it.
  final double minCenterHeight;
}

/// The editor window's layout: title bar, toolbar, three columns with a
/// bottom dock under the centre one, and the status bar. It knows only
/// slots and sizes; the app passes the panels in.
///
/// - **Regions:** [titleBar] 38 (`bg-app`; the first
///   [titleBarLeadingInset] px, and as much on the right so a centred title
///   stays centred in the window, are the macOS traffic-light zone),
///   [toolbar] 32, then [left] | [center] | [right] separated by 1px of
///   `bg-app`, [bottom] under [center], and [statusBar] 22 (`bg-app`,
///   `small` in `text-secondary`).
/// - **Seams:** each 1px line has a 4px hit area with the column or row
///   resize cursor. Hover draws it in `border-strong`, dragging in
///   `accent-text`. Dragging clamps to [limits].
/// - **Sizes are reported, not stored:** [onSizesChanged] fires during the
///   drag (rebuild with the new [sizes]), [onSizesChangeEnd] when it ends
///   (persist them per project then).
/// - **Fitting the window:** the docks shrink in proportion, never below
///   their minimum, when the window can't fit them and the centre's
///   minimum ([PrShellLimits.minCenterWidth] and
///   [PrShellLimits.minCenterHeight]). That is layout only: [sizes] keep
///   the user's choice and come back when the window grows. A drag starts
///   from the size on screen.
/// - **Bottom dock:** null hides it. [bottomCollapsed] shows only its top
///   28px (the dock's tab strip, [PrSizes.tab]); the dock keeps its
///   expanded layout and state underneath. With
///   [onBottomCollapsedChanged], dragging the seam below half the minimum
///   height collapses the dock and dragging a collapsed one up expands it.
/// - The title bar draws nothing native: hiding the macOS title bar and
///   placing the traffic lights is app runner configuration.
///
/// Parts for `PrDebugStates`: `seam-left`, `seam-right` and `seam-bottom`
/// ([WidgetState.hovered], and [WidgetState.dragged] for dragging; exact).
class PrEditorShell extends StatefulWidget {
  /// Creates the shell.
  const PrEditorShell({
    super.key,
    required this.titleBar,
    this.titleBarLeadingInset = 78,
    required this.toolbar,
    required this.left,
    required this.center,
    required this.right,
    this.bottom,
    this.bottomCollapsed = false,
    this.onBottomCollapsedChanged,
    required this.statusBar,
    required this.sizes,
    required this.onSizesChanged,
    this.onSizesChangeEnd,
    this.limits = PrShellLimits.standard,
  });

  /// The window's title bar content, usually the centred document title.
  final Widget titleBar;

  /// The traffic-light zone kept clear at the start of the title bar (and
  /// at its end, for symmetry).
  final double titleBarLeadingInset;

  /// The main toolbar, usually a `PrToolbar`.
  final Widget toolbar;

  /// The left dock: Scene / Hierarchy.
  final Widget left;

  /// The centre: document tabs, viewport toolbar and viewport.
  final Widget center;

  /// The right dock: Inspector.
  final Widget right;

  /// The bottom dock under the centre: Console / Assets. Null hides it.
  final Widget? bottom;

  /// Shows only the bottom dock's tab strip.
  final bool bottomCollapsed;

  /// Called when a seam drag collapses or expands the bottom dock; without
  /// it the seam only resizes.
  final ValueChanged<bool>? onBottomCollapsedChanged;

  /// The status bar content.
  final Widget statusBar;

  /// The dock sizes.
  final PrShellSizes sizes;

  /// The new sizes, during a seam drag.
  final ValueChanged<PrShellSizes> onSizesChanged;

  /// The sizes once a seam drag ends, to persist.
  final ValueChanged<PrShellSizes>? onSizesChangeEnd;

  /// The drag limits and the centre's minimum.
  final PrShellLimits limits;

  /// The width of the seams between regions.
  static const double seam = 1;

  /// The width of a seam's hit area.
  static const double seamHitArea = 4;

  @override
  State<PrEditorShell> createState() => _FsEditorShellState();
}

enum _Seam { left, right, bottom }

/// Where the regions go for one body size.
class _Layout {
  factory _Layout(PrEditorShell shell, Size body) {
    final l = shell.limits;
    final sizes = shell.sizes;
    var left = sizes.left.clamp(l.minLeft, l.maxLeft);
    var right = sizes.right.clamp(l.minRight, l.maxRight);
    final room = body.width - 2 * PrEditorShell.seam - l.minCenterWidth;
    if (left + right > room) {
      final scale = math.max(0.0, room) / (left + right);
      left = math.max(l.minLeft, left * scale);
      right = math.max(l.minRight, right * scale);
    }

    final roomY = body.height - PrEditorShell.seam - l.minCenterHeight;
    final expanded = math.max(
      l.minBottom,
      math.min(sizes.bottom.clamp(l.minBottom, l.maxBottom), roomY),
    );
    final double bottom = shell.bottom == null
        ? 0
        : shell.bottomCollapsed
        ? PrSizes.tab
        : expanded;
    return _Layout._(body, left, right, bottom, expanded);
  }

  const _Layout._(
    this.body,
    this.left,
    this.right,
    this.bottom,
    this.expandedBottom,
  );

  final Size body;
  final double left;
  final double right;

  /// The bottom dock's height on screen; 0 when there is none.
  final double bottom;

  /// The bottom dock's height when expanded, which it keeps laid out at
  /// while collapsed.
  final double expandedBottom;

  double get centerX => left + PrEditorShell.seam;

  double get centerWidth =>
      math.max(0, body.width - left - right - 2 * PrEditorShell.seam);

  double get centerHeight => bottom == 0
      ? body.height
      : math.max(0, body.height - bottom - PrEditorShell.seam);
}

class _FsEditorShellState extends State<PrEditorShell> {
  _Seam? _dragging;
  double _dragStart = 0;
  double _dragDelta = 0;
  late _Layout _layout;

  void _start(_Seam seam) {
    setState(() {
      _dragging = seam;
      _dragDelta = 0;
      _dragStart = switch (seam) {
        _Seam.left => _layout.left,
        _Seam.right => _layout.right,
        _Seam.bottom => _layout.bottom,
      };
    });
  }

  void _update(_Seam seam, double delta) {
    if (_dragging != seam) return;
    _dragDelta += delta;
    final l = widget.limits;
    final layout = _layout;
    const seams = 2 * PrEditorShell.seam;
    final sizes = widget.sizes;
    switch (seam) {
      case _Seam.left:
        final room =
            layout.body.width - seams - layout.right - l.minCenterWidth;
        final double width = (_dragStart + _dragDelta).clamp(
          l.minLeft,
          math.max(l.minLeft, math.min(l.maxLeft, room)),
        );
        _report(sizes.copyWith(left: width));
      case _Seam.right:
        final room = layout.body.width - seams - layout.left - l.minCenterWidth;
        final double width = (_dragStart - _dragDelta).clamp(
          l.minRight,
          math.max(l.minRight, math.min(l.maxRight, room)),
        );
        _report(sizes.copyWith(right: width));
      case _Seam.bottom:
        final raw = _dragStart - _dragDelta;
        final onCollapse = widget.onBottomCollapsedChanged;
        if (onCollapse != null) {
          final collapse = raw < l.minBottom / 2;
          if (collapse != widget.bottomCollapsed) onCollapse(collapse);
          if (collapse) return;
        }
        final room =
            layout.body.height - PrEditorShell.seam - l.minCenterHeight;
        final double height = raw.clamp(
          l.minBottom,
          math.max(l.minBottom, math.min(l.maxBottom, room)),
        );
        _report(sizes.copyWith(bottom: height));
    }
  }

  void _report(PrShellSizes sizes) {
    if (sizes != widget.sizes) widget.onSizesChanged(sizes);
  }

  void _end(_Seam seam) {
    if (_dragging != seam) return;
    setState(() => _dragging = null);
    widget.onSizesChangeEnd?.call(widget.sizes);
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    return ColoredBox(
      color: c.bgApp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: PrSizes.titlebar,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.titleBarLeadingInset,
              ),
              child: DefaultTextStyle.merge(
                style: PrText.bodyStrong.copyWith(color: c.textSecondary),
                child: widget.titleBar,
              ),
            ),
          ),
          SizedBox(height: PrSizes.toolbar, child: widget.toolbar),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => _body(constraints.biggest),
            ),
          ),
          SizedBox(
            height: PrSizes.statusbar,
            child: DefaultTextStyle.merge(
              style: PrText.small.copyWith(color: c.textSecondary),
              child: widget.statusBar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(Size body) {
    final layout = _layout = _Layout(widget, body);
    const seam = PrEditorShell.seam;
    const hit = PrEditorShell.seamHitArea;
    const out = (hit - seam) / 2;
    final bottom = widget.bottom;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          key: const ValueKey((PrEditorShell, 'left')),
          left: 0,
          top: 0,
          bottom: 0,
          width: layout.left,
          child: widget.left,
        ),
        Positioned(
          key: const ValueKey((PrEditorShell, 'center')),
          left: layout.centerX,
          top: 0,
          width: layout.centerWidth,
          height: layout.centerHeight,
          child: widget.center,
        ),
        Positioned(
          key: const ValueKey((PrEditorShell, 'right')),
          right: 0,
          top: 0,
          bottom: 0,
          width: layout.right,
          child: widget.right,
        ),
        if (bottom != null)
          Positioned(
            key: const ValueKey((PrEditorShell, 'bottom')),
            left: layout.centerX,
            bottom: 0,
            width: layout.centerWidth,
            height: layout.bottom,
            child: ClipRect(
              // The same tree collapsed or not, so the dock keeps its state.
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: layout.expandedBottom,
                maxHeight: layout.expandedBottom,
                child: bottom,
              ),
            ),
          ),
        Positioned(
          key: const ValueKey((PrEditorShell, 'seam-left')),
          left: layout.left - out,
          top: 0,
          bottom: 0,
          width: hit,
          child: _seam(_Seam.left),
        ),
        Positioned(
          key: const ValueKey((PrEditorShell, 'seam-right')),
          right: layout.right - out,
          top: 0,
          bottom: 0,
          width: hit,
          child: _seam(_Seam.right),
        ),
        if (bottom != null)
          Positioned(
            key: const ValueKey((PrEditorShell, 'seam-bottom')),
            left: layout.centerX,
            bottom: layout.bottom - out,
            width: layout.centerWidth,
            height: hit,
            child: _seam(_Seam.bottom),
          ),
      ],
    );
  }

  Widget _seam(_Seam seam) => _SeamHandle(
    axis: seam == _Seam.bottom ? Axis.vertical : Axis.horizontal,
    part: 'seam-${seam.name}',
    dragging: _dragging == seam,
    onStart: () => _start(seam),
    onUpdate: (delta) => _update(seam, delta),
    onEnd: () => _end(seam),
  );
}

/// A seam's 4px hit area and its 1px line.
class _SeamHandle extends StatefulWidget {
  const _SeamHandle({
    required this.axis,
    required this.part,
    required this.dragging,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  /// [Axis.horizontal] for the side seams (dragged left and right).
  final Axis axis;
  final String part;
  final bool dragging;
  final VoidCallback onStart;
  final ValueChanged<double> onUpdate;
  final VoidCallback onEnd;

  @override
  State<_SeamHandle> createState() => _SeamHandleState();
}

class _SeamHandleState extends State<_SeamHandle> {
  bool _hovered = false;

  void _hover(bool hovered) {
    if (_hovered != hovered) setState(() => _hovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final forced = PrDebugStates.of(context, part: widget.part, exact: true);
    final Color line;
    if (widget.dragging || forced.contains(WidgetState.dragged)) {
      line = c.accentText;
    } else if (_hovered || forced.contains(WidgetState.hovered)) {
      line = c.borderStrong;
    } else {
      line = Colors.transparent;
    }
    final horizontal = widget.axis == Axis.horizontal;
    return MouseRegion(
      cursor: horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => _hover(true),
      onExit: (_) => _hover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: horizontal ? (_) => widget.onStart() : null,
        onHorizontalDragUpdate: horizontal
            ? (d) => widget.onUpdate(d.delta.dx)
            : null,
        onHorizontalDragEnd: horizontal ? (_) => widget.onEnd() : null,
        onHorizontalDragCancel: horizontal ? widget.onEnd : null,
        onVerticalDragStart: horizontal ? null : (_) => widget.onStart(),
        onVerticalDragUpdate: horizontal
            ? null
            : (d) => widget.onUpdate(d.delta.dy),
        onVerticalDragEnd: horizontal ? null : (_) => widget.onEnd(),
        onVerticalDragCancel: horizontal ? null : widget.onEnd,
        child: Center(
          child: SizedBox(
            width: horizontal ? PrEditorShell.seam : double.infinity,
            height: horizontal ? double.infinity : PrEditorShell.seam,
            child: ColoredBox(color: line),
          ),
        ),
      ),
    );
  }
}
