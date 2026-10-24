import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:yaml/yaml.dart';

part 'asset_folders.freezed.dart';

/// The project's declared asset folders and the Scene files under them
/// (FR-009, §10).
@freezed
sealed class AssetFolders with _$AssetFolders {
  /// Creates the discovery result.
  const factory AssetFolders({
    /// The `flutter: assets:` folder entries, project-relative with `/`
    /// separators, as written in the pubspec.
    required IList<String> declared,

    /// Every `*.scene.json` under the declared folders, project-relative,
    /// sorted.
    required IList<String> scenes,
  }) = _AssetFolders;

  /// No pubspec, or one without asset folders.
  static const empty = AssetFolders(
    declared: IList.empty(),
    scenes: IList.empty(),
  );
}

/// Whether [folder] (project-relative, `/`-separated) is declared in the
/// project's `flutter: assets:` — the new-scene dialog's warning (FR-008).
bool isDeclaredFolder(AssetFolders folders, String folder) =>
    folders.declared.contains(folder);

/// Parses the project at [projectRoot]'s `pubspec.yaml` for its declared
/// asset folders and lists the `*.scene.json` files under them (*Q53*).
///
/// A missing or unreadable pubspec yields [AssetFolders.empty]; a declared
/// folder that doesn't exist on disk is kept in `declared` and simply
/// contributes no scenes.
Future<AssetFolders> discoverAssetFolders(
  String projectRoot, {
  FileSystem fileSystem = const LocalFileSystem(),
}) async {
  final pubspec = fileSystem.file(
    fileSystem.path.join(projectRoot, 'pubspec.yaml'),
  );
  if (!pubspec.existsSync()) return AssetFolders.empty;
  final Map<Object?, Object?>? yaml;
  try {
    yaml = loadYaml(pubspec.readAsStringSync()) as Map?;
  } on YamlException {
    return AssetFolders.empty;
  }
  final flutter = yaml?['flutter'];
  final assets = flutter is Map ? flutter['assets'] : null;
  final declared = IList<String>([
    if (assets is List)
      for (final entry in assets)
        if (entry is String) _normalize(entry),
  ]);
  final scenes = <String>[];
  for (final folder in declared) {
    final dir = fileSystem.directory(
      fileSystem.path.joinAll([projectRoot, ...folder.split('/')]),
    );
    if (!dir.existsSync()) continue;
    _collectScenes(fileSystem, projectRoot, dir, scenes);
  }
  scenes.sort();
  return AssetFolders(declared: declared, scenes: IList(scenes));
}

String _normalize(String entry) {
  final trimmed = entry.endsWith('/')
      ? entry.substring(0, entry.length - 1)
      : entry;
  return trimmed.replaceAll('\\', '/');
}

void _collectScenes(
  FileSystem fs,
  String projectRoot,
  Directory dir,
  List<String> into,
) {
  for (final entity in dir.listSync()) {
    if (entity is Directory) {
      _collectScenes(fs, projectRoot, entity, into);
    } else if (entity is File && entity.path.endsWith('.scene.json')) {
      final relative = fs.path
          .split(fs.path.relative(entity.path, from: projectRoot))
          .join('/');
      into.add(relative);
    }
  }
}

/// The image extensions an image-path Field offers.
const Set<String> imageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
};

/// The image files under the project's declared asset folders, as
/// project-relative `/`-separated paths in name order (*Q31*). Read from
/// disk on every call, so a file added meanwhile shows up without a
/// restart.
Future<IList<String>> discoverImages(
  String projectRoot, {
  FileSystem fileSystem = const LocalFileSystem(),
}) async {
  final folders = await discoverAssetFolders(
    projectRoot,
    fileSystem: fileSystem,
  );
  final images = <String>{};
  for (final folder in folders.declared) {
    final dir = fileSystem.directory(
      fileSystem.path.joinAll([projectRoot, ...folder.split('/')]),
    );
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final extension = fileSystem.path
          .extension(entity.path)
          .toLowerCase()
          .replaceFirst('.', '');
      if (!imageExtensions.contains(extension)) continue;
      images.add(
        fileSystem.path
            .split(fileSystem.path.relative(entity.path, from: projectRoot))
            .join('/'),
      );
    }
  }
  return IList(images.toList()..sort());
}
