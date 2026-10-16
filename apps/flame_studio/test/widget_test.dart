import 'package:flame_studio/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the app name', (tester) async {
    await tester.pumpWidget(const FlameStudioApp());
    expect(find.text('Flame Studio'), findsOneWidget);
  });
}
