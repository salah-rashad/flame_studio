import 'dart:async';

import 'package:flutter/material.dart';

import '../actions/button.dart';
import '../actions/icon_button.dart';
import '../colors.dart';
import '../icons.dart';
import '../metrics.dart';
import '../shadows.dart';
import '../status/progress.dart';
import '../typography.dart';

/// What a toast reports, which sets its icon and whether it goes away by
/// itself.
enum FsToastKind {
  /// Done (hot reload complete): `success` check; auto-dismissed.
  success,

  /// For information: `info` icon; auto-dismissed.
  info,

  /// Needs a look: `warning` triangle; stays until dismissed.
  warning,

  /// Failed (build failed): `error` alert circle; stays until dismissed.
  error,

  /// Running (import progress): an `info` spinner and an `info` progress
  /// bar; stays until updated or dismissed.
  progress,
}

/// A toast button: a ghost [FsButton].
@immutable
class FsToastAction {
  /// Creates the action.
  const FsToastAction({
    required this.label,
    required this.onPressed,
    this.dismisses = true,
  });

  /// A verb: "Show in console", "Restart game".
  final String label;

  /// Runs the action.
  final VoidCallback onPressed;

  /// Whether pressing it also dismisses the toast.
  final bool dismisses;
}

/// What a toast shows.
@immutable
class FsToastData {
  /// Creates the content.
  const FsToastData({
    required this.kind,
    required this.title,
    this.message,
    this.actions = const [],
    this.dismissible = true,
    this.progress,
  });

  /// Icon, colour and auto-dismissal.
  final FsToastKind kind;

  /// What happened: "Hot reload complete".
  final String title;

  /// The detail, in `small` `text-secondary`.
  final String? message;

  /// At most two ghost buttons under the message (asserted when shown;
  /// a const constructor can't check a list's length).
  final List<FsToastAction> actions;

  /// Shows the close ×.
  final bool dismissible;

  /// For [FsToastKind.progress]: the fraction done, null while unknown.
  final double? progress;

  /// Whether the host dismisses it after `FsToastHost.autoDismiss`.
  bool get autoDismisses =>
      kind == FsToastKind.success || kind == FsToastKind.info;
}

/// A toast card: a transient notification for an event (hot reload done,
/// build failed, import progress). Shown through [FsToastHost]; the card
/// alone is for galleries and tests.
///
/// 320px, `surface-overlay`, 1px `border-overlay`, `radius-md`,
/// `shadow-popover`; a 16px status icon in the kind's colour, the title in
/// `heading`, the message in `small` `text-secondary`, the actions as ghost
/// buttons, the close × on the right.
class FsToast extends StatelessWidget {
  /// Creates the card.
  const FsToast({
    super.key,
    required this.data,
    this.onDismiss,
    this.dismissTooltip,
  });

  /// The content.
  final FsToastData data;

  /// Called by the close × and by actions that dismiss.
  final VoidCallback? onDismiss;

  /// The close ×'s tooltip and semantics label ("Dismiss").
  final String? dismissTooltip;

  /// The card's width.
  static const double width = 320;

  @override
  Widget build(BuildContext context) {
    assert(data.actions.length <= 2, 'At most two toast actions');
    final c = FsColors.of(context);
    final Widget icon = switch (data.kind) {
      FsToastKind.success => Icon(FsIcons.checkCircle, color: c.success),
      FsToastKind.info => Icon(FsIcons.info, color: c.info),
      FsToastKind.warning => Icon(FsIcons.alertTriangle, color: c.warning),
      FsToastKind.error => Icon(FsIcons.alertCircle, color: c.error),
      FsToastKind.progress => const Padding(
        padding: EdgeInsets.only(top: 1),
        child: FsSpinner(tone: FsProgressTone.background),
      ),
    };
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 2,
      children: [
        Text(data.title, style: FsText.heading.copyWith(color: c.textPrimary)),
        if (data.message != null)
          Text(
            data.message!,
            style: FsText.small.copyWith(color: c.textSecondary),
          ),
        if (data.kind == FsToastKind.progress)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: FsProgressBar(
              value: data.progress,
              tone: FsProgressTone.background,
            ),
          ),
        if (data.actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: FsSpacing.s1),
            // Ghost buttons line their labels up with the text above.
            child: Transform.translate(
              offset: const Offset(-FsSpacing.s2, 0),
              child: Row(
                spacing: FsSpacing.s1,
                children: [
                  for (final action in data.actions)
                    FsButton(
                      label: action.label,
                      variant: FsButtonVariant.ghost,
                      onPressed: () {
                        action.onPressed();
                        if (action.dismisses) onDismiss?.call();
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(
          FsSpacing.s3,
          FsSpacing.s2,
          FsSpacing.s2,
          FsSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: c.surfaceOverlay,
          border: Border.all(color: c.borderOverlay),
          borderRadius: FsRadii.md,
          boxShadow: FsShadows.of(context).popover,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: FsSpacing.s2,
          children: [
            IconTheme.merge(
              data: const IconThemeData(size: FsSizes.icon),
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: icon,
              ),
            ),
            Expanded(child: body),
            if (data.dismissible)
              FsIconButton(
                icon: FsIcons.x,
                iconSize: FsSizes.iconSm,
                size: FsIconButtonSize.small,
                tooltip: dismissTooltip ?? '',
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows toasts at the bottom right of [child]: once, above the editor
/// shell (inside the app's Navigator: the close ×'s tooltip needs an
/// Overlay).
///
/// 16px from the edges, 8px apart, newest on top; at most 3 visible, older
/// ones wait until a newer one goes. Toasts enter and leave over 200ms
/// (fade and size). Success and info toasts dismiss themselves after
/// [autoDismiss]; the countdown pauses while the pointer is over the
/// stack. Logging toasts to the Console is the app's job.
class FsToastHost extends StatefulWidget {
  /// Creates the host.
  const FsToastHost({super.key, required this.child, this.dismissTooltip});

  /// The editor.
  final Widget child;

  /// The close ×'s tooltip and semantics label ("Dismiss").
  final String? dismissTooltip;

  /// How long success and info toasts stay.
  static const Duration autoDismiss = Duration(seconds: 4);

  /// How many toasts show at once.
  static const int maxVisible = 3;

  /// The controller of the nearest host.
  static FsToastController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ToastScope>();
    assert(scope != null, 'No FsToastHost above this context');
    return scope!.controller;
  }

  @override
  State<FsToastHost> createState() => _FsToastHostState();
}

/// Shows toasts in an [FsToastHost]; get it with `FsToastHost.of`.
abstract interface class FsToastController {
  /// Shows [data] on top of the stack.
  FsToastHandle show(FsToastData data);
}

/// One shown toast.
abstract interface class FsToastHandle {
  /// Replaces the content (progress, or progress → success); restarts the
  /// auto-dismiss countdown.
  void update(FsToastData data);

  /// Removes the toast (a no-op once it is gone).
  void dismiss();

  /// Whether the toast is still shown or waiting.
  bool get isActive;
}

class _Entry implements FsToastHandle {
  _Entry(this.host, this.data, this.controller);

  final _FsToastHostState host;
  final AnimationController controller;
  late final CurvedAnimation curved = CurvedAnimation(
    parent: controller,
    curve: FsMotion.enter,
    reverseCurve: FsMotion.exit,
  );
  final Key key = UniqueKey();
  FsToastData data;
  Duration remaining = FsToastHost.autoDismiss;
  bool dismissed = false;

  @override
  bool get isActive => !dismissed;

  @override
  void update(FsToastData data) => host._update(this, data);

  @override
  void dismiss() => host._dismiss(this);

  void dispose() {
    curved.dispose();
    controller.dispose();
  }
}

class _FsToastHostState extends State<FsToastHost>
    with TickerProviderStateMixin
    implements FsToastController {
  /// Oldest first; dismissed ones stay until their exit has run.
  final List<_Entry> _entries = [];
  Timer? _countdown;
  bool _hovered = false;

  static const Duration _tick = Duration(milliseconds: 100);

  @override
  FsToastHandle show(FsToastData data) {
    final entry = _Entry(
      this,
      data,
      AnimationController(vsync: this, duration: FsMotion.slow),
    );
    entry.controller.addStatusListener((status) {
      if (status != AnimationStatus.dismissed || !mounted) return;
      // Gone, or back in the queue: either way it leaves the stack.
      setState(() {
        if (entry.dismissed && _entries.remove(entry)) entry.dispose();
      });
    });
    setState(() => _entries.add(entry));
    _sync();
    return entry;
  }

  void _update(_Entry entry, FsToastData data) {
    if (entry.dismissed || !mounted) return;
    setState(() {
      entry
        ..data = data
        ..remaining = FsToastHost.autoDismiss;
    });
    _sync();
  }

  void _dismiss(_Entry entry) {
    if (entry.dismissed || !mounted) return;
    setState(() => entry.dismissed = true);
    _sync();
  }

  /// The newest [FsToastHost.maxVisible] live entries.
  Iterable<_Entry> get _visible =>
      _entries.reversed.where((e) => !e.dismissed).take(FsToastHost.maxVisible);

  /// Runs enter and exit animations and the countdown for what is visible.
  void _sync() {
    final visible = _visible.toSet();
    for (final entry in List.of(_entries)) {
      if (visible.contains(entry)) {
        unawaited(entry.controller.forward());
      } else if (entry.controller.isDismissed) {
        // A waiting entry that never showed, or a dismissed one at rest.
        if (entry.dismissed && _entries.remove(entry)) entry.dispose();
      } else {
        unawaited(entry.controller.reverse());
      }
    }
    final counting = visible.any((e) => e.data.autoDismisses);
    if (counting) {
      _countdown ??= Timer.periodic(_tick, (_) => _onTick());
    } else {
      _countdown?.cancel();
      _countdown = null;
    }
  }

  void _onTick() {
    if (_hovered) return;
    for (final entry in _visible.toList()) {
      if (!entry.data.autoDismisses) continue;
      entry.remaining -= _tick;
      if (entry.remaining <= Duration.zero) _dismiss(entry);
    }
  }

  @override
  void dispose() {
    _countdown?.cancel();
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Newest on top; entries at rest that aren't visible are not built.
    final visible = _visible.toSet();
    final shown = _entries.reversed.where(
      (e) => !e.controller.isDismissed || visible.contains(e),
    );
    return _ToastScope(
      controller: this,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            right: FsSpacing.s4,
            bottom: FsSpacing.s4,
            child: MouseRegion(
              onEnter: (_) => _hovered = true,
              onExit: (_) => _hovered = false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final entry in shown)
                    _ToastSlot(
                      key: entry.key,
                      animation: entry.curved,
                      child: FsToast(
                        data: entry.data,
                        dismissTooltip: widget.dismissTooltip,
                        onDismiss: entry.dismiss,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One toast's place in the stack: it fades and grows in, and shrinks and
/// fades out, so the others slide into place.
class _ToastSlot extends StatelessWidget {
  const _ToastSlot({super.key, required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: animation,
      alignment: AlignmentDirectional.bottomEnd,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(top: FsSpacing.s2),
          child: child,
        ),
      ),
    );
  }
}

class _ToastScope extends InheritedWidget {
  const _ToastScope({required this.controller, required super.child});

  final FsToastController controller;

  @override
  bool updateShouldNotify(_ToastScope oldWidget) =>
      controller != oldWidget.controller;
}
