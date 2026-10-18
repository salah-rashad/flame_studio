import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

class ToggleButtonPage extends StatefulWidget {
  const ToggleButtonPage({super.key});

  @override
  State<ToggleButtonPage> createState() => _ToggleButtonPageState();
}

class _ToggleButtonPageState extends State<ToggleButtonPage> {
  bool _grid = true;
  bool _hitboxes = false;
  bool _snap = true;

  @override
  Widget build(BuildContext context) {
    Widget cell(
      bool text, {
      bool value = false,
      Set<WidgetState> states = const {},
      bool enabled = true,
    }) {
      final toggle = PrToggleButton(
        icon: text ? PrIcons.magnet : PrIcons.grid,
        label: text ? 'Snap' : null,
        value: value,
        tooltip: 'Sample',
        onChanged: enabled ? (_) {} : null,
      );
      return Padding(
        padding: const EdgeInsets.all(PrSpacing.s2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: states.isEmpty ? toggle : forced(states, toggle),
        ),
      );
    }

    GridRow row(String name, bool text) => GridRow(name, [
      cell(text),
      cell(text, states: {WidgetState.hovered}),
      cell(text, states: {WidgetState.pressed}),
      cell(text, states: {WidgetState.focused}),
      cell(text, enabled: false),
      cell(text, value: true),
      cell(text, value: true, states: {WidgetState.hovered}),
      cell(text, value: true, states: {WidgetState.focused}),
    ]);

    return GalleryPage(
      title: 'ToggleButton',
      note:
          'A button that stays on. Use a segmented control when exactly one '
          'of several options must be on.',
      children: [
        StateGrid(
          columns: const [
            'Off',
            'Hover',
            'Pressed',
            'Focused',
            'Disabled',
            'On',
            'On · hover',
            'On · focused',
          ],
          cellWidth: 96,
          labelWidth: 100,
          rows: [row('Icon toggle', false), row('Text toggle', true)],
        ),
        const SectionLabel('Live'),
        PrTooltipGroup(
          child: Row(
            children: [
              PrToggleButton(
                icon: PrIcons.grid,
                value: _grid,
                tooltip: 'Show grid',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyG,
                  meta: true,
                ),
                onChanged: (v) => setState(() => _grid = v),
              ),
              const SizedBox(width: 2),
              PrToggleButton(
                icon: PrIcons.hitbox,
                value: _hitboxes,
                tooltip: 'Show hitboxes',
                onChanged: (v) => setState(() => _hitboxes = v),
              ),
              const SizedBox(width: PrSpacing.s2),
              PrToggleButton(
                icon: PrIcons.magnet,
                label: 'Snap',
                value: _snap,
                tooltip: 'Snap to grid',
                onChanged: (v) => setState(() => _snap = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
