import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Which side of the anchor a floating layer prefers.
enum FsOverlaySide {
  /// Below the anchor (dropdown lists, menus, tooltips).
  below,

  /// Above the anchor.
  above,
}

/// How a floating layer lines up with its anchor horizontally.
enum FsOverlayAlign {
  /// Left edges line up (dropdown lists, menus).
  start,

  /// Centres line up (tooltips).
  center,

  /// Right edges line up.
  end,
}

/// Where a floating layer goes next to its anchor: the maths shared by
/// [FsAnchoredOverlay], tooltips (`RawTooltip.positionDelegate`) and menus.
///
/// The layer goes on the preferred [FsOverlaySide] with a gap, **flips** to
/// the other side when it doesn't fit there and the other side has more
/// room, and **shifts** to stay [margin] inside the bounds. With
/// `flipHorizontally` (context menus at a point) it also opens to the left
/// of the anchor when it doesn't fit to the right.
abstract final class FsOverlayPlacement {
  /// The top-left corner of a layer of [size] next to [anchor], inside
  /// [bounds] (all in the same coordinates, the overlay's).
  static Offset place({
    required Rect anchor,
    required Size size,
    required Size bounds,
    FsOverlaySide side = FsOverlaySide.below,
    FsOverlayAlign align = FsOverlayAlign.start,
    double gap = 4,
    double margin = 8,
    bool flipHorizontally = false,
  }) {
    // Vertical: preferred side, flipped when it doesn't fit and the other
    // side has more room.
    final roomBelow = bounds.height - margin - anchor.bottom - gap;
    final roomAbove = anchor.top - gap - margin;
    var below = side == FsOverlaySide.below;
    if (below && size.height > roomBelow && roomAbove > roomBelow) {
      below = false;
    } else if (!below && size.height > roomAbove && roomBelow > roomAbove) {
      below = true;
    }
    var y = below ? anchor.bottom + gap : anchor.top - gap - size.height;

    // Horizontal: aligned, flipped (point anchors), then shifted.
    var x = switch (align) {
      FsOverlayAlign.start => anchor.left,
      FsOverlayAlign.center => anchor.center.dx - size.width / 2,
      FsOverlayAlign.end => anchor.right - size.width,
    };
    if (flipHorizontally &&
        align == FsOverlayAlign.start &&
        x + size.width > bounds.width - margin) {
      x = anchor.right - size.width;
    }

    x = _clamp(x, margin, bounds.width - margin - size.width);
    y = _clamp(y, margin, bounds.height - margin - size.height);
    return Offset(x, y);
  }

  /// [value] kept inside [min]…[max]; [min] wins when the layer is larger
  /// than the bounds.
  static double _clamp(double value, double min, double max) =>
      math.max(min, math.min(value, max));
}

/// A layout delegate that places its child with [FsOverlayPlacement].
///
/// The child may be at most the bounds minus the margins; it sizes itself
/// within that (a menu's 248px, a tooltip's text).
class FsAnchoredLayout extends SingleChildLayoutDelegate {
  /// Creates the delegate.
  FsAnchoredLayout({
    required this.anchor,
    this.side = FsOverlaySide.below,
    this.align = FsOverlayAlign.start,
    this.gap = 4,
    this.margin = 8,
    this.flipHorizontally = false,
    this.minWidth = 0,
  });

  /// The anchor's rectangle in the overlay.
  final Rect anchor;

  /// Preferred side.
  final FsOverlaySide side;

  /// Horizontal alignment.
  final FsOverlayAlign align;

  /// Distance from the anchor.
  final double gap;

  /// Distance kept from the bounds' edges.
  final double margin;

  /// Open to the left of a point when there's no room to the right.
  final bool flipHorizontally;

  /// Smallest width of the child (a dropdown list as wide as its field).
  final double minWidth;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = math.max(0.0, constraints.maxWidth - 2 * margin);
    final maxHeight = math.max(0.0, constraints.maxHeight - 2 * margin);
    return BoxConstraints(
      minWidth: math.min(minWidth, maxWidth),
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      FsOverlayPlacement.place(
        anchor: anchor,
        size: childSize,
        bounds: size,
        side: side,
        align: align,
        gap: gap,
        margin: margin,
        flipHorizontally: flipHorizontally,
      );

  @override
  bool shouldRelayout(FsAnchoredLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      side != oldDelegate.side ||
      align != oldDelegate.align ||
      gap != oldDelegate.gap ||
      margin != oldDelegate.margin ||
      flipHorizontally != oldDelegate.flipHorizontally ||
      minWidth != oldDelegate.minWidth;
}

/// Shows a floating layer next to [child] (its anchor): dropdown lists,
/// popovers, the colour picker. Menus and tooltips have their own widgets
/// (`RawMenuAnchor`, `RawTooltip`) and borrow only [FsOverlayPlacement].
///
/// - Built on [OverlayPortal]: [controller] shows and hides the layer, and
///   the layer goes away with the anchor.
/// - Placed below the anchor (or at [position], for context menus) with a
///   [gap], flipped to the other side when it doesn't fit and shifted to
///   stay inside the window.
/// - [onDismiss] is called for a tap outside both the anchor and the layer,
///   and for Esc while focus is in either. Taps on the anchor are left to
///   the anchor (a dropdown field toggles its own list). The caller hides
///   the layer in [onDismiss].
///
/// The layer inherits from the anchor's context (theme, focus, actions), so
/// it can use `FsColors.of` and take focus as usual.
class FsAnchoredOverlay extends StatefulWidget {
  /// Creates the anchor and its layer.
  const FsAnchoredOverlay({
    super.key,
    required this.controller,
    required this.overlayBuilder,
    required this.child,
    this.position,
    this.side = FsOverlaySide.below,
    this.align = FsOverlayAlign.start,
    this.gap = 4,
    this.margin = 8,
    this.flipHorizontally,
    this.matchAnchorWidth = false,
    this.onDismiss,
  });

  /// Shows and hides the layer.
  final OverlayPortalController controller;

  /// Builds the layer. It sizes itself; it is laid out loosely within the
  /// window minus [margin].
  final WidgetBuilder overlayBuilder;

  /// The anchor.
  final Widget child;

  /// Opens at this point instead of next to the whole anchor, in the
  /// anchor's own coordinates (e.g. `TapUpDetails.localPosition` of a right
  /// click on it).
  final Offset? position;

  /// Preferred side.
  final FsOverlaySide side;

  /// Horizontal alignment with the anchor.
  final FsOverlayAlign align;

  /// Distance between the anchor and the layer (0 at a [position]).
  final double gap;

  /// Distance kept from the window's edges.
  final double margin;

  /// Open to the left when there's no room to the right; defaults to true
  /// at a [position] and false otherwise.
  final bool? flipHorizontally;

  /// Makes the layer at least as wide as the anchor (dropdown lists).
  final bool matchAnchorWidth;

  /// Called for an outside tap or Esc; null leaves dismissal to the caller.
  final VoidCallback? onDismiss;

  @override
  State<FsAnchoredOverlay> createState() => _FsAnchoredOverlayState();
}

class _FsAnchoredOverlayState extends State<FsAnchoredOverlay> {
  final Object _tapGroup = Object();

  void _dismiss() {
    if (widget.controller.isShowing) widget.onDismiss?.call();
  }

  Widget _layer(BuildContext context, OverlayChildLayoutInfo info) {
    final transform = info.childPaintTransform;
    final position = widget.position;
    final Rect anchor;
    if (position == null) {
      anchor = MatrixUtils.transformRect(
        transform,
        Offset.zero & info.childSize,
      );
    } else {
      final point = MatrixUtils.transformPoint(transform, position);
      anchor = Rect.fromLTWH(point.dx, point.dy, 0, 0);
    }
    return CustomSingleChildLayout(
      delegate: FsAnchoredLayout(
        anchor: anchor,
        side: widget.side,
        align: widget.align,
        gap: position == null ? widget.gap : 0,
        margin: widget.margin,
        flipHorizontally: widget.flipHorizontally ?? position != null,
        minWidth: widget.matchAnchorWidth && position == null
            ? anchor.width
            : 0,
      ),
      child: TapRegion(
        groupId: _tapGroup,
        onTapOutside: widget.onDismiss == null ? null : (_) => _dismiss(),
        child: Builder(builder: widget.overlayBuilder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always wrapped, so the subtree keeps its shape; the action is enabled
    // only while there is something to dismiss, so Esc otherwise reaches
    // the actions above.
    return Actions(
      actions: {DismissIntent: _DismissAction(this)},
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: widget.controller,
        overlayChildBuilder: _layer,
        child: TapRegion(groupId: _tapGroup, child: widget.child),
      ),
    );
  }
}

/// Esc: dismisses the open layer, or hands the intent to the next
/// `DismissIntent` action up the tree when there is nothing to dismiss.
class _DismissAction extends Action<DismissIntent> {
  _DismissAction(this.state);

  final _FsAnchoredOverlayState state;

  bool get _canDismiss =>
      state.widget.onDismiss != null && state.widget.controller.isShowing;

  Action<DismissIntent>? get _outer =>
      Actions.maybeFind<DismissIntent>(state.context);

  @override
  bool isEnabled(DismissIntent intent) =>
      _canDismiss || (_outer?.isEnabled(intent) ?? false);

  @override
  Object? invoke(DismissIntent intent) {
    if (_canDismiss) {
      state._dismiss();
      return null;
    }
    final outer = _outer;
    if (outer == null) return null;
    return Actions.of(state.context).invokeAction(outer, intent, state.context);
  }
}
