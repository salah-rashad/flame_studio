import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'open_scene.dart';
import 'providers.dart';
import 'save_scene.dart';
import 'scene_tabs.dart';

/// The editor's keyboard shortcuts (spec 006, T016): ⌘N/⌘O/⌘S/⌘W over
/// the open tabs, ⌘Z/⇧⌘Z routed to the active scene's provider methods,
/// and panel cycling (F6/⇧F6) over the shell's panel `FocusScopeNode`s.
///
/// Wrap the window's content; every action goes through the same flows
/// the tabs and menus use — never around `DocumentSession`.
class PyroShortcuts extends StatelessWidget {
  /// Creates the shortcut layer.
  const PyroShortcuts({
    super.key,
    required this.command,
    required this.panels,
    required this.child,
    this.fileSystem = const LocalFileSystem(),
  });

  /// The open-scene command for the open project.
  final OpenSceneCommand command;

  /// The panels' focus nodes, in cycle order (Hierarchy, Viewport,
  /// Inspector); created by the shell with `PrPanelFocus.createNode`.
  final List<FocusScopeNode> panels;

  /// The window content the shortcuts apply over.
  final Widget child;

  /// The file system ⌘O discovers scenes on.
  final FileSystem fileSystem;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            _onContainer(
              context,
              (container, ctx) async =>
                  newScene(ctx, container, command: command),
            ),
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true): () =>
            _onContainer(context, _openScenePicker),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
            _onContainer(context, (container, ctx) async {
              final sceneId = _active(container);
              if (sceneId != null) {
                await saveScene(
                  ctx,
                  container,
                  sceneId: sceneId,
                  command: command,
                  fileSystem: fileSystem,
                );
              }
            }),
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true): () =>
            _onContainer(context, (container, ctx) async {
              final sceneId = _active(container);
              if (sceneId != null) {
                await confirmClose(
                  ctx,
                  container,
                  sceneId: sceneId,
                  command: command,
                );
              }
            }),
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () =>
            _onContainer(
              context,
              (container, _) async => _undoRedo(container, redo: false),
            ),
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          meta: true,
          shift: true,
        ): () => _onContainer(
          context,
          (container, _) async => _undoRedo(container, redo: true),
        ),
        const SingleActivator(LogicalKeyboardKey.f6): () =>
            _cyclePanel(forward: true),
        const SingleActivator(LogicalKeyboardKey.f6, shift: true): () =>
            _cyclePanel(forward: false),
      },
      child: child,
    );
  }

  String? _active(ProviderContainer container) =>
      container.read(openScenesProvider).active;

  void _undoRedo(ProviderContainer container, {required bool redo}) {
    final sceneId = _active(container);
    if (sceneId == null) return;
    final notifier = container.read(documentProvider(sceneId).notifier);
    redo ? notifier.redo() : notifier.undo();
  }

  void _cyclePanel({required bool forward}) {
    FocusScopeNode? focused;
    var index = -1;
    for (var i = 0; i < panels.length; i++) {
      if (panels[i].hasFocus) {
        focused = panels[i];
        index = i;
      }
    }
    if (focused == null) {
      if (panels.isNotEmpty) panels.first.requestFocus();
      return;
    }
    final next = (index + (forward ? 1 : -1)) % panels.length;
    panels[next].requestFocus();
  }

  Future<void> _onContainer(
    BuildContext context,
    Future<void> Function(ProviderContainer container, BuildContext ctx) action,
  ) {
    final container = ProviderScope.containerOf(context);
    return action(container, context);
  }

  /// ⌘O: the project's Scenes (T009) in a dialog, then the open flow
  /// with its prompts.
  Future<void> _openScenePicker(
    ProviderContainer container,
    BuildContext context,
  ) async {
    final project = container.read(projectProvider);
    if (project == null || !context.mounted) return;
    final folders = await discoverAssetFolders(
      project.root,
      fileSystem: fileSystem,
    );
    if (folders.scenes.isEmpty) {
      if (!context.mounted) return;
      await showFsDialog<void>(
        context,
        dialog: const PrDialog(
          title: 'No Scenes found',
          body:
              'No *.scene.json was found under the asset folders declared in '
              'the project\'s pubspec.yaml.',
          primary: PrDialogAction(label: 'OK'),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    var scene = folders.scenes.first;
    // The dropdown's latest value wins over the primary button's
    // snapshot, exactly like the new-scene dialog.
    // ignore: unused_local_variable
    final path = await showFsDialog<String>(
      context,
      dialog: PrDialog<String>(
        title: 'Open Scene',
        width: PrDialogWidth.form,
        content: PrDropdown<String>(
          value: scene,
          onChanged: (value) => scene = value,
          options: [
            for (final s in folders.scenes)
              PrDropdownOption(value: s, label: s),
          ],
        ),
        primary: PrDialogAction(label: 'Open', value: folders.scenes.first),
        secondary: const PrDialogAction(label: 'Cancel'),
      ),
    );
    if (path == null || !context.mounted) return;
    await openSceneWithPrompts(
      context,
      container,
      command: command,
      path: fileSystem.path.joinAll([project.root, ...scene.split('/')]),
    );
  }
}
