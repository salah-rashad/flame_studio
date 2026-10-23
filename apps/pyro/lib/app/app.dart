/// The editor window: shell, scene tabs, dialogs, shortcuts and the
/// provider layout (spec 006, work item 1).
library;

export 'open_scene.dart' show OpenSceneCommand, openSceneWithPrompts;
export 'providers.dart'
    show
        DocumentNotifier,
        DocumentView,
        OpenScene,
        OpenScenesNotifier,
        OpenScenesState,
        ProjectNotifier,
        ProjectState,
        documentProvider,
        nodeProvider,
        openScenesProvider,
        projectProvider,
        selectionProvider,
        sessionRegistryProvider;
export 'save_scene.dart' show reloadFromDisk, saveScene;
export 'scene_tabs.dart' show SceneTabs, closeScene, confirmClose, newScene;
export 'shell.dart' show PyroEditorWindow, discardScene;
export 'shortcuts.dart' show PyroShortcuts;
