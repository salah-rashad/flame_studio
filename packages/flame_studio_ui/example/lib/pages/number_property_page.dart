import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

class NumberPropertyPage extends StatefulWidget {
  const NumberPropertyPage({super.key});

  @override
  State<NumberPropertyPage> createState() => _NumberPropertyPageState();
}

class _NumberPropertyPageState extends State<NumberPropertyPage> {
  double _priority = 10;
  double _speed = 180;
  FsValueSource _speedSource = FsValueSource.codeDefault;
  double _opacity = 0.85;
  final _log = <String>[];

  void _note(String text) => setState(() {
    _log.insert(0, text);
    if (_log.length > 6) _log.removeLast();
  });

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    Widget priority({
      Set<WidgetState> states = const {},
      String? part,
      bool enabled = true,
      bool mixed = false,
      FsValueSource source = FsValueSource.codeDefault,
    }) => forced(
      states,
      part: part,
      FsNumberProperty(
        label: 'priority',
        value: mixed ? null : 10,
        mixed: mixed,
        kind: FsNumberKind.int,
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
      FsValueSource source = FsValueSource.codeDefault,
      double value = 180,
    }) => forced(
      states,
      part: part,
      FsNumberProperty(
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
    GridRow row(
      String label, {
      Set<WidgetState> states = const {},
      String? part,
      bool enabled = true,
      bool mixed = false,
      FsValueSource source = FsValueSource.codeDefault,
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
    ]);

    return GalleryPage(
      title: 'NumberProperty',
      note:
          'Scrub: press on the label and drag, 1 step per 2px, Shift ×10, '
          'Alt ×0.1; the cursor stays visible (no hide or wrap yet). Click or '
          'Enter edits with the value selected; Enter or Tab commits; Esc '
          'reverts; ↑/↓ step. Not yet: the range slider column and '
          'expressions (32*2, +=8).',
      children: [
        StateGrid(
          columns: const ['int', 'double + unit'],
          rows: [
            row('Default'),
            row('Hover · label', states: {WidgetState.hovered}),
            row('Scrubbing', states: {WidgetState.dragged}),
            row(
              'Focused · editing',
              states: {WidgetState.focused},
              part: 'field',
            ),
            row('Disabled', enabled: false),
            row('Error', states: {WidgetState.error}),
            row('Mixed', mixed: true),
            row('Overridden', source: FsValueSource.overridden),
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
                  FsNumberProperty(
                    label: 'priority',
                    value: _priority,
                    kind: FsNumberKind.int,
                    tooltip: 'int · default 10',
                    onChanged: (v) => setState(() => _priority = v),
                    onCommit: (v) => _note('priority → ${v.round()}'),
                  ),
                  FsNumberProperty(
                    label: 'speed',
                    value: _speed,
                    unit: 'px/s',
                    source: _speedSource,
                    onReset: () => setState(() {
                      _speed = 180;
                      _speedSource = FsValueSource.codeDefault;
                      _note('speed reset');
                    }),
                    resetTooltip: 'Reset to default',
                    tooltip: 'double · default 180.0',
                    onChanged: (v) => setState(() {
                      _speed = v;
                      _speedSource = FsValueSource.overridden;
                    }),
                    onCommit: (v) => _note('speed → $v'),
                  ),
                  FsNumberProperty(
                    label: 'opacity',
                    value: _opacity,
                    min: 0,
                    max: 1,
                    validator: (v) =>
                        v < 0 || v > 1 ? 'Expected a number from 0 to 1' : null,
                    invalidMessage: 'Expected a number from 0 to 1',
                    onChanged: (v) => setState(() => _opacity = v),
                    onCommit: (v) => _note('opacity → $v'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FsSpacing.s4),
            SizedBox(
              width: 280,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('onCommit log (one per gesture or edit)'),
                  for (final line in _log)
                    Text(
                      line,
                      style: FsText.mono.copyWith(color: c.textSecondary),
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
