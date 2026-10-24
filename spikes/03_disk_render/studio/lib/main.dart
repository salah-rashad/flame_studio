// Spike #3 stand-in for the Studio's viewport: renders a sprite, a frame
// animation and two Tiled maps from a project folder on disk (never from this
// app's asset bundle), and reloads whatever a changed file feeds.
//
// Environment (all optional; the folder can also be picked in the UI):
//   FLAME_SPIKE_PROJECT  project folder to open at startup
//   FLAME_SPIKE_SHOTS    folder to write a PNG of the window after each (re)load
//   FLAME_SPIKE_TILED    resolved (default) | stock   (see tiled_disk_loader.dart)
//   FLAME_SPIKE_CACHE    generation (default) | shared (see _Viewport._flush)
//   FLAME_SPIKE_SLOW_MS  delay every disk read by this many ms
//   FLAME_SPIKE_KEEP_ATLAS=1  skip TiledAtlas.clearCache() before map builds
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flame/components.dart' hide Timer;
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart' show TiledAtlas;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;

import 'disk_asset_source.dart';
import 'tiled_disk_loader.dart';

final _env = Platform.environment;
final tiledMode = TiledMode.values.byName(
  _env['FLAME_SPIKE_TILED'] ?? 'resolved',
);
final sharedCache = (_env['FLAME_SPIKE_CACHE'] ?? 'generation') == 'shared';
final shotsDir = _env['FLAME_SPIKE_SHOTS'];
final keepAtlasCache = _env['FLAME_SPIKE_KEEP_ATLAS'] == '1';

void log(String event, [Map<String, Object?> data = const {}]) {
  stdout.writeln(
    jsonEncode({
      'event': event,
      't': DateTime.now().millisecondsSinceEpoch,
      ...data,
    }),
  );
}

void main() {
  // print() from a directly launched macOS app doesn't reach stdout; errors
  // must, so log them like everything else.
  FlutterError.onError = (d) => log('flutter-error', {
    'error': d.exceptionAsString().split('\n').first,
    'library': d.library,
  });
  runApp(const SpikeApp());
}

class SpikeApp extends StatefulWidget {
  const SpikeApp({super.key});

  @override
  State<SpikeApp> createState() => _SpikeAppState();
}

class _SpikeAppState extends State<SpikeApp> {
  final _boundary = GlobalKey();
  final _pathField = TextEditingController(text: _env['FLAME_SPIKE_PROJECT']);
  _Viewport? _game;
  StreamSubscription<FileSystemEvent>? _watch;
  final _status = ValueNotifier<List<String>>(const []);
  int _shot = 0;

  @override
  void initState() {
    super.initState();
    if (_pathField.text.isNotEmpty) _open(_pathField.text);
  }

  Future<void> _browse() async {
    final dir = await getDirectoryPath(confirmButtonText: 'Open project');
    if (dir == null) return;
    _pathField.text = dir;
    await _open(dir);
  }

  Future<void> _open(String folder) async {
    await _watch?.cancel();
    // FSEvents reports real paths (/private/tmp, not /tmp), so resolve links
    // up front or dependency paths never match event paths.
    final root = Directory(folder).resolveSymbolicLinksSync();
    final bundle = DiskAssetBundle(root);
    final game = _Viewport(bundle, onChanged: _onViewportChanged);
    setState(() => _game = game);
    log('open', {'root': root, 'tiled': tiledMode.name, 'shared': sharedCache});
    _watch = Directory(root).watch(recursive: true).listen(game.onFileEvent);
  }

  void _onViewportChanged(String label) {
    _status.value = _game!.statusLines();
    if (shotsDir != null) _screenshot(label);
  }

  Future<void> _screenshot(String label) async {
    // Two frames: one for Flame to process the add/remove, one to paint.
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    final ro =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await ro.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final n = (++_shot).toString().padLeft(2, '0');
    final file = File(p.join(shotsDir!, '${n}_$label.png'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    log('screenshot', {'file': file.path});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: RepaintBoundary(
          key: _boundary,
          child: ColoredBox(
            color: const Color(0xFF1E1E24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pathField,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText:
                                'Project folder (not this app\'s bundle)',
                          ),
                          onSubmitted: _open,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _browse,
                        child: const Text('Browse…'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _game == null
                      ? const Center(child: Text('Pick a project folder'))
                      : ClipRect(child: GameWidget(game: _game!)),
                ),
                ValueListenableBuilder(
                  valueListenable: _status,
                  builder: (context, lines, _) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      [
                        'tiled=${tiledMode.name}  cache=${sharedCache ? 'shared' : 'generation'}',
                        ...lines,
                      ].join('\n'),
                      style: const TextStyle(fontFamily: 'Menlo', fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One thing on screen built from files: its component and the files it read.
class _Slot {
  _Slot(this.label, this.position, this.build);

  final String label;
  final Vector2 position;
  final Future<PositionComponent> Function(
    _Viewport game,
    List<TrackingImages> images,
  )
  build;

  PositionComponent? component;
  Set<String> deps = {};
  List<TrackingImages> images = [];
  String status = 'loading';
}

class _Viewport extends FlameGame {
  _Viewport(this.bundle, {required this.onChanged})
    : sharedImages = TrackingImages(bundle: bundle);

  final DiskAssetBundle bundle;
  final void Function(String label) onChanged;

  /// Project-wide cache, used for everything in `shared` mode.
  final TrackingImages sharedImages;

  late final List<_Slot> slots = [
    _Slot('sprite', Vector2(0, 8), (game, images) async {
      final img = await images.first.load('assets/images/hero.png');
      return SpriteComponent(sprite: Sprite(img));
    }),
    _Slot('animation', Vector2(44, 8), (game, images) async {
      final img = await images.first.load('assets/images/coin.png');
      return SpriteAnimationComponent(
        animation: SpriteAnimation.fromFrameData(
          img,
          SpriteAnimationData.sequenced(
            amount: 4,
            stepTime: 0.15,
            textureSize: Vector2.all(16),
          ),
        ),
        size: Vector2.all(32),
      );
    }),
    _Slot('edge.tmx', Vector2(88, 8), (game, images) {
      return loadTiledFromDisk(
        'assets/maps/edge.tmx',
        bundle: bundle,
        rootImages: images.first,
        mode: tiledMode,
        extraImages: images,
      );
    }),
    _Slot('level.tmx', Vector2(0, 56), (game, images) {
      return loadTiledFromDisk(
        'assets/maps/level.tmx',
        bundle: bundle,
        rootImages: images.first,
        mode: tiledMode,
        extraImages: images,
      );
    }),
  ];

  @override
  Color backgroundColor() => const Color(0xFF2B2B33);

  @override
  Future<void> onLoad() async {
    camera.viewfinder
      ..anchor = Anchor.topLeft
      ..position = Vector2(-6, -6)
      ..zoom = 2.5;
    for (final slot in slots) {
      world.add(
        TextComponent(
          text: slot.label,
          position: slot.position - Vector2(0, 7),
          textRenderer: TextPaint(
            style: const TextStyle(fontSize: 5, color: Color(0xFFB0B0C0)),
          ),
        ),
      );
    }
    final sw = Stopwatch()..start();
    await Future.wait(slots.map(_build));
    log('initial-load', {'ms': sw.elapsedMilliseconds, 'reads': bundle.reads});
    onChanged('initial');
  }

  /// (Re)builds a slot and swaps it in. The old component, and in
  /// `generation` mode the Images caches it used, are dropped only once the
  /// new one is ready, so nothing on screen ever draws a disposed image.
  Future<void> _build(_Slot slot) async {
    final images = sharedCache
        ? [sharedImages]
        : [TrackingImages(bundle: bundle)];
    final deps = <String>{};
    final old = slot.component;
    final oldImages = slot.images;
    try {
      // flame_tiled keeps a static, process-wide atlas cache keyed by image
      // source names; it would hand back the old atlas.
      if (!keepAtlasCache) TiledAtlas.clearCache();
      final c = await runZoned(
        () => slot.build(this, images),
        zoneValues: {depsZoneKey: deps},
      );
      c.position = slot.position;
      slot
        ..component = c
        ..images = images
        ..status = 'ok';
      old?.removeFromParent();
      world.add(c);
    } catch (e) {
      slot.status = 'ERROR ${e.toString().split('\n').first}';
      log('build-error', {'slot': slot.label, 'error': '$e'});
      final placeholder = RectangleComponent(
        position: slot.position,
        size: Vector2.all(16),
        paint: Paint()..color = const Color(0xFFE04040),
      );
      slot
        ..component = placeholder
        ..images = images;
      old?.removeFromParent();
      world.add(placeholder);
    }
    // Keep deps from the failed build too: the missing file is in there, so
    // re-creating it triggers a rebuild.
    slot.deps = deps;
    if (old != null && !sharedCache) {
      await old.removed;
      for (final i in oldImages) {
        i.clearCache();
      }
    }
  }

  final _pending = <String>{};
  final _firstEventAt = <String, int>{};
  Timer? _debounce;

  void onFileEvent(FileSystemEvent e) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final paths = [
      e.path,
      if (e is FileSystemMoveEvent && e.destination != null) e.destination!,
    ];
    for (final path in paths) {
      final n = p.normalize(path);
      _pending.add(n);
      _firstEventAt.putIfAbsent(n, () => now);
    }
    log('fs-event', {
      'type': e.runtimeType.toString(),
      'path': e.path,
      if (e is FileSystemMoveEvent) 'to': e.destination,
    });
    // Editors save in bursts (write, chmod, rename); coalesce them.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 30), _flush);
  }

  Future<void> _flush() async {
    final changed = Set.of(_pending);
    final firstAt = Map.of(_firstEventAt);
    _pending.clear();
    _firstEventAt.clear();
    final affected = slots.where((s) => s.deps.any(changed.contains)).toList();
    if (affected.isEmpty) {
      log('ignored', {'paths': changed.toList()});
      return;
    }
    if (sharedCache) {
      // Drop the changed files from every cache so the rebuild re-reads them.
      // Images.clear disposes the image while the old component may still
      // draw it until the swap: that's what this mode is here to show.
      for (final images in [sharedImages, ...slots.expand((s) => s.images)]) {
        for (final path in changed) {
          images.keysFor(path).forEach(images.clear);
        }
      }
      for (final s in affected) {
        final c = s.component;
        if (c is SpriteComponent) {
          log('evicted', {
            'slot': s.label,
            'oldImageDisposed': c.sprite!.image.debugDisposed,
          });
        }
      }
      onChanged('mid-swap');
    }
    final sw = Stopwatch()..start();
    await Future.wait(affected.map(_build));
    final built = sw.elapsedMilliseconds;
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    final now = DateTime.now().millisecondsSinceEpoch;
    final earliest = firstAt.values.reduce((a, b) => a < b ? a : b);
    log('reloaded', {
      'slots': [for (final s in affected) s.label],
      'changed': [for (final c in changed) p.relative(c, from: bundle.root)],
      'buildMs': built,
      'eventToFrameMs': now - earliest,
      'status': [for (final s in affected) s.status],
    });
    onChanged(affected.map((s) => s.label.replaceAll('.', '_')).join('+'));
  }

  List<String> statusLines() => [
    'root=${bundle.root}  disk reads=${bundle.reads}',
    for (final s in slots)
      '${s.label.padRight(10)} ${s.status.padRight(6)} deps: '
          '${s.deps.map((d) => p.relative(d, from: bundle.root)).join(', ')}',
  ];
}
