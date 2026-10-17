import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../colors.dart';
import '../foundation/anchored_overlay.dart';
import '../foundation/debug_states.dart';
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
///   or shifted to stay inside the window (`FsOverlayPlacement`). Moving to
///   an adjacent tooltipped control shows its tooltip at once: right away
///   while the previous one is still up (`RawTooltip`), and for 300ms after
///   it hides when an [FsTooltipGroup] is above.
/// - Hides on press and on Esc. Shown for disabled controls too, which
///   should say why they are disabled.
///
/// Built on [RawTooltip]. For the gallery and goldens, an `FsDebugStates`
/// with part `tooltip` (any state) draws the tooltip below its anchor
/// without hover.
class FsTooltip extends StatelessWidget {
  /// Wraps [child] in a tooltip.
  const FsTooltip({
    super.key,
    required this.message,
    this.shortcut,
    this.details = const [],
    this.monoMessage = false,
    this.error = false,
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

  /// The anchor.
  final Widget child;

  /// The normal delay before a tooltip appears.
  static const Duration delay = Duration(milliseconds: 500);

  static Offset _place(TooltipPositionContext context) =>
      FsOverlayPlacement.place(
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
    if (FsDebugStates.of(context, part: 'tooltip', exact: true).isNotEmpty) {
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
    final group = FsTooltipGroup._maybeOf(context);
    return RawTooltip(
      semanticsTooltip: message,
      hoverDelay: group?.warm ?? false ? Duration.zero : delay,
      positionDelegate: _place,
      animationStyle: const AnimationStyle(
        curve: FsMotion.enter,
        duration: FsMotion.fast,
        reverseDuration: FsMotion.fast,
      ),
      ignorePointer: true,
      tooltipBuilder: (context, animation) => FadeTransition(
        opacity: animation,
        child: _Visible(
          group: group,
          child: _TooltipBody(tooltip: this),
        ),
      ),
      child: child,
    );
  }
}

/// The tooltip's box.
class _TooltipBody extends StatelessWidget {
  const _TooltipBody({required this.tooltip});

  final FsTooltip tooltip;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final t = tooltip;
    final messageStyle = (t.monoMessage ? FsText.mono : FsText.small).copyWith(
      color: t.error ? c.error : c.textPrimary,
    );
    Widget first = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (t.error) ...[
          Icon(FsIcons.alertCircle, size: FsSizes.iconSm, color: c.error),
          const SizedBox(width: 6),
        ],
        Flexible(child: Text(t.message, style: messageStyle)),
        if (t.shortcut != null) ...[
          const SizedBox(width: FsSpacing.s2),
          FsShortcutLabel(t.shortcut!, style: FsShortcutStyle.keycap),
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
            Text(line, style: FsText.small.copyWith(color: c.textSecondary)),
          ],
        ],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FsSpacing.s2,
          vertical: FsSpacing.s1,
        ),
        decoration: BoxDecoration(
          color: c.surfaceOverlay,
          border: Border.all(color: t.error ? c.errorBorder : c.borderOverlay),
          borderRadius: FsRadii.sm,
          boxShadow: FsShadows.of(context).tooltip,
        ),
        child: DefaultTextStyle.merge(
          style: FsText.small.copyWith(color: c.textPrimary),
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
class FsTooltipGroup extends StatefulWidget {
  /// Groups the tooltips in [child].
  const FsTooltipGroup({super.key, required this.child});

  /// The app, or a part of it.
  final Widget child;

  /// How long tooltips stay warm after the last one hides.
  static const Duration cooldown = Duration(milliseconds: 300);

  static _FsTooltipGroupState? _maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GroupScope>()?.state;

  @override
  State<FsTooltipGroup> createState() => _FsTooltipGroupState();
}

class _FsTooltipGroupState extends State<FsTooltipGroup> {
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
    _cooldown = Timer(FsTooltipGroup.cooldown, () {
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
