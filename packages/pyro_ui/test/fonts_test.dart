import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'flutter_test_config.dart';

// The fonts are loaded once for every test file by flutter_test_config.dart.

Future<double> _width(WidgetTester tester, String text, TextStyle style) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: PrTheme.dark(),
      home: Center(
        child: Text(text, key: const Key('t'), style: style),
      ),
    ),
  );
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(
      of: find.byKey(const Key('t')),
      matching: find.byType(RichText),
    ),
  );
  expect(paragraph.text.style!.fontFamily, style.fontFamily);
  return paragraph.size.width;
}

void main() {
  test('the package declares Inter and JetBrains Mono; Lucide loads', () {
    expect(loadedFontFamilies, {
      'packages/pyro_ui/${PrText.uiFamily}',
      'packages/pyro_ui/${PrText.monoFamily}',
      'packages/lucide_icons_flutter/Lucide',
    });
    expect(PrText.body.fontFamily, 'packages/pyro_ui/Inter');
    expect(PrText.mono.fontFamily, 'packages/pyro_ui/JetBrains Mono');
  });

  testWidgets('UI text renders in Inter, which is proportional', (
    tester,
  ) async {
    final narrow = await _width(tester, 'iiii', PrText.body);
    final wide = await _width(tester, 'WWWW', PrText.body);
    // In the FlutterTest fallback both would be 4em (52px).
    expect(narrow, lessThan(wide / 2));
  });

  testWidgets('mono text renders in JetBrains Mono, 0.6em per glyph', (
    tester,
  ) async {
    final narrow = await _width(tester, 'iiii', PrText.mono);
    final wide = await _width(tester, 'WWWW', PrText.mono);
    expect(narrow, wide);
    // JetBrains Mono advances 600 units of 1000; FlutterTest would give 48px.
    expect(narrow, closeTo(4 * 12 * 0.6, 0.01));
  });
}
