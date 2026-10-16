# Issue filed as flame-engine/flame#4117 (2026-10-16)

**Title:** flame_tiled: tileset image in a subfolder of an external `.tsx` resolves to the wrong path

**Body:**

### What happens

`TiledComponent.load` loads a tileset's image from the wrong folder when the external tileset and
its image paths have the same number of segments.

Map `assets/tiles/edge.tmx`:

```xml
<tileset firstgid="1" source="sets/edge.tsx"/>
```

Tileset `assets/tiles/sets/edge.tsx`:

```xml
<image source="img/edge.png" width="32" height="16"/>
```

Tiled resolves the image relative to the `.tsx`: `assets/tiles/sets/img/edge.png`.
flame_tiled 3.1.2 loads `img/edge.png` relative to the map folder instead
(`assets/tiles/img/edge.png`), so loading fails with `Unable to load asset`.

### Why

`TiledAtlas.fromTiledMap` (`lib/src/tile_atlas.dart`) only prepends the tileset's folder when the
paths' segment counts differ:

```dart
if (tilesetParts.length != imageParts.length) {
  tileImageSource = [...tilesetParts.sublist(0, tilesetParts.length - 1), ...imageParts].join('/');
}
```

`sets/edge.tsx` and `img/edge.png` both have 2 segments, so no join happens. `../tilesets/a.tsx` +
`a.png` (3 vs 1) works, which is probably why this hasn't come up.

### Expected

The image path is always resolved against the folder of the file that declares it (the `.tsx`
for external tilesets, the map for embedded ones), then normalized, the way Tiled does it.

### Versions

flame 1.38.2, flame_tiled 3.1.2, tiled 0.11.1, Flutter 3.44.2, macOS. Possibly relevant to
#4015 (new `imagesDirectory` resolution) and #4073 (tiled 0.12 loader).

A minimal reproduction (generated assets + app) is available if useful.
