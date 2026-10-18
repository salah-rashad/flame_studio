import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

class BoolPropertyPage extends StatefulWidget {
  const BoolPropertyPage({super.key});

  @override
  State<BoolPropertyPage> createState() => _BoolPropertyPageState();
}

class _BoolPropertyPageState extends State<BoolPropertyPage> {
  bool? _debugMode = false;
  bool _visible = true;
  bool _pauseOnError = true;
  bool? _all;

  @override
  Widget build(BuildContext context) {
    Widget cell(
      PrBoolStyle style, {
      bool? value = false,
      Set<WidgetState> states = const {},
      bool enabled = true,
      bool overridden = false,
    }) {
      final checkbox = style == PrBoolStyle.checkbox;
      final row = PrBoolProperty(
        label: checkbox ? 'debugMode' : 'Pause on error',
        value: value,
        style: style,
        source: overridden
            ? PrValueSource.overridden
            : PrValueSource.codeDefault,
        onReset: noop,
        resetTooltip: 'Reset to default',
        onChanged: enabled ? noop : null,
      );
      if (states.isEmpty) return row;
      // The states go to the control; the row itself stays unhovered.
      return forced(
        states,
        forced(const {}, forced(const {}, row, part: 'label'), part: 'row'),
      );
    }

    GridRow row(
      String name, {
      bool? value = false,
      Set<WidgetState> states = const {},
      bool enabled = true,
      bool overridden = false,
      bool switchToo = true,
    }) => GridRow(name, [
      cell(
        PrBoolStyle.checkbox,
        value: value,
        states: states,
        enabled: enabled,
        overridden: overridden,
      ),
      if (switchToo)
        cell(
          PrBoolStyle.toggle,
          value: value ?? false,
          states: states,
          enabled: enabled,
        )
      else
        const _NotApplicable(),
    ]);

    return GalleryPage(
      title: 'BoolProperty',
      note:
          'Use the checkbox for data (a field on the component). Use the '
          'switch only for something that takes effect immediately and is '
          'not saved to the scene (e.g. "Pause on error"). Space toggles; '
          'clicking the label toggles too.',
      children: [
        StateGrid(
          columns: const [
            'Checkbox · in property rows',
            'Switch · live editor toggles',
          ],
          cellWidth: 280,
          labelWidth: 100,
          rows: [
            row('Off'),
            row('On', value: true),
            row('Hover', states: {WidgetState.hovered}),
            row('Pressed', states: {WidgetState.pressed}),
            row('Focused', states: {WidgetState.focused}),
            row('Disabled · off', enabled: false),
            row('Disabled · on', value: true, enabled: false),
            row('Mixed', value: null, switchToo: false),
            row('Overridden', value: true, overridden: true, switchToo: false),
          ],
        ),
        const SectionLabel('Live'),
        SampleBox(
          width: 300,
          child: Column(
            children: [
              PrBoolProperty(
                label: 'debugMode',
                value: _debugMode,
                source: _debugMode == false
                    ? PrValueSource.codeDefault
                    : PrValueSource.overridden,
                onReset: () => setState(() => _debugMode = false),
                resetTooltip: 'Reset to default',
                tooltip: 'bool · default false',
                onChanged: (v) => setState(() => _debugMode = v),
              ),
              PrBoolProperty(
                label: 'isVisible',
                value: _all == null ? null : _visible,
                tooltip: 'Mixed until clicked',
                onChanged: (v) => setState(() {
                  _all = v;
                  _visible = v;
                }),
              ),
              PrBoolProperty(
                label: 'Pause on error',
                value: _pauseOnError,
                style: PrBoolStyle.toggle,
                onChanged: (v) => setState(() => _pauseOnError = v),
              ),
            ],
          ),
        ),
        const SectionLabel('Standalone'),
        const Row(
          children: [
            PrCheckbox(value: true, onChanged: noop),
            SizedBox(width: PrSpacing.s3),
            PrCheckbox(value: null, onChanged: noop),
            SizedBox(width: PrSpacing.s3),
            PrSwitch(value: true, onChanged: noop),
          ],
        ),
      ],
    );
  }
}

class _NotApplicable extends StatelessWidget {
  const _NotApplicable();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: PrSizes.rowProperty,
    child: Padding(
      padding: const EdgeInsets.only(left: PrSpacing.s2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'n/a',
          style: PrText.caption.copyWith(
            color: PrColors.of(context).textDisabled,
          ),
        ),
      ),
    ),
  );
}
