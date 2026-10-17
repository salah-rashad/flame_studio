import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Forces interaction states on every `FsInteractive` (and every widget that
/// reads it) below it, so the gallery and tests can show Hover, Pressed and
/// Focused side by side like the design system's `preview.html`.
///
/// Read only in debug and profile builds; in release builds [of] always
/// returns an empty set, so a stray `FsDebugStates` changes nothing.
///
/// [WidgetState.dragged] stands for "scrubbing" in the number editors.
///
/// Widgets made of several parts that have their own states (the X and Y
/// fields of a Vector2 editor, a row's label) read the states for a named
/// [part]; set [part] to force states on that part only. The part names are
/// listed on each widget.
class FsDebugStates extends InheritedWidget {
  /// Adds [states] to every interactive widget in [child], or only to the
  /// parts named [part].
  const FsDebugStates({
    super.key,
    required this.states,
    this.part,
    required super.child,
  });

  /// The states to add.
  final Set<WidgetState> states;

  /// The part the states apply to; null for every widget.
  final String? part;

  /// The forced states above [context] that apply to [part], or an empty
  /// set. A widget without parts passes no [part] and gets only the states
  /// forced without one.
  ///
  /// The nearest `FsDebugStates` that applies wins; ones for other parts are
  /// skipped, so several can be nested to force different parts (the items
  /// of one menu).
  ///
  /// With [exact], states forced without a part don't count: for parts that
  /// stand for a situation rather than a region (a tree row's `drop-inside`).
  static Set<WidgetState> of(
    BuildContext context, {
    String? part,
    bool exact = false,
  }) {
    if (kReleaseMode) return const {};
    bool applies(FsDebugStates forced) =>
        forced.part == null ? !exact : forced.part == part;

    final nearest = context
        .getElementForInheritedWidgetOfExactType<FsDebugStates>();
    if (nearest == null) return const {};
    context.dependOnInheritedElement(nearest);
    final first = nearest.widget as FsDebugStates;
    if (applies(first)) return first.states;
    // Look further up, past ones for other parts.
    Set<WidgetState>? found;
    nearest.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is FsDebugStates && applies(widget)) {
        context.dependOnInheritedElement(element as InheritedElement);
        found = widget.states;
        return false;
      }
      return true;
    });
    return found ?? const {};
  }

  @override
  bool updateShouldNotify(FsDebugStates oldWidget) =>
      part != oldWidget.part || !setEquals(states, oldWidget.states);
}
