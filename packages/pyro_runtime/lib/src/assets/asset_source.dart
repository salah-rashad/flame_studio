import 'dart:ui' show Image;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../scene/values.dart';

/// Where a Scene load reads its files from: the Scene, its animation files
/// and its images, each by project-relative path such as
/// `assets/images/goblin.png` (*Q31, Q79*).
///
/// Games use [AssetSource.bundle]; Pyro's viewport reads the project folder
/// on disk through its own source, so one Scene loads from the same paths
/// in both.
abstract interface class AssetSource {
  /// Reads [bundle] ([rootBundle] by default), with its own image cache and
  /// no path prefix.
  factory AssetSource.bundle([AssetBundle? bundle]) = BundleAssetSource;

  /// The text of the file at [path], read fresh rather than from a cache, so
  /// a Hot-swap sees the file as it is now.
  Future<String> loadText(AssetPath path);

  /// The decoded image at [path]. Repeated calls may return the same
  /// [Image]; the source owns its images and disposes them.
  Future<Image> loadImage(AssetPath path);
}

/// The [AssetSource] over an [AssetBundle]: `AssetSource.bundle`.
///
/// Nothing goes through Flame's global `Flame.images`, `Flame.assets` or
/// `Flame.bundle`, so a game's own image cache and prefixes are untouched.
/// Images are decoded once and kept for the source's lifetime; a failed
/// load isn't kept, so the next load (a Hot-swap after the file is fixed)
/// reads the bundle again. Flame's `Images` can't forget a failed load
/// without raising a second, unhandled error (spike #3 finding 3), so the
/// cache is this class's own.
final class BundleAssetSource implements AssetSource {
  /// Reads [bundle], or [rootBundle] when it is null.
  BundleAssetSource([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<AssetPath, Future<Image>> _images = {};

  /// The bundle this source reads.
  @visibleForTesting
  AssetBundle get bundle => _bundle;

  @override
  Future<String> loadText(AssetPath path) =>
      _bundle.loadString(path, cache: false);

  @override
  Future<Image> loadImage(AssetPath path) => _images[path] ??= _decode(path);

  Future<Image> _decode(AssetPath path) async {
    try {
      final data = await _bundle.load(path);
      return await decodeImageFromList(Uint8List.sublistView(data));
    } catch (_) {
      // Not kept: the next load reads the bundle again.
      // ignore() only adds a listener; callers still get the error.
      _images.remove(path)?.ignore();
      rethrow;
    }
  }
}
