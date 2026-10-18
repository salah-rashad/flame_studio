import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/main.dart';

void main() {
  testWidgets('shows the app name', (tester) async {
    await tester.pumpWidget(const PyroApp());
    expect(find.text('Pyro'), findsOneWidget);
  });
}
