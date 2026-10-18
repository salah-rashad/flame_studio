import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../foundation/anchored_overlay.dart';
import '../foundation/debug_states.dart';
import '../foundation/field_box.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../foundation/number_editing.dart';
import '../foundation/value_source.dart';
import '../inputs/number_field.dart';
import '../metrics.dart';
import 'color_picker.dart';
import 'hex_input.dart';
import 'property_row.dart';

/// A `Color` inspector row: a solid swatch, an upper-case hex field and a
/// separate alpha % field.
///
/// - **Swatch** 28×16, `radius-xs`, with a 1px white-15% inner edge so dark
///   colours stay visible; drawn opaque (no checkerboard), so transparency
///   is read from the % field. A click, Enter or Space opens the
///   [FsColorPicker] popover below it; a click outside or Esc closes it.
/// - **Keyboard:** Enter or Space opens the popover with focus in its SV
///   area, ready to step with the arrows (a click leaves focus where it
///   was); Tab goes on to the hue slider, hex and alpha. In the Tab order the
///   popover sits between the swatch and the row's hex field: Tab past its
///   last control goes on to the row's hex field, ⇧Tab before its first
///   back to the swatch, and either closes it. Focus moving anywhere else
///   closes it too. Esc anywhere in it closes it and puts focus back on the
///   swatch.
/// - **Hex** in mono, `#` and six upper-case digits; the alpha is kept.
///   Text that isn't a colour gets the `error` border until fixed or Esc,
///   and the swatch keeps the last valid colour.
/// - **Alpha** 0–100 % in a 52px number field (it scrubs too).
/// - Mixed: the swatch and both fields show "—". Typing a hex sets every
///   selected object; the alpha field waits for a colour (there is none to
///   apply it to), so it is read-only while mixed.
/// - Default from code, overridden, disabled: as [FsPropertyRow].
///
/// The picker's drags and arrow-key runs call [onChanged] while moving and
/// [onCommit] once; the fields commit once per edit. [onPickerClosed]
/// reports the colour the popover was left on, for the recent colours. Parts for `FsDebugStates`: `row`,
/// `label`, `hex`, `field` (alpha), and `picker` with
/// [WidgetState.selected] (exact) to show the popover.
class FsColorProperty extends StatefulWidget {
  /// Creates the row.
  const FsColorProperty({
    super.key,
    required this.label,
    required this.value,
    this.mixed = false,
    this.source = FsValueSource.codeDefault,
    this.onReset,
    this.resetTooltip,
    this.tooltip,
    required this.onChanged,
    required this.onCommit,
    this.onPickerClosed,
    this.recentColors = const [],
    this.eyedropperTooltip,
    this.pickerAreaLabel,
    this.pickerHueLabel,
    this.enabled = true,
  });

  /// The field's Dart name.
  final String label;

  /// The colour; null when [mixed].
  final Color? value;

  /// The selected objects disagree.
  final bool mixed;

  /// Default from code or overridden.
  final FsValueSource source;

  /// Restores the default; shown when overridden.
  final VoidCallback? onReset;

  /// The reset button's tooltip.
  final String? resetTooltip;

  /// The label's tooltip (type and default value).
  final String? tooltip;

  /// Continuous: each move while dragging in the picker.
  final ValueChanged<Color> onChanged;

  /// Once per drag, field edit, swatch click or sample.
  final ValueChanged<Color> onCommit;

  /// The popover closed after the colour changed while it was open; with
  /// the colour it was left on. Where the app adds to [recentColors], so
  /// they get the colour picked, not each step on the way.
  final ValueChanged<Color>? onPickerClosed;

  /// The picker's recent colours; the app keeps the list.
  final List<Color> recentColors;

  /// The picker's eyedropper tooltip.
  final String? eyedropperTooltip;

  /// The picker's SV area semantics label (`FsColorPicker.areaLabel`).
  final String? pickerAreaLabel;

  /// The picker's hue slider semantics label (`FsColorPicker.hueLabel`).
  final String? pickerHueLabel;

  /// False disables the row.
  final bool enabled;

  @override
  State<FsColorProperty> createState() => _FsColorPropertyState();
}

class _FsColorPropertyState extends State<FsColorProperty> {
  final _overlay = OverlayPortalController();
  final _hexFocus = FocusNode(debugLabel: 'hex');
  final _swatchFocus = FocusNode(debugLabel: 'swatch');

  /// The popover's scope. Tab stops at its edges (`_PickerTab` takes over
  /// there), and a field that lets go of focus (its Esc) leaves focus on
  /// the scope itself.
  final _pickerScope = FocusScopeNode(
    debugLabel: 'picker',
    traversalEdgeBehavior: TraversalEdgeBehavior.stop,
  );
  bool _debugOpen = false;

  /// A pointer is down on the swatch: the press it ends in is a click.
  bool _pointerDown = false;

  /// The popover was opened from the keyboard: it takes focus.
  bool _focusPicker = false;

  /// The colour when the popover opened, for [FsColorProperty.onPickerClosed].
  Color? _openedWith;

  @override
  void initState() {
    super.initState();
    _swatchFocus.addListener(_onFocusMoved);
    _pickerScope.addListener(_onFocusMoved);
  }

  Color? get _value => widget.mixed ? null : widget.value;

  @override
  void didUpdateWidget(FsColorProperty oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _overlay.isShowing) _close();
  }

  @override
  void dispose() {
    _swatchFocus.removeListener(_onFocusMoved);
    _pickerScope.removeListener(_onFocusMoved);
    _hexFocus.dispose();
    _swatchFocus.dispose();
    _pickerScope.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_overlay.isShowing) {
      _close();
    } else {
      _focusPicker = !_pointerDown;
      _openedWith = _value;
      setState(_overlay.show);
    }
  }

  void _close() {
    if (!_overlay.isShowing) return;
    setState(_overlay.hide);
    final onClosed = widget.onPickerClosed;
    final color = _value;
    if (onClosed == null || color == null || color == _openedWith) return;
    // Closed from didUpdateWidget (disabled): report after the build.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onClosed(color));
    } else {
      onClosed(color);
    }
  }

  /// A click outside or Esc: close, and don't strand focus in the popover.
  void _dismiss() {
    final inPicker = _pickerScope.hasFocus;
    _close();
    if (inPicker) _swatchFocus.requestFocus();
  }

  /// Tab past the popover's last control, or ⇧Tab before its first.
  void _leavePicker({required bool forward}) {
    _close();
    (forward ? _hexFocus : _swatchFocus).requestFocus();
  }

  void _onFocusMoved() {
    if (!_overlay.isShowing) return;
    if (_pickerScope.hasPrimaryFocus) {
      // A field in the popover let go of focus: its Esc.
      _close();
      _swatchFocus.requestFocus();
    } else if (!_swatchFocus.hasFocus && !_pickerScope.hasFocus) {
      _close();
    }
  }

  void _commit(Color color) {
    widget.onChanged(color);
    widget.onCommit(color);
  }

  Widget _picker(BuildContext context) => FocusScope(
    node: _pickerScope,
    child: Actions(
      actions: {
        NextFocusIntent: _PickerTab<NextFocusIntent>(this, forward: true),
        PreviousFocusIntent: _PickerTab<PreviousFocusIntent>(
          this,
          forward: false,
        ),
      },
      child: FsColorPicker(
        // A mixed row starts the picker from white.
        value: _value ?? FsSwatchInk.marker,
        recentColors: widget.recentColors,
        eyedropperTooltip: widget.eyedropperTooltip,
        areaLabel: widget.pickerAreaLabel,
        hueLabel: widget.pickerHueLabel,
        onChanged: widget.onChanged,
        onCommit: widget.onCommit,
        autofocus: _focusPicker,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final debugOpen = FsDebugStates.of(
      context,
      part: 'picker',
      exact: true,
    ).contains(WidgetState.selected);
    if (debugOpen && !_debugOpen && !_overlay.isShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_overlay.show);
      });
    }
    _debugOpen = debugOpen;
    final value = _value;
    final enabled = widget.enabled;

    final swatch = FsAnchoredOverlay(
      controller: _overlay,
      onDismiss: _dismiss,
      overlayBuilder: _picker,
      // Runs after the swatch's own Listener, which presses on pointer up.
      child: Listener(
        onPointerDown: (_) => _pointerDown = true,
        onPointerUp: (_) => _pointerDown = false,
        onPointerCancel: (_) => _pointerDown = false,
        child: FsInteractive(
          onPressed: enabled ? _toggle : null,
          focusNode: _swatchFocus,
          requestFocusOnPress: true,
          cursor: SystemMouseCursors.click,
          semanticsLabel: value == null
              ? widget.label
              : '${widget.label} #${FsColorText.hex(value)}',
          builder: (context, states) => FsFocusRing.outside(
            visible: states.contains(WidgetState.focused),
            borderRadius: FsRadii.xs,
            child: FsSwatch(
              color: value,
              highlighted:
                  enabled &&
                  (states.contains(WidgetState.hovered) || _overlay.isShowing),
              disabled: !enabled,
            ),
          ),
        ),
      ),
    );

    return FsPropertyRow(
      label: widget.label,
      source: widget.source,
      onReset: widget.onReset,
      resetTooltip: widget.resetTooltip,
      tooltip: widget.tooltip,
      mixed: widget.mixed,
      enabled: enabled,
      editor: Row(
        children: [
          swatch,
          const SizedBox(width: FsSpacing.s1),
          Expanded(
            child: FsHexInput(
              value: value,
              mixed: value == null,
              focusNode: _hexFocus,
              enabled: enabled,
              onCommit: _commit,
              debugPart: 'hex',
            ),
          ),
          const SizedBox(width: FsSpacing.s1),
          FsNumberField(
            value: value == null ? null : FsColorText.alphaPercent(value),
            mixed: value == null,
            kind: FsNumberKind.int,
            min: 0,
            max: 100,
            unit: '%',
            stepper: false,
            size: FsFieldSize.dense,
            width: 52,
            onChanged: enabled && value != null
                ? (v) => widget.onChanged(value.withValues(alpha: v / 100))
                : null,
            onCommit: enabled && value != null
                ? (v) => widget.onCommit(value.withValues(alpha: v / 100))
                : null,
          ),
        ],
      ),
    );
  }
}

/// Tab inside the popover: moves within it, and at its edges leaves to the
/// row (the scope's `stop` edge behaviour makes the move report failure).
class _PickerTab<T extends Intent> extends Action<T> {
  _PickerTab(this.state, {required this.forward});

  final _FsColorPropertyState state;
  final bool forward;

  @override
  Object? invoke(T intent) {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return null;
    final moved = forward ? primary.nextFocus() : primary.previousFocus();
    if (!moved) state._leavePicker(forward: forward);
    return true;
  }
}
