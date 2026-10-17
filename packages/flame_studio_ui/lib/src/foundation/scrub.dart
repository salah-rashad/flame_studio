import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'number_editing.dart';

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
/// Internal. Cursor hiding and wrapping at the screen edges need native code
/// (plan §7.1) and come with `FsPointerLock`; until then the cursor stays
/// visible and a second drag continues from the new value.
class FsScrubRegion extends StatelessWidget {
  /// Wraps [child]; does nothing extra when [handle] is null.
  const FsScrubRegion({super.key, required this.handle, required this.child});

  /// What to call; null disables scrubbing.
  final FsScrubHandle? handle;

  /// The label or axis letter.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final handle = this.handle;
    if (handle == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (_) => handle.onStart(),
        onHorizontalDragUpdate: (details) {
          final keys = HardwareKeyboard.instance;
          handle.onUpdate(
            details.delta.dx,
            FsNumberEditing.modifierMultiplier(
              shift: keys.isShiftPressed,
              alt: keys.isAltPressed,
            ),
          );
        },
        onHorizontalDragEnd: (_) => handle.onEnd(),
        child: child,
      ),
    );
  }
}
