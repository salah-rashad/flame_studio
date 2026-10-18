import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

String? _names(String text) => RegExp(r'^[A-Za-z0-9_]*$').hasMatch(text)
    ? null
    : 'Names may only use letters, digits and _';

class TextFieldPage extends StatelessWidget {
  const TextFieldPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget cell(
      String? value, {
      String? placeholder,
      bool mono = false,
      Set<WidgetState> states = const {},
      bool enabled = true,
      bool readOnly = false,
    }) {
      final field = FsTextField(
        value: value,
        placeholder: placeholder,
        mono: mono,
        enabled: enabled,
        readOnly: readOnly,
      );
      return Padding(
        padding: const EdgeInsets.all(FsSpacing.s2),
        child: states.isEmpty ? field : forced(states, field),
      );
    }

    GridRow row(
      String name, {
      Set<WidgetState> states = const {},
      bool enabled = true,
      bool readOnly = false,
    }) => GridRow(name, [
      cell(
        'PlayerController',
        states: states,
        enabled: enabled,
        readOnly: readOnly,
      ),
      cell(
        null,
        placeholder: 'Node name',
        states: states,
        enabled: enabled,
        readOnly: readOnly,
      ),
      cell(
        'lib/game/player.dart',
        mono: true,
        states: states,
        enabled: enabled,
        readOnly: readOnly,
      ),
    ]);

    return GalleryPage(
      title: 'TextField',
      note:
          'Built on EditableText inside FsFieldBox. Errors show a trailing '
          'alert icon and a message below, or in a tooltip in dense rows. '
          'The tooltip stays up while the field has focus, so type a space '
          'in the dense field to see the message without hovering.',
      children: [
        StateGrid(
          columns: const ['Filled', 'Empty · placeholder', 'Path (mono)'],
          cellWidth: 236,
          labelWidth: 100,
          rows: [
            row('Default'),
            row('Hover', states: {WidgetState.hovered}),
            row('Focused', states: {WidgetState.focused}),
            row('Disabled', enabled: false),
            row('Error', states: {WidgetState.error}),
            row('Read-only', readOnly: true),
          ],
        ),
        const SectionLabel('Live · names may only use letters, digits and _'),
        const SizedBox(
          width: 220,
          child: FsTextField(
            value: 'Player 1!',
            placeholder: 'Node name',
            validator: _names,
          ),
        ),
        const SectionLabel('Dense, message in a tooltip'),
        const SizedBox(
          width: 220,
          child: FsTextField(
            value: 'Player',
            size: FsFieldSize.dense,
            validator: _names,
            errorDisplay: FsErrorDisplay.tooltip,
          ),
        ),
      ],
    );
  }
}
