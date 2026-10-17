import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../floating/tooltip.dart';
import '../foundation/debug_states.dart';
import '../foundation/editable.dart';
import '../foundation/field_box.dart';
import '../icons.dart';
import '../metrics.dart';
import '../typography.dart';

/// Where an [FsTextField] shows its validation message.
enum FsErrorDisplay {
  /// One line of `small` `error` text below the field.
  below,

  /// In the field's tooltip (dense rows, where there's no room below).
  tooltip,
}

/// A single-line text input for names, labels and paths.
///
/// - 24px (20px [FsFieldSize.dense] inside property rows), `surface-input`,
///   1px `border-control`, `radius-sm` (the shared [FsFieldBox]).
/// - Hover `border-strong`; focused a `focus-ring` border and outer ring
///   (for clicks too: fields show where typing goes).
/// - Error (the [validator] returns a message): `error` border, a trailing
///   alert icon, and the message below or in a tooltip ([errorDisplay]).
/// - Disabled: flat and `text-disabled`. Read-only: flat, text stays
///   `text-primary` and can still be selected.
/// - [placeholder] in `text-placeholder`; [mono] for paths.
///
/// Built on [EditableText], not Material's `TextField`. Give either a
/// [controller] or a [value]; with [value] the field shows each new value
/// while it isn't focused.
class FsTextField extends StatefulWidget {
  /// Creates the field.
  const FsTextField({
    super.key,
    this.controller,
    this.value,
    this.placeholder,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.mono = false,
    this.readOnly = false,
    this.enabled = true,
    this.size = FsFieldSize.regular,
    this.errorDisplay = FsErrorDisplay.below,
    this.focusNode,
    this.autofocus = false,
    this.selectAllOnFocus = false,
  }) : assert(
         controller == null || value == null,
         'Give a controller or a value, not both',
       );

  /// The text; one is created when null.
  final TextEditingController? controller;

  /// The text, for callers that keep it elsewhere.
  final String? value;

  /// Shown while the field is empty.
  final String? placeholder;

  /// Checks the text on every change; a non-null result is the error
  /// message.
  final String? Function(String text)? validator;

  /// Every change.
  final ValueChanged<String>? onChanged;

  /// Enter.
  final ValueChanged<String>? onSubmitted;

  /// JetBrains Mono 12/16, for paths.
  final bool mono;

  /// Selectable but not editable.
  final bool readOnly;

  /// False disables the field.
  final bool enabled;

  /// 24 or 20.
  final FsFieldSize size;

  /// Message below or in a tooltip.
  final FsErrorDisplay errorDisplay;

  /// The focus node.
  final FocusNode? focusNode;

  /// Take focus when first built.
  final bool autofocus;

  /// Select the whole text when focus arrives.
  final bool selectAllOnFocus;

  @override
  State<FsTextField> createState() => _FsTextFieldState();
}

class _FsTextFieldState extends State<FsTextField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  bool _hovered = false;
  String? _error;

  TextEditingController get _controller =>
      widget.controller ??
      (_ownController ??= TextEditingController(text: widget.value));

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'FsTextField'));

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focusNode.addListener(_rebuild);
    _error = widget.validator?.call(_controller.text);
  }

  @override
  void didUpdateWidget(FsTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      _controller.addListener(_onText);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_rebuild);
      _focusNode.addListener(_rebuild);
    }
    final value = widget.value;
    if (value != null && value != _controller.text && !_focusNode.hasFocus) {
      _controller.text = value; // validates through _onText
    } else if (oldWidget.validator != widget.validator) {
      _error = widget.validator?.call(_controller.text);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _focusNode.removeListener(_rebuild);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  late String _lastText = _controller.text;

  /// Keeps the editor's state when an error message or tooltip wraps it.
  final GlobalKey _fieldKey = GlobalKey();

  void _onText() {
    final text = _controller.text;
    if (text == _lastText) return; // a selection change
    final placeholderChanges = _lastText.isEmpty != text.isEmpty;
    _lastText = text;
    final error = widget.validator?.call(text);
    if (error != _error || placeholderChanges) {
      setState(() => _error = error);
    }
    // The user's edits are reported, not a new [value] from the caller.
    if (_focusNode.hasFocus) widget.onChanged?.call(text);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _submit() => widget.onSubmitted?.call(_controller.text);

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final forced = FsDebugStates.of(context);
    final error = _error;
    final hasError = error != null || forced.contains(WidgetState.error);
    final states = <WidgetState>{
      ...forced,
      if (_hovered) WidgetState.hovered,
      if (_focusNode.hasFocus) WidgetState.focused,
      if (!widget.enabled) WidgetState.disabled,
      if (hasError) WidgetState.error,
    };
    final base = widget.mono ? FsText.mono : FsText.body;
    final editable = widget.enabled && !widget.readOnly;

    final Widget field = MouseRegion(
      key: _fieldKey,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FsFieldBox(
        size: widget.size,
        states: states,
        readOnly: widget.readOnly,
        trailing: hasError && widget.enabled
            ? Icon(FsIcons.alertCircle, size: FsSizes.iconSm, color: c.error)
            : null,
        child: IgnorePointer(
          ignoring: !widget.enabled,
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              Visibility(
                visible: _controller.text.isEmpty && widget.placeholder != null,
                child: Text(
                  widget.placeholder ?? '',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: base.copyWith(
                    color: widget.enabled ? c.textPlaceholder : c.textDisabled,
                  ),
                ),
              ),
              FsEditableText(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                readOnly: !editable,
                selectAllOnFocus: widget.selectAllOnFocus,
                style: base.copyWith(
                  color: widget.enabled ? c.textPrimary : c.textDisabled,
                ),
                shortcuts: {
                  const SingleActivator(LogicalKeyboardKey.enter): _submit,
                  const SingleActivator(LogicalKeyboardKey.numpadEnter):
                      _submit,
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (error == null || error.isEmpty) return field;
    if (widget.errorDisplay == FsErrorDisplay.tooltip) {
      return FsTooltip(message: error, error: true, child: field);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        const SizedBox(height: FsSpacing.s1),
        Text(
          error,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FsText.small.copyWith(color: c.error),
        ),
      ],
    );
  }
}
