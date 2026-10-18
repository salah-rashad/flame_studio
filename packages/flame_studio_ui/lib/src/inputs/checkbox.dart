import 'package:flutter/material.dart';

import '../colors.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../metrics.dart';

/// A 14px checkbox: `bool` fields in the inspector, the component toggle in
/// section headers, options in dialogs.
///
/// - Off: `surface-input` with a 1px `border-control` edge, `radius-xs`.
/// - On: `accent` fill and edge with a `text-on-accent` check. Mixed
///   ([value] null): the same with a dash.
/// - Hover: edge `border-strong` (on: `accent-hover`). Pressed:
///   `surface-pressed` (on: `accent-pressed`). Keyboard focus: the 2px
///   ring outside.
/// - Disabled: flat `surface-panel` and `border-subtle`; on and mixed keep
///   their mark in `text-disabled` on `surface-pressed`.
///
/// Clicking or Space calls [onChanged] with the new value; a mixed box
/// becomes checked.
class FsCheckbox extends StatelessWidget {
  /// Creates the checkbox.
  const FsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticsLabel,
    this.focusNode,
    this.autofocus = false,
  });

  /// Checked, unchecked, or null for mixed.
  final bool? value;

  /// Called with the new value; null disables the checkbox.
  final ValueChanged<bool>? onChanged;

  /// The semantics label (the row's label, the option's text).
  final String? semanticsLabel;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// The box's edge length.
  static const double size = 14;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final onChanged = this.onChanged;
    final value = this.value;
    return FsInteractive(
      onPressed: onChanged == null ? null : () => onChanged(!(value ?? false)),
      focusNode: focusNode,
      autofocus: autofocus,
      semanticsLabel: semanticsLabel,
      semanticsChecked: value ?? false,
      semanticsMixed: value == null,
      builder: (context, states) {
        final disabled = states.contains(WidgetState.disabled);
        final pressed = states.contains(WidgetState.pressed);
        final hovered = states.contains(WidgetState.hovered);
        final marked = value != false;
        final Color fill;
        final Color edge;
        final Color mark;
        if (disabled) {
          fill = marked ? c.surfacePressed : c.surfacePanel;
          edge = marked ? c.surfacePressed : c.borderSubtle;
          mark = c.textDisabled;
        } else if (marked) {
          fill = pressed
              ? c.accentPressed
              : hovered
              ? c.accentHover
              : c.accent;
          edge = fill;
          mark = c.textOnAccent;
        } else {
          fill = pressed ? c.surfacePressed : c.surfaceInput;
          edge = pressed || hovered ? c.borderStrong : c.borderControl;
          mark = c.textOnAccent;
        }
        return FsFocusRing.outside(
          visible: states.contains(WidgetState.focused),
          borderRadius: FsRadii.xs,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: edge),
              borderRadius: FsRadii.xs,
            ),
            child: CustomPaint(
              painter: marked
                  ? FsCheckMarkPainter(color: mark, dash: value == null)
                  : null,
            ),
          ),
        );
      },
    );
  }
}

/// Draws the check (or the mixed dash) of [FsCheckbox]: Lucide's `check`
/// and `minus` paths with a heavier stroke than the icon font has (the
/// design's stroke-width 3 at 12px).
///
/// Internal.
class FsCheckMarkPainter extends CustomPainter {
  /// Creates the painter.
  const FsCheckMarkPainter({required this.color, required this.dash});

  /// Stroke colour.
  final Color color;

  /// The mixed dash instead of the check.
  final bool dash;

  @override
  void paint(Canvas canvas, Size size) {
    // The 24-unit icon grid, scaled to a 12px glyph centred in the box.
    const glyph = 12.0;
    const unit = glyph / 24;
    canvas
      ..save()
      ..translate((size.width - glyph) / 2, (size.height - glyph) / 2)
      ..scale(unit);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = dash
        ? (Path()
            ..moveTo(5, 12)
            ..lineTo(19, 12))
        : (Path()
            ..moveTo(20, 6)
            ..lineTo(9, 17)
            ..lineTo(4, 12));
    canvas
      ..drawPath(path, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(FsCheckMarkPainter oldDelegate) =>
      color != oldDelegate.color || dash != oldDelegate.dash;
}

/// A 28×16 switch, only for things that take effect at once and aren't
/// saved to the scene ("Pause on error"). Data fields use [FsCheckbox].
///
/// - Off: `surface-pressed` track with a `border-control` edge, a 10px
///   `text-secondary` knob on the left.
/// - On: `accent` track and edge, the knob on the right in
///   `text-on-accent`.
/// - Hover: edge `border-strong` and knob `text-primary` (on:
///   `accent-hover` track). Pressed: the knob widens to 12px. Keyboard
///   focus: the 2px ring outside.
/// - Disabled: `surface-panel` track, `border-subtle` edge,
///   `text-disabled` knob.
///
/// The knob slides in 100ms. Clicking or Space flips the value.
class FsSwitch extends StatelessWidget {
  /// Creates the switch.
  const FsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticsLabel,
    this.focusNode,
    this.autofocus = false,
  });

  /// On or off.
  final bool value;

  /// Called with the new value; null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// The semantics label.
  final String? semanticsLabel;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// The track's size.
  static const Size size = Size(28, 16);

  static const double _knob = 10;
  static const double _inset = 2;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final onChanged = this.onChanged;
    return FsInteractive(
      onPressed: onChanged == null ? null : () => onChanged(!value),
      focusNode: focusNode,
      autofocus: autofocus,
      semanticsLabel: semanticsLabel,
      semanticsToggled: value,
      builder: (context, states) {
        final disabled = states.contains(WidgetState.disabled);
        final pressed = states.contains(WidgetState.pressed) && !disabled;
        final hovered = states.contains(WidgetState.hovered) && !disabled;
        final Color track;
        final Color edge;
        final Color knob;
        if (disabled) {
          track = c.surfacePanel;
          edge = c.borderSubtle;
          knob = c.textDisabled;
        } else if (value) {
          track = hovered || pressed ? c.accentHover : c.accent;
          edge = track;
          knob = c.textOnAccent;
        } else {
          track = c.surfacePressed;
          edge = hovered || pressed ? c.borderStrong : c.borderControl;
          knob = hovered || pressed ? c.textPrimary : c.textSecondary;
        }
        final knobWidth = pressed ? _knob + 2 : _knob;
        // Inside the 1px edge: 26px wide, so on puts the knob at 14.
        final inner = size.width - 2;
        final left = value ? inner - _inset - knobWidth : _inset;
        return FsFocusRing.outside(
          visible: states.contains(WidgetState.focused),
          borderRadius: FsRadii.full,
          child: Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              color: track,
              border: Border.all(color: edge),
              borderRadius: FsRadii.full,
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: FsMotion.fast,
                  curve: FsMotion.enter,
                  left: left,
                  top: _inset,
                  width: knobWidth,
                  height: _knob,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: knob,
                      borderRadius: FsRadii.full,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
