import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../floating/tooltip.dart';
import '../foundation/debug_states.dart';
import '../foundation/editable.dart';
import '../foundation/field_box.dart';
import '../icons.dart';
import '../metrics.dart';
import '../typography.dart';

/// Where an [PrTextField] shows its validation message.
enum PrErrorDisplay {
  /// One line of `small` `error` text below the field.
  below,

  /// In the field's tooltip (dense rows, where there's no room below):
  /// shown while the field has focus, and on hover otherwise.
  tooltip,
}

/// A single-line text input for names, labels and paths.
///
/// - 24px (20px [PrFieldSize.dense] inside property rows), `surface-input`,
///   1px `border-control`, `radius-sm` (the shared [PrFieldBox]).
/// - Hover `border-strong`; focused a `focus-ring` border and outer ring
///   (for clicks too: fields show where typing goes).
/// - Error (the [validator] returns a message): `error` border, a trailing
///   alert icon, and the message below or in a tooltip ([errorDisplay]).
///   The tooltip stays up while the field has focus, so the message is
///   visible while typing; either way screen readers hear it when it
///   appears or changes.
/// - Disabled: flat and `text-disabled`. Read-only: flat, text stays
///   `text-primary` and can still be selected.
/// - [placeholder] in `text-placeholder`; [mono] for paths.
///
/// Built on [EditableText], not Material's `TextField`. Give either a
/// [controller] or a [value]; with [value] the field shows each new value
/// while it isn't focused.
class PrTextField extends StatefulWidget {
  /// Creates the field.
  const PrTextField({
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
    this.size = PrFieldSize.regular,
    this.errorDisplay = PrErrorDisplay.below,
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

  /// Enter. Without it, Enter is left to the widgets around the field (an
  /// `PrDialog` answers its primary button).
  final ValueChanged<String>? onSubmitted;

  /// JetBrains Mono 12/16, for paths.
  final bool mono;

  /// Selectable but not editable.
  final bool readOnly;

  /// False disables the field.
  final bool enabled;

  /// 24 or 20.
  final PrFieldSize size;

  /// Message below or in a tooltip.
  final PrErrorDisplay errorDisplay;

  /// The focus node.
  final FocusNode? focusNode;

  /// Take focus when first built.
  final bool autofocus;

  /// Select the whole text when focus arrives.
  final bool selectAllOnFocus;

  @override
  State<PrTextField> createState() => _FsTextFieldState();
}

class _FsTextFieldState extends State<PrTextField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  bool _hovered = false;
  String? _error;

  TextEditingController get _controller =>
      widget.controller ??
      (_ownController ??= TextEditingController(text: widget.value));

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'PrTextField'));

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focusNode.addListener(_rebuild);
    _error = widget.validator?.call(_controller.text);
  }

  @override
  void didUpdateWidget(PrTextField oldWidget) {
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
      // The tooltip form announces itself (PrTooltip); the message below
      // is announced here, while the user is typing.
      if (error != null &&
          error != _error &&
          _focusNode.hasFocus &&
          widget.errorDisplay == PrErrorDisplay.below) {
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            error,
            Directionality.of(context),
          ),
        );
      }
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
    final c = PrColors.of(context);
    final forced = PrDebugStates.of(context);
    final error = _error;
    final hasError = error != null || forced.contains(WidgetState.error);
    final states = <WidgetState>{
      ...forced,
      if (_hovered) WidgetState.hovered,
      if (_focusNode.hasFocus) WidgetState.focused,
      if (!widget.enabled) WidgetState.disabled,
      if (hasError) WidgetState.error,
    };
    final base = widget.mono ? PrText.mono : PrText.body;
    final editable = widget.enabled && !widget.readOnly;

    final Widget field = MouseRegion(
      key: _fieldKey,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: PrFieldBox(
        size: widget.size,
        states: states,
        readOnly: widget.readOnly,
        trailing: hasError && widget.enabled
            ? Icon(PrIcons.alertCircle, size: PrSizes.iconSm, color: c.error)
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
              PrEditableText(
                enabled: widget.enabled,
                controller: _controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                readOnly: !editable,
                selectAllOnFocus: widget.selectAllOnFocus,
                style: base.copyWith(
                  color: widget.enabled ? c.textPrimary : c.textDisabled,
                ),
                // Without onSubmitted, Enter passes up (a dialog answers
                // its primary button).
                shortcuts: {
                  if (widget.onSubmitted != null) ...{
                    const SingleActivator(LogicalKeyboardKey.enter): _submit,
                    const SingleActivator(LogicalKeyboardKey.numpadEnter):
                        _submit,
                  },
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (error == null || error.isEmpty) return field;
    if (widget.errorDisplay == PrErrorDisplay.tooltip) {
      return PrTooltip(
        message: error,
        error: true,
        showWhileFocused: true,
        child: field,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        const SizedBox(height: PrSpacing.s1),
        Text(
          error,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PrText.small.copyWith(color: c.error),
        ),
      ],
    );
  }
}
