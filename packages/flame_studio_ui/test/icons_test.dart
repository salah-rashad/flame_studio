import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  test('FsIcons draw from the regular-weight Lucide font', () {
    const icons = [
      FsIcons.video,
      FsIcons.image,
      FsIcons.film,
      FsIcons.type,
      FsIcons.hitbox,
      FsIcons.layers,
      FsIcons.globe,
      FsIcons.sparkle,
      FsIcons.circleDot,
      FsIcons.box,
      FsIcons.fileCode,
    ];
    for (final icon in icons) {
      expect(icon.fontFamily, 'Lucide');
      expect(icon.fontPackage, 'lucide_icons_flutter');
    }
    expect(icons.map((i) => i.codePoint).toSet(), hasLength(icons.length));
    expect(FsIcons.hitbox, LucideIcons.squareDashed);
  });
}
