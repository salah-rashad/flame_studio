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
  double _sx = 1;
  double _sy = 2;
  bool _locked = true;
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
      bool lock = false,
    }) => forced(
      states,
      part: part,
      FsVector2Property(
        label: lock ? 'scale' : 'position',
        x: mixedX ? null : (lock ? 1 : 412.5),
        y: lock ? 1 : 288,
        mixedX: mixedX,
        aspectLocked: lock ? true : null,
        aspectLockTooltip: 'Lock aspect ratio',
        onAspectLockChanged: noop,
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
      for (final lock in [false, true])
        position(
          states: states,
          part: part,
          enabled: enabled,
          mixedX: mixedX,
          source: source,
          lock: lock,
        ),
    ]);

    return GalleryPage(
      title: 'Vector2Property',
      note:
          'Drag a letter to scrub that axis, drag the label to scrub both. '
          'Tab moves X → Y → next row. With the aspect lock on, changing one '
          'axis scales the other (scale, size).',
      children: [
        StateGrid(
          columns: const ['Vector2', 'Vector2 + aspect lock'],
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
        SampleBox(
          width: 320,
          child: FsVector2Property(
            label: 'scale',
            x: _sx,
            y: _sy,
            step: 0.1,
            aspectLocked: _locked,
            aspectLockTooltip: 'Lock aspect ratio',
            onAspectLockChanged: (v) => setState(() => _locked = v),
            onChanged: (x, y) => setState(() {
              _sx = x ?? _sx;
              _sy = y ?? _sy;
            }),
            onCommit: (x, y) => setState(() => _last = 'commit ($x, $y)'),
          ),
        ),
        Text(_last, style: FsText.mono.copyWith(color: c.textSecondary)),
      ],
    );
  }
}
