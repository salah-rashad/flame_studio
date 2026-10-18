import 'package:flutter/widgets.dart';

/// Native help for scrubbing a number: hides the cursor and frees the drag
/// from the screen edges, so a long scrub never stops at the edge (plan
/// §7.1).
///
/// Flutter can't move or capture the pointer, so the app's macOS runner
/// implements this (for example `CGAssociateMouseAndMouseCursorPosition`
/// plus a method channel that reports the raw movement). Without it, the
/// scrub keeps the ↔ cursor visible and stops at the screen edge.
abstract interface class PrPointerLock {
  /// Hides the cursor and holds it in place for a scrub. While locked, the
  /// movement arrives through [onMove] (logical pixels) instead of pointer
  /// events. Completes with false when the lock couldn't be taken; the scrub
  /// then goes on with pointer events.
  Future<bool> lock(void Function(Offset delta) onMove);

  /// Ends the lock and shows the cursor again where the scrub started.
  Future<void> unlock();
}

/// Optional features that need native code, supplied by the app from its
/// runner. The package stays Flutter-only (Q83): each widget checks for
/// its hook and hides or simplifies the feature when it is missing, so the
/// gallery and tests run without native code.
///
/// Put one above the app (or any subtree).
class PrPlatformHooks extends InheritedWidget {
  /// Provides the hooks to [child].
  const PrPlatformHooks({
    super.key,
    this.sampleScreenColor,
    this.pointerLock,
    required super.child,
  });

  /// Picks a colour anywhere on screen (macOS `NSColorSampler`), for the
  /// colour picker's eyedropper; null result when cancelled. Without it the
  /// eyedropper button is hidden.
  final Future<Color?> Function()? sampleScreenColor;

  /// Cursor hiding and edge wrapping while scrubbing numbers.
  final PrPointerLock? pointerLock;

  /// The hooks above [context], or null.
  static PrPlatformHooks? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrPlatformHooks>();

  @override
  bool updateShouldNotify(PrPlatformHooks oldWidget) =>
      sampleScreenColor != oldWidget.sampleScreenColor ||
      pointerLock != oldWidget.pointerLock;
}
