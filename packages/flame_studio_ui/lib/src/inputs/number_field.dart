import 'package:flutter/widgets.dart';

import '../floating/tooltip.dart';
import '../foundation/field_box.dart';
import '../foundation/number_editing.dart';
import '../foundation/scrub.dart';
import '../inspector/number_input.dart';

/// A standalone number input for dialogs, toolbars and settings (grid
/// size, zoom). In the inspector use `FsNumberProperty`, whose label is the
/// scrub handle.
///
/// - The text field's box, 24px (20px [FsFieldSize.dense]); the value in
///   mono, left-aligned; [unit] in `text-secondary`; with [stepper], 12px
///   ▲▼ chevrons at the end that step the value.
/// - **Scrub:** press on the value and drag (cursor ↔): 1 step per 2px,
///   Shift ×10, Alt ×0.1, an `accent-text` border while dragging.
///   [onChanged] fires during the drag, [onCommit] once at its end.
/// - **Edit:** a click without a drag, or Tab, edits with the value
///   selected; Enter, Tab or clicking elsewhere commits; Esc reverts; ↑/↓
///   step (Shift ×10).
/// - **Invalid text** (not a number, outside [min]…[max], or rejected by
///   [validator]): `error` border, the message in a tooltip, the typed text
///   kept until fixed or Esc.
/// - Mixed shows "—" and doesn't scrub until a value is typed.
///
/// Both callbacks null disables the field. Part for `FsDebugStates`:
/// `field`.
class FsNumberField extends StatefulWidget {
  /// Creates the field.
  const FsNumberField({
    super.key,
    required this.value,
    this.mixed = false,
    this.kind = FsNumberKind.double,
    this.min,
    this.max,
    this.step,
    this.unit,
    this.stepper = true,
    this.onChanged,
    this.onCommit,
    this.validator,
    this.invalidMessage,
    this.size = FsFieldSize.regular,
    this.width,
    this.focusNode,
  });

  /// The value; null when [mixed].
  final double? value;

  /// The objects being edited disagree: "—".
  final bool mixed;

  /// Int or double.
  final FsNumberKind kind;

  /// Lower bound for scrubbing, steps and typed values.
  final double? min;

  /// Upper bound for scrubbing, steps and typed values.
  final double? max;

  /// The step at ×1. Defaults to 1, or a hundredth of the range for a
  /// bounded double.
  final double? step;

  /// Unit suffix ("px", "%").
  final String? unit;

  /// Show the ▲▼ chevrons.
  final bool stepper;

  /// Continuous: each scrub move, step and committed edit.
  final ValueChanged<double>? onChanged;

  /// Once per scrub gesture, step or edit.
  final ValueChanged<double>? onCommit;

  /// Checks a typed value; a non-null result is the error message.
  final String? Function(double value)? validator;

  /// The message for text that isn't a number, and for out-of-range values
  /// the [validator] doesn't explain.
  final String? invalidMessage;

  /// 24 or 20.
  final FsFieldSize size;

  /// A fixed width; otherwise the field fills the width it is given.
  final double? width;

  /// The focus node.
  final FocusNode? focusNode;

  @override
  State<FsNumberField> createState() => _FsNumberFieldState();
}

class _FsNumberFieldState extends State<FsNumberField> {
  FocusNode? _ownFocusNode;
  FsScrub? _scrub;
  double? _scrubStart;
  String? _error;

  /// Keeps the input's state when the error tooltip wraps it.
  final GlobalKey _inputKey = GlobalKey();

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'FsNumberField'));

  bool get _enabled => widget.onChanged != null || widget.onCommit != null;

  double get _step =>
      widget.step ??
      FsNumberEditing.defaultStep(
        widget.kind,
        min: widget.min,
        max: widget.max,
      );

  @override
  void dispose() {
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _startScrub() {
    final value = widget.value;
    if (value == null || widget.mixed) return;
    setState(() {
      _scrubStart = value;
      _scrub = FsScrub(
        start: value,
        step: _step,
        kind: widget.kind,
        min: widget.min,
        max: widget.max,
      );
    });
  }

  void _updateScrub(double dx, double multiplier) {
    final scrub = _scrub;
    if (scrub == null) return;
    final before = scrub.value;
    final value = scrub.update(dx, multiplier: multiplier);
    if (value == before) return;
    setState(() {});
    widget.onChanged?.call(value);
  }

  void _endScrub() {
    final scrub = _scrub;
    if (scrub == null) return;
    setState(() => _scrub = null);
    if (scrub.value != _scrubStart) widget.onCommit?.call(scrub.value);
  }

  @override
  Widget build(BuildContext context) {
    final scrub = _scrub;
    final canScrub = widget.value != null && !widget.mixed && _enabled;
    Widget field = FsNumberInput(
      key: _inputKey,
      value: scrub?.value ?? widget.value,
      mixed: widget.mixed && scrub == null,
      focusNode: _focusNode,
      kind: widget.kind,
      min: widget.min,
      max: widget.max,
      step: _step,
      unit: widget.unit,
      size: widget.size,
      stepper: widget.stepper,
      scrubbing: scrub != null,
      enabled: _enabled,
      validator: widget.validator,
      invalidMessage: widget.invalidMessage,
      onChanged: (v) => widget.onChanged?.call(v),
      onCommit: (v) => widget.onCommit?.call(v),
      onErrorChanged: (error) => setState(() => _error = error),
      debugPart: 'field',
      fieldScrub: canScrub
          ? FsScrubHandle(
              onStart: _startScrub,
              onUpdate: _updateScrub,
              onEnd: _endScrub,
              active: scrub != null,
            )
          : null,
    );
    final error = _error;
    if (error != null && error.isNotEmpty) {
      field = FsTooltip(message: error, error: true, child: field);
    }
    final width = widget.width;
    return width == null ? field : SizedBox(width: width, child: field);
  }
}
