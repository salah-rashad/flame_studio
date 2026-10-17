import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../foundation/debug_states.dart';
import '../foundation/interactive.dart';
import '../foundation/number_editing.dart';

/// The slider of `FsNumberProperty`'s range variant: a 4px
/// `border-control` track with an `accent` fill and a 12px `text-primary`
/// thumb (2px `surface-panel` edge) in a 20px-high box.
///
/// - Hover grows the thumb to 14px; while dragging (or while the row's
///   label scrubs, [active]) the fill is `accent-hover`; keyboard focus
///   rings the thumb in `focus-ring`.
/// - Disabled: `surface-pressed` track, `text-disabled` fill and thumb.
///   Mixed ([value] null): the track only.
/// - A press jumps to the pointer and dragging follows it, snapped to
///   [step]: [onChanged] while moving, [onCommit] once on release. ← →
///   step (Shift ×10, Alt ×0.1) and commit each step.
///
/// Internal. Part for `FsDebugStates`: `slider`.
class FsRangeSlider extends StatefulWidget {
  /// Creates the slider.
  const FsRangeSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    this.kind = FsNumberKind.double,
    this.active = false,
    required this.onChanged,
    required this.onCommit,
    this.semanticsLabel,
  });

  /// The value; null draws the track only (mixed).
  final double? value;

  /// The left end.
  final double min;

  /// The right end.
  final double max;

  /// Values snap to multiples of this from [min].
  final double step;

  /// Int or double.
  final FsNumberKind kind;

  /// Draw as dragged (the row's label is scrubbing).
  final bool active;

  /// Continuous; null disables the slider.
  final ValueChanged<double>? onChanged;

  /// Once per drag or key step.
  final ValueChanged<double>? onCommit;

  /// The semantics label.
  final String? semanticsLabel;

  @override
  State<FsRangeSlider> createState() => _FsRangeSliderState();
}

class _FsRangeSliderState extends State<FsRangeSlider> {
  bool _dragging = false;
  double? _start;
  double? _last;

  static const double _thumb = 12;
  static const double _track = 4;

  bool get _enabled => widget.onChanged != null && widget.max > widget.min;

  double _fraction(double value) =>
      ((value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

  double _snap(double raw) {
    final step = widget.step;
    final steps = ((raw - widget.min) / step).round();
    final decimals = math.max(
      FsNumberEditing.decimalsOf(step),
      FsNumberEditing.decimalsOf(widget.min),
    );
    var value = widget.min + steps * step;
    value = widget.kind == FsNumberKind.int
        ? value.roundToDouble()
        : FsNumberEditing.roundTo(value, decimals);
    return FsNumberEditing.clamp(value, min: widget.min, max: widget.max);
  }

  void _moveTo(double dx, double width) {
    final usable = math.max(1.0, width - _thumb);
    final fraction = ((dx - _thumb / 2) / usable).clamp(0.0, 1.0);
    final value = _snap(widget.min + fraction * (widget.max - widget.min));
    if (value == _last) return;
    _last = value;
    widget.onChanged?.call(value);
  }

  void _down(Offset local, double width) {
    if (!_enabled) return;
    setState(() => _dragging = true);
    _start = widget.value;
    _last = widget.value;
    _moveTo(local.dx, width);
  }

  void _up() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    final last = _last;
    if (last != null && last != _start) widget.onCommit?.call(last);
  }

  void _key(int direction) {
    final value = widget.value;
    if (!_enabled || value == null) return;
    final keys = HardwareKeyboard.instance;
    final next = FsNumberEditing.step(
      value,
      direction,
      step: widget.step,
      multiplier: FsNumberEditing.modifierMultiplier(
        shift: keys.isShiftPressed,
        alt: keys.isAltPressed,
      ),
      kind: widget.kind,
      min: widget.min,
      max: widget.max,
    );
    if (next == value) return;
    widget.onChanged?.call(next);
    widget.onCommit?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final forced = FsDebugStates.of(context, part: 'slider', exact: true);
    return FsInteractive(
      enabled: _enabled,
      focusable: _enabled,
      semanticsLabel: widget.semanticsLabel,
      cursor: SystemMouseCursors.click,
      shortcuts: {
        for (final shift in [false, true])
          for (final alt in [false, true]) ...{
            SingleActivator(
              LogicalKeyboardKey.arrowRight,
              shift: shift,
              alt: alt,
            ): const _StepIntent(
              1,
            ),
            SingleActivator(
              LogicalKeyboardKey.arrowLeft,
              shift: shift,
              alt: alt,
            ): const _StepIntent(
              -1,
            ),
          },
      },
      actions: {
        _StepIntent: CallbackAction<_StepIntent>(
          onInvoke: (intent) {
            _key(intent.direction);
            return null;
          },
        ),
      },
      builder: (context, states) {
        final all = {...states, ...forced};
        final disabled = all.contains(WidgetState.disabled);
        final hovered = all.contains(WidgetState.hovered) && !disabled;
        final pressed =
            !disabled &&
            (_dragging || widget.active || all.contains(WidgetState.pressed));
        final focused = all.contains(WidgetState.focused) && !disabled;
        final value = widget.value;
        final thumb = hovered || pressed ? _thumb + 2 : _thumb;
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragDown: (d) => _down(d.localPosition, width),
              onHorizontalDragUpdate: (d) {
                if (_dragging) _moveTo(d.localPosition.dx, width);
              },
              onHorizontalDragEnd: (_) => _up(),
              onHorizontalDragCancel: _up,
              child: SizedBox(
                height: 20,
                child: CustomPaint(
                  painter: _SliderPainter(
                    fraction: value == null ? null : _fraction(value),
                    track: disabled ? c.surfacePressed : c.borderControl,
                    fill: disabled
                        ? c.textDisabled
                        : (pressed ? c.accentHover : c.accent),
                    thumb: disabled ? c.textDisabled : c.textPrimary,
                    thumbEdge: c.surfacePanel,
                    ring: focused ? c.focusRing : null,
                    thumbSize: thumb,
                    reserve: _thumb,
                    trackHeight: _track,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StepIntent extends Intent {
  const _StepIntent(this.direction);

  final int direction;
}

class _SliderPainter extends CustomPainter {
  const _SliderPainter({
    required this.fraction,
    required this.track,
    required this.fill,
    required this.thumb,
    required this.thumbEdge,
    required this.ring,
    required this.thumbSize,
    required this.reserve,
    required this.trackHeight,
  });

  final double? fraction;
  final Color track;
  final Color fill;
  final Color thumb;
  final Color thumbEdge;
  final Color? ring;
  final double thumbSize;
  final double reserve;
  final double trackHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final radius = Radius.circular(trackHeight / 2);
    final bar = Rect.fromLTWH(0, cy - trackHeight / 2, size.width, trackHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, radius),
      Paint()..color = track,
    );
    final f = fraction;
    if (f == null) return;
    // The thumb's centre stays half a thumb inside each end.
    final cx = reserve / 2 + f * (size.width - reserve);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, bar.top, cx, bar.bottom),
        radius,
      ),
      Paint()..color = fill,
    );
    final center = Offset(cx, cy);
    final r = thumbSize / 2;
    final ring = this.ring;
    if (ring != null) {
      canvas.drawCircle(center, r + 2, Paint()..color = ring);
    }
    canvas
      ..drawCircle(center, r, Paint()..color = thumbEdge)
      ..drawCircle(center, r - 2, Paint()..color = thumb);
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      fraction != old.fraction ||
      track != old.track ||
      fill != old.fill ||
      thumb != old.thumb ||
      thumbEdge != old.thumbEdge ||
      ring != old.ring ||
      thumbSize != old.thumbSize;
}
