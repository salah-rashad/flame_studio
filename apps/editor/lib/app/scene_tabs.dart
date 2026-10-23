import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'dialogs.dart';
import 'open_scene.dart';
import 'providers.dart';
import 'save_scene.dart';
import 'shell.dart';

/// The document tab strip (spec 006, T013, FR-006/FR-007/FR-008):
/// `PrTabs` in document style with the dirty dot per tab, the
/// close-confirmation flow on ×, and the window's empty state once the
/// last tab is closed — the project stays open (spec Edge Cases).
class SceneTabs extends ConsumerWidget {
  /// Creates the tab strip for the open project.
  const SceneTabs({super.key, required this.command});

  /// The open-scene command, for new scenes and closes.
  final OpenSceneCommand command;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenes = ref.watch(openScenesProvider);
    if (scenes.scenes.isEmpty) {
      return Center(
        child: PrEmptyState(
          icon: PrIcons.layers,
          title: 'No scene open',
          message: 'Open a Scene from the project, or start a new one.',
          action: PrButton(
            label: 'New scene',
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyN,
              meta: true,
            ),
            onPressed: () => newScene(
              context,
              ProviderScope.containerOf(context),
              command: command,
            ),
          ),
        ),
      );
    }
    final selected = scenes.active ?? scenes.scenes.first.sceneId;
    return PrTabs<String>(
      tabs: [
        for (final scene in scenes.scenes)
          PrTab(
            value: scene.sceneId,
            label: scene.displayName,
            icon: PrIcons.layers,
            dirty: ref.watch(
              documentProvider(scene.sceneId).select((v) => v.isDirty),
            ),
          ),
      ],
      selected: selected,
      onSelect: (sceneId) =>
          ref.read(openScenesProvider.notifier).focus(sceneId),
      onClose: (sceneId) => confirmClose(
        context,
        ProviderScope.containerOf(context),
        sceneId: sceneId,
        command: command,
      ),
      closeTooltip: 'Close',
    );
  }
}

/// Opens a new, untitled Scene: one root Node, clean (FR-008) — the ⌘N
/// path; its first save goes through the path dialog.
void newScene(
  BuildContext context,
  ProviderContainer container, {
  required OpenSceneCommand command,
}) {
  final scenes = container.read(openScenesProvider);
  var name = 'untitled';
  var n = 2;
  final taken = scenes.scenes.map((s) => s.displayName).toSet();
  while (taken.contains(name)) {
    name = 'untitled $n';
    n++;
  }
  final session = command.create();
  command.register(
    container,
    sceneId: name,
    session: session,
    displayName: name,
  );
}

/// The × on a tab (FR-007): a clean Scene closes; a dirty one gets the
/// unsaved-changes dialog — *Save* saves (then closes), *Discard* drops
/// the changes, *Cancel* keeps the Scene open. The provider is pinned
/// while the dialog is up so the session isn't auto-closed mid-question.
Future<void> confirmClose(
  BuildContext context,
  ProviderContainer container, {
  required String sceneId,
  required OpenSceneCommand command,
}) async {
  if (!container.read(documentProvider(sceneId)).isDirty) {
    await closeScene(container, sceneId);
    return;
  }
  // A live listener pins the autoDispose family for the dialog.
  final link = container.listen(documentProvider(sceneId), (_, _) {});
  try {
    if (!context.mounted) return;
    final answer = await showUnsavedChangesDialog(
      context,
      container
          .read(openScenesProvider)
          .scenes
          .firstWhere((s) => s.sceneId == sceneId)
          .displayName,
    );
    switch (answer) {
      case UnsavedChangesAnswer.cancel:
        return;
      case UnsavedChangesAnswer.save:
        if (!context.mounted) return;
        final session = container.read(sessionRegistryProvider)[sceneId];
        final saved = await saveScene(
          context,
          container,
          sceneId: sceneId,
          command: command,
        );
        if (saved) {
          // A first save renamed the tab to the saved path.
          await closeScene(container, session?.state.path ?? sceneId);
        }
      case UnsavedChangesAnswer.discard:
        await discardScene(container, sceneId);
    }
  } finally {
    link.close();
  }
}

/// Closes a clean session and its tab.
Future<void> closeScene(ProviderContainer container, String sceneId) async {
  final session = container.read(sessionRegistryProvider)[sceneId];
  if (session != null && !session.isClosed) {
    await session.close();
  }
  container.read(sessionRegistryProvider.notifier).forget(sceneId);
  container.read(openScenesProvider.notifier).close(sceneId);
}
