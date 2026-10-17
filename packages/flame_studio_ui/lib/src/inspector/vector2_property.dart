import 'package:flutter/material.dart';

import '../colors.dart';
import '../foundation/debug_states.dart';
import '../foundation/number_editing.dart';
import '../foundation/scrub.dart';
import '../foundation/value_source.dart';
import '../metrics.dart';
import '../typography.dart';
import 'number_input.dart';
import 'property_row.dart';

/// A `Vector2` inspector row: X and Y fields side by side, each starting
/// with a coloured axis letter that scrubs that axis.
///
/// - Two 20px fields 4px apart; each starts with a 16px axis cell ("X" in
///   `axis-x`, "Y" in `axis-y`, 11/600) separated by a 1px `border-subtle`
///   line.
/// - Drag a letter to scrub that axis; drag the row label to scrub both.
///   Scrubbing and editing behave as in `FsNumberProperty`.
/// - Each axis can be mixed ("—" in that field only). The callbacks get
///   null for an axis that is mixed and wasn't changed.
/// - Tab order X → Y → next row.
///
/// Not yet: the aspect lock.
///
/// Parts for `FsDebugStates`: `row`, `label`, `x` and `y`.
class FsVector2Property extends StatefulWidget {
  /// Creates the row.
  const FsVector2Property({
    super.key,
    required this.label,
    required this.x,
    required this.y,
    this.mixedX = false,
    this.mixedY = false,
    this.step = 1,
    this.source = FsValueSource.codeDefault,
    this.onReset,
    this.resetTooltip,
    this.tooltip,
    required this.onChanged,
    required this.onCommit,
    this.invalidMessage,
    this.enabled = true,
  });

  /// The field's Dart name.
  final String label;

  /// X; null when [mixedX].
  final double? x;

  /// Y; null when [mixedY].
  final double? y;

  /// The selected objects disagree on X.
  final bool mixedX;

  /// The selected objects disagree on Y.
  final bool mixedY;

  /// The scrub and ↑/↓ step at ×1.
  final double step;

  /// Default from code or overridden.
  final FsValueSource source;

  /// Restores the default; shown when overridden.
  final VoidCallback? onReset;

  /// The reset button's tooltip.
  final String? resetTooltip;

  /// The label's tooltip.
  final String? tooltip;

  /// Continuous, with both axes (null for a mixed, unchanged axis).
  final void Function(double? x, double? y) onChanged;

  /// Once per scrub gesture, step or edit.
  final void Function(double? x, double? y) onCommit;

  /// The message for text that isn't a number.
  final String? invalidMessage;

  /// False disables the row.
  final bool enabled;

  @override
  State<FsVector2Property> createState() => _FsVector2PropertyState();
}

enum _Axis { x, y }

class _FsVector2PropertyState extends State<FsVector2Property> {
  final _focusX = FocusNode(debugLabel: 'x');
  final _focusY = FocusNode(debugLabel: 'y');
  FsScrub? _scrubX;
  FsScrub? _scrubY;
  (double?, double?) _scrubStart = (null, null);
  bool _labelScrub = false;
  String? _errorX;
  String? _errorY;

  double? get _x => widget.mixedX ? null : widget.x;
  double? get _y => widget.mixedY ? null : widget.y;

  @override
  void dispose() {
    _focusX.dispose();
    _focusY.dispose();
    super.dispose();
  }

  FsScrub? _scrubFrom(double? value) =>
      value == null ? null : FsScrub(start: value, step: widget.step);

  void _start(Set<_Axis> axes, {bool label = false}) {
    _focusX.unfocus();
    _focusY.unfocus();
    setState(() {
      _labelScrub = label;
      if (axes.contains(_Axis.x)) _scrubX = _scrubFrom(_x);
      if (axes.contains(_Axis.y)) _scrubY = _scrubFrom(_y);
      _scrubStart = (_x, _y);
    });
  }

  void _update(double dx, double multiplier) {
    if (_scrubX == null && _scrubY == null) return;
    final before = (_scrubX?.value, _scrubY?.value);
    _scrubX?.update(dx, multiplier: multiplier);
    _scrubY?.update(dx, multiplier: multiplier);
    if ((_scrubX?.value, _scrubY?.value) == before) return;
    setState(() {});
    widget.onChanged(_scrubX?.value ?? _x, _scrubY?.value ?? _y);
  }

  void _end() {
    final (sx, sy) = (_scrubX, _scrubY);
    if (sx == null && sy == null) return;
    setState(() {
      _scrubX = null;
      _scrubY = null;
      _labelScrub = false;
    });
    final (startX, startY) = _scrubStart;
    final changed =
        (sx != null && sx.value != startX) ||
        (sy != null && sy.value != startY);
    if (changed) widget.onCommit(sx?.value ?? _x, sy?.value ?? _y);
  }

  FsScrubHandle? _handle(Set<_Axis> axes, {bool label = false}) {
    final usable = axes.where((a) => (a == _Axis.x ? _x : _y) != null).toSet();
    if (usable.isEmpty || !widget.enabled) return null;
    return FsScrubHandle(
      onStart: () => _start(usable, label: label),
      onUpdate: _update,
      onEnd: _end,
      active: label && _labelScrub,
    );
  }

  Widget _field(_Axis axis) {
    final isX = axis == _Axis.x;
    final scrub = isX ? _scrubX : _scrubY;
    final value = isX ? _x : _y;
    final mixed = isX ? widget.mixedX : widget.mixedY;
    void set(double v, void Function(double? x, double? y) callback) =>
        isX ? callback(v, _y) : callback(_x, v);
    return FsNumberInput(
      value: scrub?.value ?? value,
      mixed: mixed && scrub == null,
      focusNode: isX ? _focusX : _focusY,
      step: widget.step,
      scrubbing: scrub != null,
      enabled: widget.enabled,
      invalidMessage: widget.invalidMessage,
      leading: _AxisCell(
        axis: axis,
        enabled: widget.enabled,
        scrub: _handle({axis}),
      ),
      onChanged: (v) => set(v, widget.onChanged),
      onCommit: (v) => set(v, widget.onCommit),
      onErrorChanged: (error) => setState(() {
        if (isX) {
          _errorX = error;
        } else {
          _errorY = error;
        }
      }),
      debugPart: isX ? 'x' : 'y',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FsPropertyRow(
      label: widget.label,
      source: widget.source,
      onReset: widget.onReset,
      resetTooltip: widget.resetTooltip,
      tooltip: widget.tooltip,
      enabled: widget.enabled,
      error: _errorX ?? _errorY,
      labelScrub: _handle({_Axis.x, _Axis.y}, label: true),
      // The row's error goes to the field that has it, not to both.
      editor: _NoRowError(
        child: Row(
          children: [
            Expanded(child: _field(_Axis.x)),
            const SizedBox(width: FsSpacing.s1),
            Expanded(child: _field(_Axis.y)),
          ],
        ),
      ),
    );
  }
}

/// Re-provides the row scope without its error flag, so only the field
/// with the bad text shows the error border.
class _NoRowError extends StatelessWidget {
  const _NoRowError({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final row = FsPropertyRowScope.of(context);
    if (row == null) return child;
    return FsPropertyRowScope(
      hovered: row.hovered,
      source: row.source,
      mixed: row.mixed,
      readOnly: row.readOnly,
      enabled: row.enabled,
      error: false,
      child: child,
    );
  }
}

/// The 16px "X" / "Y" cell at the start of a Vector2 field: the scrub
/// handle for that axis.
class _AxisCell extends StatelessWidget {
  const _AxisCell({required this.axis, required this.enabled, this.scrub});

  final _Axis axis;
  final bool enabled;
  final FsScrubHandle? scrub;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final forced = FsDebugStates.of(context, part: axis == _Axis.x ? 'x' : 'y');
    final Color ink;
    if (!enabled || forced.contains(WidgetState.disabled)) {
      ink = c.textDisabled;
    } else {
      ink = axis == _Axis.x ? c.axisX : c.axisY;
    }
    return FsScrubRegion(
      handle: scrub,
      child: Container(
        width: FsSpacing.s4,
        height: 18,
        margin: const EdgeInsetsDirectional.only(end: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: BorderDirectional(end: BorderSide(color: c.borderSubtle)),
        ),
        child: Text(
          axis == _Axis.x ? 'X' : 'Y',
          style: FsText.caption.copyWith(
            color: ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
