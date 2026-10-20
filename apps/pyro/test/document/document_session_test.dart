import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:file/file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'helpers/failing_file_system.dart';
import 'helpers/fixtures.dart';
import 'helpers/scenes.dart';

const projectRoot = '/project';
const folder = '$projectRoot/assets/scenes';
const path = '$folder/level.scene.json';
const reads = Scene.currentSchemaVersion;

const recoveryFolder = '/support/recovery';

// Scene files and recovery copies share one file system, as on a real disk.
SessionServices services([FileSystem? fs]) {
  final files = fs ?? FailingFileSystem();
  return SessionServices(
    files: SceneFiles(fileSystem: files, offload: runInline),
    recovery: RecoveryStore(
      folder: recoveryFolder,
      fileSystem: files,
      offload: runInline,
    ),
    projectRoot: projectRoot,
    newId: counterIds(),
  );
}

void main() {
  group('editing', () {
    late DocumentSession session;
    late List<OpenDocument> published;

    setUp(() {
      session = DocumentSession.create(services: services());
      published = [];
      session.changes.listen(published.add);
    });

    tearDown(() async {
      if (!session.isClosed) await session.discardAndClose();
    });

    NodeId root() => session.state.state.rootId;

    test('a new Scene holds only a root Node, is clean and has no path', () {
      final doc = session.state;
      expect(doc.state.nodes.length, 1);
      expect(doc.state.node(root()), isA<RootNode>());
      expect(doc.isDirty, isFalse);
      expect(doc.path, isNull);
      expect(doc.origin, OpenedFrom.created);
    });

    test('transact publishes each step synchronously and in order', () {
      session.transact(
        'Add Node',
        (d) => d.addNode(entity('x'), parentId: root()),
      );
      expect(published, hasLength(1));
      expect(identical(published.single, session.state), isTrue);
      session.transact(
        'Add another',
        (d) => d.addNode(entity('y'), parentId: root()),
      );
      expect(published, hasLength(2));
      expect(session.state.history.undoLabel, 'Add another');
      expect(session.state.isDirty, isTrue);
    });

    test('a no-op transaction publishes nothing', () {
      session.transact('Nothing', (d) => d);
      expect(published, isEmpty);
    });

    test('a refused edit throws TransactionFailed and changes nothing', () {
      final before = session.state;
      expect(
        () => session.transact('Remove root', (d) => d.removeNode(d.rootId)),
        throwsA(
          isA<TransactionFailed>()
              .having((e) => e.label, 'label', 'Remove root')
              .having((e) => e.cause, 'cause', isA<RootNotAllowed>()),
        ),
      );
      expect(identical(session.state, before), isTrue);
      expect(published, isEmpty);
    });

    test('other errors propagate unchanged and change nothing', () {
      final before = session.state;
      expect(
        () => session.transact('Bug', (d) => throw StateError('bug')),
        throwsStateError,
      );
      expect(identical(session.state, before), isTrue);
    });

    test('undo and redo publish', () {
      session.transact('Add', (d) => d.addNode(entity('x'), parentId: root()));
      session.undo();
      expect(session.state.isDirty, isFalse);
      session.redo();
      expect(session.state.isDirty, isTrue);
      expect(published, hasLength(3));
      session.redo();
      expect(published, hasLength(3), reason: 'nothing to redo');
    });

    test('close refuses unsaved changes; discardAndClose drops them', () async {
      session.transact('Add', (d) => d.addNode(entity('x'), parentId: root()));
      await expectLater(session.close(), throwsStateError);
      await session.discardAndClose();
      expect(() => session.undo(), throwsStateError, reason: 'closed');
    });

    test('a clean session closes', () async {
      await session.close();
    });

    test('two sessions keep separate histories', () {
      final other = DocumentSession.create(services: services());
      addTearDown(other.discardAndClose);
      final otherPublished = <OpenDocument>[];
      other.changes.listen(otherPublished.add);
      session.transact('Add', (d) => d.addNode(entity('x'), parentId: root()));
      expect(otherPublished, isEmpty);
      expect(other.state.isDirty, isFalse);
      session.undo();
      session.redo();
      expect(otherPublished, isEmpty);
      expect(other.state.state.nodes.length, 1);
    });
  });

  group('saving', () {
    late FailingFileSystem fs;
    late DocumentSession session;

    setUp(() async {
      fs = FailingFileSystem();
      fs.inner.directory(folder).createSync(recursive: true);
      fs.inner
          .file(path)
          .writeAsBytesSync(readFixtureBytes('canonical/entity.scene.json'));
      session = await DocumentSession.open(path, services: services(fs));
      fs.operations.clear();
    });

    tearDown(() async {
      if (!session.isClosed) await session.discardAndClose();
    });

    void add(String id) => session.transact(
      'Add $id',
      (d) => d.addNode(entity(id), parentId: d.rootId),
    );

    test('opens a Scene file clean', () {
      expect(session.state.path, path);
      expect(session.state.isDirty, isFalse);
      expect(session.state.origin, OpenedFrom.file);
    });

    test('a save makes the session clean and publishes', () async {
      final published = <OpenDocument>[];
      session.changes.listen(published.add);
      add('x');
      await session.save(runtimeReadsUpTo: reads);
      expect(session.state.isDirty, isFalse);
      expect(published.last.isDirty, isFalse);
      expect(fs.inner.file(path).readAsStringSync(), contains('"x"'));
    });

    test('edits made during a save stay unsaved', () async {
      add('x');
      final hold = Completer<void>();
      fs
        ..holdWrites = hold
        ..holdPattern = '.pyro-tmp';
      final saving = session.save(runtimeReadsUpTo: reads);
      await pumpEventQueue();
      add('y');
      hold.complete();
      await saving;
      expect(session.state.isDirty, isTrue);
      final written = fs.inner.file(path).readAsStringSync();
      expect(written, contains('"x"'));
      expect(written, isNot(contains('"y"')));
      session.undo();
      expect(session.state.isDirty, isFalse, reason: 'back at the saved state');
    });

    test('saves run one after the other', () async {
      add('x');
      final first = session.save(runtimeReadsUpTo: reads);
      add('y');
      final second = session.save(runtimeReadsUpTo: reads);
      await Future.wait([first, second]);
      final kinds = [for (final op in fs.operations) op.split(' ').first];
      expect(kinds, ['read', 'write', 'rename', 'read', 'write', 'rename']);
      expect(fs.inner.file(path).readAsStringSync(), contains('"y"'));
      expect(session.state.isDirty, isFalse);
    });

    test('after "Save as" the session belongs to the new path', () async {
      const other = '$folder/copy.scene.json';
      add('x');
      await session.save(runtimeReadsUpTo: reads, saveAs: other);
      expect(session.state.path, other);
      add('y');
      await session.save(runtimeReadsUpTo: reads);
      expect(fs.inner.file(other).readAsStringSync(), contains('"y"'));
      expect(fs.inner.file(path).readAsStringSync(), isNot(contains('"x"')));
    });

    test(
      'a save ends a coalescing run, so undo returns to the saved state',
      () async {
        void drag(String id) => session.transact(
          'Drag',
          (d) => d.addNode(entity(id), parentId: d.rootId),
          coalesceKey: 'drag',
        );
        drag('x');
        final hold = Completer<void>();
        fs
          ..holdWrites = hold
          ..holdPattern = '.pyro-tmp';
        final saving = session.save(runtimeReadsUpTo: reads);
        await pumpEventQueue();
        drag('y');
        hold.complete();
        await saving;
        expect(session.state.isDirty, isTrue);
        expect(session.state.history.undoLabel, 'Drag');
        session.undo();
        expect(
          session.state.isDirty,
          isFalse,
          reason: 'the saved state is kept',
        );
        expect(session.state.state.contains(const NodeId('x')), isTrue);
      },
    );

    test('close waits for a save in flight', () async {
      add('x');
      final hold = Completer<void>();
      fs
        ..holdWrites = hold
        ..holdPattern = '.pyro-tmp';
      final saving = session.save(runtimeReadsUpTo: reads);
      await pumpEventQueue();
      final closing = session.close();
      hold.complete();
      await saving;
      await closing;
      expect(session.isClosed, isTrue);
      expect(fs.inner.file(path).readAsStringSync(), contains('"x"'));
    });

    test('discardAndClose waits for a save in flight', () async {
      add('x');
      final hold = Completer<void>();
      fs
        ..holdWrites = hold
        ..holdPattern = '.pyro-tmp';
      final saving = session.save(runtimeReadsUpTo: reads);
      await pumpEventQueue();
      final closing = session.discardAndClose();
      hold.complete();
      await expectLater(saving, completes);
      await closing;
      expect(session.isClosed, isTrue);
    });

    test('a refused save keeps the edits and the unsaved state', () async {
      add('x');
      fs.inner.file(path).writeAsStringSync('changed elsewhere');
      await expectLater(
        session.save(runtimeReadsUpTo: reads),
        throwsA(isA<SceneChangedOnDisk>()),
      );
      expect(session.state.isDirty, isTrue);
      expect(session.state.state.contains(const NodeId('x')), isTrue);
      add('y');
      await session.save(runtimeReadsUpTo: reads, overwrite: true);
      expect(session.state.isDirty, isFalse);
    });
  });

  group('recovery', () {
    late FailingFileSystem fs;
    late SessionServices svc;
    late Uint8List original;

    setUp(() {
      fs = FailingFileSystem();
      fs.inner.directory(folder).createSync(recursive: true);
      original = readFixtureBytes('canonical/entity.scene.json');
      fs.inner.file(path).writeAsBytesSync(original);
      svc = services(fs);
    });

    // Runs [body] in fake time; [open] resolves a future there.
    void inFakeTime(
      void Function(FakeAsync async, T Function<T>(Future<T>) wait) body,
    ) {
      fakeAsync((async) {
        T wait<T>(Future<T> future) {
          late T value;
          Object? error;
          StackTrace? stack;
          unawaited(
            future.then(
              (v) => value = v,
              onError: (Object e, StackTrace s) {
                error = e;
                stack = s;
              },
            ),
          );
          async.flushMicrotasks();
          if (error != null) Error.throwWithStackTrace(error!, stack!);
          return value;
        }

        body(async, wait);
      });
    }

    RecoveryCheck find(T Function<T>(Future<T>) wait, [String scene = path]) =>
        wait(svc.recovery.find(projectRoot: projectRoot, scenePath: scene));

    void add(DocumentSession session, String id) => session.transact(
      'Add $id',
      (d) => d.addNode(entity(id), parentId: d.rootId),
    );

    int recoveryWrites() => fs.operations
        .where((op) => op.startsWith('write $recoveryFolder'))
        .length;

    test('no copy while clean', () {
      inFakeTime((async, wait) {
        wait(DocumentSession.open(path, services: svc));
        async.elapse(const Duration(seconds: 90));
        expect(find(wait), isA<NoRecovery>());
      });
    });

    test('a copy every 30 s while dirty, only when the state changed', () {
      inFakeTime((async, wait) {
        final session = wait(DocumentSession.open(path, services: svc));
        add(session, 'x');
        async.elapse(const Duration(seconds: 29));
        expect(find(wait), isA<NoRecovery>());
        async.elapse(const Duration(seconds: 2));
        expect(find(wait), isA<RecoveryAvailable>());
        final writes = recoveryWrites();
        async.elapse(const Duration(seconds: 90));
        expect(recoveryWrites(), writes, reason: 'unchanged state');
        add(session, 'y');
        async.elapse(const Duration(seconds: 30));
        expect(recoveryWrites(), greaterThan(writes));
        expect(
          fs.inner.file(path).readAsBytesSync(),
          original,
          reason: 'FR-026',
        );
      });
    });

    test('a never-saved Scene gets no copy until it has a path', () {
      inFakeTime((async, wait) {
        final session = DocumentSession.create(services: svc);
        add(session, 'x');
        async.elapse(const Duration(seconds: 90));
        expect(fs.inner.directory(recoveryFolder).existsSync(), isFalse);
        const target = '$folder/new.scene.json';
        wait(session.save(runtimeReadsUpTo: reads, saveAs: target));
        add(session, 'y');
        async.elapse(const Duration(seconds: 31));
        expect(find(wait, target), isA<RecoveryAvailable>());
      });
    });

    test('saving and discarding remove the copy', () {
      inFakeTime((async, wait) {
        final session = wait(DocumentSession.open(path, services: svc));
        add(session, 'x');
        async.elapse(const Duration(seconds: 31));
        expect(find(wait), isA<RecoveryAvailable>());
        wait(session.save(runtimeReadsUpTo: reads));
        expect(find(wait), isA<NoRecovery>());

        add(session, 'y');
        async.elapse(const Duration(seconds: 31));
        expect(find(wait), isA<RecoveryAvailable>());
        wait(session.discardAndClose());
        expect(find(wait), isA<NoRecovery>());
      });
    });

    test('"Save as" removes the copy under the old path', () {
      inFakeTime((async, wait) {
        final session = wait(DocumentSession.open(path, services: svc));
        add(session, 'x');
        async.elapse(const Duration(seconds: 31));
        const other = '$folder/copy.scene.json';
        wait(session.save(runtimeReadsUpTo: reads, saveAs: other));
        expect(find(wait), isA<NoRecovery>());
        expect(find(wait, other), isA<NoRecovery>());
      });
    });

    test('after a crash, restore gives back the last copy', () {
      inFakeTime((async, wait) {
        final session = wait(DocumentSession.open(path, services: svc));
        add(session, 'x');
        async.elapse(const Duration(seconds: 31));
        final copied = SceneCodec.encode(session.state.state.toScene());
        async.elapse(const Duration(seconds: 9));
        add(session, 'y');
        async.elapse(const Duration(seconds: 10));
        // The crash: the session is dropped without closing, 20 s after the
        // last copy, so only "y" (made 10 s ago) is lost (SC-004).

        final check = find(wait);
        expect(check, isA<RecoveryAvailable>());
        final info = (check as RecoveryAvailable).info;
        final restored = wait(DocumentSession.restore(info, services: svc));
        final doc = restored.state;
        expect(SceneCodec.encode(doc.state.toScene()), copied);
        expect(doc.state.contains(const NodeId('y')), isFalse);
        expect(doc.isDirty, isTrue);
        expect(doc.history.canUndo, isFalse);
        expect(doc.origin, OpenedFrom.restored);
        expect(doc.path, path);
        expect(fs.inner.file(path).readAsBytesSync(), original);

        wait(restored.save(runtimeReadsUpTo: reads));
        expect(fs.inner.file(path).readAsStringSync(), copied);
        expect(find(wait), isA<NoRecovery>());
      });
    });

    test('a restored document refuses to save over a file changed since', () {
      inFakeTime((async, wait) {
        final session = wait(DocumentSession.open(path, services: svc));
        add(session, 'x');
        async.elapse(const Duration(seconds: 31));
        final info = (find(wait) as RecoveryAvailable).info;
        final restored = wait(DocumentSession.restore(info, services: svc));
        fs.inner.file(path).writeAsStringSync('changed after the restore');
        expect(
          () => wait(restored.save(runtimeReadsUpTo: reads)),
          throwsA(isA<SceneChangedOnDisk>()),
        );
      });
    });

    test('a failed recovery write is reported and editing goes on', () {
      inFakeTime((async, wait) {
        final session = wait(DocumentSession.open(path, services: svc));
        final errors = <Object>[];
        session.errors.listen(errors.add);
        add(session, 'x');
        fs.failAt = fs.operationCount + 1;
        async.elapse(const Duration(seconds: 31));
        expect(errors.single, isA<RecoveryWriteFailed>());
        add(session, 'y');
        expect(session.state.state.contains(const NodeId('y')), isTrue);
        async.elapse(const Duration(seconds: 30));
        expect(find(wait), isA<RecoveryAvailable>());
      });
    });
  });
}
