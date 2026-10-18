import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

class NumberPropertyPage extends StatefulWidget {
  const NumberPropertyPage({super.key});

  @override
  State<NumberPropertyPage> createState() => _NumberPropertyPageState();
}

class _NumberPropertyPageState extends State<NumberPropertyPage> {
  double _priority = 10;
  double _speed = 180;
  PrValueSource _speedSource = PrValueSource.codeDefault;
  double _opacity = 0.85;
  double _jumpForce = 520;
  late final _lock = _SimulatedLock(_note);
  final _log = <String>[];

  void _note(String text) => setState(() {
    _log.insert(0, text);
    if (_log.length > 6) _log.removeLast();
  });

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    Widget priority({
      Set<WidgetState> states = const {},
      String? part,
      bool enabled = true,
      bool mixed = false,
      PrValueSource source = PrValueSource.codeDefault,
    }) => forced(
      states,
      part: part,
      PrNumberProperty(
        label: 'priority',
        value: mixed ? null : 10,
        mixed: mixed,
        kind: PrNumberKind.int,
        source: source,
        enabled: enabled,
        onReset: noop,
        resetTooltip: 'Reset to default',
        onChanged: noop,
        onCommit: noop,
      ),
    );
    Widget speed({
      Set<WidgetState> states = const {},
      String? part,
      bool enabled = true,
      bool mixed = false,
      PrValueSource source = PrValueSource.codeDefault,
      double value = 180,
    }) => forced(
      states,
      part: part,
      PrNumberProperty(
        label: 'speed',
        value: mixed ? null : value,
        mixed: mixed,
        unit: 'px/s',
        source: source,
        enabled: enabled,
        onReset: noop,
        resetTooltip: 'Reset to default',
        onChanged: noop,
        onCommit: noop,
      ),
    );
    Widget opacity({
      Set<WidgetState> states = const {},
      String? part,
      Set<WidgetState> slider = const {},
      bool enabled = true,
      bool mixed = false,
      PrValueSource source = PrValueSource.codeDefault,
      double value = 0.85,
    }) => forced(
      states,
      part: part,
      forced(
        slider,
        part: 'slider',
        PrNumberProperty(
          label: 'opacity',
          value: mixed ? null : value,
          mixed: mixed,
          min: 0,
          max: 1,
          slider: true,
          source: source,
          enabled: enabled,
          onReset: noop,
          resetTooltip: 'Reset to default',
          onChanged: noop,
          onCommit: noop,
        ),
      ),
    );
    GridRow row(
      String label, {
      Set<WidgetState> slider = const {},
      Set<WidgetState> states = const {},
      String? part,
      bool enabled = true,
      bool mixed = false,
      PrValueSource source = PrValueSource.codeDefault,
    }) => GridRow(label, [
      priority(
        states: states,
        part: part,
        enabled: enabled,
        mixed: mixed,
        source: source,
      ),
      speed(
        states: states,
        part: part,
        enabled: enabled,
        mixed: mixed,
        source: source,
      ),
      opacity(
        states: states,
        part: part,
        slider: slider,
        enabled: enabled,
        mixed: mixed,
        source: source,
      ),
    ]);

    return GalleryPage(
      title: 'NumberProperty',
      note:
          'Scrub: press on the label and drag, 1 step per 2px, Shift ×10, '
          'Alt ×0.1; the cursor stays visible (no hide or wrap yet). Click or '
          'Enter edits with the value selected; Enter or Tab commits; Esc '
          'reverts; ↑/↓ step. Typed expressions (32*2, +=8) are evaluated on '
          'commit. With a range, the slider variant: drag it or use ← →.',
      children: [
        StateGrid(
          columns: const ['int', 'double + unit', 'double · range slider'],
          rows: [
            row('Default'),
            row(
              'Hover · label',
              states: {WidgetState.hovered},
              slider: {WidgetState.hovered},
            ),
            row(
              'Scrubbing',
              states: {WidgetState.dragged},
              slider: {WidgetState.pressed},
            ),
            row(
              'Focused · editing',
              states: {WidgetState.focused},
              part: 'field',
            ),
            row('Disabled', enabled: false),
            row('Error', states: {WidgetState.error}),
            row('Mixed', mixed: true),
            row('Overridden', source: PrValueSource.overridden),
          ],
        ),
        const SectionLabel('Live'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SampleBox(
              width: 320,
              child: Column(
                children: [
                  PrNumberProperty(
                    label: 'priority',
                    value: _priority,
                    kind: PrNumberKind.int,
                    tooltip: 'int · default 10',
                    onChanged: (v) => setState(() => _priority = v),
                    onCommit: (v) => _note('priority → ${v.round()}'),
                  ),
                  PrNumberProperty(
                    label: 'speed',
                    value: _speed,
                    unit: 'px/s',
                    source: _speedSource,
                    onReset: () => setState(() {
                      _speed = 180;
                      _speedSource = PrValueSource.codeDefault;
                      _note('speed reset');
                    }),
                    resetTooltip: 'Reset to default',
                    tooltip: 'double · default 180.0',
                    onChanged: (v) => setState(() {
                      _speed = v;
                      _speedSource = PrValueSource.overridden;
                    }),
                    onCommit: (v) => _note('speed → $v'),
                  ),
                  PrNumberProperty(
                    label: 'opacity',
                    value: _opacity,
                    min: 0,
                    max: 1,
                    slider: true,
                    validator: (v) =>
                        v < 0 || v > 1 ? 'Expected a number from 0 to 1' : null,
                    invalidMessage: 'Expected a number from 0 to 1',
                    onChanged: (v) => setState(() => _opacity = v),
                    onCommit: (v) => _note('opacity → $v'),
                  ),
                  // The PrPlatformHooks path, with a lock that only
                  // forwards pointer movement (no native code here).
                  PrPlatformHooks(
                    pointerLock: _lock,
                    child: PrNumberProperty(
                      label: 'jumpForce',
                      value: _jumpForce,
                      unit: 'px/s',
                      tooltip: 'Scrubs through a simulated PrPointerLock',
                      onChanged: (v) => setState(() => _jumpForce = v),
                      onCommit: (v) => _note('jumpForce → $v'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: PrSpacing.s4),
            SizedBox(
              width: 280,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('onCommit and pointer-lock log'),
                  for (final line in _log)
                    Text(
                      line,
                      style: PrText.mono.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Stands in for the macOS runner's lock: it reports the pointer's
/// movement through the lock callback (the cursor stays visible, since
/// hiding it needs native code) and logs lock and unlock.
class _SimulatedLock implements PrPointerLock {
  _SimulatedLock(this.note);

  final void Function(String) note;
  void Function(Offset delta)? _onMove;

  void _route(PointerEvent event) {
    if (event is PointerMoveEvent) _onMove?.call(event.delta);
  }

  @override
  Future<bool> lock(void Function(Offset delta) onMove) async {
    note('pointer lock taken');
    _onMove = onMove;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_route);
    return true;
  }

  @override
  Future<void> unlock() async {
    note('pointer lock released');
    _onMove = null;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_route);
  }
}
