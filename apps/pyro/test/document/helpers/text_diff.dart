import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// Expects [actual] to be exactly [expected], printing the differing lines
/// first when they aren't.
void expectSameBytes(List<int> actual, List<int> expected, {String? reason}) {
  if (_same(actual, expected)) return;
  final a = utf8.decode(actual, allowMalformed: true).split('\n');
  final e = utf8.decode(expected, allowMalformed: true).split('\n');
  final lines = <String>[];
  for (var i = 0; i < a.length || i < e.length; i++) {
    final got = i < a.length ? a[i] : '<missing>';
    final want = i < e.length ? e[i] : '<missing>';
    if (got != want) lines.add('line ${i + 1}:\n  want: $want\n  got:  $got');
  }
  fail('${reason ?? 'bytes differ'}\n${lines.take(20).join('\n')}');
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
