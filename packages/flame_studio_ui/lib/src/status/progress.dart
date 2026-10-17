import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../colors.dart';
import '../metrics.dart';
import '../typography.dart';

/// Whose wait a [FsProgressBar] or [FsSpinner] shows, which sets its
/// colour.
enum FsProgressTone {
  /// The user is waiting on it: `accent-text`.
  foreground,

  /// It runs in the background (hot reload, an import): `info`.
  background,
}

/// A 2px progress bar: track `surface-pressed`, indicator `accent-text`
/// ([FsProgressTone.foreground]) or `info` ([FsProgressTone.background]).
///
/// With a [value] (0…1) the indicator fills that fraction from the left;
/// without one it is indeterminate: a 30% segment slides across every
/// 1.2s. Under reduce-motion (`MediaQuery.disableAnimations`) it slides
/// over 3s instead of stopping.
///
/// It takes the full width it is given, so it needs a bounded width. In an
/// `FsPanel` it goes in `headerProgress`, over the top of the body.
class FsProgressBar extends StatelessWidget {
  /// Creates a bar; null [value] is indeterminate.
  const FsProgressBar({
    super.key,
    this.value,
    this.tone = FsProgressTone.foreground,
    this.semanticsLabel,
  });

  /// The fraction done, 0…1; null while unknown.
  final double? value;

  /// The indicator's colour.
  final FsProgressTone tone;

  /// What is in progress, for screen readers.
  final String? semanticsLabel;

  /// The bar's height.
  static const double height = 2;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final ink = _ink(c, tone);
    final fraction = value?.clamp(0.0, 1.0);
    return Semantics(
      label: semanticsLabel,
      value: fraction == null ? null : '${(fraction * 100).round()}%',
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: fraction != null
            ? CustomPaint(
                painter: _BarPainter(
                  track: c.surfacePressed,
                  ink: ink,
                  start: 0,
                  extent: fraction,
                ),
              )
            : _Looping(
                period: const Duration(milliseconds: 1200),
                builder: (context, t) => CustomPaint(
                  painter: _BarPainter(
                    track: c.surfacePressed,
                    ink: ink,
                    // CSS fs-slide: left −30% → 100%,
                    // cubic-bezier(.4, 0, .2, 1).
                    start: -0.3 + 1.3 * Curves.fastOutSlowIn.transform(t),
                    extent: 0.3,
                  ),
                ),
              ),
      ),
    );
  }
}

/// A small spinner: a 2px `surface-pressed` ring with a quarter arc in
/// `accent-text` (or `info` for [FsProgressTone.background]) turning every
/// 0.8s; 3s under reduce-motion.
///
/// 14px by default, 16 in toolbars. Pair it with a label, or show it
/// through [FsDelayedProgress].
class FsSpinner extends StatelessWidget {
  /// Creates a spinner.
  const FsSpinner({
    super.key,
    this.size = FsSizes.iconSm,
    this.tone = FsProgressTone.foreground,
  });

  /// Width and height: 14, or 16 in toolbars.
  final double size;

  /// The arc's colour.
  final FsProgressTone tone;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final ink = _ink(c, tone);
    return SizedBox.square(
      dimension: size,
      child: _Looping(
        period: const Duration(milliseconds: 800),
        builder: (context, t) => CustomPaint(
          painter: _SpinnerPainter(track: c.surfacePressed, ink: ink, turn: t),
        ),
      ),
    );
  }
}

/// The runtime states a [FsStatusDot] shows.
enum FsStatus {
  /// Nothing running: `status-idle`.
  idle,

  /// Busy (hot reloading, building): `info`, pulsing.
  working,

  /// Running fine: `success`.
  ok,

  /// Crashed or failed: `error`.
  error,
}

/// An 8px status dot with its label (colour never stands alone): idle,
/// working (pulses every 1.2s; 3s under reduce-motion), ok, error.
///
/// Label in `small` `text-secondary`, 6px after the dot.
class FsStatusDot extends StatelessWidget {
  /// Creates the dot and label.
  const FsStatusDot({super.key, required this.status, required this.label});

  /// Sets the colour, and the pulse for [FsStatus.working].
  final FsStatus status;

  /// What the status is ("Running · 60 fps").
  final String label;

  /// The dot's diameter.
  static const double dotSize = 8;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final fill = switch (status) {
      FsStatus.idle => c.statusIdle,
      FsStatus.working => c.info,
      FsStatus.ok => c.success,
      FsStatus.error => c.error,
    };
    final dot = Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(color: fill, borderRadius: FsRadii.full),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        // CSS fs-pulse: opacity 1 → .35 → 1, ease-in-out.
        _Looping(
          period: const Duration(milliseconds: 1200),
          running: status == FsStatus.working,
          builder: (context, t) => Opacity(
            opacity: status == FsStatus.working
                ? 1 - 0.65 * Curves.easeInOut.transform(1 - (2 * t - 1).abs())
                : 1,
            child: dot,
          ),
        ),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: FsText.small.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Shows [child] (a bar or a spinner) only once [busy] has been true for
/// `FsMotion.progressDelay` (300ms), so quick work shows no progress at
/// all; hides it as soon as [busy] turns false.
class FsDelayedProgress extends StatefulWidget {
  /// Creates the delay.
  const FsDelayedProgress({super.key, required this.busy, required this.child});

  /// Whether the work is running.
  final bool busy;

  /// The progress indicator.
  final Widget child;

  @override
  State<FsDelayedProgress> createState() => _FsDelayedProgressState();
}

class _FsDelayedProgressState extends State<FsDelayedProgress> {
  Timer? _timer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (widget.busy) _start();
  }

  @override
  void didUpdateWidget(FsDelayedProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy == oldWidget.busy) return;
    if (widget.busy) {
      _start();
    } else {
      _timer?.cancel();
      _shown = false;
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer(FsMotion.progressDelay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _shown ? widget.child : const SizedBox.shrink();
}

Color _ink(FsColors c, FsProgressTone tone) => switch (tone) {
  FsProgressTone.foreground => c.accentText,
  FsProgressTone.background => c.info,
};

/// Runs a repeating 0…1 animation over [period] while [running] (3s under
/// reduce-motion, which slows the loop instead of stopping it) and builds
/// with its value.
class _Looping extends StatefulWidget {
  const _Looping({
    required this.period,
    required this.builder,
    this.running = true,
  });

  final Duration period;
  final bool running;
  final Widget Function(BuildContext context, double t) builder;

  /// The period under reduce-motion (the design's 3s).
  static const Duration reduced = Duration(seconds: 3);

  @override
  State<_Looping> createState() => _LoopingState();
}

class _LoopingState extends State<_Looping>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Looping oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final period = MediaQuery.disableAnimationsOf(context)
        ? _Looping.reduced
        : widget.period;
    final changed = _controller.duration != period;
    _controller.duration = period;
    if (!widget.running) {
      _controller
        ..stop()
        ..value = 0;
    } else if (changed || !_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(context, _controller.value),
  );
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.track,
    required this.ink,
    required this.start,
    required this.extent,
  });

  final Color track;
  final Color ink;

  /// Left edge of the indicator, as a fraction of the width.
  final double start;

  /// Width of the indicator, as a fraction of the width.
  final double extent;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(bounds, const Radius.circular(1)))
      ..drawRect(bounds, Paint()..color = track)
      ..drawRect(
        Rect.fromLTWH(start * size.width, 0, extent * size.width, size.height),
        Paint()..color = ink,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.track != track ||
      old.ink != ink ||
      old.start != start ||
      old.extent != extent;
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({required this.track, required this.ink, required this.turn});

  final Color track;
  final Color ink;

  /// How far round the arc is, 0…1.
  final double turn;

  static const double _stroke = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    canvas.drawCircle(rect.center, rect.width / 2, paint..color = track);
    // The CSS top border: the quarter centred on 12 o'clock.
    canvas.drawArc(
      rect,
      -0.75 * math.pi + turn * 2 * math.pi,
      math.pi / 2,
      false,
      paint..color = ink,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.track != track || old.ink != ink || old.turn != turn;
}
