import 'package:flutter/material.dart';

import '../actions/icon_button.dart';
import '../actions/toggle_button.dart';
import '../colors.dart';
import '../foundation/debug_states.dart';
import '../foundation/number_editing.dart';
import '../foundation/scrub.dart';
import '../foundation/value_source.dart';
import '../icons.dart';
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
///   Scrubbing and editing behave as in `PrNumberProperty`.
/// - Each axis can be mixed ("—" in that field only). The callbacks get
///   null for an axis that is mixed and wasn't changed.
/// - **Aspect lock** ([aspectLocked] not null, for `scale` and `size`): a
///   20px link toggle after the fields. While locked, editing, stepping or
///   scrubbing one axis scales the other by the same factor, inside the
///   widget, so [onChanged] and [onCommit] already get the locked pair.
///   Scrubbing the label scales both. An axis that is mixed or zero has no
///   ratio to keep; then the axes change on their own.
/// - Tab order X → Y (→ the lock) → next row.
///
/// Parts for `PrDebugStates`: `row`, `label`, `x` and `y`.
class PrVector2Property extends StatefulWidget {
  /// Creates the row.
  const PrVector2Property({
    super.key,
    required this.label,
    required this.x,
    required this.y,
    this.mixedX = false,
    this.mixedY = false,
    this.step = 1,
    this.source = PrValueSource.codeDefault,
    this.onReset,
    this.resetTooltip,
    this.tooltip,
    required this.onChanged,
    required this.onCommit,
    this.invalidMessage,
    this.enabled = true,
    this.aspectLocked,
    this.onAspectLockChanged,
    this.aspectLockTooltip,
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
  final PrValueSource source;

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

  /// Whether X and Y keep their ratio; null shows no lock button.
  final bool? aspectLocked;

  /// The lock button was toggled; null disables the button.
  final ValueChanged<bool>? onAspectLockChanged;

  /// The lock button's tooltip ("Lock aspect ratio").
  final String? aspectLockTooltip;

  @override
  State<PrVector2Property> createState() => _FsVector2PropertyState();
}

enum _Axis { x, y }

class _FsVector2PropertyState extends State<PrVector2Property> {
  final _focusX = FocusNode(debugLabel: 'x');
  final _focusY = FocusNode(debugLabel: 'y');
  PrScrub? _scrub;
  _Axis? _scrubbed; // null: the label scrubs both axes (unlocked)
  (double?, double?) _scrubStart = (null, null);
  (double?, double?)? _live;
  bool _labelScrub = false;
  String? _errorX;
  String? _errorY;
  PrScrub? _scrubX;
  PrScrub? _scrubY;

  double? get _x => widget.mixedX ? null : widget.x;
  double? get _y => widget.mixedY ? null : widget.y;

  /// The lock applies: on, and both axes known.
  bool get _locked => widget.aspectLocked == true && _x != null && _y != null;

  @override
  void dispose() {
    _focusX.dispose();
    _focusY.dispose();
    super.dispose();
  }

  /// The pair after [axis] became [value], keeping the ratio of [from]
  /// while locked.
  (double?, double?) _pair(_Axis axis, double value, (double?, double?) from) {
    final (fx, fy) = from;
    if (!_locked || fx == null || fy == null) {
      return axis == _Axis.x ? (value, fy) : (fx, value);
    }
    final source = axis == _Axis.x ? fx : fy;
    if (source == 0) return axis == _Axis.x ? (value, fy) : (fx, value);
    final other = (axis == _Axis.x ? fy : fx) * value / source;
    final rounded = PrNumberEditing.roundTo(other, PrNumberEditing.maxDecimals);
    return axis == _Axis.x ? (value, rounded) : (rounded, value);
  }

  void _start(Set<_Axis> axes, {bool label = false}) {
    _focusX.unfocus();
    _focusY.unfocus();
    final start = (_x, _y);
    setState(() {
      _labelScrub = label;
      _scrubStart = start;
      _live = start;
      if (_locked) {
        // One axis drives; the other follows its ratio. The label drives X
        // unless X is 0 (no ratio to scale).
        final driver = axes.length == 1
            ? axes.single
            : (_x != 0 ? _Axis.x : _Axis.y);
        _scrubbed = driver;
        _scrubX = driver == _Axis.x ? _scrubFrom(_x) : null;
        _scrubY = driver == _Axis.y ? _scrubFrom(_y) : null;
      } else {
        _scrubbed = null;
        _scrubX = axes.contains(_Axis.x) ? _scrubFrom(_x) : null;
        _scrubY = axes.contains(_Axis.y) ? _scrubFrom(_y) : null;
      }
      _scrub = _scrubX ?? _scrubY;
    });
  }

  PrScrub? _scrubFrom(double? value) =>
      value == null ? null : PrScrub(start: value, step: widget.step);

  void _update(double dx, double multiplier) {
    if (_scrub == null) return;
    final before = _live;
    _scrubX?.update(dx, multiplier: multiplier);
    _scrubY?.update(dx, multiplier: multiplier);
    final driver = _scrubbed;
    final next = driver == null
        ? (_scrubX?.value ?? _x, _scrubY?.value ?? _y)
        : _pair(
            driver,
            (driver == _Axis.x ? _scrubX : _scrubY)!.value,
            _scrubStart,
          );
    if (next == before) return;
    setState(() => _live = next);
    widget.onChanged(next.$1, next.$2);
  }

  void _end() {
    if (_scrub == null) return;
    final live = _live;
    setState(() {
      _scrub = null;
      _scrubX = null;
      _scrubY = null;
      _scrubbed = null;
      _live = null;
      _labelScrub = false;
    });
    if (live != null && live != _scrubStart) {
      widget.onCommit(live.$1, live.$2);
    }
  }

  PrScrubHandle? _handle(Set<_Axis> axes, {bool label = false}) {
    final usable = axes.where((a) => (a == _Axis.x ? _x : _y) != null).toSet();
    if (usable.isEmpty || !widget.enabled) return null;
    return PrScrubHandle(
      onStart: () => _start(usable, label: label),
      onUpdate: _update,
      onEnd: _end,
      active: label && _labelScrub,
    );
  }

  Widget _field(_Axis axis) {
    final isX = axis == _Axis.x;
    final live = _live;
    final scrubbing = _scrub != null;
    final value = live == null ? (isX ? _x : _y) : (isX ? live.$1 : live.$2);
    final mixed = isX ? widget.mixedX : widget.mixedY;
    // While locked, a scrub moves both fields, so both show the accent.
    final moving =
        scrubbing &&
        (_scrubbed == null ? (isX ? _scrubX : _scrubY) != null : true);
    void set(double v, void Function(double? x, double? y) callback) {
      final (x, y) = _pair(axis, v, (_x, _y));
      callback(x, y);
    }

    return PrNumberInput(
      value: value,
      mixed: mixed && !moving,
      focusNode: isX ? _focusX : _focusY,
      step: widget.step,
      scrubbing: moving,
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
    final locked = widget.aspectLocked;
    final onLock = widget.onAspectLockChanged;
    return PrPropertyRow(
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
            const SizedBox(width: PrSpacing.s1),
            Expanded(child: _field(_Axis.y)),
            if (locked != null) ...[
              const SizedBox(width: PrSpacing.s1),
              PrToggleButton(
                icon: PrIcons.link,
                value: locked,
                tooltip: widget.aspectLockTooltip ?? '',
                size: PrIconButtonSize.small,
                iconSize: 12,
                onChanged: widget.enabled ? onLock : null,
              ),
            ],
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
    final row = PrPropertyRowScope.of(context);
    if (row == null) return child;
    return PrPropertyRowScope(
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
  final PrScrubHandle? scrub;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final forced = PrDebugStates.of(context, part: axis == _Axis.x ? 'x' : 'y');
    final Color ink;
    if (!enabled || forced.contains(WidgetState.disabled)) {
      ink = c.textDisabled;
    } else {
      ink = axis == _Axis.x ? c.axisX : c.axisY;
    }
    return PrScrubRegion(
      handle: scrub,
      child: Container(
        width: PrSpacing.s4,
        height: 18,
        margin: const EdgeInsetsDirectional.only(end: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: BorderDirectional(end: BorderSide(color: c.borderSubtle)),
        ),
        child: Text(
          axis == _Axis.x ? 'X' : 'Y',
          style: PrText.caption.copyWith(
            color: ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
