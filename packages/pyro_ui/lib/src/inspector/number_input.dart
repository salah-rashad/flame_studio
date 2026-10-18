import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../foundation/debug_states.dart';
import '../foundation/editable.dart';
import '../foundation/field_box.dart';
import '../foundation/interactive.dart';
import '../foundation/number_editing.dart';
import '../foundation/scrub.dart';
import '../foundation/value_source.dart';
import '../icons.dart';
import '../metrics.dart';
import '../typography.dart';
import 'property_row.dart';

/// The text-editing half of a number editor: one 20px field that shows a
/// value and edits it.
///
/// Click or Tab in selects the value; Enter commits and keeps focus; Tab and
/// clicking elsewhere commit (simple expressions such as `32*2` or `+=8`
/// are evaluated then); Esc reverts and leaves the field; ↑/↓ step
/// (Shift ×10, Alt ×0.1) and commit each step. Text that isn't a number, is
/// out of range or fails the validator keeps the error state (and the typed
/// text) until it is fixed or Esc.
///
/// Scrubbing belongs to the owner: it passes the scrubbed [value] and
/// [scrubbing], and the field shows them. With [fieldScrub] the value
/// itself is the scrub handle while the field isn't focused (a click
/// without a drag starts editing), as in the standalone `PrNumberField`.
///
/// Internal; `PrNumberProperty`, `PrVector2Property` and `PrNumberField`
/// use it.
class PrNumberInput extends StatefulWidget {
  /// Creates the field.
  const PrNumberInput({
    super.key,
    required this.value,
    required this.focusNode,
    this.mixed = false,
    this.kind = PrNumberKind.double,
    this.min,
    this.max,
    required this.step,
    this.unit,
    this.leading,
    this.scrubbing = false,
    this.enabled = true,
    this.readOnly = false,
    this.validator,
    this.invalidMessage,
    required this.onChanged,
    required this.onCommit,
    this.onErrorChanged,
    this.debugPart,
    this.size = PrFieldSize.dense,
    this.stepper = false,
    this.fieldScrub,
  });

  /// The value; null with [mixed].
  final double? value;

  /// The field's focus node, owned by the caller so it can unfocus the field
  /// when a scrub starts.
  final FocusNode focusNode;

  /// Shows "—" until the user types.
  final bool mixed;

  /// Int or double.
  final PrNumberKind kind;

  /// Lower bound; typed values below it are an error.
  final double? min;

  /// Upper bound; typed values above it are an error.
  final double? max;

  /// The ↑/↓ step at ×1.
  final double step;

  /// Unit suffix ("px").
  final String? unit;

  /// Before the value (the Vector2 axis cell).
  final Widget? leading;

  /// Draws the `accent-text` border.
  final bool scrubbing;

  /// False disables the field.
  final bool enabled;

  /// Flat, not editable.
  final bool readOnly;

  /// Further checks of a parsed value; a non-null result is the error
  /// message.
  final String? Function(double value)? validator;

  /// The message for text that isn't a number, and for out-of-range values
  /// the [validator] doesn't explain.
  final String? invalidMessage;

  /// Called with each new value (↑/↓ and committed text).
  final ValueChanged<double> onChanged;

  /// Called once per edit.
  final ValueChanged<double> onCommit;

  /// The error message changed: null when valid, possibly empty when there
  /// is no message to show.
  final ValueChanged<String?>? onErrorChanged;

  /// The `PrDebugStates` part this field reads (`field`, `x`, `y`).
  final String? debugPart;

  /// 20 (inside rows) or 24.
  final PrFieldSize size;

  /// Up and down chevrons at the end that step the value.
  final bool stepper;

  /// Makes the value a scrub handle while the field isn't focused.
  final PrScrubHandle? fieldScrub;

  @override
  State<PrNumberInput> createState() => _FsNumberInputState();
}

class _FsNumberInputState extends State<PrNumberInput> {
  late final TextEditingController _controller = TextEditingController(
    text: _display,
  );
  String? _error;
  bool _hovered = false;

  static const String _mixedGlyph = '—';

  String get _display => widget.mixed || widget.value == null
      ? _mixedGlyph
      : PrNumberEditing.format(widget.value!, widget.kind);

  bool get _interactive => widget.enabled && !widget.readOnly;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(PrNumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
    final changed =
        oldWidget.value != widget.value ||
        oldWidget.mixed != widget.mixed ||
        oldWidget.kind != widget.kind;
    if (changed && (!widget.focusNode.hasFocus || widget.scrubbing)) {
      if (_error != null) {
        // A new value replaces the rejected text. Tell the owner after this
        // build, not during it.
        _error = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _error == null) widget.onErrorChanged?.call(null);
        });
      }
      _controller.text = _display;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    _controller.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (widget.focusNode.hasFocus) {
      if (_controller.text == _mixedGlyph) _controller.text = '';
    } else {
      _commit();
      if (_error == null) _controller.text = _display;
    }
    setState(() {});
  }

  void _setError(String? error) {
    if (_error == error) return;
    setState(() => _error = error);
    widget.onErrorChanged?.call(error);
  }

  /// Applies the typed text; returns whether it was valid.
  bool _commit() {
    if (!_interactive) return true;
    final text = _controller.text.trim();
    if (widget.mixed && (text.isEmpty || text == _mixedGlyph)) {
      _setError(null);
      return true;
    }
    // Typed text may be an expression: `32*2`, `+=8` (on the value).
    final value = PrNumberEditing.parse(
      text,
      widget.kind,
      current: widget.mixed ? null : widget.value,
    );
    if (value == null) {
      _setError(widget.invalidMessage ?? '');
      return false;
    }
    final message = widget.validator?.call(value);
    final inRange = PrNumberEditing.inRange(
      value,
      min: widget.min,
      max: widget.max,
    );
    if (message != null || !inRange) {
      _setError(message ?? widget.invalidMessage ?? '');
      return false;
    }
    _setError(null);
    if (widget.mixed || value != widget.value) {
      widget.onChanged(value);
      widget.onCommit(value);
    }
    _controller.text = PrNumberEditing.format(value, widget.kind);
    return true;
  }

  void _submit() {
    if (_commit()) _selectAll();
  }

  void _revert() {
    _setError(null);
    _controller.text = _display;
    widget.focusNode.unfocus();
  }

  void _step(int direction) {
    if (!_interactive) return;
    final keys = HardwareKeyboard.instance;
    final base =
        PrNumberEditing.parse(
          _controller.text,
          widget.kind,
          current: widget.value,
        ) ??
        widget.value ??
        widget.min ??
        0;
    final next = PrNumberEditing.step(
      PrNumberEditing.clamp(base, min: widget.min, max: widget.max),
      direction,
      step: widget.step,
      multiplier: PrNumberEditing.modifierMultiplier(
        shift: keys.isShiftPressed,
        alt: keys.isAltPressed,
      ),
      kind: widget.kind,
      min: widget.min,
      max: widget.max,
    );
    _setError(null);
    _controller.text = PrNumberEditing.format(next, widget.kind);
    _selectAll();
    widget.onChanged(next);
    widget.onCommit(next);
  }

  void _selectAll() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final row = PrPropertyRowScope.of(context);
    final forced = PrDebugStates.of(context, part: widget.debugPart);
    final focused = widget.focusNode.hasFocus;
    final states = <WidgetState>{
      ...forced,
      if (_hovered || (row?.hovered ?? false)) WidgetState.hovered,
      if (focused) WidgetState.focused,
      if (!widget.enabled) WidgetState.disabled,
      if (_error != null || (row?.error ?? false)) WidgetState.error,
    };
    final scrubbing = widget.scrubbing || forced.contains(WidgetState.dragged);
    final showsMixed = _controller.text == _mixedGlyph;
    final quiet =
        showsMixed ||
        (!focused &&
            !scrubbing &&
            _error == null &&
            row?.source == PrValueSource.codeDefault);
    final Color ink;
    if (!widget.enabled) {
      ink = c.textDisabled;
    } else if (quiet) {
      ink = c.textSecondary;
    } else {
      ink = c.textPrimary;
    }

    final interactive = _interactive;
    final scrubHandle = interactive && !focused ? widget.fieldScrub : null;
    // The value takes clicks itself only while editing when the field
    // scrubs; otherwise a click lands on the scrub region and starts
    // editing.
    final valueTakesPointer =
        interactive && (widget.fieldScrub == null || focused);
    final unit = widget.unit;
    final Widget? trailing = widget.stepper
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (unit != null) ...[Text(unit), const SizedBox(width: 2)],
              _Stepper(size: widget.size, onStep: interactive ? _step : null),
            ],
          )
        : (unit == null ? null : Text(unit));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: PrFieldBox(
        size: widget.size,
        states: states,
        readOnly: widget.readOnly,
        accentEdge: scrubbing,
        padding: widget.leading == null
            ? (widget.stepper
                  ? EdgeInsetsDirectional.only(
                      start: widget.size == PrFieldSize.dense
                          ? 6
                          : PrSpacing.s2,
                      end: 0,
                    )
                  : null)
            : const EdgeInsetsDirectional.only(end: 6),
        leading: widget.leading,
        trailing: trailing,
        child: PrScrubRegion(
          handle: scrubHandle,
          onTap: widget.fieldScrub != null && interactive && !focused
              ? widget.focusNode.requestFocus
              : null,
          // The whole height of the field, so a click above or below the
          // text still edits or scrubs.
          child: SizedBox(
            height: double.infinity,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: IgnorePointer(
                ignoring: !valueTakesPointer,
                child: PrEditableText(
                  enabled: widget.enabled,
                  controller: _controller,
                  focusNode: widget.focusNode,
                  readOnly: !interactive,
                  style: PrText.mono.copyWith(color: ink),
                  shortcuts: {
                    const SingleActivator(LogicalKeyboardKey.enter): _submit,
                    const SingleActivator(LogicalKeyboardKey.numpadEnter):
                        _submit,
                    const SingleActivator(LogicalKeyboardKey.escape): _revert,
                    for (final shift in [false, true])
                      for (final alt in [false, true]) ...{
                        SingleActivator(
                          LogicalKeyboardKey.arrowUp,
                          shift: shift,
                          alt: alt,
                        ): () =>
                            _step(1),
                        SingleActivator(
                          LogicalKeyboardKey.arrowDown,
                          shift: shift,
                          alt: alt,
                        ): () =>
                            _step(-1),
                      },
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The stacked ▲▼ chevrons at the end of a number field; each half steps
/// the value (Shift ×10, Alt ×0.1).
class _Stepper extends StatelessWidget {
  const _Stepper({required this.size, required this.onStep});

  final PrFieldSize size;
  final ValueChanged<int>? onStep;

  @override
  Widget build(BuildContext context) {
    // Two halves filling the box inside its border.
    final half =
        (size == PrFieldSize.dense ? PrSizes.controlSm : PrSizes.control) / 2 -
        1;
    Widget arrow(int direction) {
      final onStep = this.onStep;
      return PrInteractive(
        onPressed: onStep == null ? null : () => onStep(direction),
        focusable: false,
        builder: (context, states) {
          final c = PrColors.of(context);
          final Color ink;
          if (states.contains(WidgetState.disabled)) {
            ink = c.textDisabled;
          } else if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed)) {
            ink = c.textPrimary;
          } else {
            ink = c.textSecondary;
          }
          return SizedBox(
            width: PrSizes.icon,
            height: half,
            child: OverflowBox(
              maxHeight: 12,
              child: RotatedBox(
                quarterTurns: direction > 0 ? 2 : 0,
                child: Icon(PrIcons.chevronDown, size: 12, color: ink),
              ),
            ),
          );
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [arrow(1), arrow(-1)],
    );
  }
}
