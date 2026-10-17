import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

class Vector2PropertyPage extends StatefulWidget {
  const Vector2PropertyPage({super.key});

  @override
  State<Vector2PropertyPage> createState() => _Vector2PropertyPageState();
}

class _Vector2PropertyPageState extends State<Vector2PropertyPage> {
  double _x = 412.5;
  double _y = 288;
  String _last = '';

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    Widget position({
      Set<WidgetState> states = const {},
      String? part,
      bool enabled = true,
      bool mixedX = false,
      FsValueSource source = FsValueSource.codeDefault,
    }) => forced(
      states,
      part: part,
      FsVector2Property(
        label: 'position',
        x: mixedX ? null : 412.5,
        y: 288,
        mixedX: mixedX,
        source: source,
        enabled: enabled,
        onReset: noop,
        resetTooltip: 'Reset to default',
        onChanged: noop,
        onCommit: noop,
      ),
    );
    GridRow row(
      String label, {
      Set<WidgetState> states = const {},
      String? part,
      bool enabled = true,
      bool mixedX = false,
      FsValueSource source = FsValueSource.codeDefault,
    }) => GridRow(label, [
      position(
        states: states,
        part: part,
        enabled: enabled,
        mixedX: mixedX,
        source: source,
      ),
    ]);

    return GalleryPage(
      title: 'Vector2Property',
      note:
          'Drag a letter to scrub that axis, drag the label to scrub both. '
          'Tab moves X → Y → next row. Not yet: the aspect lock column.',
      children: [
        StateGrid(
          columns: const ['Vector2'],
          rows: [
            row('Default'),
            row('Hover', states: {WidgetState.hovered}, part: 'row'),
            row('Scrubbing Y', states: {WidgetState.dragged}, part: 'y'),
            row('Focused · X', states: {WidgetState.focused}, part: 'x'),
            row('Disabled', enabled: false),
            row('Error · Y', states: {WidgetState.error}, part: 'y'),
            row('Mixed · X', mixedX: true),
            row('Overridden', source: FsValueSource.overridden),
          ],
        ),
        const SectionLabel('Live'),
        SampleBox(
          width: 320,
          child: FsVector2Property(
            label: 'position',
            x: _x,
            y: _y,
            onChanged: (x, y) => setState(() {
              _x = x ?? _x;
              _y = y ?? _y;
            }),
            onCommit: (x, y) => setState(() => _last = 'commit ($x, $y)'),
          ),
        ),
        Text(_last, style: FsText.mono.copyWith(color: c.textSecondary)),
      ],
    );
  }
}
