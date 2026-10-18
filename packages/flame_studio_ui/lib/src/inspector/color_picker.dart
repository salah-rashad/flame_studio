import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../actions/icon_button.dart';
import '../colors.dart';
import '../foundation/field_box.dart';
import '../foundation/focus_ring.dart';
import '../foundation/interactive.dart';
import '../foundation/number_editing.dart';
import '../foundation/platform_hooks.dart';
import '../icons.dart';
import '../inputs/number_field.dart';
import '../metrics.dart';
import '../shadows.dart';
import '../typography.dart';
import 'hex_input.dart';

/// Marks drawn over arbitrary colours (the SV marker, the hue thumb, the
/// swatch edge): fixed by the design to stay visible on any colour, so they
/// aren't theme tokens.
abstract final class FsSwatchInk {
  /// The white of markers and thumbs.
  static const Color marker = Colors.white;

  /// The 1px dark ring around markers (black 50%).
  static const Color markerRing = Color.fromRGBO(0, 0, 0, 0.5);

  /// The 1px inner edge of swatches (white 15%), so dark colours stay
  /// visible on the panel.
  static const Color swatchEdge = Color.fromRGBO(255, 255, 255, 0.15);
}

/// The colour picker popover's content: a saturation/value area, a hue
/// slider, the hex and alpha fields, and the recent colours.
///
/// - 232px wide, 8px padding and gaps, on the overlay surface
///   (`surface-overlay`, `border-overlay`, `radius-md`, the popover shadow).
/// - **SV area** (120px): drag to set saturation (→) and brightness (↑);
///   a 10px white ring marks the colour. From the keyboard, ← → step the
///   saturation and ↑ ↓ the brightness by 1% (Shift: 10%). [autofocus]
///   focuses it.
/// - **Hue slider** (8px): drag to set the hue; a 12×14 white thumb. From
///   the keyboard, → and ↑ step it up by 1°, ← and ↓ down (Shift: 10°), as
///   sliders do.
/// - Both take focus (a click focuses them too) and draw the focus ring for
///   keyboard focus; screen readers get them as sliders named [areaLabel]
///   and [hueLabel], valued "40%, 80%" (saturation, brightness) and "210°".
///   Tab order: SV area, hue, hex, alpha.
/// - **Hex** (`FFD7A8`, the alpha kept) and **alpha** (0–100 %, a number
///   field that also scrubs).
/// - **Eyedropper:** a 20px button before the hex field, only when
///   `FsPlatformHooks.sampleScreenColor` is set; the sampled colour keeps
///   the current alpha.
/// - **Recent colours:** 20×16 swatches; a click picks one.
///
/// Dragging calls [onChanged] while moving and [onCommit] once on release.
/// Arrow-key steps are treated like a drag: [onChanged] on each press and
/// one [onCommit] when the run of presses ends (half a second without one,
/// focus leaving the area or slider, or the picker closing). Fields,
/// swatches and the eyedropper call both at once. The hue is kept while
/// saturation or brightness is zero, so dragging back restores it.
///
/// Usually shown by `FsColorProperty`'s swatch; it can be placed directly.
class FsColorPicker extends StatefulWidget {
  /// Creates the picker.
  const FsColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onCommit,
    this.recentColors = const [],
    this.eyedropperTooltip,
    this.areaLabel,
    this.hueLabel,
    this.autofocus = false,
  });

  /// The colour.
  final Color value;

  /// Continuous, while dragging.
  final ValueChanged<Color> onChanged;

  /// Once per drag, field edit, swatch click or sample.
  final ValueChanged<Color> onCommit;

  /// The recent colours, newest first; the app keeps the list.
  final List<Color> recentColors;

  /// The eyedropper button's tooltip ("Pick a colour from the screen").
  final String? eyedropperTooltip;

  /// The SV area's semantics label ("Saturation and brightness").
  final String? areaLabel;

  /// The hue slider's semantics label ("Hue").
  final String? hueLabel;

  /// Focus the SV area when shown.
  final bool autofocus;

  /// The popover's width.
  static const double width = 232;

  @override
  State<FsColorPicker> createState() => _FsColorPickerState();
}

class _FsColorPickerState extends State<FsColorPicker> {
  final _svFocus = FocusNode(debugLabel: 'FsColorPicker SV area');
  final _hexFocus = FocusNode(debugLabel: 'hex');
  late HSVColor _hsv = HSVColor.fromColor(widget.value);
  Color? _dragStart;

  /// The colour before the current run of arrow-key steps; null outside one.
  Color? _stepStart;
  Timer? _stepIdle;

  /// How long after the last arrow-key step its run ends and commits.
  static const Duration _stepCommitDelay = Duration(milliseconds: 500);

  static const double _padding = 8;
  static const double _svHeight = 120;
  static const double _hueHeight = 8;
  static const int _recentMax = 9;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _svFocus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(FsColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep our hue (and saturation) when the new value is the colour they
    // already make; otherwise follow the value.
    if (widget.value != oldWidget.value && widget.value != _color) {
      final next = HSVColor.fromColor(widget.value);
      _hsv = next.saturation == 0 || next.value == 0
          ? next.withHue(_hsv.hue)
          : next;
    }
  }

  @override
  void dispose() {
    // Closing mid-run still commits it; after this frame, as the tree is
    // locked now.
    final start = _stepStart;
    _stepIdle?.cancel();
    if (start != null && _color != start) {
      final color = _color;
      final onCommit = widget.onCommit;
      WidgetsBinding.instance.addPostFrameCallback((_) => onCommit(color));
    }
    _svFocus.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor().withValues(alpha: widget.value.a);

  void _set(HSVColor hsv) {
    final before = _color;
    setState(() => _hsv = hsv);
    if (_color != before) widget.onChanged(_color);
  }

  /// An arrow-key step: a change now, committed when the run of steps ends.
  void _step(HSVColor hsv) {
    _stepStart ??= _color;
    _set(hsv);
    _stepIdle?.cancel();
    _stepIdle = Timer(_stepCommitDelay, _endSteps);
  }

  /// Ends a run of arrow-key steps: one commit if it changed the colour.
  void _endSteps() {
    final start = _stepStart;
    _stepStart = null;
    _stepIdle?.cancel();
    _stepIdle = null;
    if (start != null && _color != start) widget.onCommit(_color);
  }

  HSVColor _svStepped(Offset step) => _hsv
      .withSaturation((_hsv.saturation + step.dx / 100).clamp(0.0, 1.0))
      .withValue((_hsv.value + step.dy / 100).clamp(0.0, 1.0));

  HSVColor _hueStepped(Offset step) =>
      _hsv.withHue((_hsv.hue + step.dx).clamp(0.0, 360.0));

  static String _svText(HSVColor hsv) =>
      '${(hsv.saturation * 100).round()}%, ${(hsv.value * 100).round()}%';

  static String _hueText(HSVColor hsv) => '${hsv.hue.round()}°';

  void _dragStarted() {
    _endSteps();
    _dragStart = widget.value;
  }

  void _dragEnded() {
    final start = _dragStart;
    _dragStart = null;
    if (start != null && _color != start) widget.onCommit(_color);
  }

  void _pick(Color color) {
    _endSteps();
    final next = HSVColor.fromColor(color);
    setState(() {
      _hsv = next.saturation == 0 || next.value == 0
          ? next.withHue(_hsv.hue)
          : next;
    });
    widget.onChanged(color);
    widget.onCommit(color);
  }

  Future<void> _sample(Future<Color?> Function() sample) async {
    final color = await sample();
    if (color == null || !mounted) return;
    _pick(FsColorText.withAlphaOf(color, widget.value));
  }

  void _alpha(double percent, {required bool commit}) {
    _endSteps();
    final color = widget.value.withValues(
      alpha: FsNumberEditing.clamp(percent, min: 0, max: 100) / 100,
    );
    widget.onChanged(color);
    if (commit) widget.onCommit(color);
  }

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final sample = FsPlatformHooks.maybeOf(context)?.sampleScreenColor;
    final recent = widget.recentColors.take(_recentMax).toList();
    return Container(
      width: FsColorPicker.width,
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: c.surfaceOverlay,
        border: Border.all(color: c.borderOverlay),
        borderRadius: FsRadii.md,
        boxShadow: FsShadows.of(context).popover,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Pad(
            height: _svHeight,
            focusNode: _svFocus,
            onStart: _dragStarted,
            onEnd: _dragEnded,
            onMove: (p) => _set(_hsv.withSaturation(p.dx).withValue(1 - p.dy)),
            onStep: (step) => _step(_svStepped(step)),
            onBlur: _endSteps,
            painter: _SvPainter(_hsv),
            semanticsLabel: widget.areaLabel,
            semanticsValue: _svText(_hsv),
            increasedValue: _svText(_svStepped(const Offset(1, 0))),
            decreasedValue: _svText(_svStepped(const Offset(-1, 0))),
          ),
          const SizedBox(height: _padding),
          _Pad(
            height: _hueHeight,
            overhang: 3,
            onStart: _dragStarted,
            onEnd: _dragEnded,
            onMove: (p) => _set(_hsv.withHue(p.dx * 360)),
            onStep: (step) => _step(_hueStepped(step)),
            onBlur: _endSteps,
            vertical: false,
            painter: _HuePainter(_hsv.hue),
            semanticsLabel: widget.hueLabel,
            semanticsValue: _hueText(_hsv),
            increasedValue: _hueText(_hueStepped(const Offset(1, 0))),
            decreasedValue: _hueText(_hueStepped(const Offset(-1, 0))),
          ),
          const SizedBox(height: _padding),
          Row(
            children: [
              if (sample != null) ...[
                FsIconButton(
                  icon: FsIcons.pipette,
                  size: FsIconButtonSize.small,
                  iconSize: FsSizes.iconSm,
                  tooltip: widget.eyedropperTooltip ?? '',
                  onPressed: () => unawaited(_sample(sample)),
                ),
                const SizedBox(width: FsSpacing.s1),
              ],
              Expanded(
                child: FsHexInput(
                  value: widget.value,
                  focusNode: _hexFocus,
                  onCommit: _pick,
                  debugPart: 'hex',
                ),
              ),
              const SizedBox(width: FsSpacing.s1),
              FsNumberField(
                value: FsColorText.alphaPercent(widget.value),
                kind: FsNumberKind.int,
                min: 0,
                max: 100,
                unit: '%',
                stepper: false,
                size: FsFieldSize.dense,
                width: 52,
                onChanged: (v) => _alpha(v, commit: false),
                onCommit: (v) => _alpha(v, commit: true),
              ),
            ],
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: _padding),
            Wrap(
              spacing: FsSpacing.s1,
              runSpacing: FsSpacing.s1,
              children: [
                for (final color in recent)
                  FsInteractive(
                    onPressed: () => _pick(color),
                    focusable: false,
                    semanticsLabel: '#${FsColorText.hex(color)}',
                    cursor: SystemMouseCursors.click,
                    builder: (context, states) => FsSwatch(
                      color: color,
                      width: 20,
                      highlighted: states.contains(WidgetState.hovered),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A 28×16 (or [width]×16) solid colour swatch, `radius-xs`, with a 1px
/// white-15% inner edge so dark colours stay visible. No checkerboard: the
/// colour is drawn opaque, and transparency is read from the alpha field.
///
/// Mixed ([color] null) shows "—" on `surface-pressed`. Internal.
class FsSwatch extends StatelessWidget {
  /// Creates a swatch.
  const FsSwatch({
    super.key,
    required this.color,
    this.width = 28,
    this.highlighted = false,
    this.disabled = false,
  });

  /// The colour; null for mixed.
  final Color? color;

  /// 28 in rows, 20 in the picker's recent colours.
  final double width;

  /// A `border-strong` edge (hovered).
  final bool highlighted;

  /// The mixed dash in `text-disabled`.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    final color = this.color;
    return Container(
      width: width,
      height: 16,
      alignment: Alignment.center,
      foregroundDecoration: BoxDecoration(
        border: Border.all(
          color: highlighted
              ? c.borderStrong
              : (color == null ? Colors.transparent : FsSwatchInk.swatchEdge),
        ),
        borderRadius: FsRadii.xs,
      ),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 1) ?? c.surfacePressed,
        borderRadius: FsRadii.xs,
      ),
      child: color == null
          ? Text(
              '—',
              style: FsText.caption.copyWith(
                color: disabled ? c.textDisabled : c.textSecondary,
              ),
            )
          : null,
    );
  }
}

/// A drag surface reporting the pointer as fractions (0…1) of its size,
/// and a focusable slider: arrow keys report steps through [onStep].
class _Pad extends StatefulWidget {
  const _Pad({
    required this.height,
    required this.onStart,
    required this.onMove,
    required this.onEnd,
    required this.onStep,
    required this.onBlur,
    required this.painter,
    required this.semanticsLabel,
    required this.semanticsValue,
    required this.increasedValue,
    required this.decreasedValue,
    this.vertical = true,
    this.overhang = 0,
    this.focusNode,
  });

  final double height;
  final VoidCallback onStart;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEnd;

  /// An arrow key: (±1, 0) for ← →, (0, ±1) for ↑ ↓ (up is +1), ×10 with
  /// Shift.
  final ValueChanged<Offset> onStep;

  /// Focus left it.
  final VoidCallback onBlur;
  final CustomPainter painter;
  final String? semanticsLabel;
  final String semanticsValue;
  final String increasedValue;
  final String decreasedValue;

  /// Whether ↑ ↓ step the vertical axis (the SV area); otherwise they step
  /// the one axis like → ← (the hue bar), as sliders do.
  final bool vertical;

  /// Extra hit area above and below (the hue bar's thumb sticks out).
  final double overhang;

  /// Its focus node; the pad makes its own if null.
  final FocusNode? focusNode;

  @override
  State<_Pad> createState() => _PadState();
}

class _PadState extends State<_Pad> {
  FocusNode? _ownFocus;
  FocusNode get _focus =>
      widget.focusNode ??
      (_ownFocus ??= FocusNode(debugLabel: 'FsColorPicker pad'));

  @override
  void dispose() {
    _ownFocus?.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    if (keys.isMetaPressed || keys.isControlPressed || keys.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final Offset? step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => Offset(rtl ? -1 : 1, 0),
      LogicalKeyboardKey.arrowLeft => Offset(rtl ? 1 : -1, 0),
      LogicalKeyboardKey.arrowUp => Offset(
        widget.vertical ? 0 : 1,
        widget.vertical ? 1 : 0,
      ),
      LogicalKeyboardKey.arrowDown => Offset(
        widget.vertical ? 0 : -1,
        widget.vertical ? -1 : 0,
      ),
      _ => null,
    };
    if (step == null) return KeyEventResult.ignored;
    widget.onStep(keys.isShiftPressed ? step * 10 : step);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, widget.height);
        Offset fraction(Offset local) => Offset(
          (local.dx / size.width).clamp(0.0, 1.0),
          ((local.dy - widget.overhang) / size.height).clamp(0.0, 1.0),
        );
        return Semantics(
          slider: true,
          label: widget.semanticsLabel,
          value: widget.semanticsValue,
          increasedValue: widget.increasedValue,
          decreasedValue: widget.decreasedValue,
          onIncrease: () => widget.onStep(const Offset(1, 0)),
          onDecrease: () => widget.onStep(const Offset(-1, 0)),
          child: Focus(
            focusNode: _focus,
            includeSemantics: false,
            onKeyEvent: _onKey,
            onFocusChange: (focused) {
              setState(() {});
              if (!focused) widget.onBlur();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (d) {
                // A click focuses it too, so the arrows work next.
                _focus.requestFocus();
                widget.onStart();
                widget.onMove(fraction(d.localPosition));
              },
              onPanUpdate: (d) => widget.onMove(fraction(d.localPosition)),
              onPanEnd: (_) => widget.onEnd(),
              onPanCancel: widget.onEnd,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: widget.overhang),
                child: ListenableBuilder(
                  listenable: FsInputModality.instance,
                  builder: (context, child) => FsFocusRing.outside(
                    visible:
                        _focus.hasFocus &&
                        FsInputModality.instance.showsFocusRing,
                    child: child!,
                  ),
                  child: CustomPaint(size: size, painter: widget.painter),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The saturation/value square for one hue, with the colour's marker.
class _SvPainter extends CustomPainter {
  const _SvPainter(this.hsv);

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = FsRadii.sm.toRRect(rect);
    canvas
      ..save()
      ..clipRRect(rrect)
      ..drawRect(
        rect,
        Paint()..color = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
      )
      ..drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              FsSwatchInk.marker,
              FsSwatchInk.marker.withValues(alpha: 0),
            ],
          ).createShader(rect),
      )
      ..drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0), Colors.black],
          ).createShader(rect),
      )
      ..restore()
      ..drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = FsSwatchInk.swatchEdge,
      );
    final marker = Offset(
      hsv.saturation * size.width,
      (1 - hsv.value) * size.height,
    );
    canvas
      ..drawCircle(
        marker,
        6.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = FsSwatchInk.markerRing,
      )
      ..drawCircle(
        marker,
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = FsSwatchInk.marker,
      );
  }

  @override
  bool shouldRepaint(_SvPainter old) => hsv != old.hsv;
}

/// The hue bar with its thumb.
class _HuePainter extends CustomPainter {
  const _HuePainter(this.hue);

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      FsRadii.sm.toRRect(rect),
      Paint()
        ..shader = LinearGradient(
          colors: [
            for (var h = 0; h <= 360; h += 60)
              HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
    final x = hue / 360 * size.width;
    final thumb = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, size.height / 2),
        width: 12,
        height: 14,
      ),
      const Radius.circular(3),
    );
    canvas
      ..drawRRect(
        thumb.inflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = FsSwatchInk.markerRing,
      )
      ..drawRRect(
        thumb.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = FsSwatchInk.marker,
      );
  }

  @override
  bool shouldRepaint(_HuePainter old) => hue != old.hue;
}
