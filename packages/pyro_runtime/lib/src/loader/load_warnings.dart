import 'package:flutter/foundation.dart';

import '../scene/values.dart';
import 'built_scene.dart';

/// Warns, in debug builds, about what `UnknownType.skip` left out of the
/// Scene at [scene] (FR-016): one warning listing every item.
void warnAboutSkipped(AssetPath scene, List<SkippedItem> items) {
  if (!kDebugMode || items.isEmpty) return;
  debugPrint(
    '══ Pyro left ${items.length} unknown item(s) out of $scene ══\n'
    '${[for (final item in items) '- ${_node(item.nodeId, item.nodeName)}: ${item.what}'].join('\n')}\n'
    'Their classes are missing from the Registry (onUnknownType: '
    'UnknownType.skip). Restore them, or remove them from the Scene in Pyro.',
  );
}

/// Warns, in debug builds, about Overrides in the Scene at [scene] for
/// fields the Registry doesn't list (FR-012). The values stay in the file.
void warnAboutUnusedOverrides(AssetPath scene, List<UnusedOverride> items) {
  if (!kDebugMode || items.isEmpty) return;
  debugPrint(
    '══ Pyro ignored ${items.length} Override(s) in $scene for fields no '
    'code has ══\n'
    '${[for (final item in items) '- ${_node(item.nodeId, item.nodeName)}: ${item.typeId}.${item.field}'].join('\n')}\n'
    'Was a field renamed or removed? Pyro lists these under "Unused '
    'values", where they can be removed.',
  );
}

String _node(NodeId id, String? name) =>
    name == null ? 'Node ($id)' : 'Node "$name" ($id)';
