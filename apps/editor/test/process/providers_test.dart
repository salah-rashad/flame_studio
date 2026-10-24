import 'package:file/memory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/process/process.dart';
import 'package:pyro/process/providers.dart';
import 'package:pyro/project/project.dart';

ProjectState project(
  String root, {
  SdkInfo sdk = SdkInfo.none,
  RuntimeCompatibility compatibility = RuntimeCompatibility.unknown,
}) => ProjectState(root: root, sdk: sdk, compatibility: compatibility);

const _sdk = SdkInfo(
  version: '3.44.2',
  source: SdkSource.flutterRoot,
  root: '/sdk',
);

const _compatible = RuntimeCompatibility(
  status: RuntimeCompatStatus.ok,
  foundVersion: '0.0.1',
  readsUpTo: 1,
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

  group('playControllerProvider', () {
    late MemoryFileSystem fs;
    late ProviderContainer container;
    late List<String> started;

    setUp(() {
      fs = MemoryFileSystem.test();
      fs.directory('/a/macos').createSync(recursive: true);
      fs.directory('/b').createSync(recursive: true);
      started = [];
      container = ProviderContainer(
        overrides: [
          playFileSystemProvider.overrideWithValue(fs),
          playStarterProvider.overrideWithValue((path) async {
            started.add(path);
            throw PlayStartException(path, 'not in tests');
          }),
        ],
      );
      addTearDown(container.dispose);
      container.listen(playControllerProvider, (_, _) {});
    });

    test('is null without a project', () {
      expect(container.read(playControllerProvider), isNull);
    });

    test('has no block for a playable project and plays it', () async {
      container
          .read(projectProvider.notifier)
          .open(project('/a', sdk: _sdk, compatibility: _compatible));
      final controller = container.read(playControllerProvider)!;
      expect(controller.projectPath, '/a');
      expect(controller.block, isNull);
      await controller.play();
      expect(started, ['/a']);
      expect(
        container.read(consoleBufferProvider).lines.last.text,
        "Can't play /a: not in tests",
      );
    });

    test('blocks in the data model order', () {
      final notifier = container.read(projectProvider.notifier);
      notifier.open(project('/b'));
      expect(
        container.read(playControllerProvider)!.block!.reason,
        contains('Flutter SDK'),
      );
      notifier.open(project('/b', sdk: _sdk));
      expect(
        container.read(playControllerProvider)!.block!.fix,
        contains('pyro_runtime was not found'),
      );
      notifier.open(project('/b', sdk: _sdk, compatibility: _compatible));
      expect(
        container.read(playControllerProvider)!.block!.fix,
        contains('flutter create --platforms=macos .'),
      );
    });

    test('is recreated per project and disposed on close', () async {
      final notifier = container.read(projectProvider.notifier);
      notifier.open(project('/a', sdk: _sdk, compatibility: _compatible));
      final first = container.read(playControllerProvider)!;
      var closed = false;
      first.phases.listen(null, onDone: () => closed = true);
      notifier.open(project('/b', sdk: _sdk, compatibility: _compatible));
      expect(container.read(playControllerProvider), isNot(same(first)));
      await pumpEventQueue();
      expect(closed, isTrue);
      notifier.close();
      expect(container.read(playControllerProvider), isNull);
    });
  });
}
