import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../grid.dart';

class ButtonPage extends StatelessWidget {
  const ButtonPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget cell(
      FsButtonVariant variant,
      String label, {
      IconData? icon,
      Set<WidgetState> states = const {},
      bool enabled = true,
    }) {
      final button = FsButton(
        label: label,
        variant: variant,
        icon: icon,
        onPressed: enabled ? () {} : null,
      );
      return Padding(
        padding: const EdgeInsets.all(FsSpacing.s2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: states.isEmpty ? button : forced(states, button),
        ),
      );
    }

    GridRow row(
      String name,
      FsButtonVariant variant,
      String label, {
      IconData? icon,
    }) => GridRow(name, [
      cell(variant, label, icon: icon),
      cell(variant, label, icon: icon, states: {WidgetState.hovered}),
      cell(variant, label, icon: icon, states: {WidgetState.pressed}),
      cell(variant, label, icon: icon, states: {WidgetState.focused}),
      cell(variant, label, icon: icon, enabled: false),
    ]);

    return GalleryPage(
      title: 'Button',
      note:
          'Selected and Error do not apply to buttons: a button that stays '
          'on is a Toggle; validation errors belong to the field, not the '
          'submit button.',
      children: [
        StateGrid(
          columns: const ['Default', 'Hover', 'Pressed', 'Focused', 'Disabled'],
          cellWidth: 150,
          labelWidth: 100,
          rows: [
            row('Primary', FsButtonVariant.primary, 'Add component'),
            row('Secondary', FsButtonVariant.secondary, 'Cancel'),
            row('Ghost', FsButtonVariant.ghost, 'Reset all'),
            row('Danger', FsButtonVariant.danger, 'Delete node'),
            row(
              'With icon',
              FsButtonVariant.secondary,
              'New scene',
              icon: FsIcons.plus,
            ),
          ],
        ),
        const SectionLabel('Live'),
        FsTooltipGroup(
          child: Wrap(
            spacing: FsSpacing.s2,
            children: [
              FsButton(
                label: 'Save',
                variant: FsButtonVariant.primary,
                tooltip: 'Save the scene',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyS,
                  meta: true,
                ),
                onPressed: () {},
              ),
              FsButton(label: "Don't save", onPressed: () {}),
              FsButton(
                label: 'Reset all',
                variant: FsButtonVariant.ghost,
                onPressed: () {},
              ),
              FsButton(
                label: 'Delete node',
                variant: FsButtonVariant.danger,
                icon: FsIcons.trash,
                onPressed: () {},
              ),
              const FsButton(
                label: 'Add component',
                onPressed: null,
                disabledReason: 'Select a node first',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
