import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The scene format is pure Dart (research R5): it must never depend on a
/// Flame version, and the benchmark runs it outside Flutter.
void main() {
  test('lib/src/scene imports no Flutter, Flame or dart:ui', () {
    final forbidden = RegExp(
      r'''^\s*(import|export)\s+['"](package:flutter|package:flame|dart:ui)''',
    );
    final offenders = <String>[];
    final files = Directory('lib/src/scene')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (forbidden.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
