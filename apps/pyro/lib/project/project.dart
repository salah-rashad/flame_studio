/// The open project: recent projects, SDK detection, Runtime compatibility,
/// asset-folder discovery and the Type catalog (spec 006, work items 1, 6).
library;

export 'asset_folders.dart'
    show AssetFolders, discoverAssetFolders, isDeclaredFolder;
export 'recent_projects.dart' show RecentProjects, RecentProjectsStore;
export 'runtime_compat.dart'
    show RuntimeCompatStatus, RuntimeCompatibility, checkRuntimeCompatibility;
export 'sdk.dart' show SdkInfo, SdkSource, detectSdk;
