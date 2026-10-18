import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../foundation/focus_ring.dart';
import '../metrics.dart';

/// Where an [PrToolbar] sits, which sets its surface.
enum PrToolbarStyle {
  /// The main toolbar under the title bar: `surface-raised`, 1px `bg-app`
  /// bottom edge.
  main,

  /// The toolbar above the viewport canvas: `surface-panel`, 1px
  /// `border-subtle` bottom edge.
  viewport,
}

/// A run of related controls in an [PrToolbar], 2px apart ([spacing]).
class PrToolbarGroup extends StatelessWidget {
  /// Creates a group.
  const PrToolbarGroup({super.key, required this.children, this.spacing = 2});

  /// The controls: icon buttons, toggles, a segmented control, a split
  /// button, a chip, plain text.
  final List<Widget> children;

  /// The gap between the controls; 2 by default (the design uses 8 between
  /// the target-device chip and the runtime status).
  final double spacing;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, spacing: spacing, children: children);
}

/// A 32px strip of grouped controls: the main toolbar and the viewport
/// toolbar.
///
/// - 4px padding at both ends and 4px between items; groups within a
///   section are split by a 1px × 16px `border-subtle` divider with 4px
///   either side. [leading] sits at the start, [trailing] at the end, and
///   [center] (the Play cluster) in the middle of the space between them.
/// - [highlighted] draws a 1px `accent` outline: the design's state for a
///   running game.
/// - **Roving focus:** the toolbar is one Tab stop. Tab lands on the
///   control that last had focus (the first one at first), ← → move to the
///   neighbouring control (Home and End to the ends; disabled controls are
///   skipped), and the next Tab leaves the toolbar. The controls stay
///   ordinary focusable widgets, so their rings, Enter/Space and screen
///   readers work as anywhere else. A control that uses ← → itself keeps
///   them: a text field, or a segmented control until its last segment.
class PrToolbar extends StatefulWidget {
  /// Creates a toolbar.
  const PrToolbar({
    super.key,
    required this.leading,
    this.center = const [],
    this.trailing = const [],
    this.style = PrToolbarStyle.main,
    this.highlighted = false,
  });

  /// Groups at the start (history, tool mode, view toggles).
  final List<PrToolbarGroup> leading;

  /// Groups centred in the space left between [leading] and [trailing].
  final List<PrToolbarGroup> center;

  /// Groups at the end (target device, status, search and settings).
  final List<PrToolbarGroup> trailing;

  /// Main or viewport.
  final PrToolbarStyle style;

  /// Draws the `accent` outline (a game is running).
  final bool highlighted;

  @override
  State<PrToolbar> createState() => _FsToolbarState();
}

class _FsToolbarState extends State<PrToolbar> {
  final _node = FocusNode(
    debugLabel: 'PrToolbar',
    canRequestFocus: false,
    skipTraversal: true,
  );

  // The control that last had focus, where Tab comes back to.
  FocusNode? _last;
  FocusManager? _manager;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listen();
  }

  // flutter_test replaces the FocusManager between tests.
  void _listen() {
    final manager = FocusManager.instance;
    if (manager == _manager) return;
    _manager?.removeListener(_onPrimaryFocus);
    _manager = manager..addListener(_onPrimaryFocus);
  }

  @override
  void dispose() {
    _manager?.removeListener(_onPrimaryFocus);
    _node.dispose();
    super.dispose();
  }

  void _onPrimaryFocus() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary.ancestors.contains(_node)) _last = primary;
  }

  /// The focusable controls, left to right.
  List<FocusNode> _controls() {
    final nodes = _node.traversalDescendants
        .where((n) => n.canRequestFocus && n.context != null)
        .toList();
    // Drop nodes inside another candidate (a control's inner parts).
    nodes.removeWhere((n) => n.ancestors.any(nodes.contains));
    nodes.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    return nodes;
  }

  int _current(List<FocusNode> controls) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return -1;
    return controls.indexWhere(
      (n) => n == primary || primary.ancestors.contains(n),
    );
  }

  void _onFocusChange(bool hasFocus) {
    if (!hasFocus) return;
    // Entering by keyboard: go back to the remembered control. A click
    // focuses what it hits.
    final last = _last;
    final primary = FocusManager.instance.primaryFocus;
    if (last == null ||
        last == primary ||
        !PrInputModality.instance.showsFocusRing ||
        last.context == null ||
        !last.canRequestFocus ||
        !last.ancestors.contains(_node)) {
      return;
    }
    last.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final keys = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.tab) {
      if (keys.isControlPressed || keys.isMetaPressed || keys.isAltPressed) {
        return KeyEventResult.ignored;
      }
      return _leave(forward: !keys.isShiftPressed);
    }
    final int? step = switch (key) {
      LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.home => -1 << 20,
      LogicalKeyboardKey.end => 1 << 20,
      _ => null,
    };
    if (step == null || keys.isShiftPressed || keys.isAltPressed) {
      return KeyEventResult.ignored;
    }
    // Text fields move their caret with these keys.
    final primary = FocusManager.instance.primaryFocus;
    if (primary?.context?.findAncestorStateOfType<EditableTextState>() !=
        null) {
      return KeyEventResult.ignored;
    }
    final controls = _controls();
    final current = _current(controls);
    if (controls.isEmpty || current < 0) return KeyEventResult.ignored;
    final target = (current + step).clamp(0, controls.length - 1);
    if (target != current) controls[target].requestFocus();
    return KeyEventResult.handled;
  }

  /// Tab out: past the last control (or before the first), whichever one
  /// has focus now.
  KeyEventResult _leave({required bool forward}) {
    final controls = _controls();
    if (controls.isEmpty || _current(controls) < 0) {
      return KeyEventResult.ignored;
    }
    final edge = forward ? controls.last : controls.first;
    // Traversal starts from the scope's focused child, so make the edge
    // control that child first; only the final request is applied.
    edge.requestFocus();
    forward ? edge.nextFocus() : edge.previousFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final main = widget.style == PrToolbarStyle.main;
    final center = widget.center;
    return FocusTraversalGroup(
      child: Focus(
        focusNode: _node,
        includeSemantics: false,
        onFocusChange: _onFocusChange,
        onKeyEvent: _onKey,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: CustomPaint(
            // Always a CustomPaint, so highlighting never rebuilds the
            // controls.
            foregroundPainter: widget.highlighted
                ? PrEdgePainter(
                    color: c.accent,
                    width: 1,
                    borderRadius: BorderRadius.zero,
                    outside: false,
                  )
                : null,
            child: Container(
              height: PrSizes.toolbar,
              padding: const EdgeInsets.symmetric(horizontal: PrSpacing.s1),
              decoration: BoxDecoration(
                color: main ? c.surfaceRaised : c.surfacePanel,
                border: Border(
                  bottom: BorderSide(color: main ? c.bgApp : c.borderSubtle),
                ),
              ),
              child: Row(
                spacing: PrSpacing.s1,
                children: [
                  ..._section(widget.leading),
                  const Spacer(),
                  if (center.isNotEmpty) ...[
                    ..._section(center),
                    const Spacer(),
                  ],
                  ..._section(widget.trailing),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _section(List<PrToolbarGroup> groups) => [
    for (final (i, group) in groups.indexed) ...[
      if (i > 0) const _Divider(),
      group,
    ],
  ];
}

/// 1px × 16px `border-subtle`, 4px either side (plus the toolbar's gap).
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 16,
    margin: const EdgeInsets.symmetric(horizontal: PrSpacing.s1),
    color: PrColors.of(context).borderSubtle,
  );
}
