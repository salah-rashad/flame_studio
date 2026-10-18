import 'package:flutter/material.dart';

import '../colors.dart';
import '../metrics.dart';
import '../typography.dart';
import 'focus_ring.dart';

/// The two field heights.
enum PrFieldSize {
  /// 24px (`size-control`): standalone fields.
  regular,

  /// 20px (`size-control-sm`): fields inside property rows and headers.
  dense,
}

/// The box drawn around every field (text, search, number, dropdown and the
/// inspector editors). It has no text logic of its own.
///
/// Fill `surface-input`, 1px `border-control` border; hover `border-strong`;
/// focus a `focus-ring` border plus a 1px outer ring; `error` border (with
/// an `error` ring when focused); disabled `surface-panel` and
/// `border-subtle`; read-only flat. [accentEdge] (scrubbing) draws the
/// border in `accent-text` over all of these.
///
/// The caller passes the [states]: [WidgetState.hovered],
/// [WidgetState.focused] (fields show focus for mouse clicks too),
/// [WidgetState.disabled], [WidgetState.error] and [WidgetState.pressed]
/// (fields that are buttons, like a dropdown: fill `surface-hover`).
class PrFieldBox extends StatelessWidget {
  /// Creates the box.
  const PrFieldBox({
    super.key,
    required this.child,
    this.leading,
    this.trailing,
    this.size = PrFieldSize.regular,
    this.states = const {},
    this.readOnly = false,
    this.accentEdge = false,
    this.padding,
  });

  /// The content, usually text; it gets the remaining width.
  final Widget child;

  /// Before [child], 4px apart (an icon, the Vector2 axis cell).
  final Widget? leading;

  /// After [child], 4px apart (a unit, a chevron).
  final Widget? trailing;

  /// Height: 24 or 20.
  final PrFieldSize size;

  /// The states to draw.
  final Set<WidgetState> states;

  /// Flat, like disabled, but the text keeps its colour.
  final bool readOnly;

  /// `accent-text` border while the value is being scrubbed.
  final bool accentEdge;

  /// Horizontal padding; defaults to 8 (regular) or 6 (dense).
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final disabled = states.contains(WidgetState.disabled);
    final error = states.contains(WidgetState.error);
    final focused = states.contains(WidgetState.focused);
    final hovered = states.contains(WidgetState.hovered);
    final pressed = states.contains(WidgetState.pressed);
    final flat = disabled || readOnly;

    final Color border;
    if (accentEdge) {
      border = c.accentText;
    } else if (flat) {
      border = c.borderSubtle;
    } else if (error) {
      border = c.error;
    } else if (focused) {
      border = c.focusRing;
    } else if (hovered) {
      border = c.borderStrong;
    } else {
      border = c.borderControl;
    }
    final Color? ring = flat || accentEdge || !focused
        ? null
        : (error ? c.error : c.focusRing);
    final quiet = disabled ? c.textDisabled : c.textSecondary;

    final box = Container(
      height: size == PrFieldSize.regular ? PrSizes.control : PrSizes.controlSm,
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: size == PrFieldSize.regular ? PrSpacing.s2 : 6,
          ),
      decoration: BoxDecoration(
        color: flat
            ? c.surfacePanel
            : (pressed ? c.surfaceHover : c.surfaceInput),
        border: Border.all(color: border),
        borderRadius: PrRadii.sm,
      ),
      child: IconTheme.merge(
        data: IconThemeData(
          color: error && !disabled ? c.error : quiet,
          size: PrSizes.iconSm,
        ),
        child: DefaultTextStyle.merge(
          style: PrText.body.copyWith(
            color: disabled ? c.textDisabled : c.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.clip,
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 4)],
              Expanded(child: child),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                DefaultTextStyle.merge(
                  style: PrText.small.copyWith(color: quiet),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    // Always a CustomPaint, so focusing never rebuilds the editor inside.
    return CustomPaint(
      foregroundPainter: ring == null
          ? null
          : PrEdgePainter(
              color: ring,
              width: 1,
              borderRadius: PrRadii.sm,
              outside: true,
            ),
      child: box,
    );
  }
}
