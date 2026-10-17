import 'dart:convert';

import 'package:flame_studio_ui/flame_studio_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the fonts this package declares in its pubspec, under the names an
/// app that depends on it sees (`packages/flame_studio_ui/<family>`).
///
/// Tests otherwise draw all text in the `FlutterTest` font, where every glyph
/// is a 1em square. Here the package is the root, so its manifest lists the
/// families without the `packages/` prefix.
Future<Set<String>> _loadPackageFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<Object?>;
  final families = <String>{};
  for (final entry in manifest.cast<Map<String, Object?>>()) {
    final declared = entry['family']! as String;
    if (declared.startsWith('packages/')) continue;
    final family = 'packages/flame_studio_ui/$declared';
    final loader = FontLoader(family);
    for (final font
        in (entry['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(font['asset']! as String));
    }
    await loader.load();
    families.add(family);
  }
  return families;
}

Future<double> _width(WidgetTester tester, String text, TextStyle style) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: FsTheme.dark(),
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
  late Set<String> families;
  setUpAll(() async => families = await _loadPackageFonts());

  test('the package declares Inter and JetBrains Mono', () {
    expect(families, {
      'packages/flame_studio_ui/${FsText.uiFamily}',
      'packages/flame_studio_ui/${FsText.monoFamily}',
    });
    expect(FsText.body.fontFamily, 'packages/flame_studio_ui/Inter');
    expect(FsText.mono.fontFamily, 'packages/flame_studio_ui/JetBrains Mono');
  });

  testWidgets('UI text renders in Inter, which is proportional', (
    tester,
  ) async {
    final narrow = await _width(tester, 'iiii', FsText.body);
    final wide = await _width(tester, 'WWWW', FsText.body);
    // In the FlutterTest fallback both would be 4em (52px).
    expect(narrow, lessThan(wide / 2));
  });

  testWidgets('mono text renders in JetBrains Mono, 0.6em per glyph', (
    tester,
  ) async {
    final narrow = await _width(tester, 'iiii', FsText.mono);
    final wide = await _width(tester, 'WWWW', FsText.mono);
    expect(narrow, wide);
    // JetBrains Mono advances 600 units of 1000; FlutterTest would give 48px.
    expect(narrow, closeTo(4 * 12 * 0.6, 0.01));
  });
}
