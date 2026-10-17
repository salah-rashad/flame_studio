import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

class PropertyRowPage extends StatelessWidget {
  const PropertyRowPage({super.key});

  @override
  Widget build(BuildContext context) {
    FsNumberProperty number(
      String label,
      double? value, {
      FsValueSource source = FsValueSource.codeDefault,
      bool mixed = false,
      bool enabled = true,
      String? unit,
    }) => FsNumberProperty(
      label: label,
      value: value,
      mixed: mixed,
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
          'The label column is fixed for now; resizing it comes with '
          'FsPropertyList. Only the number and Vector2 editors exist yet, so '
          'the "every field kind" column of preview.html is not shown.',
      children: [
        const SectionLabel('Value states'),
        SampleBox(
          width: 360,
          child: Column(
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
              forced(const {WidgetState.error}, number('maxHealth', 100)),
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
    );
  }
}
