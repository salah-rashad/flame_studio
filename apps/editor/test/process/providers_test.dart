import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/process/process.dart';
import 'package:pyro/process/providers.dart';
import 'package:pyro/project/project.dart';

ProjectState project(String root) => ProjectState(
  root: root,
  sdk: SdkInfo.none,
  compatibility: RuntimeCompatibility.unknown,
);

void main() {
  group('consoleBufferProvider', () {
    test('is recreated when the project root changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(consoleBufferProvider, (_, _) {});
      container.read(projectProvider.notifier).open(project('/a'));
      final first = container.read(consoleBufferProvider)
        ..add('from a', source: ConsoleSource.pyro);
      container.read(projectProvider.notifier).open(project('/b'));
      final second = container.read(consoleBufferProvider);
      expect(second, isNot(same(first)));
      expect(second.lines, isEmpty);
    });

    test('is disposed when the project closes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(consoleBufferProvider, (_, _) {});
      container.read(projectProvider.notifier).open(project('/a'));
      final buffer = container.read(consoleBufferProvider);
      var closed = false;
      buffer.changes.listen(null, onDone: () => closed = true);
      container.read(projectProvider.notifier).close();
      container.read(consoleBufferProvider);
      return pumpEventQueue().then((_) => expect(closed, isTrue));
    });
  });

  group('consoleSourceFilterProvider', () {
    test('shows every source by default, one, then all again', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(consoleSourceFilterProvider), {
        ...ConsoleSource.values,
      });
      container
          .read(consoleSourceFilterProvider.notifier)
          .showOnly(ConsoleSource.game);
      expect(container.read(consoleSourceFilterProvider), {ConsoleSource.game});
      container.read(consoleSourceFilterProvider.notifier).showAll();
      expect(container.read(consoleSourceFilterProvider), {
        ...ConsoleSource.values,
      });
    });
  });
}
