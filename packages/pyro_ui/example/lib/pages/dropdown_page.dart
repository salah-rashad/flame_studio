import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

enum _Anchor {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

final _anchors = [
  for (final a in _Anchor.values)
    PrDropdownOption(value: a, label: a.name, detail: 'Anchor.${a.name}'),
];

enum _Body { dynamic, kinematic, static }

const _bodies = [
  PrDropdownOption(value: _Body.dynamic, label: 'Dynamic', icon: PrIcons.zap),
  PrDropdownOption(
    value: _Body.kinematic,
    label: 'Kinematic',
    icon: PrIcons.move,
  ),
  PrDropdownOption(value: _Body.static, label: 'Static', icon: PrIcons.lock),
];

class DropdownPage extends StatefulWidget {
  const DropdownPage({super.key});

  @override
  State<DropdownPage> createState() => _DropdownPageState();
}

class _DropdownPageState extends State<DropdownPage> {
  _Anchor _anchor = _Anchor.center;
  _Anchor _rowAnchor = _Anchor.topLeft;
  _Body _body = _Body.dynamic;

  @override
  Widget build(BuildContext context) {
    Widget cell({
      Set<WidgetState> states = const {},
      bool enabled = true,
      String? errorText,
      bool mixed = false,
    }) {
      final dropdown = PrDropdown<_Anchor>(
        options: _anchors,
        value: _Anchor.center,
        mixed: mixed,
        monoOptions: true,
        errorText: errorText,
        onChanged: enabled ? noop : null,
      );
      return Padding(
        padding: const EdgeInsets.all(PrSpacing.s2),
        child: states.isEmpty ? dropdown : forced(states, dropdown),
      );
    }

    return GalleryPage(
      title: 'Dropdown',
      note:
          'Enum values show their Dart name in the list (mono) and a short '
          'label in the field. Space/Enter/↓ opens; typing jumps to the first '
          'match; the list opens on the current value; Esc closes it without '
          'a change.',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StateGrid(
              columns: const ['Dropdown'],
              cellWidth: 236,
              labelWidth: 88,
              rows: [
                GridRow('Default', [cell()]),
                GridRow('Hover', [
                  cell(states: {WidgetState.hovered}),
                ]),
                GridRow('Pressed', [
                  cell(states: {WidgetState.pressed}),
                ]),
                GridRow('Focused', [
                  cell(states: {WidgetState.focused}),
                ]),
                GridRow('Disabled', [cell(enabled: false)]),
                GridRow('Error', [cell(errorText: '')]),
                GridRow('Mixed', [cell(mixed: true)]),
              ],
            ),
            const SizedBox(width: PrSpacing.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Open'),
                SizedBox(
                  width: 220,
                  child: forced(
                    const {WidgetState.selected},
                    forced(
                      const {WidgetState.hovered},
                      PrDropdown<_Anchor>(
                        options: _anchors,
                        value: _Anchor.center,
                        monoOptions: true,
                        onChanged: noop,
                      ),
                      part: 'Anchor.centerRight',
                    ),
                    part: 'open',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 120),
        const SectionLabel('Live'),
        Row(
          children: [
            SizedBox(
              width: 220,
              child: PrDropdown<_Anchor>(
                options: _anchors,
                value: _anchor,
                monoOptions: true,
                onChanged: (v) => setState(() => _anchor = v),
              ),
            ),
            const SizedBox(width: PrSpacing.s4),
            SizedBox(
              width: 160,
              child: PrDropdown<_Body>(
                options: _bodies,
                value: _body,
                onChanged: (v) => setState(() => _body = v),
              ),
            ),
          ],
        ),
        const SectionLabel('In a property row (20px)'),
        SampleBox(
          width: 320,
          child: PrPropertyRow(
            label: 'anchor',
            source: _rowAnchor == _Anchor.topLeft
                ? PrValueSource.codeDefault
                : PrValueSource.overridden,
            onReset: () => setState(() => _rowAnchor = _Anchor.topLeft),
            resetTooltip: 'Reset to default',
            editor: PrDropdown<_Anchor>(
              options: _anchors,
              value: _rowAnchor,
              size: PrFieldSize.dense,
              monoOptions: true,
              onChanged: (v) => setState(() => _rowAnchor = v),
            ),
          ),
        ),
      ],
    );
  }
}
