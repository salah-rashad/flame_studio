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
/// Tab traversal leaves the panel at its ends instead of looping inside it,
/// and skips a panel with nothing focusable inside (rows whose keyboard
/// cursor the app owns, say).
/// Panel cycling (⌃Tab, ⌘1–⌘4) is the app's: it owns the panel order and
/// calls `requestFocus` on each panel's [node].
///
/// Part for `FsDebugStates`: `panel` (exact); [WidgetState.focused] makes
/// [of] report focus, for the gallery and goldens.
class FsPanelFocus extends StatefulWidget {
  /// Wraps [child] in a panel focus scope.
  const FsPanelFocus({super.key, this.node, required this.child});

  /// The panel's scope node; one is created when null. Create it with
  /// [createNode] so Tab can leave the panel and skips it when empty.
  final FocusScopeNode? node;

  /// A scope node for [node]: Tab leaves at the panel's ends, and the scope
  /// is a Tab stop only while something inside can take focus.
  static FocusScopeNode createNode({String? debugLabel}) =>
      _PanelScopeNode(debugLabel: debugLabel);

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
      (_ownNode ??= FsPanelFocus.createNode(debugLabel: 'FsPanelFocus'));

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = _node;
    return Actions(
      actions: {
        NextFocusIntent: _LeaveEmptyPanel<NextFocusIntent>(
          context,
          node,
          forward: true,
        ),
        PreviousFocusIntent: _LeaveEmptyPanel<PreviousFocusIntent>(
          context,
          node,
          forward: false,
        ),
      },
      child: FocusScope(
        node: node,
        child: _PanelFocusScope(
          notifier: node,
          forced: FsDebugStates.of(
            context,
            part: 'panel',
            exact: true,
          ).contains(WidgetState.focused),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Skips traversal while nothing inside can take focus, so Tab passes an
/// empty panel by instead of landing on the bare scope.
class _PanelScopeNode extends FocusScopeNode {
  _PanelScopeNode({super.debugLabel})
    : super(traversalEdgeBehavior: TraversalEdgeBehavior.parentScope);

  @override
  bool get skipTraversal => super.skipTraversal || traversalDescendants.isEmpty;

  /// Derived, never stored: `FocusScope` writes the getter's value back on
  /// mount, when the panel is still empty, which would freeze it at true.
  @override
  set skipTraversal(bool value) {}
}

/// Tab and ⇧Tab while an empty panel's scope itself holds focus (a click on
/// the panel focuses it): move on from the panel in the parent scope.
/// Flutter's own traversal finds nothing inside and keeps focus there.
///
/// Otherwise it hands the intent to the actions above [outer]: shortcuts take
/// the nearest action even when it is disabled, so this one must not be.
class _LeaveEmptyPanel<T extends Intent> extends Action<T> {
  _LeaveEmptyPanel(this.outer, this.node, {required this.forward});

  /// A context above the panel's [Actions].
  final BuildContext outer;
  final FocusScopeNode node;
  final bool forward;

  @override
  Object? invoke(T intent) {
    final parent = node.enclosingScope;
    if (parent != null &&
        node.hasPrimaryFocus &&
        node.traversalDescendants.isEmpty) {
      return forward ? parent.nextFocus() : parent.previousFocus();
    }
    return Actions.maybeInvoke<T>(outer, intent);
  }

  /// As [NextFocusAction]: a traversal that went nowhere lets the platform
  /// have the key.
  @override
  KeyEventResult toKeyEventResult(T intent, Object? invokeResult) =>
      switch (invokeResult) {
        false => KeyEventResult.skipRemainingHandlers,
        null => KeyEventResult.ignored,
        _ => KeyEventResult.handled,
      };
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
