import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'number_editing.dart';
import 'platform_hooks.dart';

/// Makes a property row's label (or a Vector2 axis letter) a scrub handle:
/// press and drag horizontally to change the value.
///
/// Set by `FsNumberProperty` and `FsVector2Property` on their row; the
/// row only draws the label and forwards the drag.
@immutable
class FsScrubHandle {
  /// Creates a handle.
  const FsScrubHandle({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    this.active = false,
  });

  /// The drag started.
  final VoidCallback onStart;

  /// The pointer moved [dx] pixels; [multiplier] is ×10 with Shift and ×0.1
  /// with Alt held at that moment.
  final void Function(double dx, double multiplier) onUpdate;

  /// The drag ended: the moment to commit.
  final VoidCallback onEnd;

  /// A scrub is running: the label is drawn in `accent-text`.
  final bool active;
}

/// The ↔ cursor and horizontal-drag detection of a scrub handle.
///
/// Internal. When the app provides an [FsPointerLock] through
/// [FsPlatformHooks], a scrub takes the lock: the cursor hides and the
/// movement comes from the lock, so it doesn't stop at the screen edge.
/// Without one the ↔ cursor stays visible and a second drag continues from
/// the new value.
class FsScrubRegion extends StatefulWidget {
  /// Wraps [child]; does nothing extra when [handle] is null.
  const FsScrubRegion({super.key, required this.handle, required this.child});

  /// What to call; null disables scrubbing.
  final FsScrubHandle? handle;

  /// The label or axis letter.
  final Widget child;

  @override
  State<FsScrubRegion> createState() => _FsScrubRegionState();
}

class _FsScrubRegionState extends State<FsScrubRegion> {
  FsPointerLock? _lock;
  bool _locked = false;
  bool _scrubbing = false;

  static double get _multiplier {
    final keys = HardwareKeyboard.instance;
    return FsNumberEditing.modifierMultiplier(
      shift: keys.isShiftPressed,
      alt: keys.isAltPressed,
    );
  }

  void _start() {
    _scrubbing = true;
    widget.handle?.onStart();
    final lock = FsPlatformHooks.maybeOf(context)?.pointerLock;
    if (lock == null) return;
    _lock = lock;
    unawaited(
      lock.lock(_onLockedMove).then((granted) {
        if (!_scrubbing || !mounted) {
          // The scrub ended before the lock arrived.
          if (granted) unawaited(lock.unlock());
          return;
        }
        _locked = granted;
      }),
    );
  }

  void _onLockedMove(Offset delta) {
    if (_scrubbing && _locked) widget.handle?.onUpdate(delta.dx, _multiplier);
  }

  void _update(DragUpdateDetails details) {
    // While locked the pointer stands still; the lock reports the movement.
    if (!_locked) widget.handle?.onUpdate(details.delta.dx, _multiplier);
  }

  void _end() {
    _release();
    widget.handle?.onEnd();
  }

  void _release() {
    _scrubbing = false;
    final lock = _lock;
    if (lock != null && _locked) unawaited(lock.unlock());
    _lock = null;
    _locked = false;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.handle == null) return widget.child;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (_) => _start(),
        onHorizontalDragUpdate: _update,
        onHorizontalDragEnd: (_) => _end(),
        child: widget.child,
      ),
    );
  }
}
