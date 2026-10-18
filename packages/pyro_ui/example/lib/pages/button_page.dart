import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

class ButtonPage extends StatelessWidget {
  const ButtonPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget cell(
      PrButtonVariant variant,
      String label, {
      IconData? icon,
      Set<WidgetState> states = const {},
      bool enabled = true,
    }) {
      final button = PrButton(
        label: label,
        variant: variant,
        icon: icon,
        onPressed: enabled ? () {} : null,
      );
      return Padding(
        padding: const EdgeInsets.all(PrSpacing.s2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: states.isEmpty ? button : forced(states, button),
        ),
      );
    }

    GridRow row(
      String name,
      PrButtonVariant variant,
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
          'submit button. Disabled buttons are skipped by Tab; "Run game" '
          'below opts in with focusableWhenDisabled, so Tab reaches it and '
          'its tooltip says why it is disabled (Enter does nothing). Use '
          'that only when the reason lives in the tooltip.',
      children: [
        StateGrid(
          columns: const ['Default', 'Hover', 'Pressed', 'Focused', 'Disabled'],
          cellWidth: 150,
          labelWidth: 100,
          rows: [
            row('Primary', PrButtonVariant.primary, 'Add component'),
            row('Secondary', PrButtonVariant.secondary, 'Cancel'),
            row('Ghost', PrButtonVariant.ghost, 'Reset all'),
            row('Danger', PrButtonVariant.danger, 'Delete node'),
            row(
              'With icon',
              PrButtonVariant.secondary,
              'New scene',
              icon: PrIcons.plus,
            ),
          ],
        ),
        const SectionLabel('Live'),
        PrTooltipGroup(
          child: Wrap(
            spacing: PrSpacing.s2,
            children: [
              PrButton(
                label: 'Save',
                variant: PrButtonVariant.primary,
                tooltip: 'Save the scene',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyS,
                  meta: true,
                ),
                onPressed: () {},
              ),
              PrButton(label: "Don't save", onPressed: () {}),
              PrButton(
                label: 'Reset all',
                variant: PrButtonVariant.ghost,
                onPressed: () {},
              ),
              PrButton(
                label: 'Delete node',
                variant: PrButtonVariant.danger,
                icon: PrIcons.trash,
                onPressed: () {},
              ),
              const PrButton(
                label: 'Add component',
                onPressed: null,
                disabledReason: 'Select a node first',
              ),
              const PrButton(
                label: 'Run game',
                variant: PrButtonVariant.primary,
                leading: PrPlayGlyph(),
                onPressed: null,
                disabledReason: 'No device connected',
                focusableWhenDisabled: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
