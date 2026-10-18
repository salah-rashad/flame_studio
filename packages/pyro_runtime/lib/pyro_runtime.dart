/// Loads Pyro scenes into a Flame game.
///
/// Re-exports `pyro_annotations`, so games depend on this package only.
/// The Scene format (`SceneCodec`, `Scene` and the Node kinds) is shared
/// with Pyro, so the editor and games always agree on it. The loader and
/// Hot-swap support (project plan §5, §6.2) land with v0.1 work item 8.
library;

export 'package:pyro_annotations/pyro_annotations.dart';

export 'src/loader/repair_warning.dart';
export 'src/scene/errors.dart';
export 'src/scene/node.dart';
export 'src/scene/overrides.dart';
export 'src/scene/scene.dart';
export 'src/scene/scene_codec.dart';
export 'src/scene/tree_repair.dart'
    show
        CycleBroken,
        DuplicateChild,
        MissingChild,
        MultipleParents,
        OrphanAttached,
        RepairReport,
        RootAsChild,
        SelfChild,
        TreeIssue;
export 'src/scene/values.dart';
