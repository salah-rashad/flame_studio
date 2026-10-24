import 'dart:async';
import 'dart:io' show FileSystemEvent, FileSystemModifyEvent;

import 'package:fake_async/fake_async.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/app/providers.dart';
import 'package:pyro/process/process.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../../helpers/fixtures.dart';

/// A Manifest with one custom component, `Ship`.
const String manifestWithShip = '''
{
  "manifestVersion": 1,
  "types": [
    {
      "id": "Ship",
      "role": "component",
      "label": "Ship",
      "supertypes": ["PositionComponent"],
      "fields": [
        {
          "name": "speed",
          "type": "double",
          "nullable": false,
          "default": 1.5
        }
      ]
    }
  ],
  "errors": [],
  "warnings": []
}
''';

void main() {
  // A broadcast stream the test drives; nothing to release.
  // ignore: close_sinks
  late StreamController<FileSystemEvent> events;
  late FileSystem fs;

  setUp(() {
    events = StreamController<FileSystemEvent>.broadcast();
    fs = MemoryFileSystem.test();
    fs.directory('/proj/lib').createSync(recursive: true);
  });

  ProviderContainer container({DirectoryWatcher? watch}) {
    final c = ProviderContainer(
      overrides: [
        catalogFileSystemProvider.overrideWithValue(fs),
        manifestWatchProvider.overrideWithValue(
          watch ?? (_) => const Stream.empty(),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  void openProject(ProviderContainer c) => c
      .read(projectProvider.notifier)
      .open(
        const ProjectState(
          root: '/proj',
          sdk: SdkInfo.none,
          compatibility: RuntimeCompatibility.unknown,
        ),
      );

  void write(String text) =>
      fs.file('/proj/lib/pyro.manifest.json').writeAsStringSync(text);

  void manifestChanged() => events.add(
    FileSystemModifyEvent('/proj/lib/pyro.manifest.json', false, true),
  );

  group('typeCatalogProvider (T021, FR-012/013, Q105)', () {
    test('a project without a Manifest is builtinOnly', () {
      final c = container();
      openProject(c);
      final catalog = c.read(typeCatalogProvider);
      expect(catalog.origin, isA<ManifestAbsent>());
      expect(catalog.types, hasLength(4));
      expect(catalog[const TypeId('entity')], isNotNull);
    });

    test('a clean Manifest joins its types with the built-ins', () {
      write(manifestWithShip);
      final c = container();
      openProject(c);
      final catalog = c.read(typeCatalogProvider);
      expect(catalog.origin, isA<ManifestUpToDate>());
      expect(catalog.types, hasLength(5));
      expect(catalog[const TypeId('Ship')]!.fields.single.name, 'speed');
      expect(catalog.problems, isEmpty);
    });

    test('a Manifest type of a built-in ID never overrides the built-in', () {
      write(manifestWithShip.replaceAll('Ship', 'sprite'));
      final c = container();
      openProject(c);
      final catalog = c.read(typeCatalogProvider);
      expect(catalog[const TypeId('sprite')]!.builtIn, isTrue);
      // The shadowed type is warned about, not silently missing (FR-012).
      expect(catalog.problems, hasLength(1));
      expect(catalog.problems.single.code, 'builtInShadowed');
      expect(catalog.problems.single.isWarning, isTrue);
      expect(catalog.problems.single.className, 'sprite');
    });

    test('a Manifest created after the open reloads the catalog (FR-013)', () {
      fakeAsync((async) {
        // `build_runner` may create lib/ and the Manifest while Pyro is
        // open; the project root is watched from the start.
        fs.directory('/proj/lib').deleteSync();
        final c = container(watch: (_) => events.stream);
        openProject(c);
        expect(c.read(typeCatalogProvider).origin, isA<ManifestAbsent>());

        fs.directory('/proj/lib').createSync(recursive: true);
        write(manifestWithShip);
        manifestChanged();
        async.elapse(manifestQuietPeriod);
        final catalog = c.read(typeCatalogProvider);
        expect(catalog.origin, isA<ManifestUpToDate>());
        expect(catalog[const TypeId('Ship')], isNotNull);
      });
    });

    test('a Manifest write reloads the catalog, debounced (FR-013)', () {
      fakeAsync((async) {
        write(manifestWithShip);
        final c = container(watch: (_) => events.stream);
        openProject(c);
        expect(c.read(typeCatalogProvider).origin, isA<ManifestUpToDate>());

        // The example Manifest replaces Ship with Banner and Spin.
        write(readExampleManifest());
        manifestChanged();
        // Before the quiet period nothing has happened yet.
        async.elapse(const Duration(milliseconds: 50));
        expect(c.read(typeCatalogProvider)[const TypeId('Ship')], isNotNull);
        async.elapse(manifestQuietPeriod);
        final catalog = c.read(typeCatalogProvider);
        expect(catalog[const TypeId('Ship')], isNull);
        expect(catalog[const TypeId('Banner')], isNotNull);
        expect(catalog[const TypeId('Spin')]!.role, TypeRole.behavior);
      });
    });

    test('a broken Manifest keeps the last good types (Q105)', () {
      fakeAsync((async) {
        write(manifestWithShip);
        final c = container(watch: (_) => events.stream);
        openProject(c);
        expect(c.read(typeCatalogProvider).origin, isA<ManifestUpToDate>());

        write(manifestBrokenJson);
        manifestChanged();
        async.elapse(manifestQuietPeriod);
        final catalog = c.read(typeCatalogProvider);
        expect(catalog.origin, isA<ManifestStale>());
        expect(
          (catalog.origin as ManifestStale).reason,
          contains('unreadable'),
        );
        // Stale, not empty: the previous types stay active.
        expect(catalog.types, hasLength(5));
        expect(catalog[const TypeId('Ship')], isNotNull);
      });
    });

    test('a newer manifestVersion keeps the last good types (Q105)', () {
      fakeAsync((async) {
        write(manifestWithShip);
        final c = container(watch: (_) => events.stream);
        openProject(c);
        expect(c.read(typeCatalogProvider).origin, isA<ManifestUpToDate>());

        write(manifestNewerVersion);
        manifestChanged();
        async.elapse(manifestQuietPeriod);
        final catalog = c.read(typeCatalogProvider);
        expect(catalog.origin, isA<ManifestStale>());
        expect(
          (catalog.origin as ManifestStale).reason,
          contains('newer Pyro'),
        );
        expect(catalog[const TypeId('Ship')], isNotNull);
      });
    });

    test('errors keep the types and carry their problems (FR-014)', () {
      fakeAsync((async) {
        write(manifestWithShip);
        final c = container(watch: (_) => events.stream);
        openProject(c);
        expect(c.read(typeCatalogProvider).origin, isA<ManifestUpToDate>());

        write(manifestWithProblems);
        manifestChanged();
        async.elapse(manifestQuietPeriod);
        final catalog = c.read(typeCatalogProvider);
        expect(catalog.origin, isA<ManifestStale>());
        expect(catalog.problems, hasLength(2));
        expect(catalog.problems.first.code, 'PYRO_NON_CONST_DEFAULT');
        expect(catalog[const TypeId('Ship')], isNotNull);
      });
    });

    test('a deleted Manifest returns to builtinOnly', () {
      fakeAsync((async) {
        write(manifestWithShip);
        final c = container(watch: (_) => events.stream);
        openProject(c);

        fs.file('/proj/lib/pyro.manifest.json').deleteSync();
        manifestChanged();
        async.elapse(manifestQuietPeriod);
        expect(c.read(typeCatalogProvider).origin, isA<ManifestAbsent>());
      });
    });

    test('closing the project falls back to the built-ins', () {
      write(manifestWithShip);
      final c = container();
      openProject(c);
      c.read(projectProvider.notifier).close();
      final catalog = c.read(typeCatalogProvider);
      expect(catalog.origin, isA<ManifestAbsent>());
      expect(catalog.types, hasLength(4));
    });
  });
}
