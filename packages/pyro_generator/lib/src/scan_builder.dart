import 'dart:convert';

import 'package:build/build.dart';

import 'introspect.dart';

/// The per-library step: scans a library under `lib/` and writes what it
/// found to `<file>.pyro.json` in the build cache (research R2).
///
/// Writes nothing for a library with no annotated class and no `@Editable`
/// field, so with build_runner's triggers most libraries cost nothing.
class PyroScanBuilder implements Builder {
  /// Creates the scan step.
  const PyroScanBuilder();

  @override
  Map<String, List<String>> get buildExtensions => const {
    '.dart': ['.pyro.json'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final input = buildStep.inputId;
    if (!input.path.startsWith('lib/')) return;
    if (!await buildStep.resolver.isLibrary(input)) return;
    final fragment = await scanLibrary(await buildStep.inputLibrary, buildStep);
    if (fragment.isEmpty) return;
    await buildStep.writeAsString(
      input.changeExtension('.pyro.json'),
      jsonEncode(fragment.toJson()),
    );
  }
}
