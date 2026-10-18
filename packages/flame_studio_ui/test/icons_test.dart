import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  // The design system's 60 icons (its Icons group).
  const all = [
    FsIcons.alertCircle,
    FsIcons.alertTriangle,
    FsIcons.box,
    FsIcons.check,
    FsIcons.checkCircle,
    FsIcons.chevronDown,
    FsIcons.chevronRight,
    FsIcons.circleDot,
    FsIcons.code,
    FsIcons.copy,
    FsIcons.crosshair,
    FsIcons.external,
    FsIcons.eye,
    FsIcons.eyeOff,
    FsIcons.file,
    FsIcons.fileCode,
    FsIcons.film,
    FsIcons.filter,
    FsIcons.folder,
    FsIcons.globe,
    FsIcons.grid,
    FsIcons.hitbox,
    FsIcons.image,
    FsIcons.info,
    FsIcons.layers,
    FsIcons.link,
    FsIcons.listTree,
    FsIcons.lock,
    FsIcons.magnet,
    FsIcons.minus,
    FsIcons.monitor,
    FsIcons.more,
    FsIcons.move,
    FsIcons.music,
    FsIcons.panelBottom,
    FsIcons.pause,
    FsIcons.pipette,
    FsIcons.play,
    FsIcons.plus,
    FsIcons.pointer,
    FsIcons.redo,
    FsIcons.reset,
    FsIcons.rotate,
    FsIcons.save,
    FsIcons.scale,
    FsIcons.search,
    FsIcons.sliders,
    FsIcons.smartphone,
    FsIcons.sparkle,
    FsIcons.stepForward,
    FsIcons.stop,
    FsIcons.terminal,
    FsIcons.trash,
    FsIcons.type,
    FsIcons.undo,
    FsIcons.unlock,
    FsIcons.user,
    FsIcons.video,
    FsIcons.x,
    FsIcons.zap,
  ];

  test('60 distinct icons from the regular-weight Lucide font', () {
    expect(all, hasLength(60));
    for (final icon in all) {
      expect(icon.fontFamily, 'Lucide');
      expect(icon.fontPackage, 'lucide_icons_flutter');
    }
    expect(all.map((i) => i.codePoint).toSet(), hasLength(60));
  });

  test('design names that differ from Lucide map to the right glyph', () {
    // Plan §5.1. Pinned by codepoint, because several Lucide names are
    // aliases of a different glyph.
    expect(FsIcons.external, LucideIcons.externalLink);
    expect(FsIcons.more, LucideIcons.ellipsis);
    expect(FsIcons.reset, LucideIcons.rotateCcw);
    expect(FsIcons.rotate, LucideIcons.rotateCw);
    expect(FsIcons.grid, LucideIcons.grid3x3);
    expect(FsIcons.hitbox, LucideIcons.squareDashed);
    expect(FsIcons.stop, LucideIcons.square);
    expect(FsIcons.alertCircle, LucideIcons.circleAlert);
    expect(FsIcons.alertTriangle, LucideIcons.triangleAlert);
    expect(FsIcons.unlock, LucideIcons.lockOpen);
    expect(FsIcons.filter, LucideIcons.funnel);
    expect(FsIcons.trash, LucideIcons.trash);
    expect(FsIcons.trash, isNot(LucideIcons.trash2));
  });

  test('the five where the same Lucide name is the wrong glyph', () {
    expect(FsIcons.scale, LucideIcons.maximize2);
    expect(FsIcons.scale, isNot(LucideIcons.scale)); // balance scale
    expect(FsIcons.pointer, LucideIcons.mousePointer2);
    expect(FsIcons.pointer, isNot(LucideIcons.pointer)); // hand
    expect(FsIcons.sliders, LucideIcons.slidersHorizontal);
    expect(FsIcons.sliders, isNot(LucideIcons.sliders)); // sliders-vertical
    expect(FsIcons.stepForward, LucideIcons.skipForward);
    expect(FsIcons.stepForward, isNot(LucideIcons.stepForward)); // bar left
    expect(FsIcons.checkCircle, LucideIcons.circleCheck);
    expect(FsIcons.checkCircle, isNot(LucideIcons.checkCircle)); // big tick
  });

  testWidgets('FsPlayGlyph paints at its size in the icon colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Center(
        child: IconTheme(
          data: IconThemeData(color: Color(0xFFFFFFFF)),
          child: FsPlayGlyph(),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FsPlayGlyph)), const Size(16, 16));
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
