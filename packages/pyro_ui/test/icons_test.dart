import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pyro_ui/pyro_ui.dart';

void main() {
  // The design system's 60 icons (its Icons group).
  const all = [
    PrIcons.alertCircle,
    PrIcons.alertTriangle,
    PrIcons.box,
    PrIcons.check,
    PrIcons.checkCircle,
    PrIcons.chevronDown,
    PrIcons.chevronRight,
    PrIcons.circleDot,
    PrIcons.code,
    PrIcons.copy,
    PrIcons.crosshair,
    PrIcons.external,
    PrIcons.eye,
    PrIcons.eyeOff,
    PrIcons.file,
    PrIcons.fileCode,
    PrIcons.film,
    PrIcons.filter,
    PrIcons.folder,
    PrIcons.globe,
    PrIcons.grid,
    PrIcons.hitbox,
    PrIcons.image,
    PrIcons.info,
    PrIcons.layers,
    PrIcons.link,
    PrIcons.listTree,
    PrIcons.lock,
    PrIcons.magnet,
    PrIcons.minus,
    PrIcons.monitor,
    PrIcons.more,
    PrIcons.move,
    PrIcons.music,
    PrIcons.panelBottom,
    PrIcons.pause,
    PrIcons.pipette,
    PrIcons.play,
    PrIcons.plus,
    PrIcons.pointer,
    PrIcons.redo,
    PrIcons.reset,
    PrIcons.rotate,
    PrIcons.save,
    PrIcons.scale,
    PrIcons.search,
    PrIcons.sliders,
    PrIcons.smartphone,
    PrIcons.sparkle,
    PrIcons.stepForward,
    PrIcons.stop,
    PrIcons.terminal,
    PrIcons.trash,
    PrIcons.type,
    PrIcons.undo,
    PrIcons.unlock,
    PrIcons.user,
    PrIcons.video,
    PrIcons.x,
    PrIcons.zap,
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
    expect(PrIcons.external, LucideIcons.externalLink);
    expect(PrIcons.more, LucideIcons.ellipsis);
    expect(PrIcons.reset, LucideIcons.rotateCcw);
    expect(PrIcons.rotate, LucideIcons.rotateCw);
    expect(PrIcons.grid, LucideIcons.grid3x3);
    expect(PrIcons.hitbox, LucideIcons.squareDashed);
    expect(PrIcons.stop, LucideIcons.square);
    expect(PrIcons.alertCircle, LucideIcons.circleAlert);
    expect(PrIcons.alertTriangle, LucideIcons.triangleAlert);
    expect(PrIcons.unlock, LucideIcons.lockOpen);
    expect(PrIcons.filter, LucideIcons.funnel);
    expect(PrIcons.trash, LucideIcons.trash);
    expect(PrIcons.trash, isNot(LucideIcons.trash2));
  });

  test('the five where the same Lucide name is the wrong glyph', () {
    expect(PrIcons.scale, LucideIcons.maximize2);
    expect(PrIcons.scale, isNot(LucideIcons.scale)); // balance scale
    expect(PrIcons.pointer, LucideIcons.mousePointer2);
    expect(PrIcons.pointer, isNot(LucideIcons.pointer)); // hand
    expect(PrIcons.sliders, LucideIcons.slidersHorizontal);
    expect(PrIcons.sliders, isNot(LucideIcons.sliders)); // sliders-vertical
    expect(PrIcons.stepForward, LucideIcons.skipForward);
    expect(PrIcons.stepForward, isNot(LucideIcons.stepForward)); // bar left
    expect(PrIcons.checkCircle, LucideIcons.circleCheck);
    expect(PrIcons.checkCircle, isNot(LucideIcons.checkCircle)); // big tick
  });

  testWidgets('PrPlayGlyph paints at its size in the icon colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Center(
        child: IconTheme(
          data: IconThemeData(color: Color(0xFFFFFFFF)),
          child: PrPlayGlyph(),
        ),
      ),
    );
    expect(tester.getSize(find.byType(PrPlayGlyph)), const Size(16, 16));
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
