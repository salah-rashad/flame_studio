import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../foundation/debug_states.dart';
import '../foundation/editable.dart';
import '../foundation/field_box.dart';
import '../foundation/value_source.dart';
import '../typography.dart';
import 'property_row.dart';

/// Hex text for colours: `FFD7A8`, upper-case, without `#` or alpha.
///
/// Internal.
abstract final class PrColorText {
  /// The six upper-case hex digits of [color]'s red, green and blue.
  static String hex(Color color) => (color.toARGB32() & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0')
      .toUpperCase();

  /// The opaque colour of typed [text] (`FFD7A8`, `#ffd7a8`, or the
  /// short `#FDA`), or null when it isn't one.
  static Color? parse(String text) {
    var digits = text.trim();
    if (digits.startsWith('#')) digits = digits.substring(1);
    if (!RegExp(r'^([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(digits)) {
      return null;
    }
    if (digits.length == 3) {
      digits = digits.split('').map((d) => '$d$d').join();
    }
    return Color(0xFF000000 | int.parse(digits, radix: 16));
  }

  /// [rgb] with the alpha of [alphaFrom].
  static Color withAlphaOf(Color rgb, Color alphaFrom) =>
      rgb.withValues(alpha: alphaFrom.a);

  /// The alpha of [color] in whole percent.
  static double alphaPercent(Color color) => (color.a * 100).roundToDouble();
}

/// A 20px hex field: a `#` and six upper-case hex digits in mono.
///
/// Click or Tab in selects the digits; Enter, Tab or clicking elsewhere
/// commits; Esc reverts. Text that isn't a colour gets the `error` border
/// and stays until fixed or Esc (the swatch keeps the last valid colour).
/// Committing reports the new colour with [value]'s alpha.
///
/// Inside an `PrPropertyRow` it follows the row (hover, default values in
/// `text-secondary`). Internal; the colour property and picker use it.
class PrHexInput extends StatefulWidget {
  /// Creates the field.
  const PrHexInput({
    super.key,
    required this.value,
    required this.focusNode,
    this.mixed = false,
    this.enabled = true,
    required this.onCommit,
    this.onErrorChanged,
    this.debugPart,
  });

  /// The colour; its alpha is kept on commit.
  final Color? value;

  /// The field's focus node.
  final FocusNode focusNode;

  /// Shows "—" until the user types.
  final bool mixed;

  /// False disables the field.
  final bool enabled;

  /// Called with a new valid colour.
  final ValueChanged<Color> onCommit;

  /// The text became invalid (true) or valid again (false).
  final ValueChanged<bool>? onErrorChanged;

  /// The `PrDebugStates` part this field reads.
  final String? debugPart;

  @override
  State<PrHexInput> createState() => _FsHexInputState();
}

class _FsHexInputState extends State<PrHexInput> {
  late final TextEditingController _controller = TextEditingController(
    text: _display,
  );
  bool _error = false;
  bool _hovered = false;

  static const String _mixedGlyph = '—';

  String get _display {
    final value = widget.value;
    return widget.mixed || value == null ? _mixedGlyph : PrColorText.hex(value);
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(PrHexInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
    final changed =
        oldWidget.value != widget.value || oldWidget.mixed != widget.mixed;
    if (changed && !widget.focusNode.hasFocus) {
      if (_error) {
        _error = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_error) widget.onErrorChanged?.call(false);
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
      if (!_error) _controller.text = _display;
    }
    setState(() {});
  }

  void _setError(bool error) {
    if (_error == error) return;
    setState(() => _error = error);
    widget.onErrorChanged?.call(error);
  }

  bool _commit() {
    if (!widget.enabled) return true;
    final text = _controller.text.trim();
    if (widget.mixed && (text.isEmpty || text == _mixedGlyph)) {
      _setError(false);
      return true;
    }
    final rgb = PrColorText.parse(text);
    if (rgb == null) {
      _setError(true);
      return false;
    }
    _setError(false);
    final value = widget.value;
    final color = value == null || widget.mixed
        ? rgb
        : PrColorText.withAlphaOf(rgb, value);
    _controller.text = PrColorText.hex(color);
    if (widget.mixed || color != value) widget.onCommit(color);
    return true;
  }

  void _submit() {
    if (_commit()) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    }
  }

  void _revert() {
    _setError(false);
    _controller.text = _display;
    widget.focusNode.unfocus();
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
      if (_error) WidgetState.error,
    };
    final quiet =
        _controller.text == _mixedGlyph ||
        (!focused && !_error && row?.source == PrValueSource.codeDefault);
    final Color ink;
    if (!widget.enabled) {
      ink = c.textDisabled;
    } else if (quiet) {
      ink = c.textSecondary;
    } else {
      ink = c.textPrimary;
    }
    final style = PrText.mono.copyWith(color: ink);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: PrFieldBox(
        size: PrFieldSize.dense,
        states: states,
        child: Row(
          children: [
            // The same Text either way, so the editor keeps its place.
            Text(_controller.text == _mixedGlyph ? '' : '#', style: style),
            Expanded(
              child: IgnorePointer(
                ignoring: !widget.enabled,
                child: PrEditableText(
                  enabled: widget.enabled,
                  controller: _controller,
                  focusNode: widget.focusNode,
                  readOnly: !widget.enabled,
                  style: style,
                  shortcuts: {
                    const SingleActivator(LogicalKeyboardKey.enter): _submit,
                    const SingleActivator(LogicalKeyboardKey.numpadEnter):
                        _submit,
                    const SingleActivator(LogicalKeyboardKey.escape): _revert,
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
