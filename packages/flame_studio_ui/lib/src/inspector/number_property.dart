import 'package:flutter/widgets.dart';

import '../foundation/number_editing.dart';
import '../foundation/scrub.dart';
import '../foundation/value_source.dart';
import 'number_input.dart';
import 'property_row.dart';

/// An `int` or `double` inspector row whose label is a scrub handle.
///
/// - **Scrub:** press on the label and drag: 1 step per 2px, Shift ×10,
///   Alt ×0.1. The label and the field border turn `accent-text` and the
///   cursor is ↔. [onChanged] fires while dragging, [onCommit] once when
///   the drag ends (one undo entry per gesture). With an `FsPointerLock`
///   from `FsPlatformHooks` the cursor hides and the scrub doesn't stop at
///   the screen edge; without one it stays visible (plan §7.1) and a second
///   drag continues from the new value.
/// - **Edit:** click or Tab in edits with the value selected; Enter, Tab or
///   clicking elsewhere commits; Esc reverts; ↑/↓ step (Shift ×10).
/// - **Invalid text** (not a number, outside [min]…[max], or rejected by
///   [validator]) keeps the typed text with an `error` border and the
///   message in the label's tooltip until it is fixed or Esc.
///
/// Not yet: expressions (`32*2`, `+=8`) and the range-slider variant.
///
/// Parts for `FsDebugStates`: `row`, `label` (from [FsPropertyRow]) and
/// `field`.
class FsNumberProperty extends StatefulWidget {
  /// Creates the row.
  const FsNumberProperty({
    super.key,
    required this.label,
    required this.value,
    this.mixed = false,
    this.kind = FsNumberKind.double,
    this.min,
    this.max,
    this.step,
    this.unit,
    this.source = FsValueSource.codeDefault,
    this.onReset,
    this.resetTooltip,
    this.tooltip,
    required this.onChanged,
    required this.onCommit,
    this.validator,
    this.invalidMessage,
    this.enabled = true,
    this.focusNode,
  });

  /// The field's Dart name.
  final String label;

  /// The value; null when [mixed].
  final double? value;

  /// The selected objects disagree: the field shows "—" and scrubbing is
  /// off until a value is typed.
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

  /// Unit suffix: "px", "°", "px/s".
  final String? unit;

  /// Default from code or overridden.
  final FsValueSource source;

  /// Restores the default; shown when overridden.
  final VoidCallback? onReset;

  /// The reset button's tooltip.
  final String? resetTooltip;

  /// The label's tooltip (type and default value).
  final String? tooltip;

  /// Continuous: each scrub move, each ↑/↓ step, each committed edit.
  final ValueChanged<double> onChanged;

  /// Once per scrub gesture, step or edit.
  final ValueChanged<double> onCommit;

  /// Checks a typed value; a non-null result is the error message ("Expected
  /// a number between 0 and 1").
  final String? Function(double value)? validator;

  /// The message for text that isn't a number, and for out-of-range values
  /// the [validator] doesn't explain.
  final String? invalidMessage;

  /// False disables the row.
  final bool enabled;

  /// The field's focus node.
  final FocusNode? focusNode;

  @override
  State<FsNumberProperty> createState() => _FsNumberPropertyState();
}

class _FsNumberPropertyState extends State<FsNumberProperty> {
  FocusNode? _ownFocusNode;
  FsScrub? _scrub;
  double? _scrubStart;
  String? _error;

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: widget.label));

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
    _focusNode.unfocus();
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
    widget.onChanged(value);
  }

  void _endScrub() {
    final scrub = _scrub;
    if (scrub == null) return;
    setState(() => _scrub = null);
    if (scrub.value != _scrubStart) widget.onCommit(scrub.value);
  }

  @override
  Widget build(BuildContext context) {
    final scrub = _scrub;
    final canScrub = widget.value != null && !widget.mixed;
    return FsPropertyRow(
      label: widget.label,
      source: widget.source,
      onReset: widget.onReset,
      resetTooltip: widget.resetTooltip,
      tooltip: widget.tooltip,
      mixed: widget.mixed,
      enabled: widget.enabled,
      error: _error,
      labelScrub: canScrub
          ? FsScrubHandle(
              onStart: _startScrub,
              onUpdate: _updateScrub,
              onEnd: _endScrub,
              active: scrub != null,
            )
          : null,
      editor: FsNumberInput(
        value: scrub?.value ?? widget.value,
        mixed: widget.mixed && scrub == null,
        focusNode: _focusNode,
        kind: widget.kind,
        min: widget.min,
        max: widget.max,
        step: _step,
        unit: widget.unit,
        scrubbing: scrub != null,
        enabled: widget.enabled,
        validator: widget.validator,
        invalidMessage: widget.invalidMessage,
        onChanged: widget.onChanged,
        onCommit: widget.onCommit,
        onErrorChanged: (error) => setState(() => _error = error),
        debugPart: 'field',
      ),
    );
  }
}
