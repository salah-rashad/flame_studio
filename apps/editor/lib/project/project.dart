/// The open project: recent projects, SDK detection, Runtime compatibility,
/// asset-folder discovery and the Type catalog (spec 006, work items 1, 6).
library;

export 'asset_folders.dart'
    show AssetFolders, discoverAssetFolders, isDeclaredFolder;
export 'catalog/built_in.dart' show builtInTypes;
export 'catalog/manifest_parse.dart'
    show
        FieldDescriptor,
        ManifestAbsent,
        ManifestFailed,
        ManifestNewer,
        ManifestParsed,
        ManifestProblem,
        ManifestRead,
        ManifestStale,
        ManifestUnreadable,
        ManifestUpToDate,
        ManifestOrigin,
        TypeCatalog,
        TypeDescriptor,
        fieldTypesByName,
        maxManifestVersion,
        readManifest;
export 'catalog/parenting.dart'
    show
        AddParent,
        OfferedChild,
        ReparentAllowed,
        ReparentCheck,
        ReparentRefused,
        canReparent,
        childOffers,
        hitboxUnderRootReason;
export 'recent_projects.dart' show RecentProjects, RecentProjectsStore;
export 'runtime_compat.dart'
    show RuntimeCompatStatus, RuntimeCompatibility, checkRuntimeCompatibility;
export 'sdk.dart' show SdkInfo, SdkSource, detectSdk, flutterPathVersion;
