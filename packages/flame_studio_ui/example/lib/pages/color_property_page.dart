import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

const _peach = Color.fromRGBO(255, 215, 168, 1);

class ColorPropertyPage extends StatefulWidget {
  const ColorPropertyPage({super.key});

  @override
  State<ColorPropertyPage> createState() => _ColorPropertyPageState();
}

class _ColorPropertyPageState extends State<ColorPropertyPage> {
  Color _tint = _peach;
  final _recent = <Color>[
    const Color.fromRGBO(255, 255, 255, 1),
    const Color.fromRGBO(124, 200, 240, 1),
    const Color.fromRGBO(108, 192, 74, 1),
  ];

  void _remember(Color color) => setState(() {
    final opaque = color.withValues(alpha: 1);
    _recent
      ..remove(opaque)
      ..insert(0, opaque);
    if (_recent.length > 9) _recent.removeLast();
  });

  @override
  Widget build(BuildContext context) {
    Widget tint({
      Set<WidgetState> states = const {},
      String? part,
      bool enabled = true,
      bool mixed = false,
      FsValueSource source = FsValueSource.codeDefault,
    }) => forced(
      states,
      part: part,
      FsColorProperty(
        label: 'tint',
        value: mixed ? null : _peach,
        mixed: mixed,
        source: source,
        enabled: enabled,
        onReset: noop,
        resetTooltip: 'Reset to default',
        onChanged: noop,
        onCommit: noop,
      ),
    );

    return GalleryPage(
      title: 'ColorProperty',
      note:
          'Hex is upper-case, 6 digits; alpha is a separate % field. The '
          'swatch shows the colour as a solid fill (no checkerboard), so a '
          'fully transparent colour also shows "0%". Click the swatch for '
          'the picker.',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StateGrid(
              columns: const ['Color'],
              cellWidth: 360,
              labelWidth: 100,
              rows: [
                GridRow('Default', [tint()]),
                GridRow('Hover', [
                  tint(states: {WidgetState.hovered}, part: 'row'),
                ]),
                GridRow('Focused · hex', [
                  tint(states: {WidgetState.focused}, part: 'hex'),
                ]),
                GridRow('Disabled', [tint(enabled: false)]),
                GridRow('Error', [
                  tint(states: {WidgetState.error}, part: 'hex'),
                ]),
                GridRow('Mixed', [tint(mixed: true)]),
                GridRow('Overridden', [tint(source: FsValueSource.overridden)]),
              ],
            ),
            const SizedBox(width: FsSpacing.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Swatch click opens the picker popover'),
                SampleBox(
                  width: 360,
                  child: forced(
                    const {WidgetState.selected},
                    part: 'picker',
                    FsColorProperty(
                      label: 'tint',
                      value: _peach,
                      recentColors: _recent,
                      onChanged: noop,
                      onCommit: noop,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SectionLabel('Live'),
        SampleBox(
          width: 360,
          child: FsColorProperty(
            label: 'tint',
            value: _tint,
            source: _tint == _peach
                ? FsValueSource.codeDefault
                : FsValueSource.overridden,
            onReset: () => setState(() => _tint = _peach),
            resetTooltip: 'Reset to default',
            tooltip: 'Color · default #FFD7A8',
            recentColors: _recent,
            eyedropperTooltip: 'Pick a colour from the screen',
            onChanged: (v) => setState(() => _tint = v),
            onCommit: _remember,
          ),
        ),
      ],
    );
  }
}
