/// The open project: recent projects, SDK detection, Runtime compatibility,
/// asset-folder discovery and the Type catalog (spec 006, work items 1, 6).
library;

export 'asset_folders.dart'
    show AssetFolders, discoverAssetFolders, isDeclaredFolder;
export 'catalog/built_in.dart' show builtInTypes;
export 'catalog/manifest_parse.dart'
    show
        FieldDescriptor,
        ManifestFailed,
        ManifestNewer,
        ManifestParsed,
        ManifestProblem,
        ManifestRead,
        ManifestUnreadable,
        TypeDescriptor,
        fieldTypesByName,
        maxManifestVersion,
        readManifest;
export 'recent_projects.dart' show RecentProjects, RecentProjectsStore;
export 'runtime_compat.dart'
    show RuntimeCompatStatus, RuntimeCompatibility, checkRuntimeCompatibility;
export 'sdk.dart' show SdkInfo, SdkSource, detectSdk, flutterPathVersion;
