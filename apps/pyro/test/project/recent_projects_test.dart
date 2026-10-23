import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_ui/pyro_ui.dart';

void main() {
  group('RecentProjectsStore (T008, FR-003)', () {
    late MemoryFileSystem fs;

    setUp(() {
      fs = MemoryFileSystem.test();
      fs.directory('/app-support').createSync(recursive: true);
    });

    RecentProjectsStore store() => RecentProjectsStore(
      fs.file('/app-support/recent_projects.json'),
      fileSystem: fs,
    );

    test('a missing file reads as empty', () async {
      expect(await store().read(), RecentProjects.empty);
    });

    test('write then read round-trips paths, lastOpened and sizes', () async {
      final s = store();
      final value = RecentProjectsStore.opened(RecentProjects.empty, '/proj-a');
      await s.write(
        value.copyWith(
          sizes: IMap(
            const <String, PrShellSizes>{},
          ).add('/proj-a', const PrShellSizes(left: 300, right: 400)),
        ),
      );
      final read = await s.read();
      expect(read.paths, ['/proj-a']);
      expect(read.lastOpened, '/proj-a');
      expect(read.sizes['/proj-a'], const PrShellSizes(left: 300, right: 400));
    });

    test("a fresh install's folder is created on the first write", () async {
      final s = RecentProjectsStore(
        fs.file('/fresh-support/recent_projects.json'),
        fileSystem: fs,
      );
      await s.write(RecentProjectsStore.opened(RecentProjects.empty, '/proj'));
      expect(await s.read().then((r) => r.paths), ['/proj']);
    });

    test('opened moves a project to the front without duplicates', () async {
      var value = RecentProjects.empty;
      value = RecentProjectsStore.opened(value, '/a');
      value = RecentProjectsStore.opened(value, '/b');
      value = RecentProjectsStore.opened(value, '/a');
      expect(value.paths, ['/a', '/b']);
      expect(value.lastOpened, '/a');
    });

    test('a broken file reads as empty and reports the error', () async {
      fs.file('/app-support/recent_projects.json').writeAsStringSync('{');
      final errors = <Object>[];
      expect(await store().read(errors.add), RecentProjects.empty);
      expect(errors, hasLength(1));
    });
  });
}
