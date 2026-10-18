import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

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
      FsBoolStyle style, {
      bool? value = false,
      Set<WidgetState> states = const {},
      bool enabled = true,
      bool overridden = false,
    }) {
      final checkbox = style == FsBoolStyle.checkbox;
      final row = FsBoolProperty(
        label: checkbox ? 'debugMode' : 'Pause on error',
        value: value,
        style: style,
        source: overridden
            ? FsValueSource.overridden
            : FsValueSource.codeDefault,
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
        FsBoolStyle.checkbox,
        value: value,
        states: states,
        enabled: enabled,
        overridden: overridden,
      ),
      if (switchToo)
        cell(
          FsBoolStyle.toggle,
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
              FsBoolProperty(
                label: 'debugMode',
                value: _debugMode,
                source: _debugMode == false
                    ? FsValueSource.codeDefault
                    : FsValueSource.overridden,
                onReset: () => setState(() => _debugMode = false),
                resetTooltip: 'Reset to default',
                tooltip: 'bool · default false',
                onChanged: (v) => setState(() => _debugMode = v),
              ),
              FsBoolProperty(
                label: 'isVisible',
                value: _all == null ? null : _visible,
                tooltip: 'Mixed until clicked',
                onChanged: (v) => setState(() {
                  _all = v;
                  _visible = v;
                }),
              ),
              FsBoolProperty(
                label: 'Pause on error',
                value: _pauseOnError,
                style: FsBoolStyle.toggle,
                onChanged: (v) => setState(() => _pauseOnError = v),
              ),
            ],
          ),
        ),
        const SectionLabel('Standalone'),
        const Row(
          children: [
            FsCheckbox(value: true, onChanged: noop),
            SizedBox(width: FsSpacing.s3),
            FsCheckbox(value: null, onChanged: noop),
            SizedBox(width: FsSpacing.s3),
            FsSwitch(value: true, onChanged: noop),
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
    height: FsSizes.rowProperty,
    child: Padding(
      padding: const EdgeInsets.only(left: FsSpacing.s2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'n/a',
          style: FsText.caption.copyWith(
            color: FsColors.of(context).textDisabled,
          ),
        ),
      ),
    ),
  );
}
