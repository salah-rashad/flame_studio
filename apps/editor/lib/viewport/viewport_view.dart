import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/app/providers.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'editor_game.dart';
import 'node_position.dart';
import 'providers.dart';

/// The Viewport panel: one [EditorGame] per open Scene, the active tab's
/// shown and the others paused but kept, so each keeps its camera and
/// components (FR-016, research §2).
class ViewportPane extends ConsumerWidget {
  /// Creates the panel.
  const ViewportPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenes = ref.watch(openScenesProvider);
    if (scenes.active == null ||
        ref.watch(diskAssetsProvider.select((assets) => assets == null))) {
      return const SizedBox.shrink();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final scene in scenes.scenes)
          // Hidden tabs keep their state; `Visibility` also mutes their
          // tickers and pauses their provider listeners.
          Visibility(
            key: ValueKey(scene.sceneId),
            visible: scene.sceneId == scenes.active,
            maintainState: true,
            child: SceneViewport(
              sceneId: scene.sceneId,
              visible: scene.sceneId == scenes.active,
            ),
          ),
      ],
    );
  }
}

/// One Scene's viewport.
class SceneViewport extends ConsumerStatefulWidget {
  /// Creates the viewport of [sceneId].
  const SceneViewport({
    super.key,
    required this.sceneId,
    required this.visible,
  });

  /// The Scene's provider key.
  final String sceneId;

  /// Whether its tab is the active one.
  final bool visible;

  @override
  ConsumerState<SceneViewport> createState() => _SceneViewportState();
}

class _SceneViewportState extends ConsumerState<SceneViewport> {
  late final EditorGame _game;
  late final PreviewBinding _binding;
  // Its own node: `GameWidget` autofocuses by default and would take the
  // keyboard from the panels (research §4).
  final FocusNode _focus = FocusNode(debugLabel: 'Viewport');

  String get _sceneId => widget.sceneId;

  @override
  void initState() {
    super.initState();
    _game = EditorGame(
      assets: ref.read(diskAssetsProvider)!,
      catalog: ref.read(typeCatalogProvider),
      camera: ref.read(editorCameraProvider(_sceneId)),
      onSelect: (id) =>
          ref.read(selectionProvider(_sceneId).notifier).select(id),
      onMove: _move,
      onCamera: (camera) =>
          ref.read(editorCameraProvider(_sceneId).notifier).set(camera),
    );
    _binding = PreviewBinding(_sceneId, _game.tree);
    _game.overlay.select(ref.read(selectionProvider(_sceneId)));
    // Hidden tabs neither tick nor draw (desktop has no lifecycle hook to
    // do it for us, research §4).
    if (!widget.visible) _game.pauseEngine();
  }

  void _move(NodeId id, Vec2 position, Object coalesceKey) {
    final label = switch (_game.tree.nodeOf(id)) {
      NamedNode(:final name?) => 'Move $name',
      _ => 'Move',
    };
    ref
        .read(documentProvider(_sceneId).notifier)
        .transact(
          label,
          (doc) => doc.replaceNode(withPosition(doc.node(id)!, position)),
          coalesceKey: coalesceKey,
        );
  }

  @override
  void didUpdateWidget(SceneViewport old) {
    super.didUpdateWidget(old);
    if (widget.visible == old.visible) return;
    if (widget.visible) {
      _game.resumeEngine();
      // The paused listener may have missed changes: re-seed from the
      // current document — after this frame, not while the tree builds.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(previewSyncProvider(_binding));
        _game.overlay.select(ref.read(selectionProvider(_sceneId)));
      });
    } else {
      _game.pauseEngine();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(previewSyncProvider(_binding))
      ..listen(
        selectionProvider(_sceneId),
        (_, id) => _game.overlay.select(id),
      );
    return GameWidget(game: _game, focusNode: _focus, autofocus: false);
  }
}
