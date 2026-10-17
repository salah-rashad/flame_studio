import 'package:flutter/material.dart';

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
/// - **Hex** in mono, `#` and six upper-case digits; the alpha is kept.
///   Text that isn't a colour gets the `error` border until fixed or Esc,
///   and the swatch keeps the last valid colour.
/// - **Alpha** 0–100 % in a 52px number field (it scrubs too).
/// - Mixed: the swatch and both fields show "—". Typing a hex sets every
///   selected object; the alpha field waits for a colour (there is none to
///   apply it to), so it is read-only while mixed.
/// - Default from code, overridden, disabled: as [FsPropertyRow].
///
/// The picker's drags call [onChanged] while moving and [onCommit] once;
/// the fields commit once per edit. Parts for `FsDebugStates`: `row`,
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
    this.recentColors = const [],
    this.eyedropperTooltip,
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

  /// The picker's recent colours; the app keeps the list.
  final List<Color> recentColors;

  /// The picker's eyedropper tooltip.
  final String? eyedropperTooltip;

  /// False disables the row.
  final bool enabled;

  @override
  State<FsColorProperty> createState() => _FsColorPropertyState();
}

class _FsColorPropertyState extends State<FsColorProperty> {
  final _overlay = OverlayPortalController();
  final _hexFocus = FocusNode(debugLabel: 'hex');
  bool _debugOpen = false;

  Color? get _value => widget.mixed ? null : widget.value;

  @override
  void didUpdateWidget(FsColorProperty oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _overlay.isShowing) _close();
  }

  @override
  void dispose() {
    _hexFocus.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_overlay.isShowing) {
      _close();
    } else {
      setState(_overlay.show);
    }
  }

  void _close() {
    if (_overlay.isShowing) setState(_overlay.hide);
  }

  void _commit(Color color) {
    widget.onChanged(color);
    widget.onCommit(color);
  }

  Widget _picker(BuildContext context) => FsColorPicker(
    // A mixed row starts the picker from white.
    value: _value ?? FsSwatchInk.marker,
    recentColors: widget.recentColors,
    eyedropperTooltip: widget.eyedropperTooltip,
    onChanged: widget.onChanged,
    onCommit: widget.onCommit,
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
      onDismiss: _close,
      overlayBuilder: _picker,
      child: FsInteractive(
        onPressed: enabled ? _toggle : null,
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
