import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Image;

import 'package:flame/cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Zone key under which a slot build collects the absolute paths it reads.
const depsZoneKey = #studioAssetDeps;

void _recordDep(String absolutePath) {
  final deps = Zone.current[depsZoneKey];
  if (deps is Set<String>) deps.add(absolutePath);
}

/// An [AssetBundle] that serves keys from a folder on disk instead of the
/// app's bundle. Keys are paths relative to [root] (`..` allowed, normalized);
/// absolute keys are used as-is. No caching: every load reads the file, so a
/// changed file is picked up as soon as the layer above (Flame's `Images`)
/// lets go of its copy.
class DiskAssetBundle extends AssetBundle {
  DiskAssetBundle(String root) : root = p.normalize(p.absolute(root));

  final String root;

  /// FLAME_SPIKE_SLOW_MS: delay every read, to widen the window between a
  /// cache eviction and the swap (see the `shared` cache mode).
  static final slowReadMs =
      int.tryParse(Platform.environment['FLAME_SPIKE_SLOW_MS'] ?? '') ?? 0;

  /// Number of bytes/strings actually read from disk, for the status line.
  int reads = 0;

  String resolve(String key) =>
      p.normalize(p.isAbsolute(key) ? key : p.join(root, key));

  @override
  Future<ByteData> load(String key) async {
    final path = resolve(key);
    _recordDep(path);
    final file = File(path);
    if (!file.existsSync()) {
      // Same exception type rootBundle throws, so callers handle both alike.
      throw FlutterError('Unable to load asset: "$key" (no file at $path)');
    }
    reads++;
    if (slowReadMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: slowReadMs));
    }
    final bytes = await file.readAsBytes();
    return ByteData.sublistView(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final data = await load(key);
    return utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async => parser(await loadString(key));

  @override
  void evict(String key) {}

  @override
  void clear() {}
}

/// Flame's [Images] cache with dependency tracking: every `load` records the
/// absolute path it stands for, even when the image is served from the cache
/// (the bundle only sees the first, uncached read).
class TrackingImages extends Images {
  TrackingImages({required DiskAssetBundle bundle, super.prefix = ''})
    : _disk = bundle,
      super(bundle: bundle);

  final DiskAssetBundle _disk;

  String pathOf(String key) => _disk.resolve('$prefix$key');

  @override
  Future<Image> load(String fileName, {String? key, String? package}) {
    _recordDep(pathOf(fileName));
    return super.load(fileName, key: key, package: package);
  }

  /// Keys whose file is [absolutePath] (a file may be cached under several
  /// keys, e.g. `../images/a.png` and `assets/images/a.png`).
  List<String> keysFor(String absolutePath) =>
      keys.where((k) => pathOf(k) == absolutePath).toList();
}
