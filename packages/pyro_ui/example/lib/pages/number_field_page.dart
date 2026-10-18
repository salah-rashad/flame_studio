import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

class NumberFieldPage extends StatefulWidget {
  const NumberFieldPage({super.key});

  @override
  State<NumberFieldPage> createState() => _NumberFieldPageState();
}

class _NumberFieldPageState extends State<NumberFieldPage> {
  double _grid = 16;
  double _zoom = 100;

  @override
  Widget build(BuildContext context) {
    Widget cell(
      String? unit, {
      double value = 16,
      Set<WidgetState> states = const {},
      bool enabled = true,
      bool mixed = false,
    }) {
      final field = PrNumberField(
        value: mixed ? null : value,
        mixed: mixed,
        kind: PrNumberKind.int,
        unit: unit,
        width: 120,
        onChanged: enabled ? noop : null,
        onCommit: enabled ? noop : null,
      );
      return Padding(
        padding: const EdgeInsets.all(PrSpacing.s2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: states.isEmpty ? field : forced(states, field, part: 'field'),
        ),
      );
    }

    GridRow row(
      String name, {
      double value = 16,
      Set<WidgetState> states = const {},
      bool enabled = true,
      bool mixed = false,
    }) => GridRow(name, [
      for (final unit in [null, 'px'])
        cell(
          unit,
          value: value,
          states: states,
          enabled: enabled,
          mixed: mixed,
        ),
    ]);

    return GalleryPage(
      title: 'NumberField',
      note:
          'Standalone number field (dialogs, toolbars, grid size). Drag the '
          'value to scrub; click to edit. In the inspector use the Number '
          'property, where the label is the scrub handle. Values are mono, '
          'left-aligned.',
      children: [
        StateGrid(
          columns: const ['Plain', 'With unit'],
          cellWidth: 160,
          labelWidth: 88,
          rows: [
            row('Default'),
            row('Hover', states: {WidgetState.hovered}),
            row('Scrubbing', value: 24, states: {WidgetState.dragged}),
            row('Focused', states: {WidgetState.focused}),
            row('Disabled', enabled: false),
            row('Error', states: {WidgetState.error}),
            row('Mixed', mixed: true),
          ],
        ),
        const SectionLabel('Live · grid size (1–256) and zoom'),
        Row(
          children: [
            PrNumberField(
              value: _grid,
              kind: PrNumberKind.int,
              min: 1,
              max: 256,
              unit: 'px',
              width: 120,
              invalidMessage: 'Expected a whole number from 1 to 256',
              onChanged: (v) => setState(() => _grid = v),
              onCommit: (v) => setState(() => _grid = v),
            ),
            const SizedBox(width: PrSpacing.s4),
            PrNumberField(
              value: _zoom,
              kind: PrNumberKind.int,
              min: 10,
              max: 800,
              step: 10,
              unit: '%',
              width: 96,
              size: PrFieldSize.dense,
              stepper: false,
              onChanged: (v) => setState(() => _zoom = v),
              onCommit: (v) => setState(() => _zoom = v),
            ),
          ],
        ),
      ],
    );
  }
}
