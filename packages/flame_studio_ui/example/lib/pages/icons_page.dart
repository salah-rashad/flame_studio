import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';

import '../grid.dart';

const _icons = <(String, IconData)>[
  ('alert-circle', FsIcons.alertCircle),
  ('alert-triangle', FsIcons.alertTriangle),
  ('box', FsIcons.box),
  ('check', FsIcons.check),
  ('check-circle', FsIcons.checkCircle),
  ('chevron-down', FsIcons.chevronDown),
  ('chevron-right', FsIcons.chevronRight),
  ('circle-dot', FsIcons.circleDot),
  ('code', FsIcons.code),
  ('copy', FsIcons.copy),
  ('crosshair', FsIcons.crosshair),
  ('external', FsIcons.external),
  ('eye', FsIcons.eye),
  ('eye-off', FsIcons.eyeOff),
  ('file', FsIcons.file),
  ('file-code', FsIcons.fileCode),
  ('film', FsIcons.film),
  ('filter', FsIcons.filter),
  ('folder', FsIcons.folder),
  ('globe', FsIcons.globe),
  ('grid', FsIcons.grid),
  ('hitbox', FsIcons.hitbox),
  ('image', FsIcons.image),
  ('info', FsIcons.info),
  ('layers', FsIcons.layers),
  ('link', FsIcons.link),
  ('list-tree', FsIcons.listTree),
  ('lock', FsIcons.lock),
  ('magnet', FsIcons.magnet),
  ('minus', FsIcons.minus),
  ('monitor', FsIcons.monitor),
  ('more', FsIcons.more),
  ('move', FsIcons.move),
  ('music', FsIcons.music),
  ('panel-bottom', FsIcons.panelBottom),
  ('pause', FsIcons.pause),
  ('pipette', FsIcons.pipette),
  ('play', FsIcons.play),
  ('plus', FsIcons.plus),
  ('pointer', FsIcons.pointer),
  ('redo', FsIcons.redo),
  ('reset', FsIcons.reset),
  ('rotate', FsIcons.rotate),
  ('save', FsIcons.save),
  ('scale', FsIcons.scale),
  ('search', FsIcons.search),
  ('sliders', FsIcons.sliders),
  ('smartphone', FsIcons.smartphone),
  ('sparkle', FsIcons.sparkle),
  ('step-forward', FsIcons.stepForward),
  ('stop', FsIcons.stop),
  ('terminal', FsIcons.terminal),
  ('trash', FsIcons.trash),
  ('type', FsIcons.type),
  ('undo', FsIcons.undo),
  ('unlock', FsIcons.unlock),
  ('user', FsIcons.user),
  ('video', FsIcons.video),
  ('x', FsIcons.x),
  ('zap', FsIcons.zap),
];

class IconsPage extends StatelessWidget {
  const IconsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = FsColors.of(context);
    Widget tile(String name, Widget glyph) => SizedBox(
      width: 112,
      height: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          glyph,
          const SizedBox(height: FsSpacing.s2),
          Text(name, style: FsText.caption.copyWith(color: c.textSecondary)),
        ],
      ),
    );
    return GalleryPage(
      title: 'Icons',
      note:
          'The design system\'s 60 icons, from the Lucide font, at 16px '
          '(size-icon) in text-secondary, and at 14px (size-icon-sm) below. '
          'FsPlayGlyph is the filled Play triangle, the only filled icon.',
      children: [
        SampleBox(
          child: Wrap(
            children: [
              for (final (name, icon) in _icons)
                tile(
                  name,
                  Icon(icon, size: FsSizes.icon, color: c.textSecondary),
                ),
            ],
          ),
        ),
        SampleBox(
          child: Wrap(
            children: [
              for (final (name, icon) in _icons)
                tile(
                  name,
                  Icon(icon, size: FsSizes.iconSm, color: c.textSecondary),
                ),
            ],
          ),
        ),
        const SectionLabel('FsPlayGlyph · 16 and 14, on accent'),
        Row(
          children: [
            for (final size in const [16.0, 14.0])
              Padding(
                padding: const EdgeInsets.only(right: FsSpacing.s4),
                child: Container(
                  width: 48,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: FsRadii.sm,
                  ),
                  child: FsPlayGlyph(size: size, color: c.textOnAccent),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
