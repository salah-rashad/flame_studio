import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../floating/tooltip.dart';
import '../foundation/debug_states.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../metrics.dart';
import '../status/badge.dart';
import '../typography.dart';

/// One option of an [PrSegmentedControl]: an icon (tool modes), a label
/// (filters), or both.
@immutable
class PrSegment<T> {
  /// Creates a segment.
  const PrSegment({
    required this.value,
    this.icon,
    this.label,
    this.count,
    this.countKind,
    this.tooltip,
    this.shortcut,
    this.enabled = true,
  }) : assert(icon != null || label != null, 'Give an icon or a label');

  /// Passed to `onChanged` when the segment is chosen.
  final T value;

  /// A 16px glyph. Without a [label] the segment is a 22px square-ish
  /// icon button; give it a [tooltip].
  final IconData? icon;

  /// The option's name ("All", "Warnings").
  final String? label;

  /// A count after the label: plain mono text, or a badge when [countKind]
  /// is set.
  final int? count;

  /// Draws [count] as an `PrBadge` of this kind (without its icon: the
  /// label says what it counts).
  final PrBadgeKind? countKind;

  /// The tooltip, and the semantics label of an icon-only segment.
  final String? tooltip;

  /// Shown in the tooltip's key cap (the tool keys Q W E R). The app binds
  /// the shortcut itself.
  final SingleActivator? shortcut;

  /// False draws the segment in `text-disabled` and skips it.
  final bool enabled;
}

/// Mutually exclusive options in one track: tool modes (Select, Move,
/// Rotate, Scale), Console filters, 2D/Camera.
///
/// - **Track:** 24px, `surface-input`, 1px `border-control`, `radius-sm`,
///   1px padding; segments 20px high with 1px gaps.
/// - **Segment:** `text-secondary`, label in 12px medium; hover
///   `surface-hover` and `text-primary`; pressed `surface-pressed`;
///   selected `accent-subtle` and `accent-text` (hover and press don't
///   change it); disabled `text-disabled` with no fill.
/// - **Keyboard:** the control is one Tab stop. ← → move the selection
///   (skipping disabled segments) and call [onChanged]; the inset focus
///   ring marks the selected segment while the control has keyboard focus.
///   At either end the key is not handled, so a roving group around the
///   control (`PrToolbar`) moves on to its neighbour.
///
/// Null [onChanged] disables the whole control (`border-subtle` track).
///
/// Parts for `PrDebugStates`: a segment's label (or its tooltip, for an
/// icon segment) forces that segment's states. Unparted forced states
/// reach every segment.
class PrSegmentedControl<T> extends StatefulWidget {
  /// Creates the control.
  const PrSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.disabledReason,
    this.focusNode,
    this.autofocus = false,
  });

  /// The options, in order.
  final List<PrSegment<T>> segments;

  /// The selected segment's value. One segment is always selected.
  final T selected;

  /// A segment was clicked or chosen with ← →. Null disables the control.
  final ValueChanged<T>? onChanged;

  /// Why the control is disabled; the tooltips' second line while it is.
  final String? disabledReason;

  /// The control's focus node (its one Tab stop).
  final FocusNode? focusNode;

  /// Take focus when first built.
  final bool autofocus;

  @override
  State<PrSegmentedControl<T>> createState() => _FsSegmentedControlState<T>();
}

class _FsSegmentedControlState<T> extends State<PrSegmentedControl<T>> {
  FocusNode? _ownFocusNode;

  // The segment last chosen with the keyboard, until the next build shows
  // the new selection, so keys pressed within one frame keep moving.
  int? _pending;

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'PrSegmentedControl'));

  bool get _enabled => widget.onChanged != null;

  int get _selectedIndex =>
      widget.segments.indexWhere((s) => s.value == widget.selected);

  @override
  void dispose() {
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _choose(int index) {
    final value = widget.segments[index].value;
    _pending = index;
    if (value != widget.selected) widget.onChanged?.call(value);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final int step;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      step = rtl ? -1 : 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      step = rtl ? 1 : -1;
    } else {
      return KeyEventResult.ignored;
    }
    if (!_enabled) return KeyEventResult.ignored;
    final segments = widget.segments;
    final from = _pending ?? _selectedIndex;
    var i = from < 0 ? (step > 0 ? -1 : segments.length) : from;
    for (i += step; i >= 0 && i < segments.length; i += step) {
      if (segments[i].enabled) {
        _choose(i);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final segments = widget.segments;
    final selected = _selectedIndex;
    _pending = null;
    final focus = Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: _enabled,
      includeSemantics: false,
      onFocusChange: (_) => setState(() {}),
      onKeyEvent: _onKey,
      child: ListenableBuilder(
        listenable: PrInputModality.instance,
        builder: (context, _) {
          final keyboardFocus =
              _focusNode.hasFocus && PrInputModality.instance.showsFocusRing;
          return Container(
            height: PrSizes.control,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: c.surfaceInput,
              border: Border.all(
                color: _enabled ? c.borderControl : c.borderSubtle,
              ),
              borderRadius: PrRadii.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, segment) in segments.indexed) ...[
                  if (i > 0) const SizedBox(width: 1),
                  _Segment<T>(
                    segment: segment,
                    selected: i == selected,
                    keyboardFocus: keyboardFocus && i == selected,
                    onPressed: _enabled && segment.enabled
                        ? () => _choose(i)
                        : null,
                    disabledReason: widget.disabledReason,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
    return Semantics(
      container: true,
      focusable: _enabled,
      focused: _focusNode.hasFocus,
      child: focus,
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.keyboardFocus,
    required this.onPressed,
    required this.disabledReason,
  });

  final PrSegment<T> segment;
  final bool selected;
  final bool keyboardFocus;
  final VoidCallback? onPressed;
  final String? disabledReason;

  // Concentric with the track: radius-sm less its 1px padding.
  static const _radius = BorderRadius.all(Radius.circular(3));

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final label = segment.label;
    final iconOnly = label == null;
    final part = label ?? segment.tooltip;
    Widget child = PrInteractive(
      onPressed: onPressed,
      selected: selected,
      focusable: false,
      semanticsLabel: label ?? segment.tooltip,
      builder: (context, own) {
        final states = {
          ...own,
          if (part != null)
            ...PrDebugStates.of(context, part: part, exact: true),
        };
        final disabled = states.contains(WidgetState.disabled);
        final pressed = states.contains(WidgetState.pressed);
        final hovered = pressed || states.contains(WidgetState.hovered);
        final Color fill;
        final Color ink;
        if (disabled) {
          fill = Colors.transparent;
          ink = c.textDisabled;
        } else if (selected) {
          fill = c.accentSubtle;
          ink = c.accentText;
        } else {
          fill = pressed
              ? c.surfacePressed
              : hovered
              ? c.surfaceHover
              : Colors.transparent;
          ink = hovered ? c.textPrimary : c.textSecondary;
        }
        final count = segment.count;
        final kind = segment.countKind;
        return PrFocusRing.inset(
          visible: keyboardFocus || states.contains(WidgetState.focused),
          borderRadius: _radius,
          child: Container(
            height: PrSizes.controlSm,
            width: iconOnly ? 22 : null,
            constraints: const BoxConstraints(minWidth: PrSizes.controlSm),
            padding: iconOnly
                ? null
                : const EdgeInsets.symmetric(horizontal: PrSpacing.s2),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: fill, borderRadius: _radius),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (segment.icon != null)
                  Icon(segment.icon, size: PrSizes.icon, color: ink),
                if (segment.icon != null && label != null)
                  const SizedBox(width: PrSpacing.s1),
                if (label != null)
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: PrText.small.copyWith(
                      fontWeight: FontWeight.w500,
                      color: ink,
                    ),
                  ),
                if (count != null) ...[
                  const SizedBox(width: PrSpacing.s1),
                  if (kind == null)
                    Text(
                      '$count',
                      maxLines: 1,
                      softWrap: false,
                      style: PrText.monoSmall.copyWith(
                        fontWeight: FontWeight.w400,
                        color: ink,
                      ),
                    )
                  else
                    SizedBox(
                      height: 14,
                      child: PrBadge(kind: kind, count: count, showIcon: false),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
    final tooltip = segment.tooltip;
    if (tooltip != null) {
      child = PrTooltip(
        message: tooltip,
        shortcut: segment.shortcut,
        details: [
          if (onPressed == null && disabledReason != null) disabledReason!,
        ],
        child: child,
      );
    }
    return child;
  }
}
