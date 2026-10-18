import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

void main() {
  testWidgets('PrColors and PrShadows are reachable from the theme', (
    tester,
  ) async {
    late PrColors colors;
    late PrShadows shadows;
    await tester.pumpWidget(
      MaterialApp(
        theme: PrTheme.dark(),
        home: Builder(
          builder: (context) {
            colors = PrColors.of(context);
            shadows = PrShadows.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(colors, PrColors.dark);
    expect(shadows, PrShadows.dark);
  });

  test('the theme draws no ripples', () {
    final theme = PrTheme.dark();
    expect(theme.splashFactory, NoSplash.splashFactory);
    expect(theme.scaffoldBackgroundColor, PrColors.dark.bgApp);
  });

  test('lerp at the ends returns each side', () {
    final other = PrColors.dark.copyWith(accent: const Color(0xFF000000));
    expect(PrColors.dark.lerp(other, 0).accent, PrColors.dark.accent);
    expect(PrColors.dark.lerp(other, 1).accent, const Color(0xFF000000));
  });
}
