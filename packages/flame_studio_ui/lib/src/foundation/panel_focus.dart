import 'package:flutter/widgets.dart';

import 'debug_states.dart';

/// Tells the widgets inside a panel whether the panel has keyboard focus.
///
/// A [FocusScope] (so focus anywhere inside counts, and requesting focus on
/// [node] returns to the last focused widget in the panel) plus an
/// [InheritedNotifier] that rebuilds readers when the panel gains or loses
/// focus. Tree rows, tabs and list rows read it to choose `surface-selected`
/// or `surface-selected-inactive`; `FsPanel` uses it for its header.
///
/// Tab traversal leaves the panel at its ends instead of looping inside it.
/// Panel cycling (⌃Tab, ⌘1–⌘4) is the app's: it owns the panel order and
/// calls `requestFocus` on each panel's [node].
///
/// Part for `FsDebugStates`: `panel` (exact); [WidgetState.focused] makes
/// [of] report focus, for the gallery and goldens.
class FsPanelFocus extends StatefulWidget {
  /// Wraps [child] in a panel focus scope.
  const FsPanelFocus({super.key, this.node, required this.child});

  /// The panel's scope node; one is created when null. Create it with
  /// `traversalEdgeBehavior: TraversalEdgeBehavior.parentScope` so Tab can
  /// leave the panel.
  final FocusScopeNode? node;

  /// The panel's content.
  final Widget child;

  /// Whether the panel around [context] has focus; true outside any panel.
  static bool of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_PanelFocusScope>();
    if (scope == null) return true;
    return scope.forced || (scope.notifier?.hasFocus ?? false);
  }

  @override
  State<FsPanelFocus> createState() => _FsPanelFocusState();
}

class _FsPanelFocusState extends State<FsPanelFocus> {
  FocusScopeNode? _ownNode;

  FocusScopeNode get _node =>
      widget.node ??
      (_ownNode ??= FocusScopeNode(
        debugLabel: 'FsPanelFocus',
        traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
      ));

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _node,
      child: _PanelFocusScope(
        notifier: _node,
        forced: FsDebugStates.of(
          context,
          part: 'panel',
          exact: true,
        ).contains(WidgetState.focused),
        child: widget.child,
      ),
    );
  }
}

class _PanelFocusScope extends InheritedNotifier<FocusScopeNode> {
  const _PanelFocusScope({
    required super.notifier,
    required this.forced,
    required super.child,
  });

  final bool forced;

  @override
  bool updateShouldNotify(_PanelFocusScope oldWidget) =>
      forced != oldWidget.forced || super.updateShouldNotify(oldWidget);
}
