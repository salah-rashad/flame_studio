import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

/// An [AssetSource] that serves text and images from maps, for tests.
///
/// Both maps can be changed between calls (Hot-swap tests change [texts]),
/// and every read is counted.
final class MemoryAssetSource implements AssetSource {
  /// Serves [texts] and [images] by asset path.
  MemoryAssetSource({Map<String, String>? texts, Map<String, Image>? images})
    : texts = texts ?? {},
      images = images ?? {};

  /// The text of each file, by asset path.
  final Map<String, String> texts;

  /// Each image, by asset path.
  final Map<String, Image> images;

  /// How often each path was read with [loadText].
  final Map<String, int> textReads = {};

  /// How often each path was read with [loadImage].
  final Map<String, int> imageReads = {};

  /// Set to hold [loadText] until the test completes it.
  Future<void>? textGate;

  @override
  Future<String> loadText(AssetPath path) async {
    textReads.update(path, (n) => n + 1, ifAbsent: () => 1);
    if (textGate case final gate?) await gate;
    return texts[path] ?? (throw _missing(path));
  }

  @override
  Future<Image> loadImage(AssetPath path) async {
    imageReads.update(path, (n) => n + 1, ifAbsent: () => 1);
    return images[path] ?? (throw _missing(path));
  }

  /// The error `rootBundle` throws for an asset it doesn't have.
  static FlutterError _missing(String path) =>
      FlutterError('Unable to load asset: "$path".');
}
