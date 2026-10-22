import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/project/project.dart';

import 'dialogs.dart';
import 'open_scene.dart';
import 'providers.dart';

/// Saves (or saves as) the open scene [sceneId] through the Document
/// model's atomic save, passing the compatibility check's `readsUpTo`
/// (FR-010, *Q49*, spec 006, T015). Every refusal from the ladder routes
/// to its dialog; the callers are the ⌘S shortcut, the tabs' close flow
/// and the unsaved-changes dialog.
///
/// Returns whether the Scene ended up saved. A first save renames the tab
/// to the saved path.
Future<bool> saveScene(
  BuildContext context,
  ProviderContainer container, {
  required String sceneId,
  required OpenSceneCommand command,
  FileSystem fileSystem = const LocalFileSystem(),
}) async {
  final view = container.read(documentProvider(sceneId));
  final compatibility =
      container.read(projectProvider)?.compatibility ??
      const RuntimeCompatibility(
        status: RuntimeCompatStatus.unknown,
        foundVersion: null,
        readsUpTo: null,
      );
  var saveAs = view.path;
  if (saveAs == null) {
    saveAs = await _askForPath(context, container, fileSystem);
    if (saveAs == null || !context.mounted) return false;
  }

  final saved = await _saveWithRefusals(
    context,
    container,
    sceneId: sceneId,
    command: command,
    runtimeReadsUpTo: compatibility.readsUpTo,
    saveAs: view.path == null ? saveAs : null,
    fileSystem: fileSystem,
  );
  if (!saved) return false;

  // A first save renamed the Scene: the tab and the registry move to the
  // saved path as the sceneId (one document per Scene file).
  if (view.path == null) {
    final session = container.read(sessionRegistryProvider)[sceneId];
    final newPath = container.read(documentProvider(sceneId)).path!;
    if (session != null) {
      container.read(sessionRegistryProvider.notifier).forget(sceneId);
      container
          .read(sessionRegistryProvider.notifier)
          .register(newPath, session);
    }
    final tab = container
        .read(openScenesProvider)
        .scenes
        .firstWhere((s) => s.sceneId == sceneId);
    container
        .read(openScenesProvider.notifier)
        .renamed(tab, tab.savedAs(newPath, _displayName(newPath)));
  }
  return true;
}

Future<bool> _saveWithRefusals(
  BuildContext context,
  ProviderContainer container, {
  required String sceneId,
  required OpenSceneCommand command,
  required int? runtimeReadsUpTo,
  String? saveAs,
  bool overwrite = false,
  FileSystem fileSystem = const LocalFileSystem(),
}) async {
  final session = container.read(documentProvider(sceneId).notifier).session;
  try {
    await session.save(
      runtimeReadsUpTo: runtimeReadsUpTo,
      saveAs: saveAs,
      overwrite: overwrite,
    );
    return true;
  } on SceneChangedOnDisk catch (reason) {
    if (!context.mounted) return false;
    final answer = await showSceneChangedOnDiskDialog(context, reason.path);
    if (!context.mounted) return false;
    switch (answer) {
      case SaveRefusedAnswer.overwrite:
        return _saveWithRefusals(
          context,
          container,
          sceneId: sceneId,
          command: command,
          runtimeReadsUpTo: runtimeReadsUpTo,
          saveAs: saveAs,
          overwrite: true,
          fileSystem: fileSystem,
        );
      case SaveRefusedAnswer.reload:
        await reloadFromDisk(container, sceneId: sceneId, command: command);
        return false;
      case SaveRefusedAnswer.cancel:
        return false;
    }
  } on SavePathRequired {
    if (!context.mounted) return false;
    final path = await _askForPath(context, container, fileSystem);
    if (path == null || !context.mounted) return false;
    return _saveWithRefusals(
      context,
      container,
      sceneId: sceneId,
      command: command,
      runtimeReadsUpTo: runtimeReadsUpTo,
      saveAs: path,
      fileSystem: fileSystem,
    );
  } on SaveRefused catch (reason) {
    if (context.mounted) await showSaveBlockedDialog(context, reason);
    return false;
  }
}

/// Asks where to save a new Scene (FR-008): the name/folder dialog over
/// the project's declared asset folders, warning when the target folder
/// isn't declared — never a pubspec edit. Returns the absolute path, or
/// null when cancelled.
Future<String?> _askForPath(
  BuildContext context,
  ProviderContainer container,
  FileSystem fileSystem,
) async {
  final project = container.read(projectProvider);
  if (project == null || !context.mounted) return null;
  const defaultFolder = 'assets/scenes/';
  final folders = await discoverAssetFolders(
    project.root,
    fileSystem: fileSystem,
  );
  final declared = folders.declared.toList();
  final offered = [
    if (!declared.contains(defaultFolder)) defaultFolder,
    ...declared,
  ];
  if (!context.mounted) return null;
  final result = await showNewSceneDialog(
    context,
    defaultName: 'untitled',
    folders: offered,
    defaultFolder: defaultFolder,
    folderDeclared: isDeclaredFolder(folders, defaultFolder),
  );
  if (result == null) return null;
  return fileSystem.path.joinAll([
    project.root,
    ...result.folder.split('/'),
    '${result.name}.scene.json',
  ]);
}

/// Reloads the scene from disk after a changed-on-disk refusal: the
/// current session is discarded and the file opened fresh (FR-010).
Future<void> reloadFromDisk(
  ProviderContainer container, {
  required String sceneId,
  required OpenSceneCommand command,
}) async {
  final session = container.read(sessionRegistryProvider)[sceneId];
  final path = container.read(documentProvider(sceneId)).path;
  if (session == null || path == null) return;
  await session.discardAndClose();
  container.read(sessionRegistryProvider.notifier).forget(sceneId);
  container.read(openScenesProvider.notifier).close(sceneId);
  final fresh = await command.open(path);
  command.register(
    container,
    sceneId: path,
    session: fresh,
    displayName: _displayName(path),
    path: path,
  );
}

/// "level1" from ".../level1.scene.json".
String _displayName(String path) {
  final base = path.split('/').last;
  return base.endsWith('.scene.json')
      ? base.substring(0, base.length - '.scene.json'.length)
      : base;
}
