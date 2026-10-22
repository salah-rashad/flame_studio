import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pyro_ui/pyro_ui.dart';

import '../document/src/atomic_write.dart';

part 'recent_projects.freezed.dart';

/// Pyro's remembered projects (FR-003): the recent paths and the shell
/// sizes the user left for each one.
@freezed
sealed class RecentProjects with _$RecentProjects {
  /// Creates the value; [lastOpened] names the project of the current
  /// session.
  const factory RecentProjects({
    /// The recently opened project roots, most recent first.
    required IList<String> paths,

    /// The last opened project's root, when there was one.
    required String? lastOpened,

    /// The dock sizes per project path.
    required IMap<String, PrShellSizes> sizes,
  }) = _RecentProjects;

  /// Nothing remembered yet.
  static const RecentProjects empty = RecentProjects(
    paths: IList.empty(),
    lastOpened: null,
    sizes: IMap.empty(),
  );
}

/// The editor settings: [RecentProjects] as one JSON in Pyro's
/// application-support folder, written atomically and never inside a user
/// project (research §3).
final class RecentProjectsStore {
  /// Creates the store reading and writing [file] on [fileSystem].
  RecentProjectsStore(this.file, {this.fileSystem = const LocalFileSystem()});

  /// The settings file, `recent_projects.json` in Pyro's app-support
  /// folder.
  final File file;

  /// The file system [file] is on.
  final FileSystem fileSystem;

  /// Reads the settings; a missing or unreadable file starts empty
  /// (reported to the caller through [onError], never thrown).
  Future<RecentProjects> read([void Function(Object error)? onError]) async {
    if (!file.existsSync()) return RecentProjects.empty;
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map<String, Object?>) {
        throw const FormatException('the settings file is not an object');
      }
      final paths = json['paths'];
      final sizes = json['sizes'];
      return RecentProjects(
        paths: IList([
          if (paths is List)
            for (final path in paths)
              if (path is String) path,
        ]),
        lastOpened: json['lastOpened'] as String?,
        sizes: IMap({
          if (sizes is Map)
            for (final entry in sizes.entries)
              if (entry.value is Map)
                entry.key as String: _sizeFrom(entry.value as Map),
        }),
      );
    } on Exception catch (error) {
      onError?.call(error);
      return RecentProjects.empty;
    }
  }

  /// Writes [value] atomically. Throws the file-system error on failure.
  Future<void> write(RecentProjects value) => writeAtomically(
    fileSystem,
    file.path,
    utf8.encode(
      '${const JsonEncoder.withIndent('  ').convert(_toJson(value))}\n',
    ),
  );

  /// [value] with [projectRoot] opened: moved to the front of the list,
  /// remembered as last opened.
  static RecentProjects opened(RecentProjects value, String projectRoot) {
    final rest = value.paths.where((p) => p != projectRoot);
    return value.copyWith(
      paths: IList([projectRoot, ...rest]),
      lastOpened: projectRoot,
    );
  }

  static PrShellSizes _sizeFrom(Map<Object?, Object?> values) => PrShellSizes(
    left: values['left'] as double? ?? 260,
    right: values['right'] as double? ?? 320,
    bottom: values['bottom'] as double? ?? 220,
  );

  static Map<String, Object?> _toJson(RecentProjects value) => {
    'formatVersion': 1,
    'paths': value.paths.toList(),
    'lastOpened': value.lastOpened,
    'sizes': {
      for (final entry in value.sizes.entries)
        entry.key: {
          'left': entry.value.left,
          'right': entry.value.right,
          'bottom': entry.value.bottom,
        },
    },
  };
}
