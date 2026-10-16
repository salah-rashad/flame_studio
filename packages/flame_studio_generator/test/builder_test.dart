import 'package:build/build.dart';
import 'package:flame_studio_generator/builder.dart';
import 'package:test/test.dart';

void main() {
  test('placeholder builder declares no outputs', () {
    final builder = flameStudioBuilder(BuilderOptions.empty);
    expect(builder.buildExtensions, isEmpty);
  });
}
