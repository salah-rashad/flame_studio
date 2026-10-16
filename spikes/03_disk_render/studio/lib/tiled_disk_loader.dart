import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'disk_asset_source.dart';

/// How the spike loads a `.tmx` from disk.
enum TiledMode {
  /// flame_tiled's own entry point: `TiledComponent.load(name, prefix: <map
  /// folder>, bundle: disk, images: Images(prefix: <map folder>))`.
  stock,

  /// Parse the map ourselves, resolve every tileset/image path against the
  /// file that references it (as Tiled does), then hand the parsed map to
  /// `RenderableTiledMap.fromTiledMap` with root-relative image keys.
  resolved,
}

/// [mapPath] is relative to the project root, e.g. `assets/maps/level.tmx`.
Future<TiledComponent> loadTiledFromDisk(
  String mapPath, {
  required DiskAssetBundle bundle,
  required TrackingImages rootImages,
  required TiledMode mode,
  required List<TrackingImages> extraImages,
}) async {
  final mapDir = p.posix.dirname(mapPath);
  switch (mode) {
    case TiledMode.stock:
      // Tile image paths are resolved by flame_tiled relative to the map
      // folder, so the Images cache needs the map folder as its prefix.
      final images = TrackingImages(bundle: bundle, prefix: '$mapDir/');
      extraImages.add(images);
      return TiledComponent.load(
        p.posix.basename(mapPath),
        Vector2.all(16),
        prefix: '$mapDir/',
        bundle: bundle,
        images: images,
      );
    case TiledMode.resolved:
      final tmx = await bundle.loadString(mapPath);
      final map = await TiledMap.fromString(tmx, (source) async {
        final tsxPath = p.posix.normalize(p.posix.join(mapDir, source));
        return _DiskTsx(source, await bundle.loadString(tsxPath));
      });
      for (final tileset in map.tilesets) {
        // Tiled resolves a tileset's images against the .tsx it lives in, or
        // against the map for embedded tilesets.
        final base = tileset.source == null
            ? mapDir
            : p.posix.dirname(p.posix.join(mapDir, tileset.source!));
        tileset.image = _rebase(tileset.image, base);
        for (final tile in tileset.tiles) {
          tile.image = _rebase(tile.image, base);
        }
        // Without this, flame_tiled re-joins the image path with the tileset
        // folder whenever their segment counts differ (tile_atlas.dart).
        tileset.source = null;
      }
      void rebaseLayers(List<Layer> layers) {
        for (final layer in layers) {
          if (layer is ImageLayer) {
            layer.image = _rebase(layer.image, mapDir)!;
          } else if (layer is Group) {
            rebaseLayers(layer.layers);
          }
        }
      }

      rebaseLayers(map.layers);
      return TiledComponent(
        await RenderableTiledMap.fromTiledMap(
          map,
          Vector2.all(16),
          images: rootImages,
        ),
      );
  }
}

TiledImage? _rebase(TiledImage? image, String base) {
  final source = image?.source;
  if (image == null || source == null) return image;
  return TiledImage(
    source: p.posix.normalize(p.posix.join(base, source)),
    format: image.format,
    width: image.width,
    height: image.height,
    trans: image.trans,
  );
}

class _DiskTsx implements TsxProvider {
  _DiskTsx(this.filename, this._data);

  @override
  final String filename;
  final String _data;

  @override
  Parser getSource(String key) =>
      XmlParser(XmlDocument.parse(_data).rootElement);

  @override
  Parser? getCachedSource() => getSource(filename);
}
