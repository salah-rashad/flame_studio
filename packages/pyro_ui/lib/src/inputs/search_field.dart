import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../floating/tooltip.dart';
import '../foundation/debug_states.dart';
import '../foundation/editable.dart';
import '../foundation/field_box.dart';
import '../foundation/interactive.dart';
import '../foundation/shortcut_label.dart';
import '../icons.dart';
import '../metrics.dart';
import '../typography.dart';

/// A filter field: a leading search icon, the query, and at the end the
/// shortcut hint (while empty) or the result count and a clear button.
///
/// - The [PrFieldBox] of a text field: hover `border-strong`; focused (by
///   click too) the focus border and ring; disabled flat.
/// - Empty: [placeholder] in `text-placeholder` and the [shortcutHint]
///   (⌘F) in `text-secondary`.
/// - With a query: [resultLabel] ("3 of 12", formatted by the app) in
///   11px mono, and a 16px × that clears the query.
/// - [noMatch]: the `error` border and [noMatchLabel] ("No match") in
///   `error` instead of the count. The list below shows an empty state;
///   that's the app's.
/// - Keyboard: every edit calls [onChanged] (no Enter needed). Esc clears
///   the query; Esc on an empty field calls [onExit] (focus back to the
///   list). ↓ and ↑ call [onNext] and [onPrevious] without leaving the
///   field.
///
/// The field shows each new [query] it is given, so the app can clear or
/// set it.
///
/// Part for `PrDebugStates`: `field` (the box, without the clear button).
class PrSearchField extends StatefulWidget {
  /// Creates the field.
  const PrSearchField({
    super.key,
    required this.query,
    required this.onChanged,
    this.placeholder,
    this.resultLabel,
    this.noMatch = false,
    this.noMatchLabel,
    this.shortcutHint,
    this.clearTooltip,
    this.onExit,
    this.onNext,
    this.onPrevious,
    this.enabled = true,
    this.size = PrFieldSize.regular,
    this.focusNode,
    this.autofocus = false,
  });

  /// The text being searched for.
  final String query;

  /// Every edit, and "" when cleared.
  final ValueChanged<String> onChanged;

  /// Shown while empty ("Search nodes").
  final String? placeholder;

  /// The count shown with a query ("3 of 12").
  final String? resultLabel;

  /// Nothing matches: error border and [noMatchLabel].
  final bool noMatch;

  /// Shown in `error` when [noMatch] ("No match").
  final String? noMatchLabel;

  /// The shortcut that focuses the field, shown while it is empty. The app
  /// binds it.
  final SingleActivator? shortcutHint;

  /// The clear button's tooltip.
  final String? clearTooltip;

  /// Esc on an empty field: the app moves focus back to its list.
  final VoidCallback? onExit;

  /// ↓: the next result.
  final VoidCallback? onNext;

  /// ↑: the previous result.
  final VoidCallback? onPrevious;

  /// False disables the field.
  final bool enabled;

  /// 24, or 20 in panel headers.
  final PrFieldSize size;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  @override
  State<PrSearchField> createState() => _FsSearchFieldState();
}

class _FsSearchFieldState extends State<PrSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.query,
  );
  FocusNode? _ownFocusNode;
  bool _hovered = false;
  late String _lastText = widget.query;

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'PrSearchField'));

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focusNode.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(PrSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_rebuild);
      _focusNode.addListener(_rebuild);
    }
    if (widget.query != _controller.text) {
      _lastText = widget.query; // the app's text, not an edit to report
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onText)
      ..dispose();
    _focusNode.removeListener(_rebuild);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onText() {
    final text = _controller.text;
    if (text == _lastText) return; // a selection change
    final emptied = _lastText.isEmpty != text.isEmpty;
    _lastText = text;
    if (emptied) setState(() {});
    widget.onChanged(text);
  }

  void _clear() {
    if (_controller.text.isNotEmpty) _controller.clear();
  }

  void _escape() {
    if (_controller.text.isNotEmpty) {
      _clear();
    } else {
      widget.onExit?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final forced = PrDebugStates.of(context, part: 'field');
    final enabled = widget.enabled;
    final empty = _controller.text.isEmpty;
    final noMatch = widget.noMatch && !empty;
    final states = <WidgetState>{
      ...forced,
      if (_hovered) WidgetState.hovered,
      if (_focusNode.hasFocus) WidgetState.focused,
      if (!enabled) WidgetState.disabled,
      if (noMatch) WidgetState.error,
    };
    final quiet = enabled ? c.textSecondary : c.textDisabled;

    final Widget? trailing;
    if (empty) {
      final hint = widget.shortcutHint;
      trailing = hint == null ? null : PrShortcutLabel(hint, color: quiet);
    } else {
      final label = noMatch ? widget.noMatchLabel : widget.resultLabel;
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Text(
              label,
              maxLines: 1,
              style: noMatch
                  ? PrText.small.copyWith(color: enabled ? c.error : quiet)
                  : PrText.monoSmall.copyWith(
                      color: quiet,
                      fontWeight: FontWeight.w400,
                    ),
            ),
          const SizedBox(width: PrSpacing.s1),
          _ClearButton(
            tooltip: widget.clearTooltip,
            onPressed: enabled
                ? () {
                    _clear();
                    _focusNode.requestFocus();
                  }
                : null,
          ),
        ],
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: PrFieldBox(
        size: widget.size,
        states: states,
        padding: EdgeInsetsDirectional.only(
          start: widget.size == PrFieldSize.regular ? PrSpacing.s2 : 6,
          end: empty ? PrSpacing.s2 : PrSpacing.s1,
        ),
        leading: Icon(PrIcons.search, size: PrSizes.iconSm, color: quiet),
        trailing: trailing,
        child: IgnorePointer(
          ignoring: !enabled,
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              Visibility(
                visible: empty && widget.placeholder != null,
                child: Text(
                  widget.placeholder ?? '',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: PrText.body.copyWith(
                    color: enabled ? c.textPlaceholder : c.textDisabled,
                  ),
                ),
              ),
              PrEditableText(
                enabled: widget.enabled,
                controller: _controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                readOnly: !enabled,
                selectAllOnFocus: false,
                style: PrText.body.copyWith(
                  color: enabled ? c.textPrimary : c.textDisabled,
                ),
                shortcuts: {
                  const SingleActivator(LogicalKeyboardKey.escape): _escape,
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      widget.onNext?.call(),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      widget.onPrevious?.call(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 16px × at the end of a search field with a query.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onPressed, this.tooltip});

  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final Widget button = PrInteractive(
      onPressed: onPressed,
      focusable: false,
      semanticsLabel: tooltip,
      builder: (context, states) {
        final disabled = states.contains(WidgetState.disabled);
        final hot =
            !disabled &&
            (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed));
        return Container(
          width: PrSizes.icon,
          height: PrSizes.icon,
          decoration: BoxDecoration(
            color: hot ? c.surfacePressed : Colors.transparent,
            borderRadius: PrRadii.xs,
          ),
          child: Icon(
            PrIcons.x,
            size: 12,
            color: disabled
                ? c.textDisabled
                : (hot ? c.textPrimary : c.textSecondary),
          ),
        );
      },
    );
    final tip = tooltip;
    return tip == null ? button : PrTooltip(message: tip, child: button);
  }
}
