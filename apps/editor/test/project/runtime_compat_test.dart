import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/project/project.dart';

import '../helpers/fixtures.dart';

void main() {
  group('checkRuntimeCompatibility (T007, FR-004, Q49)', () {
    test(
      'a lock resolving a known runtime is ok and reads its version',
      () async {
        final fs = MemoryFileSystem.test();
        fs.directory('/proj').createSync(recursive: true);
        fs.file('/proj/pubspec.lock').writeAsStringSync(lockOk);
        final compat = await checkRuntimeCompatibility('/proj', fileSystem: fs);
        expect(compat.status, RuntimeCompatStatus.ok);
        expect(compat.foundVersion, '0.0.1');
        expect(compat.readsUpTo, 1);
      },
    );

    test(
      'a runtime older than the Scene version is tooOld and gates saving',
      () async {
        final fs = MemoryFileSystem.test();
        fs.directory('/proj').createSync(recursive: true);
        fs.file('/proj/pubspec.lock').writeAsStringSync(lockTooOld);
        final compat = await checkRuntimeCompatibility('/proj', fileSystem: fs);
        expect(compat.status, RuntimeCompatStatus.tooOld);
        expect(compat.readsUpTo, isNull);
      },
    );

    test('a runtime newer than the table is tooNew', () async {
      final fs = MemoryFileSystem.test();
      fs.directory('/proj').createSync(recursive: true);
      fs.file('/proj/pubspec.lock').writeAsStringSync(lockTooNew);
      final compat = await checkRuntimeCompatibility('/proj', fileSystem: fs);
      expect(compat.status, RuntimeCompatStatus.tooNew);
      expect(compat.readsUpTo, isNull);
    });

    test(
      'a lock without pyro_runtime and no workspace fallback is unknown',
      () async {
        final fs = MemoryFileSystem.test();
        fs.directory('/proj').createSync(recursive: true);
        fs.file('/proj/pubspec.lock').writeAsStringSync(lockNoRuntime);
        final compat = await checkRuntimeCompatibility('/proj', fileSystem: fs);
        expect(compat, RuntimeCompatibility.unknown);
        expect(compat.readsUpTo, isNull);
      },
    );

    test(
      'a workspace member falls back to the sibling runtime pubspec',
      () async {
        final fs = MemoryFileSystem.test();
        fs.directory('/proj').createSync(recursive: true);
        fs.directory('/packages/pyro_runtime').createSync(recursive: true);
        fs
            .file('/packages/pyro_runtime/pubspec.yaml')
            .writeAsStringSync('name: pyro_runtime\nversion: 0.0.1\n');
        final compat = await checkRuntimeCompatibility('/proj', fileSystem: fs);
        expect(compat.status, RuntimeCompatStatus.ok);
        expect(compat.foundVersion, '0.0.1');
      },
    );

    test('no lock at all is unknown, never an error', () async {
      final fs = MemoryFileSystem.test();
      fs.directory('/proj').createSync(recursive: true);
      final compat = await checkRuntimeCompatibility('/proj', fileSystem: fs);
      expect(compat, RuntimeCompatibility.unknown);
    });
  });
}
