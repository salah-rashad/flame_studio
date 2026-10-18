import 'package:flutter/foundation.dart';

import '../scene/tree_repair.dart';

/// Warns, in debug builds, that the Scene at [sceneKey] was repaired while
/// loading (FR-024a).
///
/// A game always loads a repaired Scene rather than stop. In debug builds
/// this prints one warning listing every repair and advising the developer
/// to save the Scene in Pyro; in release builds it does nothing and is
/// tree-shaken. `PyroScene.load` calls it after reading each Scene.
void warnAboutRepairs(String sceneKey, RepairReport repairs) {
  if (!kDebugMode || repairs.isEmpty) return;
  debugPrint(
    '══ Pyro repaired the Node tree of $sceneKey while loading it ══\n'
    '${repairs.describe()}\n'
    'Open this Scene in Pyro and save it to keep the repair.',
  );
}
