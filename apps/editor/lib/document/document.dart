/// Pyro's Document model: one open Scene's state, history, saving and crash
/// recovery (spec 002).
///
/// Callers change a Scene only through [DocumentSession.transact]; the
/// values it publishes are immutable.
library;

export 'src/atomic_write.dart' show writeAtomically;
export 'src/document_session.dart' show DocumentSession, SessionServices;
export 'src/errors.dart'
    show
        ChildrenChanged,
        DocumentEditError,
        DuplicateNodeId,
        IndexOutOfRange,
        MoveIntoOwnSubtree,
        NodeHasChildren,
        NodeNotFound,
        RecoveryWriteFailed,
        RootNotAllowed,
        RuntimeTooOld,
        RuntimeVersionUnknown,
        SaveFailed,
        SavePathRequired,
        SaveRefused,
        SaveTargetExists,
        SceneChangedOnDisk,
        SceneOpenFailed,
        TransactionFailed;
export 'src/history.dart' show DocumentHistory, HistoryEntry;
export 'src/node_ids.dart' show NodeIdSource, uuidNodeIds;
export 'src/offload.dart' show Offload;
export 'src/open_document.dart'
    show OpenDocument, OpenedFrom, SaveResult, createDocument;
export 'src/recovery_store.dart'
    show
        NoRecovery,
        RecoveryAvailable,
        RecoveryCheck,
        RecoveryInfo,
        RecoveryStore,
        RecoveryUnreadable;
export 'src/scene_document.dart' show SceneDocument;
export 'src/scene_files.dart' show SceneFiles;
