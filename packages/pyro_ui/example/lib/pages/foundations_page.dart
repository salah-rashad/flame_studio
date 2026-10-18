import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

class FoundationsPage extends StatelessWidget {
  const FoundationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    Widget field(
      PrFieldSize size, {
      Set<WidgetState> states = const {},
      bool readOnly = false,
      bool accentEdge = false,
    }) => Padding(
      padding: const EdgeInsets.all(PrSpacing.s2),
      child: PrFieldBox(
        size: size,
        states: states,
        readOnly: readOnly,
        accentEdge: accentEdge,
        trailing: const Text('px/s'),
        child: Text(
          '180.0',
          style: PrText.mono.copyWith(
            color: states.contains(WidgetState.disabled)
                ? c.textDisabled
                : c.textPrimary,
          ),
        ),
      ),
    );
    GridRow row(
      String label, {
      Set<WidgetState> states = const {},
      bool readOnly = false,
      bool accentEdge = false,
    }) => GridRow(label, [
      for (final size in PrFieldSize.values)
        field(size, states: states, readOnly: readOnly, accentEdge: accentEdge),
    ]);

    Widget button(Set<WidgetState> forcedStates) => forced(
      forcedStates,
      PrInteractive(
        onPressed: () {},
        builder: (context, states) => PrFocusRing.outside(
          visible: states.contains(WidgetState.focused),
          child: Container(
            height: PrSizes.control,
            padding: const EdgeInsets.symmetric(horizontal: PrSpacing.s3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PrStateColor.resolve(states, {
                WidgetState.pressed: c.surfacePressed,
                WidgetState.hovered: c.surfaceHover,
              }, fallback: c.surfaceRaised),
              border: Border.all(color: c.borderControl),
              borderRadius: PrRadii.sm,
            ),
            child: Text(
              'Add component',
              style: PrText.bodyStrong.copyWith(color: c.textPrimary),
            ),
          ),
        ),
      ),
    );

    return GalleryPage(
      title: 'Foundations',
      note:
          'PrFieldBox, the chrome every field shares, and PrInteractive with '
          'PrFocusRing. The PrInteractive sample is the bare primitive that '
          'PrButton and the other controls are built on; the focus ring shows '
          'for keyboard focus only: Tab to the live copy, then click it.',
      children: [
        StateGrid(
          columns: const ['regular · 24', 'dense · 20'],
          cellWidth: 220,
          rows: [
            row('Default'),
            row('Hover', states: {WidgetState.hovered}),
            row('Focused', states: {WidgetState.focused}),
            row('Error', states: {WidgetState.error}),
            row(
              'Error + focused',
              states: {WidgetState.error, WidgetState.focused},
            ),
            row('Scrubbing', accentEdge: true),
            row('Disabled', states: {WidgetState.disabled}),
            row('Read-only', readOnly: true),
          ],
        ),
        StateGrid(
          columns: const ['PrInteractive + PrFocusRing.outside'],
          cellWidth: 220,
          rows: [
            for (final (label, states) in const [
              ('Default', <WidgetState>{}),
              ('Hover', {WidgetState.hovered}),
              ('Pressed', {WidgetState.pressed}),
              ('Focused', {WidgetState.focused}),
            ])
              GridRow(label, [
                Padding(
                  padding: const EdgeInsets.all(PrSpacing.s2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: button(states),
                  ),
                ),
              ]),
            GridRow('Live', [
              Padding(
                padding: const EdgeInsets.all(PrSpacing.s2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: button(const {}),
                ),
              ),
            ]),
          ],
        ),
      ],
    );
  }
}
