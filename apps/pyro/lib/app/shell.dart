import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'dialogs.dart';
import 'open_scene.dart';
import 'providers.dart';
import 'save_scene.dart';
import 'shortcuts.dart';

/// The editor window (spec 006, T012): the `PrEditorShell` layout with
/// the panel slots, the status bar and the title bar, dock sizes
/// persisted per project (T008), and the app-quit interception that
/// walks dirty tabs through the unsaved-changes dialog (FR-007).
///
/// The panel widgets arrive with their stories; until then the slots
/// show placeholders. The scene tabs (T013) mount on top of the centre.
class PyroEditorWindow extends ConsumerStatefulWidget {
  /// Creates the window for the open project.
  const PyroEditorWindow({
    super.key,
    required this.command,
    required this.settings,
    this.tabs,
    this.left,
    this.center,
    this.right,
  });

  /// The open-scene command for the open project.
  final OpenSceneCommand command;

  /// The editor-settings store the dock sizes persist through (T008).
  final RecentProjectsStore settings;

  /// The centre's tab strip (T013); null shows only the placeholder.
  final Widget? tabs;

  /// The left dock (Hierarchy); null shows the placeholder.
  final Widget? left;

  /// The centre (Viewport); null shows the placeholder.
  final Widget? center;

  /// The right dock (Inspector); null shows the placeholder.
  final Widget? right;

  @override
  ConsumerState<PyroEditorWindow> createState() => _PyroEditorWindowState();
}

class _PyroEditorWindowState extends ConsumerState<PyroEditorWindow> {
  PrShellSizes _sizes = PrShellSizes.standard;
  late final AppLifecycleListener _listener;

  /// The panels' focus scopes (T016): Hierarchy, Viewport, Inspector —
  /// the cycle order the shortcuts walk.
  final List<FocusScopeNode> panelNodes = [
    PrPanelFocus.createNode(debugLabel: 'hierarchy'),
    PrPanelFocus.createNode(debugLabel: 'viewport'),
    PrPanelFocus.createNode(debugLabel: 'inspector'),
  ];

  @override
  void initState() {
    super.initState();
    // App-quit interception (FR-007): every dirty tab is walked through
    // the unsaved-changes dialog before the app may exit. *Cancel* on any
    // tab denies the exit.
    _listener = AppLifecycleListener(
      onExitRequested: () => _exitWhenScenesClean(context),
    );
    unawaited(_loadSizes());
  }

  @override
  void dispose() {
    _listener.dispose();
    for (final node in panelNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSizes() async {
    final root = ref.read(projectProvider)?.root;
    if (root == null) return;
    await widget.settings.read().then((recent) {
      if (!mounted) return;
      setState(() => _sizes = recent.sizes[root] ?? PrShellSizes.standard);
    });
  }

  void _persistSizes(PrShellSizes sizes) {
    final root = ref.read(projectProvider)?.root;
    if (root == null) return;
    unawaited(
      widget.settings.read().then((recent) {
        return widget.settings.write(
          recent.copyWith(sizes: recent.sizes.add(root, sizes)),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    final scenes = ref.watch(openScenesProvider);
    String title = 'Pyro';
    if (project != null) {
      final name = project.root
          .split('/')
          .where((part) => part.isNotEmpty)
          .last;
      for (final scene in scenes.scenes) {
        if (scene.sceneId == scenes.active) {
          title = '$name — ${scene.displayName}';
        }
      }
      if (scenes.active == null) title = name;
    }

    Widget dock(int index, Widget? slot, String label) => PrPanelFocus(
      node: panelNodes[index],
      child: slot ?? _PanelPlaceholder(label: label),
    );

    return PyroShortcuts(
      command: widget.command,
      panels: panelNodes,
      child: PrEditorShell(
        titleBar: Text(
          title,
          style: PrText.small.copyWith(
            color: PrColors.of(context).textSecondary,
          ),
        ),
        toolbar: const SizedBox(height: PrSizes.toolbar),
        left: dock(0, widget.left, 'Hierarchy'),
        center: dock(
          1,
          widget.tabs != null
              ? Column(
                  children: [
                    widget.tabs!,
                    Expanded(
                      child:
                          widget.center ??
                          const _PanelPlaceholder(label: 'Viewport'),
                    ),
                  ],
                )
              : widget.center,
          'Viewport',
        ),
        right: dock(2, widget.right, 'Inspector'),
        bottom: null,
        statusBar: _StatusBar(project: project),
        sizes: _sizes,
        onSizesChanged: (sizes) => setState(() => _sizes = sizes),
        onSizesChangeEnd: _persistSizes,
      ),
    );
  }

  Future<AppExitResponse> _exitWhenScenesClean(BuildContext context) async {
    final container = ProviderScope.containerOf(context);
    for (final scene in container.read(openScenesProvider).scenes) {
      if (!container.read(documentProvider(scene.sceneId)).isDirty) continue;
      if (!context.mounted) return AppExitResponse.cancel;
      final answer = await showUnsavedChangesDialog(context, scene.displayName);
      switch (answer) {
        case UnsavedChangesAnswer.cancel:
          return AppExitResponse.cancel;
        case UnsavedChangesAnswer.save:
          if (!context.mounted) return AppExitResponse.cancel;
          final saved = await saveScene(
            context,
            container,
            sceneId: scene.sceneId,
            command: widget.command,
          );
          if (!saved) return AppExitResponse.cancel;
        case UnsavedChangesAnswer.discard:
          await discardScene(container, scene.sceneId);
      }
    }
    return AppExitResponse.exit;
  }
}

/// Closes [sceneId]'s tab discarding unsaved changes. The document
/// provider is pinned for the await so the session isn't auto-closed
/// mid-dialog (the shared half of the tabs' close flow, T013).
Future<void> discardScene(ProviderContainer container, String sceneId) async {
  // A live listener pins the autoDispose family for the await (the
  // KeepAliveLink of research §2, from outside the provider).
  final link = container.listen(documentProvider(sceneId), (_, _) {});
  try {
    final session = container.read(sessionRegistryProvider)[sceneId];
    if (session != null && !session.isClosed) {
      await session.discardAndClose();
    }
    container.read(sessionRegistryProvider.notifier).forget(sceneId);
    container.read(openScenesProvider.notifier).close(sceneId);
  } finally {
    link.close();
  }
}

/// The status bar (FR-003/FR-004): the detected SDK, the Runtime
/// compatibility result, and the Type catalog's status — a placeholder
/// until the catalog lands (US2, T022).
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.project});

  final ProjectState? project;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final sdk = project?.sdk;
    final compatibility = project?.compatibility;
    return Row(
      spacing: PrSpacing.s4,
      children: [
        _item(
          context,
          icon: PrIcons.terminal,
          text: sdk == null || sdk.version == null
              ? 'No Flutter SDK found'
              : 'Flutter ${sdk.version}',
        ),
        _item(
          context,
          icon: PrIcons.box,
          text: switch (compatibility?.status) {
            RuntimeCompatStatus.ok =>
              'pyro_runtime ${compatibility!.foundVersion}',
            RuntimeCompatStatus.tooOld =>
              'pyro_runtime ${compatibility!.foundVersion} — too old to read saves',
            RuntimeCompatStatus.tooNew =>
              'pyro_runtime ${compatibility!.foundVersion} — needs a newer Pyro',
            RuntimeCompatStatus.unknown || null => 'pyro_runtime: not found',
          },
        ),
        Text(
          'Types: catalog not loaded yet',
          style: PrText.small.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final c = PrColors.of(context);
    return Row(
      spacing: PrSpacing.s1,
      children: [
        Icon(icon, size: 12, color: c.textSecondary),
        Text(text, style: PrText.small.copyWith(color: c.textSecondary)),
      ],
    );
  }
}

/// A panel slot's stand-in until its story lands.
class _PanelPlaceholder extends StatelessWidget {
  const _PanelPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PrEmptyState(
        icon: PrIcons.box,
        title: label,
        message: 'This panel arrives with its story.',
        action: PrButton(label: 'Coming soon', onPressed: () {}),
      ),
    );
  }
}
