import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

const _recent = [
  Color.fromRGBO(255, 255, 255, 1),
  Color.fromRGBO(255, 215, 168, 1),
  Color.fromRGBO(124, 200, 240, 1),
  Color.fromRGBO(108, 192, 74, 1),
  Color.fromRGBO(92, 107, 192, 1),
  Color.fromRGBO(255, 213, 74, 1),
  Color.fromRGBO(27, 27, 47, 1),
];

class ColorPickerPage extends StatefulWidget {
  const ColorPickerPage({super.key});

  @override
  State<ColorPickerPage> createState() => _ColorPickerPageState();
}

class _ColorPickerPageState extends State<ColorPickerPage> {
  Color _color = const Color.fromRGBO(255, 215, 168, 1);
  String _last = '';

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    return GalleryPage(
      title: 'ColorPicker',
      note:
          'The ColorProperty swatch opens this popover: SV area, hue slider, '
          'hex + alpha, recent colours. The eyedropper shows only when '
          'FsPlatformHooks.sampleScreenColor is set (here: a stand-in that '
          'returns a fixed green). The SV area and hue slider take focus: '
          'arrows step 1% / 1° (Shift ×10), one commit per press.',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Without the eyedropper hook'),
                FsColorPicker(
                  value: _color,
                  recentColors: _recent,
                  onChanged: (v) => setState(() => _color = v),
                  onCommit: (v) => setState(() => _last = '$v'),
                ),
              ],
            ),
            const SizedBox(width: FsSpacing.s6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('With the hook'),
                FsPlatformHooks(
                  sampleScreenColor: () async =>
                      const Color.fromRGBO(108, 192, 74, 1),
                  child: FsColorPicker(
                    value: _color,
                    recentColors: _recent,
                    eyedropperTooltip: 'Pick a colour from the screen',
                    areaLabel: 'Saturation and brightness',
                    hueLabel: 'Hue',
                    onChanged: (v) => setState(() => _color = v),
                    onCommit: (v) => setState(() => _last = '$v'),
                  ),
                ),
              ],
            ),
          ],
        ),
        Text(
          'onCommit: $_last',
          style: FsText.small.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}
