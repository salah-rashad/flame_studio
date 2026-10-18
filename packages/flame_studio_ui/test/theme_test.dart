import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FsColors and FsShadows are reachable from the theme', (
    tester,
  ) async {
    late FsColors colors;
    late FsShadows shadows;
    await tester.pumpWidget(
      MaterialApp(
        theme: FsTheme.dark(),
        home: Builder(
          builder: (context) {
            colors = FsColors.of(context);
            shadows = FsShadows.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(colors, FsColors.dark);
    expect(shadows, FsShadows.dark);
  });

  test('the theme draws no ripples', () {
    final theme = FsTheme.dark();
    expect(theme.splashFactory, NoSplash.splashFactory);
    expect(theme.scaffoldBackgroundColor, FsColors.dark.bgApp);
  });

  test('lerp at the ends returns each side', () {
    final other = FsColors.dark.copyWith(accent: const Color(0xFF000000));
    expect(FsColors.dark.lerp(other, 0).accent, FsColors.dark.accent);
    expect(FsColors.dark.lerp(other, 1).accent, const Color(0xFF000000));
  });
}
