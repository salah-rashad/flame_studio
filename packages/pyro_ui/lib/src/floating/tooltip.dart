import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../foundation/anchored_overlay.dart';
import '../foundation/debug_states.dart';
import '../foundation/focus_ring.dart';
import '../foundation/shortcut_label.dart';
import '../icons.dart';
import '../metrics.dart';
import '../shadows.dart';
import '../typography.dart';

/// A short, non-interactive label for icon buttons, truncated text and
/// property metadata.
///
/// - `surface-overlay`, 1px `border-overlay`, `radius-sm`,
///   `shadow-tooltip`, 4×8 padding, at most 240px wide, `small` text; a
///   [shortcut] in a 16px key cap; [details] as secondary lines.
/// - Appears after 500ms of hover, below the anchor with a 4px gap, flipped
///   or shifted to stay inside the window (`PrOverlayPlacement`). Moving to
///   an adjacent tooltipped control shows its tooltip at once: right away
///   while the previous one is still up (`RawTooltip`), and for 300ms after
///   it hides when an [PrTooltipGroup] is above.
/// - Also appears after the same delay when the anchor takes keyboard focus
///   (not on a click that moves focus), and hides when focus leaves.
/// - [showWhileFocused] (a field's error message): shown at once and kept
///   while the field has focus, by click or keyboard, so the person typing
///   sees what is wrong; screen readers hear it when it appears or changes.
/// - Hides on press and on Esc. Shown for disabled controls too, which
///   should say why they are disabled; keyboard users reach those only when
///   the control sets `focusableWhenDisabled`.
///
/// Built on [RawTooltip]. For the gallery and goldens, an `PrDebugStates`
/// with part `tooltip` (any state) draws the tooltip below its anchor
/// without hover.
class PrTooltip extends StatelessWidget {
  /// Wraps [child] in a tooltip.
  const PrTooltip({
    super.key,
    required this.message,
    this.shortcut,
    this.details = const [],
    this.monoMessage = false,
    this.error = false,
    this.showWhileFocused = false,
    this.focusTarget,
    required this.child,
  });

  /// The first line.
  final String message;

  /// Shown in a key cap after the message.
  final SingleActivator? shortcut;

  /// Secondary lines in `text-secondary` (type, default value, why a
  /// control is disabled).
  final List<String> details;

  /// The message in mono (a truncated path or file name).
  final bool monoMessage;

  /// An error tooltip: `error-border` edge, alert icon and message in
  /// `error`.
  final bool error;

  /// Keep the tooltip up while focus is in the anchor (or [focusTarget]),
  /// shown at once and announced to screen readers when it appears or its
  /// message changes. For a field's error message, so whoever is typing
  /// sees it; not for errors the user didn't just cause (a dropdown's,
  /// whose list opens where the tooltip would be).
  final bool showWhileFocused;

  /// Where focus counts for [showWhileFocused] when the field isn't inside
  /// the anchor: a property row's label tooltip names the row.
  final FocusNode? focusTarget;

  /// The anchor.
  final Widget child;

  /// The normal delay before a tooltip appears.
  static const Duration delay = Duration(milliseconds: 500);

  static Offset _place(TooltipPositionContext context) =>
      PrOverlayPlacement.place(
        anchor: Rect.fromCenter(
          center: context.target,
          width: context.targetSize.width,
          height: context.targetSize.height,
        ),
        size: context.tooltipSize,
        bounds: context.overlaySize,
      );

  @override
  Widget build(BuildContext context) {
    if (PrDebugStates.of(context, part: 'tooltip', exact: true).isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          const SizedBox(height: 4),
          _TooltipBody(tooltip: this),
        ],
      );
    }
    final group = PrTooltipGroup._maybeOf(context);
    return _TooltipAnchor(
      tooltip: this,
      group: group,
      wait: group?.warm ?? false ? Duration.zero : delay,
    );
  }
}

/// The live tooltip: a [RawTooltip] for hover, plus focus handling.
///
/// - Keyboard focus in [PrTooltip.child] shows the tooltip after [wait];
///   leaving hides it.
/// - With [PrTooltip.showWhileFocused] it is shown at once, and kept, while
///   focus is in the anchor or [PrTooltip.focusTarget], and announced when
///   it appears or changes. That's a separate layer, not the [RawTooltip],
///   which hides on any press, on Esc and when the mouse leaves; meanwhile
///   the hover tooltip draws nothing, so there is never a second copy.
class _TooltipAnchor extends StatefulWidget {
  const _TooltipAnchor({
    required this.tooltip,
    required this.group,
    required this.wait,
  });

  final PrTooltip tooltip;
  final _FsTooltipGroupState? group;
  final Duration wait;

  @override
  State<_TooltipAnchor> createState() => _TooltipAnchorState();
}

class _TooltipAnchorState extends State<_TooltipAnchor> {
  final _raw = GlobalKey<RawTooltipState>();
  final _focus = FocusNode(
    debugLabel: 'PrTooltip',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final _pinned = OverlayPortalController();
  Timer? _timer;
  bool _shownByFocus = false;

  FocusNode get _pinSource => widget.tooltip.focusTarget ?? _focus;

  bool get _pin => widget.tooltip.showWhileFocused && _pinSource.hasFocus;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    widget.tooltip.focusTarget?.addListener(_onTargetFocus);
    // An error tooltip often wraps a field that already has focus (the
    // message appears while typing); the new node learns that only once it
    // is in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(announce: true);
    });
  }

  @override
  void didUpdateWidget(_TooltipAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.tooltip;
    final tooltip = widget.tooltip;
    if (old.focusTarget != tooltip.focusTarget) {
      old.focusTarget?.removeListener(_onTargetFocus);
      tooltip.focusTarget?.addListener(_onTargetFocus);
    }
    final changed = old.message != tooltip.message;
    if (changed ||
        old.showWhileFocused != tooltip.showWhileFocused ||
        old.focusTarget != tooltip.focusTarget) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sync(announce: changed);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focus.removeListener(_onFocus);
    widget.tooltip.focusTarget?.removeListener(_onTargetFocus);
    _focus.dispose();
    super.dispose();
  }

  void _onTargetFocus() => _sync(announce: true);

  void _onFocus() {
    _sync(announce: true);
    _timer?.cancel();
    if (_focus.hasFocus) {
      if (widget.tooltip.showWhileFocused) return;
      // Checked when the timer fires: the Tab that moved focus reaches
      // PrInputModality after the focus change.
      _timer = Timer(widget.wait, () {
        if (!mounted || !PrInputModality.instance.showsFocusRing) return;
        _shownByFocus = _raw.currentState?.ensureTooltipVisible() ?? false;
      });
    } else if (_shownByFocus) {
      _shownByFocus = false;
      // A tooltip shown this way stays up until dismissed.
      RawTooltip.dismissAllToolTips();
    }
  }

  /// Shows or hides the pinned layer to match focus.
  void _sync({required bool announce}) {
    final pin = _pin;
    if (pin == _pinned.isShowing) {
      if (pin && announce) _announce();
      return;
    }
    if (pin) {
      _pinned.show();
      if (announce) _announce();
    } else {
      _pinned.hide();
    }
    setState(() {}); // the hover tooltip steps aside while pinned
  }

  void _announce() {
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        widget.tooltip.message,
        Directionality.of(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tooltip = widget.tooltip;
    return PrAnchoredOverlay(
      controller: _pinned,
      overlayBuilder: (context) =>
          IgnorePointer(child: _TooltipBody(tooltip: widget.tooltip)),
      child: RawTooltip(
        key: _raw,
        semanticsTooltip: tooltip.message,
        hoverDelay: widget.wait,
        positionDelegate: PrTooltip._place,
        animationStyle: const AnimationStyle(
          curve: PrMotion.enter,
          duration: PrMotion.fast,
          reverseDuration: PrMotion.fast,
        ),
        ignorePointer: true,
        tooltipBuilder: (context, animation) => _pinned.isShowing
            ? const SizedBox.shrink()
            : FadeTransition(
                opacity: animation,
                child: _Visible(
                  group: widget.group,
                  child: _TooltipBody(tooltip: widget.tooltip),
                ),
              ),
        child: Focus(
          focusNode: _focus,
          includeSemantics: false,
          child: tooltip.child,
        ),
      ),
    );
  }
}

/// The tooltip's box.
class _TooltipBody extends StatelessWidget {
  const _TooltipBody({required this.tooltip});

  final PrTooltip tooltip;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final t = tooltip;
    final messageStyle = (t.monoMessage ? PrText.mono : PrText.small).copyWith(
      color: t.error ? c.error : c.textPrimary,
    );
    Widget first = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (t.error) ...[
          Icon(PrIcons.alertCircle, size: PrSizes.iconSm, color: c.error),
          const SizedBox(width: 6),
        ],
        Flexible(child: Text(t.message, style: messageStyle)),
        if (t.shortcut != null) ...[
          const SizedBox(width: PrSpacing.s2),
          PrShortcutLabel(t.shortcut!, style: PrShortcutStyle.keycap),
        ],
      ],
    );
    if (t.details.isNotEmpty) {
      first = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          first,
          for (final line in t.details) ...[
            const SizedBox(height: 2),
            Text(line, style: PrText.small.copyWith(color: c.textSecondary)),
          ],
        ],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PrSpacing.s2,
          vertical: PrSpacing.s1,
        ),
        decoration: BoxDecoration(
          color: c.surfaceOverlay,
          border: Border.all(color: t.error ? c.errorBorder : c.borderOverlay),
          borderRadius: PrRadii.sm,
          boxShadow: PrShadows.of(context).tooltip,
        ),
        child: DefaultTextStyle.merge(
          style: PrText.small.copyWith(color: c.textPrimary),
          child: first,
        ),
      ),
    );
  }
}

/// Lives exactly as long as a tooltip is on screen: tells the group, and
/// hides every tooltip on Esc meanwhile.
class _Visible extends StatefulWidget {
  const _Visible({required this.group, required this.child});

  final _FsTooltipGroupState? group;
  final Widget child;

  @override
  State<_Visible> createState() => _VisibleState();
}

class _VisibleState extends State<_Visible> {
  @override
  void initState() {
    super.initState();
    widget.group?._shown();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    widget.group?._hidden();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      RawTooltip.dismissAllToolTips();
    }
    return false; // Esc still reaches the focused widget.
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Makes tooltips "warm": while one is visible and for [cooldown] after it
/// hides, the next tooltip appears without the 500ms delay, so moving along
/// a toolbar reads every tooltip at once. One at the app root is enough.
class PrTooltipGroup extends StatefulWidget {
  /// Groups the tooltips in [child].
  const PrTooltipGroup({super.key, required this.child});

  /// The app, or a part of it.
  final Widget child;

  /// How long tooltips stay warm after the last one hides.
  static const Duration cooldown = Duration(milliseconds: 300);

  static _FsTooltipGroupState? _maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GroupScope>()?.state;

  @override
  State<PrTooltipGroup> createState() => _FsTooltipGroupState();
}

class _FsTooltipGroupState extends State<PrTooltipGroup> {
  int _visible = 0;
  bool _warm = false;
  Timer? _cooldown;

  bool get warm => _warm;

  // Called from a tooltip's initState: the group rebuilds after this frame,
  // not during it.
  void _shown() {
    _visible++;
    _cooldown?.cancel();
    if (_warm) return;
    _warm = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  // Called from a tooltip's dispose.
  void _hidden() {
    _visible--;
    if (_visible > 0) return;
    _cooldown?.cancel();
    _cooldown = Timer(PrTooltipGroup.cooldown, () {
      if (mounted && _visible == 0) setState(() => _warm = false);
    });
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _GroupScope(state: this, warm: _warm, child: widget.child);
}

class _GroupScope extends InheritedWidget {
  const _GroupScope({
    required this.state,
    required this.warm,
    required super.child,
  });

  final _FsTooltipGroupState state;
  final bool warm;

  @override
  bool updateShouldNotify(_GroupScope oldWidget) => warm != oldWidget.warm;
}
