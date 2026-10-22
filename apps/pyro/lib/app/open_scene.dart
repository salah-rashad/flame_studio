import 'dart:async';
import 'dart:isolate';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../document/document.dart';
import 'providers.dart';

/// The open-scene command (FR-009, spec 006, T011): recovery check →
/// open/restore → register the session and open the tab.
///
/// The UI layers (the Open menu, scene tabs) drive this through providers;
/// the command itself never touches a widget.
final class OpenSceneCommand {
  /// Creates the command for the project at [projectRoot], keeping
  /// recovery copies under [recoveryFolder] (the app-support folder, never
  /// inside the project).
  OpenSceneCommand({
    required this.projectRoot,
    required String recoveryFolder,
    FileSystem fileSystem = const LocalFileSystem(),
    Offload offload = Isolate.run,
  }) : services = SessionServices(
         files: SceneFiles(fileSystem: fileSystem, offload: offload),
         recovery: RecoveryStore(
           folder: recoveryFolder,
           fileSystem: fileSystem,
           offload: offload,
         ),
         projectRoot: projectRoot,
       );

  /// The open project's root folder, absolute.
  final String projectRoot;

  /// The sessions' services, built from the project root.
  final SessionServices services;

  /// The recovery copy for the Scene at [path], if any (FR-009): the
  /// caller offers *Restore* on `RecoveryAvailable` before opening.
  Future<RecoveryCheck> checkRecovery(String path) =>
      services.recovery.find(
        projectRoot: projectRoot,
        scenePath: path,
      );

  /// Opens the Scene at [path], or restores the recovery copy [restore]
  /// instead when given (dirty, no saved snapshot, FR-028).
  ///
  /// Throws `SceneOpenFailed` (with `UnsupportedSchemaVersion` naming the
  /// required version, *Q49*, as its cause for a newer file).
  Future<DocumentSession> open(String path, {RecoveryInfo? restore}) =>
      restore == null
          ? DocumentSession.open(path, services: services)
          : DocumentSession.restore(restore, services: services);

  /// A new, untitled Scene: one root Node, clean (FR-008).
  DocumentSession create() => DocumentSession.create(services: services);

  /// Registers [session] as [sceneId] and opens its tab. Re-opening a
  /// scene focuses its existing tab (spec Assumptions).
  ///
  /// Takes the app's [ProviderContainer] (owned by `PyroApp`) rather than a
  /// `Ref`: both the widget layer and tests reach providers through it.
  void register(
    ProviderContainer container, {
    required String sceneId,
    required DocumentSession session,
    required String displayName,
    String? path,
  }) {
    container
        .read(sessionRegistryProvider.notifier)
        .register(sceneId, session);
    container.read(openScenesProvider.notifier).open(
          OpenScene(
            sceneId: sceneId,
            path: path,
            displayName: displayName,
          ),
        );
  }
}
