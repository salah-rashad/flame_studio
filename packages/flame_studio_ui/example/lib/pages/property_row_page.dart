import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

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
    final c = FsColors.of(context);
    FsNumberProperty number(
      String label,
      double? value, {
      FsValueSource source = FsValueSource.codeDefault,
      bool mixed = false,
      bool enabled = true,
      String? unit,
      FsNumberKind kind = FsNumberKind.double,
    }) => FsNumberProperty(
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
          'Inside an FsPropertyList the rows share one label column: drag '
          'the boundary between label and editor in any row. The asset and '
          'entity editors join the "every field kind" list as they are '
          'built.',
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
                  child: FsPropertyList(
                    initialLabelFraction: _fraction,
                    onLabelFractionChanged: (f) =>
                        setState(() => _fraction = f),
                    children: [
                      number('speed', 180, unit: 'px/s'),
                      number('gravity', 9.81),
                      const FsNumberProperty(
                        label: 'opacity',
                        value: 0.85,
                        min: 0,
                        max: 1,
                        slider: true,
                        onChanged: noop,
                        onCommit: noop,
                      ),
                      const FsBoolProperty(
                        label: 'debugMode',
                        value: false,
                        onChanged: noop,
                      ),
                      const FsBoolProperty(
                        label: 'playing',
                        value: true,
                        source: FsValueSource.overridden,
                        onReset: noop,
                        resetTooltip: 'Reset to default',
                        onChanged: noop,
                      ),
                      const FsPropertyRow(
                        label: 'label',
                        editor: FsTextField(
                          value: 'Hero',
                          size: FsFieldSize.dense,
                        ),
                      ),
                      FsPropertyRow(
                        label: 'anchor',
                        editor: FsDropdown<_Anchor>(
                          options: [
                            for (final a in _Anchor.values)
                              FsDropdownOption(
                                value: a,
                                label: a.name,
                                detail: 'Anchor.${a.name}',
                              ),
                          ],
                          value: _Anchor.center,
                          size: FsFieldSize.dense,
                          monoOptions: true,
                          onChanged: noop,
                        ),
                      ),
                      const FsVector2Property(
                        label: 'position',
                        x: 412.5,
                        y: 288,
                        onChanged: noop,
                        onCommit: noop,
                      ),
                      const FsColorProperty(
                        label: 'tint',
                        value: Color.fromRGBO(255, 215, 168, 1),
                        onChanged: noop,
                        onCommit: noop,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FsSpacing.s1),
                Text(
                  'Label column: ${(_fraction * 100).round()}% '
                  '(reported on drag end)',
                  style: FsText.small.copyWith(color: c.textSecondary),
                ),
              ],
            ),
            const SizedBox(width: FsSpacing.s6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Value states'),
                SampleBox(
                  width: 360,
                  child: FsPropertyList(
                    children: [
                      number('speed', 180, unit: 'px/s'),
                      number(
                        'jumpForce',
                        520,
                        unit: 'px/s',
                        source: FsValueSource.overridden,
                      ),
                      const FsVector2Property(
                        label: 'position',
                        x: null,
                        y: 288,
                        mixedX: true,
                        source: FsValueSource.overridden,
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
