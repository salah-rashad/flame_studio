import 'dart:async';

import 'package:flutter/material.dart';

import '../colors.dart';

/// A single-line [EditableText] with desktop mouse selection (click places
/// the caret, drag and double-click select) and the design's caret and
/// selection colours. No Material decoration: the caller draws the box.
///
/// Internal: the number editors and the tree row's inline rename use it; the
/// later `FsTextField` will too.
class FsEditableText extends StatefulWidget {
  /// Creates the editor.
  const FsEditableText({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    this.selectAllOnFocus = true,
    this.autofocus = false,
    this.readOnly = false,
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

  /// Key bindings handled before the editor sees the key (Enter, Esc, ↑/↓).
  final Map<ShortcutActivator, VoidCallback> shortcuts;

  @override
  State<FsEditableText> createState() => _FsEditableTextState();
}

class _FsEditableTextState extends State<FsEditableText>
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
  void didUpdateWidget(FsEditableText oldWidget) {
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
    final c = FsColors.of(context);
    return CallbackShortcuts(
      bindings: widget.shortcuts,
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: _gestures.buildGestureDetector(
          behavior: HitTestBehavior.translucent,
          child: EditableText(
            key: editableTextKey,
            controller: widget.controller,
            focusNode: widget.focusNode,
            style: widget.style,
            cursorColor: c.textPrimary,
            backgroundCursorColor: c.textDisabled,
            selectionColor: c.surfaceSelected,
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
    );
  }
}
