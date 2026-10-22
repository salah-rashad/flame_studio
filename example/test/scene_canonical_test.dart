import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

/// The Scene is hand-written but must be exactly what Pyro's writer
/// produces, so a later save by Pyro makes no spurious diff (spec 005,
/// FR-003).
void main() {
  test('level1.scene.json is in canonical form', () {
    final text = File('assets/scenes/level1.scene.json').readAsStringSync();
    final decoded = SceneCodec.decode(text);
    expect(decoded.repairs.isEmpty, isTrue, reason: '${decoded.repairs}');
    expect(SceneCodec.encode(decoded.scene), text);
  });
}
