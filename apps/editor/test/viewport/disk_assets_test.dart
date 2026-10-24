import 'dart:async';
import 'dart:io' show FileSystemEvent, FileSystemModifyEvent;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pyro/viewport/viewport.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

/// A [width]×[height] PNG, encoded by the engine.
Future<Uint8List> png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFF0000),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryFileSystem fs;
  late StreamController<FileSystemEvent> events;
  late DiskAssetSource source;
  const root = '/project';
  const hero = AssetPath('assets/images/hero.png');
  const coin = AssetPath('assets/images/coin.png');

  Future<void> write(AssetPath path, Uint8List bytes) async {
    final file = fs.file('$root/$path');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  setUp(() async {
    fs = MemoryFileSystem.test();
    events = StreamController<FileSystemEvent>.broadcast();
    await write(hero, await png(1, 1));
    await write(coin, await png(1, 1));
    source = DiskAssetSource(
      fileSystem: fs,
      root: root,
      watch: (_) => events.stream,
      quietPeriod: Duration.zero,
    );
  });

  tearDown(() async {
    source.dispose();
    await events.close();
  });

  test('loadText reads the file fresh every time', () async {
    const path = AssetPath('assets/scenes/a.scene.json');
    final file = fs.file('$root/$path');
    await file.parent.create(recursive: true);
    await file.writeAsString('one');
    expect(await source.loadText(path), 'one');
    await file.writeAsString('two');
    expect(await source.loadText(path), 'two');
  });

  test('loadImage decodes the file once and shares the image', () async {
    final a = await source.loadImage(hero);
    final b = await source.loadImage(hero);
    expect(a.width, 1);
    expect(identical(a, b), isTrue);
  });

  test('a missing image fails and is not kept', () async {
    const missing = AssetPath('assets/images/nope.png');
    await expectLater(source.loadImage(missing), throwsA(anything));
    await write(missing, await png(3, 1));
    expect((await source.loadImage(missing)).width, 3);
  });

  test('a changed file is reported and reloads fresh', () async {
    await source.loadImage(hero);
    final changed = source.changes.first;
    await write(hero, await png(2, 2));
    events.add(FileSystemModifyEvent('$root/$hero', false, true));
    expect(await changed, {hero});
    expect((await source.loadImage(hero)).width, 2);
  });

  test('changes to files never read are not reported', () async {
    await source.loadImage(hero);
    final reports = <Set<AssetPath>>[];
    final sub = source.changes.listen(reports.add);
    events
      ..add(FileSystemModifyEvent('$root/assets/images/other.png', false, true))
      ..add(FileSystemModifyEvent('$root/$hero', false, true));
    await pumpEventQueue();
    await sub.cancel();
    expect(reports, [
      {hero},
    ]);
  });

  test('a leased image is released only after its last lease goes', () async {
    final lease = await source.leaseImage(hero);
    final old = lease.image;
    source.invalidate({hero});
    expect(old.debugDisposed, isFalse, reason: 'still drawn');
    final fresh = await source.leaseImage(hero);
    expect(identical(fresh.image, old), isFalse);
    lease.release();
    expect(old.debugDisposed, isTrue, reason: 'nothing draws it any more');
    expect(fresh.image.debugDisposed, isFalse);
    fresh.release();
  });

  test('a stale image nobody leases is released at once', () async {
    final image = await source.loadImage(hero);
    source.invalidate({hero});
    expect(image.debugDisposed, isTrue);
  });

  group('AssetDependents', () {
    test('a change reaches only the dependents that read the file', () {
      final dependents = AssetDependents<String>()
        ..record('heroSprite', {hero})
        ..record('coinSprite', {coin})
        ..record('both', {hero, coin});
      expect(dependents.of({hero}), {'heroSprite', 'both'});
      expect(dependents.of({coin}), {'coinSprite', 'both'});
    });

    test('a re-record replaces the paths and forget drops them', () {
      final dependents = AssetDependents<String>()
        ..record('sprite', {hero})
        ..record('sprite', {coin});
      expect(dependents.of({hero}), isEmpty);
      expect(dependents.of({coin}), {'sprite'});
      dependents.forget('sprite');
      expect(dependents.of({coin}), isEmpty);
    });
  });
}
