import 'dart:io';

import 'package:test/test.dart';

import 'support/golden.dart';
import 'support/harness.dart';

/// Every case under `test/goldens/` (research R12): its `input/lib/` sources
/// through both builders, compared with `pyro.g.dart.golden`,
/// `pyro.manifest.json.golden` and `log.golden`.
void main() {
  final root = Directory('test/goldens');
  final cases = [
    for (final dir in root.listSync(recursive: true).whereType<Directory>())
      if (Directory('${dir.path}/input').existsSync()) dir,
  ]..sort((a, b) => a.path.compareTo(b.path));

  for (final dir in cases) {
    final name = dir.path.substring(root.path.length + 1).replaceAll(r'\', '/');
    test(name, () async {
      final input = Directory('${dir.path}/input');
      final sources = {
        for (final file in input.listSync(recursive: true).whereType<File>())
          if (file.path.endsWith('.dart'))
            file.path.substring(input.path.length + 1).replaceAll(r'\', '/'):
                file.readAsStringSync(),
      };
      final run = await runGenerator(
        sources,
        withRuntime: !File('${input.path}/no_runtime').existsSync(),
      );
      expectGolden(File('${dir.path}/pyro.g.dart.golden'), run.registry);
      expectGolden(File('${dir.path}/pyro.manifest.json.golden'), run.manifest);
      expectGolden(File('${dir.path}/log.golden'), run.logText);
    });
  }
}
