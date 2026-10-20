import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../assets/asset_source.dart';
import '../scene/values.dart';
import 'built_scene.dart';

/// Whether any of [texts] (the Scene file and the animation files a build
/// read) reads differently through [source] now (research R11).
///
/// A read that fails counts as a change, so the rebuild reports the error.
Future<bool> contentChanged(
  AssetSource source,
  Map<AssetPath, String> texts,
) async {
  for (final MapEntry(key: path, value: text) in texts.entries) {
    try {
      if (await source.loadText(path) != text) return true;
    } on Object {
      // The rebuild reads the file again and reports why it failed.
      return true;
    }
  }
  return false;
}

/// Watches the components of the Nodes a Hot-swap removed, and warns the
/// first time game code still uses one (*Q71*, research R12): when its
/// transform changes, or when it is added to a tree again.
///
/// Debug only. Components of the current Scene version carry no listener.
final class StaleWatch {
  /// Watches each of [removed], removed from the Scene at [scene].
  StaleWatch(this.scene, Iterable<NodeEntry> removed) {
    for (final entry in removed) {
      final watcher = _Watcher(this, entry);
      _watchers.add(watcher);
      // Removal is only queued until the next tick; until then the
      // component is still mounted and `mounted` is already complete.
      entry.component.removed.then((_) => watcher.start()).ignore();
    }
  }

  /// The Scene's asset path, for the warning.
  final AssetPath scene;

  final List<_Watcher> _watchers = [];
  bool _closed = false;

  /// How many removed Nodes are still watched.
  @visibleForTesting
  int get watching => _watchers.where((w) => w.active).length;

  /// Stops watching every Node.
  void close() {
    _closed = true;
    for (final watcher in _watchers) {
      watcher.stop();
    }
    _watchers.clear();
  }

  void _fire(_Watcher watcher) {
    watcher.stop();
    final entry = watcher.entry;
    debugPrint(
      '══ Pyro: $scene was Hot-swapped, but game code still uses Node '
      '${entry.label} from before ══\n'
      'That component was removed from the game. Re-run lookups in '
      'onReloaded (PyroScene.load) to use the new one.',
    );
  }
}

final class _Watcher {
  _Watcher(this.watch, this.entry);

  final StaleWatch watch;
  final NodeEntry entry;
  bool active = false;
  bool _stopped = false;

  void start() {
    if (_stopped || watch._closed) return;
    active = true;
    final component = entry.component;
    if (component is PositionComponent) {
      component.transform.addListener(_onUse);
    }
    component.mounted.then((_) {
      if (active) _onUse();
    }).ignore();
  }

  void _onUse() {
    if (active) watch._fire(this);
  }

  void stop() {
    _stopped = true;
    if (!active) return;
    active = false;
    final component = entry.component;
    if (component is PositionComponent) {
      component.transform.removeListener(_onUse);
    }
  }
}
