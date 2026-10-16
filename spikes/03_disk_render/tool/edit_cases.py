#!/usr/bin/env python3
"""Edits files in a project made by make_assets.py while the spike app watches it.

Usage: python3 edit_cases.py <project_dir> [case ...]   (default: all cases, in order)

Each case prints one JSON line with the wall-clock time (ms) its last write
returned, to compare with the app's `fs-event` / `reloaded` log lines.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_assets as m  # noqa: E402


def now_ms():
    return int(time.time() * 1000)


def in_place(root, rel, data):
    """Truncate + write the same inode, like most image editors' plain save."""
    mode = "wb" if isinstance(data, bytes) else "w"
    with open(os.path.join(root, rel), mode) as f:
        f.write(data)


def atomic(root, rel, data):
    """Write a temp file next to it, then rename over (Tiled, VS Code, many tools)."""
    path = os.path.join(root, rel)
    tmp = path + ".tmp~"
    mode = "wb" if isinstance(data, bytes) else "w"
    with open(tmp, mode) as f:
        f.write(data)
    os.replace(tmp, path)


def delete(root, rel, _):
    os.remove(os.path.join(root, rel))


CASES = {
    # name: (action, file, data)
    "sprite_inplace": (in_place, "assets/images/hero.png", lambda: m.hero(2)),
    "anim_atomic": (atomic, "assets/images/coin.png", lambda: m.coin(2)),
    "tmx_edit": (in_place, "assets/maps/level.tmx", lambda: m.level_tmx(2)),
    "tsx_image_atomic": (atomic, "assets/tilesets/terrain.png", lambda: m.terrain(2)),
    "edge_image": (in_place, "assets/maps/sets/img/edge.png", lambda: m.edge(2)),
    "unrelated_file": (in_place, "assets/notes.txt", lambda: "not an asset anyone uses\n"),
    "delete_props": (delete, "assets/images/props.png", lambda: None),
    "recreate_props": (in_place, "assets/images/props.png", lambda: m.props(2)),
}


def main():
    root = sys.argv[1]
    names = sys.argv[2:] or list(CASES)
    for name in names:
        action, rel, data = CASES[name]
        action(root, rel, data())
        print(json.dumps({"case": name, "file": rel, "written": now_ms()}), flush=True)
        time.sleep(1.5)


if __name__ == "__main__":
    main()
