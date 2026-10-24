/// The viewport's wiring (spec 006, T029): the reconciler listener, the
/// per-scene camera, and the project's disk asset source.
library;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/app/providers.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/process/process.dart';
import 'package:pyro/project/project.dart';

import 'disk_assets.dart';
import 'editor_game.dart';
import 'preview_tree.dart';
import 'reconciler.dart';

/// The file system the viewport reads project files through; tests inject
/// a memory one.
final assetFileSystemProvider = Provider<FileSystem>(
  (ref) => const LocalFileSystem(),
);

/// The project-folder watcher behind image reloads; tests inject a stream
/// they control.
final assetWatchProvider = Provider<DirectoryWatcher>(
  (ref) => watchRecursively,
);

/// The open project's files (FR-021): one source — one image cache, one
/// watcher — shared by every open Scene; null while no project is open.
final diskAssetsProvider = Provider<DiskAssetSource?>((ref) {
  final root = ref.watch(projectProvider.select((project) => project?.root));
  if (root == null) return null;
  final source = DiskAssetSource(
    fileSystem: ref.watch(assetFileSystemProvider),
    root: root,
    watch: ref.watch(assetWatchProvider),
  );
  ref.onDispose(source.dispose);
  return source;
});

/// Each open Scene's camera (*Q25*): editor state outside the document,
/// kept per session and never written anywhere (spec Assumptions).
final editorCameraProvider =
    NotifierProvider.family<EditorCameraNotifier, EditorCamera, String>(
      EditorCameraNotifier.new,
    );

/// [editorCameraProvider]'s notifier.
class EditorCameraNotifier extends Notifier<EditorCamera> {
  /// Creates the notifier for [sceneId].
  EditorCameraNotifier(this.sceneId);

  /// The family argument.
  final String sceneId;

  @override
  EditorCamera build() => const EditorCamera();

  /// Moves the camera to [camera].
  void set(EditorCamera camera) => state = camera;
}

/// One viewport's link between a Scene and the world showing it. Compared
/// by identity: each viewport has its own.
final class PreviewBinding {
  /// Links [sceneId]'s document to [world].
  PreviewBinding(this.sceneId, this.world);

  /// The Scene's provider key.
  final String sceneId;

  /// Where its ops go.
  final PreviewWorld world;
}

/// The reconciler's only caller (`contracts/reconciler.md`): while a
/// viewport watches it, every document change becomes ops on the world —
/// seeded from the current document on first listen, cleared on dispose.
/// Invalidating it forces a full reconcile (a tab shown again after its
/// paused listener missed changes, research §2). Catalog changes and
/// changed image files flow to the same world.
final previewSyncProvider = Provider.autoDispose.family<void, PreviewBinding>((
  ref,
  binding,
) {
  final world = binding.world;
  SceneDocument? shown;
  ref.listen(
    documentProvider(binding.sceneId).select((view) => view.document),
    (_, next) {
      world.apply(reconcile(shown, next), next);
      shown = next;
    },
    fireImmediately: true,
  );
  ref.listen(
    typeCatalogProvider,
    (_, catalog) => world.catalogChanged(catalog),
  );
  final changes = ref
      .read(diskAssetsProvider)
      ?.changes
      .listen(world.assetsChanged);
  ref.onDispose(() {
    changes?.cancel().ignore();
    world.clear();
  });
});
