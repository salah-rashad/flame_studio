import 'package:build/build.dart';
import 'package:pyro_generator/builder.dart';
import 'package:test/test.dart';

void main() {
  test('placeholder builder declares no outputs', () {
    final builder = pyroBuilder(BuilderOptions.empty);
    expect(builder.buildExtensions, isEmpty);
  });
}
