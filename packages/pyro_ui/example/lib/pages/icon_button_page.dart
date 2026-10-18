import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

class IconButtonPage extends StatefulWidget {
  const IconButtonPage({super.key});

  @override
  State<IconButtonPage> createState() => _IconButtonPageState();
}

class _IconButtonPageState extends State<IconButtonPage> {
  bool _grid = true;

  @override
  Widget build(BuildContext context) {
    Widget cell(
      IconData icon,
      PrIconButtonSize size, {
      Set<WidgetState> states = const {},
      bool enabled = true,
      bool selected = false,
    }) => Padding(
      padding: const EdgeInsets.all(PrSpacing.s2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: forced(
          states,
          PrIconButton(
            icon: icon,
            tooltip: 'Sample',
            size: size,
            selected: selected,
            onPressed: enabled ? () {} : null,
          ),
        ),
      ),
    );
    GridRow row(String label, IconData icon, PrIconButtonSize size) =>
        GridRow(label, [
          cell(icon, size),
          cell(icon, size, states: {WidgetState.hovered}),
          cell(icon, size, states: {WidgetState.pressed}),
          cell(icon, size, states: {WidgetState.focused}),
          cell(icon, size, enabled: false),
          cell(icon, size, selected: true),
        ]);

    return GalleryPage(
      title: 'IconButton',
      note:
          'Always has a tooltip with the action name and its shortcut. '
          'Selected = latched on (use ToggleButton for that).',
      children: [
        StateGrid(
          columns: const [
            'Default',
            'Hover',
            'Pressed',
            'Focused',
            'Disabled',
            'Selected',
          ],
          cellWidth: 72,
          labelWidth: 100,
          rows: [
            row('24 · toolbar', PrIcons.undo, PrIconButtonSize.regular),
            row('20 · header', PrIcons.plus, PrIconButtonSize.small),
            row('20 · row', PrIcons.eye, PrIconButtonSize.small),
          ],
        ),
        const SectionLabel('Live'),
        PrTooltipGroup(
          child: Row(
            children: [
              PrIconButton(
                icon: PrIcons.undo,
                tooltip: 'Undo',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  meta: true,
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 2),
              const PrIconButton(
                icon: PrIcons.redo,
                tooltip: 'Redo',
                shortcut: SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  meta: true,
                  shift: true,
                ),
                onPressed: null,
                disabledReason: 'Nothing to redo',
              ),
              const SizedBox(width: 2),
              PrIconButton(
                icon: PrIcons.grid,
                tooltip: 'Show grid',
                selected: _grid,
                onPressed: () => setState(() => _grid = !_grid),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
