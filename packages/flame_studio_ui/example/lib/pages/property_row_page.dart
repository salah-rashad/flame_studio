import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

/// A stand-in editor until the number editors exist.
class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FsFieldBox(
    size: FsFieldSize.dense,
    child: Text(text, style: FsText.mono),
  );
}

class PropertyRowPage extends StatelessWidget {
  const PropertyRowPage({super.key});

  @override
  Widget build(BuildContext context) {
    FsPropertyRow row(
      String label,
      String value, {
      FsValueSource source = FsValueSource.codeDefault,
      bool enabled = true,
      String? error,
    }) => FsPropertyRow(
      label: label,
      editor: _Value(value),
      source: source,
      enabled: enabled,
      error: error,
      onReset: noop,
      resetTooltip: 'Reset to default',
      tooltip: 'double · default 180.0',
    );

    return GalleryPage(
      title: 'PropertyRow',
      note:
          'A 24px inspector row: label 40% (min 72px), editor, reset slot. '
          'The label column is fixed for now; resizing it comes with '
          'FsPropertyList. The editors here are stand-ins.',
      children: [
        const SectionLabel('Value states'),
        SampleBox(
          width: 360,
          child: Column(
            children: [
              row('speed', '180.0'),
              row('jumpForce', '520.0', source: FsValueSource.overridden),
              row('maxHealth', 'abc', error: 'Expected a number'),
              row('hitboxType', 'passive', enabled: false),
            ],
          ),
        ),
        const SectionLabel('Hover'),
        SampleBox(
          width: 360,
          child: forced(
            const {WidgetState.hovered},
            row('speed', '180.0'),
            part: 'row',
          ),
        ),
      ],
    );
  }
}
