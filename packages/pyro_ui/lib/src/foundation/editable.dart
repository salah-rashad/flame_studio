import 'dart:async';

import 'package:flutter/material.dart';

import '../colors.dart';

/// A single-line [EditableText] with desktop mouse selection (click places
/// the caret, drag and double-click select) and the design's caret and
/// selection colours. No Material decoration: the caller draws the box.
///
/// The selection is painted only while the editor has focus, as in native
/// fields; it is kept, and shows again when focus returns. A disabled
/// editor ([enabled] false) can't take focus at all, and loses it if it had
/// it.
///
/// Internal: `PrTextField`, `PrSearchField`, the number and hex editors and
/// the tree row's inline rename use it.
class PrEditableText extends StatefulWidget {
  /// Creates the editor.
  const PrEditableText({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    this.selectAllOnFocus = true,
    this.autofocus = false,
    this.readOnly = false,
    this.enabled = true,
    this.shortcuts = const {},
  });

  /// The text.
  final TextEditingController controller;

  /// The focus node.
  final FocusNode focusNode;

  /// Text style, colour included.
  final TextStyle style;

  /// Select the whole text when focus arrives (by click or Tab).
  final bool selectAllOnFocus;

  /// Take focus when first built.
  final bool autofocus;

  /// No editing (the text can still be selected).
  final bool readOnly;

  /// False takes the editor out of focus and the Tab order. Callers still
  /// block the pointer and draw the disabled look.
  final bool enabled;

  /// Key bindings handled before the editor sees the key (Enter, Esc, ↑/↓).
  final Map<ShortcutActivator, VoidCallback> shortcuts;

  @override
  State<PrEditableText> createState() => _FsEditableTextState();
}

class _FsEditableTextState extends State<PrEditableText>
    implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  late final _gestures = TextSelectionGestureDetectorBuilder(delegate: this);

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
    if (widget.autofocus && widget.selectAllOnFocus) _selectAll();
  }

  @override
  void didUpdateWidget(PrEditableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    // The selection is painted only while focused.
    if (mounted) setState(() {});
    if (widget.focusNode.hasFocus && widget.selectAllOnFocus) {
      // After the click that focused us has placed its caret.
      scheduleMicrotask(_selectAll);
    }
  }

  void _selectAll() {
    if (!mounted) return;
    final text = widget.controller.text;
    widget.controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    return CallbackShortcuts(
      bindings: widget.shortcuts,
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: _gestures.buildGestureDetector(
          behavior: HitTestBehavior.translucent,
          child: ExcludeFocus(
            excluding: !widget.enabled,
            child: EditableText(
              key: editableTextKey,
              controller: widget.controller,
              focusNode: widget.focusNode,
              style: widget.style,
              cursorColor: c.textPrimary,
              backgroundCursorColor: c.textDisabled,
              selectionColor: widget.focusNode.hasFocus
                  ? c.surfaceSelected
                  : null,
              cursorWidth: 1,
              cursorHeight: 14,
              autofocus: widget.autofocus,
              readOnly: widget.readOnly,
              maxLines: 1,
              rendererIgnoresPointer: true,
              enableInteractiveSelection: true,
              textInputAction: TextInputAction.done,
            ),
          ),
        ),
      ),
    );
  }
}
