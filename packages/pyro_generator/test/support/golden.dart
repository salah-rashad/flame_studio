import 'dart:io';

import 'package:test/test.dart';

/// Whether goldens are rewritten instead of compared
/// (`PYRO_UPDATE_GOLDENS=1 dart test`).
final bool updateGoldens = Platform.environment['PYRO_UPDATE_GOLDENS'] == '1';

/// Compares [actual] with [golden] byte for byte, or rewrites [golden] when
/// [updateGoldens] is set. A null [actual] means the file must not exist.
void expectGolden(File golden, String? actual) {
  if (updateGoldens) {
    if (actual == null) {
      if (golden.existsSync()) golden.deleteSync();
    } else {
      golden.writeAsStringSync(actual);
    }
    return;
  }
  if (actual == null) {
    expect(
      golden.existsSync(),
      isFalse,
      reason: '${golden.path} exists, but nothing was written',
    );
    return;
  }
  expect(
    golden.existsSync(),
    isTrue,
    reason: '${golden.path} is missing; run with PYRO_UPDATE_GOLDENS=1',
  );
  final expected = golden.readAsStringSync();
  if (expected != actual) {
    fail('${golden.path} differs:\n${_diff(expected, actual)}');
  }
}

String _diff(String expected, String actual) {
  final a = expected.split('\n');
  final b = actual.split('\n');
  final out = StringBuffer();
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : '<missing>';
    final y = i < b.length ? b[i] : '<missing>';
    if (x != y) out.writeln('line ${i + 1}:\n  - $x\n  + $y');
  }
  return out.toString();
}
