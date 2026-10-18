import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../metrics.dart';
import '../shadows.dart';

/// The keyboard focus ring: 2px of `focus-ring`, drawn outside the edge
/// ([FsFocusRing.outside], `shadow-focus`) or inside it
/// ([FsFocusRing.inset], `shadow-focus-inset`, for rows in scrolling lists
/// where an outer ring would be clipped).
///
/// The ring is painted as a stroke, not a [BoxShadow]: a spread shadow would
/// also fill the area under a transparent child.
class FsFocusRing extends StatelessWidget {
  /// The ring outside the edge, for buttons and standalone controls.
  const FsFocusRing.outside({
    super.key,
    required this.visible,
    this.borderRadius = FsRadii.sm,
    required this.child,
  }) : _inset = false;

  /// The ring inside the edge, for rows and cells in scrolling lists.
  const FsFocusRing.inset({
    super.key,
    required this.visible,
    this.borderRadius = FsRadii.sm,
    required this.child,
  }) : _inset = true;

  /// Whether to draw the ring. Pass the `focused` state of `FsInteractive`,
  /// which is only set for keyboard focus.
  final bool visible;

  /// The corner radius the ring follows.
  final BorderRadius borderRadius;

  /// The control.
  final Widget child;

  final bool _inset;

  @override
  Widget build(BuildContext context) {
    final shadows = FsShadows.of(context);
    final (color, width) = _inset
        ? (shadows.focusInset.color, shadows.focusInset.width)
        : (shadows.focus.first.color, shadows.focus.first.spreadRadius);
    // Always a CustomPaint, so showing the ring never rebuilds the child's
    // subtree (which would cancel a gesture or reset an editor).
    return CustomPaint(
      foregroundPainter: visible
          ? FsEdgePainter(
              color: color,
              width: width,
              borderRadius: borderRadius,
              outside: !_inset,
            )
          : null,
      child: child,
    );
  }
}

/// Strokes a rounded rectangle just outside or just inside a box's edge.
///
/// Internal: used by the focus ring, the field box's outer ring and the tree
/// row's drop borders.
class FsEdgePainter extends CustomPainter {
  /// Creates the painter.
  const FsEdgePainter({
    required this.color,
    required this.width,
    required this.borderRadius,
    required this.outside,
  });

  /// Stroke colour.
  final Color color;

  /// Stroke width.
  final double width;

  /// Radius of the box the stroke follows.
  final BorderRadius borderRadius;

  /// Outside the edge (`true`) or inside it.
  final bool outside;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = borderRadius.toRRect(Offset.zero & size);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    canvas.drawRRect(
      outside ? rrect.inflate(width / 2) : rrect.deflate(width / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(FsEdgePainter oldDelegate) =>
      color != oldDelegate.color ||
      width != oldDelegate.width ||
      borderRadius != oldDelegate.borderRadius ||
      outside != oldDelegate.outside;
}

/// Whether the user is currently working with the keyboard, the Flutter
/// version of the browser's `:focus-visible` heuristic.
///
/// Flutter's `FocusHighlightMode` stays `traditional` on desktop after a
/// mouse click, so it can't tell a clicked button from a tabbed-to one. This
/// tracker flips to "keyboard" on any non-modifier key press and back to
/// "pointer" on any pointer down. Focus rings show only for keyboard
/// modality, and never in touch highlight mode.
///
/// Internal; `FsInteractive` and the rows read it.
class FsInputModality extends ChangeNotifier {
  FsInputModality._(this._manager) {
    _manager.addEarlyKeyEventHandler(_onKey);
    _manager.addHighlightModeListener(_onHighlightMode);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  static FsInputModality? _instance;

  /// The tracker, installed on first use and again whenever the
  /// [FocusManager] is replaced (as between widget tests).
  static FsInputModality get instance {
    final manager = FocusManager.instance;
    final current = _instance;
    if (current != null && current._manager == manager) return current;
    current?._uninstall();
    return _instance = FsInputModality._(manager);
  }

  final FocusManager _manager;
  bool _keyboard = false;

  void _uninstall() {
    _manager.removeEarlyKeyEventHandler(_onKey);
    _manager.removeHighlightModeListener(_onHighlightMode);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
  }

  /// Whether a focus ring may show: the last input was a key press and the
  /// highlight mode is not touch.
  bool get showsFocusRing =>
      _keyboard && _manager.highlightMode == FocusHighlightMode.traditional;

  KeyEventResult _onKey(KeyEvent event) {
    if (event is KeyDownEvent && !_isModifier(event.logicalKey)) {
      _set(true);
    }
    return KeyEventResult.ignored;
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) _set(false);
  }

  void _onHighlightMode(FocusHighlightMode mode) => notifyListeners();

  void _set(bool keyboard) {
    if (_keyboard == keyboard) return;
    _keyboard = keyboard;
    notifyListeners();
  }

  static bool _isModifier(LogicalKeyboardKey key) => _modifiers.contains(key);

  static final Set<LogicalKeyboardKey> _modifiers = {
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.fn,
  };
}
