import 'package:flutter/material.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../grid.dart';

const _icons = <(String, IconData)>[
  ('alert-circle', PrIcons.alertCircle),
  ('alert-triangle', PrIcons.alertTriangle),
  ('box', PrIcons.box),
  ('check', PrIcons.check),
  ('check-circle', PrIcons.checkCircle),
  ('chevron-down', PrIcons.chevronDown),
  ('chevron-right', PrIcons.chevronRight),
  ('circle-dot', PrIcons.circleDot),
  ('code', PrIcons.code),
  ('copy', PrIcons.copy),
  ('crosshair', PrIcons.crosshair),
  ('external', PrIcons.external),
  ('eye', PrIcons.eye),
  ('eye-off', PrIcons.eyeOff),
  ('file', PrIcons.file),
  ('file-code', PrIcons.fileCode),
  ('film', PrIcons.film),
  ('filter', PrIcons.filter),
  ('folder', PrIcons.folder),
  ('globe', PrIcons.globe),
  ('grid', PrIcons.grid),
  ('hitbox', PrIcons.hitbox),
  ('image', PrIcons.image),
  ('info', PrIcons.info),
  ('layers', PrIcons.layers),
  ('link', PrIcons.link),
  ('list-tree', PrIcons.listTree),
  ('lock', PrIcons.lock),
  ('magnet', PrIcons.magnet),
  ('minus', PrIcons.minus),
  ('monitor', PrIcons.monitor),
  ('more', PrIcons.more),
  ('move', PrIcons.move),
  ('music', PrIcons.music),
  ('panel-bottom', PrIcons.panelBottom),
  ('pause', PrIcons.pause),
  ('pipette', PrIcons.pipette),
  ('play', PrIcons.play),
  ('plus', PrIcons.plus),
  ('pointer', PrIcons.pointer),
  ('redo', PrIcons.redo),
  ('reset', PrIcons.reset),
  ('rotate', PrIcons.rotate),
  ('save', PrIcons.save),
  ('scale', PrIcons.scale),
  ('search', PrIcons.search),
  ('sliders', PrIcons.sliders),
  ('smartphone', PrIcons.smartphone),
  ('sparkle', PrIcons.sparkle),
  ('step-forward', PrIcons.stepForward),
  ('stop', PrIcons.stop),
  ('terminal', PrIcons.terminal),
  ('trash', PrIcons.trash),
  ('type', PrIcons.type),
  ('undo', PrIcons.undo),
  ('unlock', PrIcons.unlock),
  ('user', PrIcons.user),
  ('video', PrIcons.video),
  ('x', PrIcons.x),
  ('zap', PrIcons.zap),
];

class IconsPage extends StatelessWidget {
  const IconsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    Widget tile(String name, Widget glyph) => SizedBox(
      width: 112,
      height: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          glyph,
          const SizedBox(height: PrSpacing.s2),
          Text(name, style: PrText.caption.copyWith(color: c.textSecondary)),
        ],
      ),
    );
    return GalleryPage(
      title: 'Icons',
      note:
          'The design system\'s 60 icons, from the Lucide font, at 16px '
          '(size-icon) in text-secondary, and at 14px (size-icon-sm) below. '
          'PrPlayGlyph is the filled Play triangle, the only filled icon.',
      children: [
        SampleBox(
          child: Wrap(
            children: [
              for (final (name, icon) in _icons)
                tile(
                  name,
                  Icon(icon, size: PrSizes.icon, color: c.textSecondary),
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
                  Icon(icon, size: PrSizes.iconSm, color: c.textSecondary),
                ),
            ],
          ),
        ),
        const SectionLabel('PrPlayGlyph · 16 and 14, on accent'),
        Row(
          children: [
            for (final size in const [16.0, 14.0])
              Padding(
                padding: const EdgeInsets.only(right: PrSpacing.s4),
                child: Container(
                  width: 48,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: PrRadii.sm,
                  ),
                  child: PrPlayGlyph(size: size, color: c.textOnAccent),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
