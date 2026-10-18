import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the package's fonts (Inter, JetBrains Mono) and the Lucide icon
/// font before every test file, so tests render real glyphs. By default
/// flutter_test draws every glyph as a 1em square.
///
/// The fonts are registered under the names an app that depends on the
/// package sees: `packages/pyro_ui/<family>` (here the package is
/// the root, so its manifest lists its own families without the prefix) and
/// `packages/lucide_icons_flutter/Lucide`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  loadedFontFamilies = await _loadFonts();
  await testMain();
}

/// The families [testExecutable] loaded, for `fonts_test.dart`.
Set<String> loadedFontFamilies = {};

const _lucide = 'packages/lucide_icons_flutter/Lucide';

Future<Set<String>> _loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<Object?>;
  final families = <String>{};
  for (final entry in manifest.cast<Map<String, Object?>>()) {
    final declared = entry['family']! as String;
    final String family;
    if (declared == _lucide) {
      family = declared;
    } else if (declared.startsWith('packages/')) {
      continue; // Lucide's other weights and other packages' fonts
    } else {
      family = 'packages/pyro_ui/$declared';
    }
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
