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
/// model's atomic save, passing the compatibility check's version
/// (FR-010, *Q49*, spec 006, T015). Every refusal from the ladder routes
/// to its dialog; the caller is the ⌘S shortcut, the tabs' close flow and
/// the toolbar.
Future<bool> saveScene(
  BuildContext context,
  Ref ref, {
  required String sceneId,
  required OpenSceneCommand command,
  FileSystem fileSystem = const LocalFileSystem(),
}) async {
  final view = ref.read(documentProvider(sceneId));
  final compatibility =
      ref.read(projectProvider)?.compatibility ?? RuntimeCompatibility.unknown;
  final saveAs = view.path == null
      ? await _askForPath(context, ref, fileSystem)
      : null;
  if (!context.mounted) return false;
  if (saveAs == null && view.path == null) return false;

  return _saveWithRefusals(
    context,
    ref,
    sceneId: sceneId,
    command: command,
    runtimeReadsUpTo: compatibility.readsUpTo,
    saveAs: saveAs,
    fileSystem: fileSystem,
  );
}

Future<bool> _saveWithRefusals(
  BuildContext context,
  Ref ref, {
  required String sceneId,
  required OpenSceneCommand command,
  required int? runtimeReadsUpTo,
  String? saveAs,
  bool overwrite = false,
  FileSystem fileSystem = const LocalFileSystem(),
}) async {
  final notifier = ref.read(documentProvider(sceneId).notifier);
  try {
    await notifier.session.save(
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
          ref,
          sceneId: sceneId,
          command: command,
          runtimeReadsUpTo: runtimeReadsUpTo,
          saveAs: saveAs,
          overwrite: true,
          fileSystem: fileSystem,
        );
      case SaveRefusedAnswer.reload:
        await _reloadFromDisk(ref, sceneId: sceneId, command: command);
        return false;
      case SaveRefusedAnswer.cancel:
        return false;
    }
  } on SavePathRequired {
    final path = await _askForPath(context, ref, fileSystem);
    if (!context.mounted || path == null) return false; // ignore: use_build_context_synchronously -- guarded
    return _saveWithRefusals(
      context,
      ref,
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

Future<String?> _askForPath(
  BuildContext context,
  Ref ref,
  FileSystem fileSystem,
) async {
  final project = ref.read(projectProvider);
  if (project == null) return null;
  if (!context.mounted) return null;
  final result = await showNewSceneDialog(
    context,
    defaultName: 'untitled',
    folders: const ['assets/scenes/'],
    defaultFolder: 'assets/scenes/',
    folderDeclared: true,
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
Future<void> _reloadFromDisk(
  Ref ref, {
  required String sceneId,
  required OpenSceneCommand command,
}) async {
  final session = ref.read(sessionRegistryProvider)[sceneId];
  final path = ref.read(documentProvider(sceneId)).path;
  if (session == null || path == null) return;
  await session.discardAndClose();
  ref.read(sessionRegistryProvider.notifier).forget(sceneId);
  ref.read(openScenesProvider.notifier).close(sceneId);
  final fresh = await command.open(path);
  command.register(
    ref,
    sceneId: path,
    session: fresh,
    displayName: _displayName(path),
    path: path,
  );
}

/// "level1" from ".../level1.scene.json".
String displayName(String path) => _displayName(path);

String _displayName(String path) {
  final base = path.split('/').last;
  return base.endsWith('.scene.json')
      ? base.substring(0, base.length - '.scene.json'.length)
      : base;
}
