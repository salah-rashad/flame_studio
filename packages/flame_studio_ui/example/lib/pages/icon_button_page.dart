import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      FsIconButtonSize size, {
      Set<WidgetState> states = const {},
      bool enabled = true,
      bool selected = false,
    }) => Padding(
      padding: const EdgeInsets.all(FsSpacing.s2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: forced(
          states,
          FsIconButton(
            icon: icon,
            tooltip: 'Sample',
            size: size,
            selected: selected,
            onPressed: enabled ? () {} : null,
          ),
        ),
      ),
    );
    GridRow row(String label, IconData icon, FsIconButtonSize size) =>
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
            row('24 · toolbar', FsIcons.undo, FsIconButtonSize.regular),
            row('20 · header', FsIcons.plus, FsIconButtonSize.small),
            row('20 · row', FsIcons.eye, FsIconButtonSize.small),
          ],
        ),
        const SectionLabel('Live'),
        FsTooltipGroup(
          child: Row(
            children: [
              FsIconButton(
                icon: FsIcons.undo,
                tooltip: 'Undo',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  meta: true,
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 2),
              const FsIconButton(
                icon: FsIcons.redo,
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
              FsIconButton(
                icon: FsIcons.grid,
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
