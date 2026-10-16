#!/usr/bin/env python3
"""Writes a tiny hand-made Flame project asset folder for spike #3.

Usage: python3 make_assets.py <out_dir> [--variant 1|2]

Variant 2 recolors every image and changes the map data, so the Studio stand-in
can be shown picking up edits. Pure stdlib (zlib PNG encoder), no third-party art.

Layout (paths are chosen to exercise relative-path resolution):

  assets/images/hero.png             32x32 sprite
  assets/images/coin.png             64x16, 4 frames of 16x16
  assets/images/props.png            32x16, used by a tileset embedded in level.tmx
  assets/tilesets/terrain.tsx        external tileset, image="terrain.png" (same folder)
  assets/tilesets/terrain.png        96x16: grass, dirt, stone, path, water x2 (animated)
  assets/maps/level.tmx              10x6, tsx "../tilesets/terrain.tsx",
                                     embedded tileset image "../images/props.png"
  assets/maps/edge.tmx               4x2, tsx "sets/edge.tsx"
  assets/maps/sets/edge.tsx          image="img/edge.png" (relative to the .tsx)
  assets/maps/sets/img/edge.png      32x16
"""
import os
import struct
import sys
import zlib


def png(width, height, pixels):
    """pixels: list of rows of (r, g, b, a)."""
    raw = b"".join(
        b"\x00" + b"".join(struct.pack("BBBB", *px) for px in row) for row in pixels
    )

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def canvas(w, h, fill=(0, 0, 0, 0)):
    return [[fill for _ in range(w)] for _ in range(h)]


def rect(px, x0, y0, w, h, color):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            px[y][x] = color


def hero(v):
    body = (60, 120, 230, 255) if v == 1 else (230, 70, 60, 255)
    px = canvas(32, 32)
    rect(px, 10, 2, 12, 10, (250, 210, 170, 255))  # head
    rect(px, 13, 6, 2, 2, (20, 20, 20, 255))  # eyes
    rect(px, 17, 6, 2, 2, (20, 20, 20, 255))
    rect(px, 8, 12, 16, 12, body)  # body
    rect(px, 4, 13, 4, 9, body)  # arms
    rect(px, 24, 13, 4, 9, body)
    rect(px, 10, 24, 5, 7, (60, 60, 70, 255))  # legs
    rect(px, 17, 24, 5, 7, (60, 60, 70, 255))
    if v == 2:
        rect(px, 8, 0, 16, 3, (250, 220, 40, 255))  # crown in v2
    return png(32, 32, px)


def coin(v):
    base = (240, 200, 40, 255) if v == 1 else (80, 220, 120, 255)
    edge = (170, 120, 20, 255) if v == 1 else (30, 120, 60, 255)
    px = canvas(64, 16)
    widths = [12, 8, 2, 8]  # spinning: full, narrow, edge-on, narrow
    for f, w in enumerate(widths):
        ox = f * 16 + (16 - w) // 2
        rect(px, ox, 2, w, 12, edge)
        if w > 2:
            rect(px, ox + 1, 3, w - 2, 10, base)
        # frame marker: f+1 dots along the bottom so frames are distinguishable
        for d in range(f + 1):
            px[15][f * 16 + 2 + d * 3] = (255, 255, 255, 255)
    return png(64, 16, px)


def tile_pattern(px, ox, a, b, step):
    for y in range(16):
        for x in range(16):
            px[y][ox + x] = a if (x // step + y // step) % 2 == 0 else b


def terrain(v):
    px = canvas(96, 16)
    green = ((70, 160, 60, 255), (60, 140, 50, 255)) if v == 1 else ((200, 200, 220, 255), (180, 180, 205, 255))
    tile_pattern(px, 0, *green, 4)  # 1 grass (snow in v2)
    tile_pattern(px, 16, (140, 95, 55, 255), (125, 85, 50, 255), 2)  # 2 dirt
    tile_pattern(px, 32, (130, 130, 135, 255), (100, 100, 105, 255), 8)  # 3 stone
    tile_pattern(px, 48, (200, 180, 120, 255), (190, 170, 110, 255), 16)  # 4 path
    tile_pattern(px, 64, (40, 90, 200, 255), (60, 120, 230, 255), 4)  # 5 water a
    tile_pattern(px, 80, (60, 120, 230, 255), (40, 90, 200, 255), 4)  # 6 water b
    return png(96, 16, px)


def props(v):
    px = canvas(32, 16)
    rect(px, 6, 10, 4, 6, (100, 60, 30, 255))  # tree trunk
    rect(px, 2, 1, 12, 10, (30, 110, 40, 255) if v == 1 else (220, 120, 40, 255))
    rect(px, 18, 6, 12, 9, (150, 90, 30, 255))  # chest
    rect(px, 18, 9, 12, 1, (60, 40, 10, 255))
    rect(px, 23, 9, 2, 3, (240, 210, 60, 255))
    return png(32, 16, px)


def edge(v):
    px = canvas(32, 16)
    a = (230, 40, 200, 255) if v == 1 else (40, 230, 230, 255)
    for y in range(16):
        for x in range(32):
            px[y][x] = a if (x + y) % 4 < 2 else (30, 30, 30, 255)
    return png(32, 16, px)


TERRAIN_TSX = """<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.10.2" name="terrain" tilewidth="16" tileheight="16" tilecount="6" columns="6">
 <image source="terrain.png" width="96" height="16"/>
 <tile id="4">
  <animation>
   <frame tileid="4" duration="400"/>
   <frame tileid="5" duration="400"/>
  </animation>
 </tile>
</tileset>
"""

EDGE_TSX = """<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.10.2" name="edge" tilewidth="16" tileheight="16" tilecount="2" columns="2">
 <image source="img/edge.png" width="32" height="16"/>
</tileset>
"""

# gids: 1 grass, 2 dirt, 3 stone, 4 path, 5 water (animated), 6 water b; 7 tree, 8 chest
LEVEL_V1 = [
    [1, 1, 1, 1, 4, 4, 1, 1, 5, 5],
    [1, 1, 1, 1, 4, 1, 1, 1, 5, 5],
    [1, 2, 2, 1, 4, 1, 1, 1, 1, 5],
    [1, 2, 2, 1, 4, 4, 4, 4, 1, 1],
    [3, 3, 3, 3, 3, 3, 3, 4, 1, 1],
    [3, 3, 3, 3, 3, 3, 3, 4, 1, 1],
]
PROPS_V1 = [
    [0, 7, 0, 0, 0, 0, 7, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 7, 8, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 7],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
]


def csv(rows):
    return ",\n".join(",".join(str(g) for g in row) for row in rows)


def level_tmx(v):
    ground = [row[:] for row in LEVEL_V1]
    props_layer = [row[:] for row in PROPS_V1]
    if v == 2:
        # v2: a stone wall across the middle and the chest moved
        ground[2] = [3] * 10
        props_layer[2] = [0] * 10
        props_layer[5][0] = 8
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal" renderorder="right-down" width="10" height="6" tilewidth="16" tileheight="16" infinite="0" nextlayerid="3" nextobjectid="1">
 <tileset firstgid="1" source="../tilesets/terrain.tsx"/>
 <tileset firstgid="7" name="props" tilewidth="16" tileheight="16" tilecount="2" columns="2">
  <image source="../images/props.png" width="32" height="16"/>
 </tileset>
 <layer id="1" name="ground" width="10" height="6">
  <data encoding="csv">
{csv(ground)}
</data>
 </layer>
 <layer id="2" name="props" width="10" height="6">
  <data encoding="csv">
{csv(props_layer)}
</data>
 </layer>
</map>
"""


EDGE_TMX = """<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal" renderorder="right-down" width="4" height="2" tilewidth="16" tileheight="16" infinite="0" nextlayerid="2" nextobjectid="1">
 <tileset firstgid="1" source="sets/edge.tsx"/>
 <layer id="1" name="edge" width="4" height="2">
  <data encoding="csv">
1,2,1,2,
2,1,2,1
</data>
 </layer>
</map>
"""


def write(root, rel, data):
    path = os.path.join(root, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    mode = "wb" if isinstance(data, bytes) else "w"
    with open(path, mode) as f:
        f.write(data)


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    out = args[0]
    v = int(args[args.index("--variant") + 1]) if "--variant" in args else 1
    files = {
        "assets/images/hero.png": hero(v),
        "assets/images/coin.png": coin(v),
        "assets/images/props.png": props(v),
        "assets/tilesets/terrain.tsx": TERRAIN_TSX,
        "assets/tilesets/terrain.png": terrain(v),
        "assets/maps/level.tmx": level_tmx(v),
        "assets/maps/edge.tmx": EDGE_TMX,
        "assets/maps/sets/edge.tsx": EDGE_TSX,
        "assets/maps/sets/img/edge.png": edge(v),
    }
    for rel, data in files.items():
        write(out, rel, data)
    print(f"wrote {len(files)} files (variant {v}) to {out}")


if __name__ == "__main__":
    main()
