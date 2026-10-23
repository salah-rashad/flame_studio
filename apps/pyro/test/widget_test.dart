import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/main.dart';

void main() {
  testWidgets('the welcome window shows the app name and open-by-path', (
    tester,
  ) async {
    await tester.pumpWidget(PyroApp(fileSystem: MemoryFileSystem.test()));
    await tester.pumpAndSettle();

    expect(find.text('Pyro'), findsOneWidget);
    expect(find.text('No recent projects'), findsOneWidget);
    expect(find.text('Open project…'), findsOneWidget);
  });
}
