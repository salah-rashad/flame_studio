import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

enum _Anchor { topLeft, center, bottomRight }

class PropertyRowPage extends StatefulWidget {
  const PropertyRowPage({super.key});

  @override
  State<PropertyRowPage> createState() => _PropertyRowPageState();
}

class _PropertyRowPageState extends State<PropertyRowPage> {
  double _fraction = 0.4;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    PrNumberProperty number(
      String label,
      double? value, {
      PrValueSource source = PrValueSource.codeDefault,
      bool mixed = false,
      bool enabled = true,
      String? unit,
      PrNumberKind kind = PrNumberKind.double,
    }) => PrNumberProperty(
      label: label,
      value: value,
      mixed: mixed,
      kind: kind,
      unit: unit,
      source: source,
      enabled: enabled,
      onReset: noop,
      resetTooltip: 'Reset to default',
      tooltip: 'double · default 180.0',
      onChanged: noop,
      onCommit: noop,
    );

    return GalleryPage(
      title: 'PropertyRow',
      note:
          'A 24px inspector row: label 40% (min 72px), editor, reset slot. '
          'Inside a PrPropertyList the rows share one label column: drag '
          'the boundary between label and editor in any row.',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Every field kind · drag the boundary'),
                SampleBox(
                  width: 360,
                  child: PrPropertyList(
                    initialLabelFraction: _fraction,
                    onLabelFractionChanged: (f) =>
                        setState(() => _fraction = f),
                    children: [
                      number('speed', 180, unit: 'px/s'),
                      number('gravity', 9.81),
                      const PrNumberProperty(
                        label: 'opacity',
                        value: 0.85,
                        min: 0,
                        max: 1,
                        slider: true,
                        onChanged: noop,
                        onCommit: noop,
                      ),
                      const PrBoolProperty(
                        label: 'debugMode',
                        value: false,
                        onChanged: noop,
                      ),
                      const PrBoolProperty(
                        label: 'playing',
                        value: true,
                        source: PrValueSource.overridden,
                        onReset: noop,
                        resetTooltip: 'Reset to default',
                        onChanged: noop,
                      ),
                      const PrPropertyRow(
                        label: 'label',
                        editor: PrTextField(
                          value: 'Hero',
                          size: PrFieldSize.dense,
                        ),
                      ),
                      PrPropertyRow(
                        label: 'anchor',
                        editor: PrDropdown<_Anchor>(
                          options: [
                            for (final a in _Anchor.values)
                              PrDropdownOption(
                                value: a,
                                label: a.name,
                                detail: 'Anchor.${a.name}',
                              ),
                          ],
                          value: _Anchor.center,
                          size: PrFieldSize.dense,
                          monoOptions: true,
                          onChanged: noop,
                        ),
                      ),
                      const PrVector2Property(
                        label: 'position',
                        x: 412.5,
                        y: 288,
                        onChanged: noop,
                        onCommit: noop,
                      ),
                      const PrColorProperty(
                        label: 'tint',
                        value: Color.fromRGBO(255, 215, 168, 1),
                        onChanged: noop,
                        onCommit: noop,
                      ),
                      const PrPropertyRow(
                        label: 'sprite',
                        editor: PrAssetSlot<String>(
                          fileName: 'player_run.png',
                          placeholder: 'None (Sprite)',
                          onBrowse: noop,
                          onClear: noop,
                        ),
                      ),
                      const PrPropertyRow(
                        label: 'target',
                        editor: PrEntitySlot<String>(
                          name: 'Camera',
                          placeholder: 'None (CameraComponent)',
                          typeIcon: PrIcons.video,
                          onPick: noop,
                          onClear: noop,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PrSpacing.s1),
                Text(
                  'Label column: ${(_fraction * 100).round()}% '
                  '(reported on drag end)',
                  style: PrText.small.copyWith(color: c.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: PrSpacing.s6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Value states'),
                SampleBox(
                  width: 360,
                  child: PrPropertyList(
                    children: [
                      number('speed', 180, unit: 'px/s'),
                      number(
                        'jumpForce',
                        520,
                        unit: 'px/s',
                        source: PrValueSource.overridden,
                      ),
                      const PrVector2Property(
                        label: 'position',
                        x: null,
                        y: 288,
                        mixedX: true,
                        source: PrValueSource.overridden,
                        onReset: noop,
                        resetTooltip: 'Reset to default',
                        onChanged: noop,
                        onCommit: noop,
                      ),
                      number('friction', null, mixed: true),
                      forced(const {
                        WidgetState.error,
                      }, number('maxHealth', 100)),
                      number('hitboxType', 1, enabled: false),
                    ],
                  ),
                ),
                const SectionLabel('Hover'),
                SampleBox(
                  width: 360,
                  child: forced(
                    const {WidgetState.hovered},
                    number('speed', 180, unit: 'px/s'),
                    part: 'row',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
