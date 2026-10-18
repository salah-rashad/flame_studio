import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../actions/icon_button.dart';
import '../colors.dart';
import '../floating/tooltip.dart';
import '../foundation/debug_states.dart';
import '../foundation/scrub.dart';
import '../foundation/value_source.dart';
import '../icons.dart';
import '../metrics.dart';
import '../typography.dart';

/// One 24px inspector row: the field's name on the left, its editor on the
/// right, and a reset slot at the far right.
///
/// - **Label column:** 40% of the row (minimum 72px). Inside an
///   [PrPropertyList] the list's shared fraction instead, and the 4px gap
///   between label and editor is the handle that resizes it.
/// - **Default from code** ([PrValueSource.codeDefault]): label and value in
///   `text-secondary`, no marker, no reset.
/// - **Overridden:** a 2px `accent-text` bar at the left edge, the label in
///   `text-primary` 500, and the ↺ reset button (when [onReset] is set).
/// - **Mixed, error, disabled, read-only:** see the fields.
/// - **Hover:** the whole row turns `surface-hover` and field borders
///   strengthen.
///
/// The editor reads the row's state with [PrPropertyRowScope.of] to pick its
/// colours. Parts for `PrDebugStates`: `row` (hover) and `label` (hover,
/// [WidgetState.dragged] for scrubbing, [WidgetState.error]).
class PrPropertyRow extends StatefulWidget {
  /// Creates a row.
  const PrPropertyRow({
    super.key,
    required this.label,
    required this.editor,
    this.source = PrValueSource.codeDefault,
    this.onReset,
    this.resetTooltip,
    this.mixed = false,
    this.readOnly = false,
    this.enabled = true,
    this.error,
    this.tooltip,
    this.labelScrub,
    this.onLabelPressed,
  });

  /// The field's Dart name, verbatim (`jumpForce`).
  final String label;

  /// The editor; it gets the width between the label and the reset slot.
  final Widget editor;

  /// Default from code or overridden.
  final PrValueSource source;

  /// Restores the default; the button shows only when [source] is
  /// overridden.
  final VoidCallback? onReset;

  /// The reset button's tooltip ("Reset to default").
  final String? resetTooltip;

  /// The selected objects disagree; the editor draws "—".
  final bool mixed;

  /// The value can be read and selected but not changed.
  final bool readOnly;

  /// False draws the row disabled.
  final bool enabled;

  /// A validation message: the label and the field border turn `error` and
  /// the label's tooltip says why. An empty string marks the error without a
  /// message.
  final String? error;

  /// The label's tooltip: type and default value, formatted by the app.
  final String? tooltip;

  /// Makes the label a scrub handle; set by the number editors.
  final PrScrubHandle? labelScrub;

  /// Called for a click on the label (a bool row toggles its checkbox);
  /// ignored while the row is disabled or read-only.
  final VoidCallback? onLabelPressed;

  @override
  State<PrPropertyRow> createState() => _FsPropertyRowState();
}

class _FsPropertyRowState extends State<PrPropertyRow> {
  bool _rowHovered = false;
  bool _labelHovered = false;

  /// In the focus path while the row's field is focused: the label's error
  /// tooltip stays up meanwhile (`PrTooltip.focusTarget`).
  final _rowFocus = FocusNode(
    debugLabel: 'PrPropertyRow',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void dispose() {
    _rowFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final rowForced = PrDebugStates.of(context, part: 'row');
    final labelForced = PrDebugStates.of(context, part: 'label');
    final hovered = _rowHovered || rowForced.contains(WidgetState.hovered);
    final interactive = widget.enabled && !widget.readOnly;
    final scrub = interactive ? widget.labelScrub : null;
    final overridden = widget.source == PrValueSource.overridden;
    final error =
        widget.error != null || labelForced.contains(WidgetState.error);
    final scrubbing =
        (scrub?.active ?? false) || labelForced.contains(WidgetState.dragged);
    final labelHovered =
        scrub != null &&
        (_labelHovered || labelForced.contains(WidgetState.hovered));

    final Color labelColor;
    if (!interactive) {
      labelColor = c.textDisabled;
    } else if (error) {
      labelColor = c.error;
    } else if (scrubbing) {
      labelColor = c.accentText;
    } else if (overridden || labelHovered) {
      labelColor = c.textPrimary;
    } else {
      labelColor = c.textSecondary;
    }
    final labelStyle = (overridden ? PrText.bodyStrong : PrText.body).copyWith(
      color: labelColor,
      decoration: labelHovered && !scrubbing ? TextDecoration.underline : null,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: c.textSecondary,
    );

    Widget label = MouseRegion(
      onEnter: (_) => setState(() => _labelHovered = true),
      onExit: (_) => setState(() => _labelHovered = false),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          widget.label,
          style: labelStyle,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    label = PrScrubRegion(handle: scrub, child: label);
    if (widget.onLabelPressed != null) {
      label = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive ? widget.onLabelPressed : null,
        child: label,
      );
    }
    final tip = (widget.error?.isNotEmpty ?? false)
        ? widget.error
        : widget.tooltip;
    if (tip != null && tip.isNotEmpty) {
      final isError = tip == widget.error;
      label = PrTooltip(
        message: tip,
        error: isError,
        showWhileFocused: isError,
        focusTarget: _rowFocus,
        child: label,
      );
    }

    final showReset = overridden && widget.onReset != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _rowHovered = true),
      onExit: (_) => setState(() => _rowHovered = false),
      child: Focus(
        focusNode: _rowFocus,
        includeSemantics: false,
        // A ColoredBox even when not hovered: a Container adds one only with a
        // colour, and the changed subtree would cancel a running scrub.
        child: ColoredBox(
          color: hovered ? c.surfaceHover : Colors.transparent,
          child: SizedBox(
            height: PrSizes.rowProperty,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: PrSpacing.s4,
                    end: PrSpacing.s1,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final list = _PropertyListScope.maybeOf(context);
                      final width = constraints.maxWidth;
                      final labelWidth = math.max(
                        _minLabelWidth,
                        width * (list?.fraction ?? _labelFraction),
                      );
                      return Row(
                        children: [
                          SizedBox(width: labelWidth, child: label),
                          if (list == null)
                            const SizedBox(width: PrSpacing.s1)
                          else
                            _ColumnHandle(list: list, contentWidth: width),
                          Expanded(
                            child: PrPropertyRowScope(
                              hovered: hovered,
                              source: widget.source,
                              mixed: widget.mixed,
                              readOnly: widget.readOnly,
                              enabled: widget.enabled,
                              error: error,
                              child: widget.editor,
                            ),
                          ),
                          const SizedBox(width: PrSpacing.s1),
                          SizedBox(
                            width: PrSizes.controlSm,
                            child: showReset
                                ? PrIconButton(
                                    icon: PrIcons.reset,
                                    size: PrIconButtonSize.small,
                                    iconSize: PrSizes.iconSm,
                                    tooltip: widget.resetTooltip ?? '',
                                    onPressed: widget.enabled
                                        ? widget.onReset
                                        : null,
                                  )
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // The override bar, after the content so adding it never
                // moves the content's place in the Stack.
                if (overridden)
                  PositionedDirectional(
                    start: 6,
                    top: 6,
                    bottom: 6,
                    width: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.accentText,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const double _labelFraction = 0.4;
  static const double _minLabelWidth = 72;
}

/// A list of [PrPropertyRow]s (and other widgets) that share one label
/// column: drag the boundary between label and editor in any row and every
/// row follows.
///
/// - The label column starts at [initialLabelFraction] of the row width
///   and never goes below 72px; the editor keeps at least 72px.
/// - The boundary is the 4px gap between label and editor, with the ↔
///   column cursor. While the pointer is over it, every row shows a 1px
///   `border-strong` line there (`accent-text` while dragging), like the
///   editor shell's seams.
/// - [onLabelFractionChanged] reports the new fraction when a drag ends, so
///   the app can persist it. The list keeps the fraction itself.
///
/// The children are laid out in a column, stretched to the list's width.
class PrPropertyList extends StatefulWidget {
  /// Creates the list.
  const PrPropertyList({
    super.key,
    required this.children,
    this.initialLabelFraction = 0.4,
    this.onLabelFractionChanged,
  });

  /// The rows, and anything between them (section headers).
  final List<Widget> children;

  /// The label column's share of the row width at first.
  final double initialLabelFraction;

  /// The fraction after a resize, once per drag.
  final ValueChanged<double>? onLabelFractionChanged;

  @override
  State<PrPropertyList> createState() => _FsPropertyListState();
}

class _FsPropertyListState extends State<PrPropertyList> {
  late double _fraction = widget.initialLabelFraction;
  bool _hovered = false;
  bool _dragging = false;
  double _startWidth = 0;
  double _dx = 0;

  /// The narrowest the editor (and its reset slot) may get.
  static const double _minEditor =
      _FsPropertyRowState._minLabelWidth + 2 * PrSpacing.s1 + PrSizes.controlSm;

  void _hover(bool hovered) {
    if (_hovered != hovered) setState(() => _hovered = hovered);
  }

  void _start(double contentWidth) {
    setState(() {
      _dragging = true;
      _dx = 0;
      _startWidth = math.max(
        _FsPropertyRowState._minLabelWidth,
        contentWidth * _fraction,
      );
    });
  }

  void _update(double dx, double contentWidth) {
    if (!_dragging || contentWidth <= 0) return;
    _dx += dx;
    const min = _FsPropertyRowState._minLabelWidth;
    final max = math.max(min, contentWidth - _minEditor);
    final width = (_startWidth + _dx).clamp(min, max);
    setState(() => _fraction = width / contentWidth);
  }

  void _end() {
    if (!_dragging) return;
    setState(() => _dragging = false);
    widget.onLabelFractionChanged?.call(_fraction);
  }

  @override
  Widget build(BuildContext context) => _PropertyListScope(
    state: this,
    fraction: _fraction,
    hovered: _hovered,
    dragging: _dragging,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.children,
    ),
  );
}

/// What the rows of an [PrPropertyList] share.
class _PropertyListScope extends InheritedWidget {
  const _PropertyListScope({
    required this.state,
    required this.fraction,
    required this.hovered,
    required this.dragging,
    required super.child,
  });

  final _FsPropertyListState state;
  final double fraction;
  final bool hovered;
  final bool dragging;

  static _PropertyListScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PropertyListScope>();

  @override
  bool updateShouldNotify(_PropertyListScope oldWidget) =>
      fraction != oldWidget.fraction ||
      hovered != oldWidget.hovered ||
      dragging != oldWidget.dragging;
}

/// The 4px gap between a row's label and editor inside an
/// [PrPropertyList]: the column boundary's handle and its 1px line.
class _ColumnHandle extends StatelessWidget {
  const _ColumnHandle({required this.list, required this.contentWidth});

  final _PropertyListScope list;
  final double contentWidth;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final Color line;
    if (list.dragging) {
      line = c.accentText;
    } else if (list.hovered) {
      line = c.borderStrong;
    } else {
      line = Colors.transparent;
    }
    final state = list.state;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => state._hover(true),
      onExit: (_) => state._hover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (_) => state._start(contentWidth),
        onHorizontalDragUpdate: (d) => state._update(d.delta.dx, contentWidth),
        onHorizontalDragEnd: (_) => state._end(),
        onHorizontalDragCancel: state._end,
        child: SizedBox(
          width: PrSpacing.s1,
          height: PrSizes.rowProperty,
          child: Center(
            child: SizedBox(
              width: 1,
              height: double.infinity,
              child: ColoredBox(color: line),
            ),
          ),
        ),
      ),
    );
  }
}

/// The state of the [PrPropertyRow] around an editor, so the editor can
/// draw its value and field to match.
class PrPropertyRowScope extends InheritedWidget {
  /// Provided by [PrPropertyRow].
  const PrPropertyRowScope({
    super.key,
    required this.hovered,
    required this.source,
    required this.mixed,
    required this.readOnly,
    required this.enabled,
    required this.error,
    required super.child,
  });

  /// The pointer is over the row: field borders go `border-strong`.
  final bool hovered;

  /// Default values are drawn in `text-secondary`.
  final PrValueSource source;

  /// The row is mixed.
  final bool mixed;

  /// The row is read-only.
  final bool readOnly;

  /// The row is enabled.
  final bool enabled;

  /// The row shows an error.
  final bool error;

  /// The scope around [context], or null outside a property row.
  static PrPropertyRowScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrPropertyRowScope>();

  @override
  bool updateShouldNotify(PrPropertyRowScope oldWidget) =>
      hovered != oldWidget.hovered ||
      source != oldWidget.source ||
      mixed != oldWidget.mixed ||
      readOnly != oldWidget.readOnly ||
      enabled != oldWidget.enabled ||
      error != oldWidget.error;
}
