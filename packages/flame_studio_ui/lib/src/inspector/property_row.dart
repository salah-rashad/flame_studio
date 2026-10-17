import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../colors.dart';
import '../foundation/debug_states.dart';
import '../foundation/interim_tooltip.dart';
import '../foundation/row_icon_button.dart';
import '../foundation/scrub.dart';
import '../foundation/value_source.dart';
import '../icons.dart';
import '../metrics.dart';
import '../typography.dart';

/// One 24px inspector row: the field's name on the left, its editor on the
/// right, and a reset slot at the far right.
///
/// - **Label column:** 40% of the row (minimum 72px). Resizing it by
///   dragging comes later with `FsPropertyList`.
/// - **Default from code** ([FsValueSource.codeDefault]): label and value in
///   `text-secondary`, no marker, no reset.
/// - **Overridden:** a 2px `accent-text` bar at the left edge, the label in
///   `text-primary` 500, and the ↺ reset button (when [onReset] is set).
/// - **Mixed, error, disabled, read-only:** see the fields.
/// - **Hover:** the whole row turns `surface-hover` and field borders
///   strengthen.
///
/// The editor reads the row's state with [FsPropertyRowScope.of] to pick its
/// colours. Parts for `FsDebugStates`: `row` (hover) and `label` (hover,
/// [WidgetState.dragged] for scrubbing, [WidgetState.error]).
class FsPropertyRow extends StatefulWidget {
  /// Creates a row.
  const FsPropertyRow({
    super.key,
    required this.label,
    required this.editor,
    this.source = FsValueSource.codeDefault,
    this.onReset,
    this.resetTooltip,
    this.mixed = false,
    this.readOnly = false,
    this.enabled = true,
    this.error,
    this.tooltip,
    this.labelScrub,
  });

  /// The field's Dart name, verbatim (`jumpForce`).
  final String label;

  /// The editor; it gets the width between the label and the reset slot.
  final Widget editor;

  /// Default from code or overridden.
  final FsValueSource source;

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
  final FsScrubHandle? labelScrub;

  @override
  State<FsPropertyRow> createState() => _FsPropertyRowState();
}

class _FsPropertyRowState extends State<FsPropertyRow> {
  bool _rowHovered = false;
  bool _labelHovered = false;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final rowForced = FsDebugStates.of(context, part: 'row');
    final labelForced = FsDebugStates.of(context, part: 'label');
    final hovered = _rowHovered || rowForced.contains(WidgetState.hovered);
    final interactive = widget.enabled && !widget.readOnly;
    final scrub = interactive ? widget.labelScrub : null;
    final overridden = widget.source == FsValueSource.overridden;
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
    final labelStyle = (overridden ? FsText.bodyStrong : FsText.body).copyWith(
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
    label = FsScrubRegion(handle: scrub, child: label);
    label = FsInterimTooltip(
      message: widget.error ?? widget.tooltip,
      error: error,
      child: label,
    );

    final showReset = overridden && widget.onReset != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _rowHovered = true),
      onExit: (_) => setState(() => _rowHovered = false),
      // A ColoredBox even when not hovered: a Container adds one only with a
      // colour, and the changed subtree would cancel a running scrub.
      child: ColoredBox(
        color: hovered ? c.surfaceHover : Colors.transparent,
        child: SizedBox(
          height: FsSizes.rowProperty,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: FsSpacing.s4,
                  end: FsSpacing.s1,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final labelWidth = math.max(
                      _minLabelWidth,
                      constraints.maxWidth * _labelFraction,
                    );
                    return Row(
                      children: [
                        SizedBox(width: labelWidth, child: label),
                        const SizedBox(width: FsSpacing.s1),
                        Expanded(
                          child: FsPropertyRowScope(
                            hovered: hovered,
                            source: widget.source,
                            mixed: widget.mixed,
                            readOnly: widget.readOnly,
                            enabled: widget.enabled,
                            error: error,
                            child: widget.editor,
                          ),
                        ),
                        const SizedBox(width: FsSpacing.s1),
                        SizedBox(
                          width: FsSizes.controlSm,
                          child: showReset
                              ? FsRowIconButton(
                                  icon: FsIcons.reset,
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
                      borderRadius: const BorderRadius.all(Radius.circular(1)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _labelFraction = 0.4;
  static const double _minLabelWidth = 72;
}

/// The state of the [FsPropertyRow] around an editor, so the editor can
/// draw its value and field to match.
class FsPropertyRowScope extends InheritedWidget {
  /// Provided by [FsPropertyRow].
  const FsPropertyRowScope({
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
  final FsValueSource source;

  /// The row is mixed.
  final bool mixed;

  /// The row is read-only.
  final bool readOnly;

  /// The row is enabled.
  final bool enabled;

  /// The row shows an error.
  final bool error;

  /// The scope around [context], or null outside a property row.
  static FsPropertyRowScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FsPropertyRowScope>();

  @override
  bool updateShouldNotify(FsPropertyRowScope oldWidget) =>
      hovered != oldWidget.hovered ||
      source != oldWidget.source ||
      mixed != oldWidget.mixed ||
      readOnly != oldWidget.readOnly ||
      enabled != oldWidget.enabled ||
      error != oldWidget.error;
}
