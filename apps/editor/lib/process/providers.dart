/// The Riverpod layer over Play, the generator and the Console (spec 007).
///
/// A library of its own: `process.dart` stays free of Flutter so
/// `bin/play.dart` still runs with `dart run`; the editor window reaches
/// the process units only through these providers.
library;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../project/project.dart';
import 'process.dart';

/// The file system Play reads the project through; tests inject a memory
/// one.
final playFileSystemProvider = Provider<FileSystem>(
  (ref) => const LocalFileSystem(),
);

/// Starts Play sessions; the app's is `PlayClient.start` with the open
/// project's `flutter`. Tests inject a fake.
final playStarterProvider = Provider<PlayStarter>((ref) {
  final sdk = ref.watch(projectProvider.select((project) => project?.sdk));
  final client = PlayClient(
    flutter: flutterExecutable(sdk ?? SdkInfo.none),
    fileSystem: ref.watch(playFileSystemProvider),
  );
  return client.start;
});

/// The open project's Play: one `PlayController` per project, disposed
/// (which stops the game) when the project closes; null with no project.
final playControllerProvider = Provider<PlayController?>((ref) {
  final project = ref.watch(projectProvider);
  if (project == null) return null;
  final fs = ref.watch(playFileSystemProvider);
  final controller = PlayController(
    projectPath: project.root,
    console: ref.watch(consoleBufferProvider),
    start: ref.watch(playStarterProvider),
    block: PlayBlock.of(
      // A project that failed to open never reaches the editor window,
      // which shows its error instead.
      projectError: null,
      hasSdk: project.sdk.source != SdkSource.none,
      runtimeProblem: runtimeProblem(project.compatibility),
      hasMacosFolder: fs
          .directory(fs.path.join(project.root, 'macos'))
          .existsSync(),
    ),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// The open project's Play phase, for the toolbar; stopped with no
/// project.
final playPhaseProvider = StreamProvider<PlayPhase>((ref) {
  final controller = ref.watch(playControllerProvider);
  if (controller == null) return Stream.value(PlayPhase.stopped);
  return controller.phases;
});

/// The Runtime compatibility check's message when it blocks Play, in the
/// status bar's words; null when the Runtime is compatible.
String? runtimeProblem(RuntimeCompatibility compatibility) =>
    switch (compatibility.status) {
      RuntimeCompatStatus.ok => null,
      RuntimeCompatStatus.tooOld =>
        'pyro_runtime ${compatibility.foundVersion} is too old for this Pyro; '
            'update pyro_runtime in the project.',
      RuntimeCompatStatus.tooNew =>
        'pyro_runtime ${compatibility.foundVersion} needs a newer Pyro; '
            'update Pyro.',
      RuntimeCompatStatus.unknown =>
        'pyro_runtime was not found in pubspec.lock; add it to the project '
            'and run `flutter pub get`.',
    };

/// The open project's Console: a new, empty buffer per project root,
/// disposed when the project closes or another one opens.
final consoleBufferProvider = Provider<ConsoleBuffer>((ref) {
  ref.watch(projectProvider.select((project) => project?.root));
  final buffer = ConsoleBuffer();
  ref.onDispose(buffer.dispose);
  return buffer;
});

/// The Console's sources shown; all of them by default, never none.
final consoleSourceFilterProvider =
    NotifierProvider<ConsoleSourceFilter, Set<ConsoleSource>>(
      ConsoleSourceFilter.new,
    );

/// [consoleSourceFilterProvider]'s notifier.
class ConsoleSourceFilter extends Notifier<Set<ConsoleSource>> {
  @override
  Set<ConsoleSource> build() => ConsoleSource.values.toSet();

  /// Shows only [source]'s lines.
  void showOnly(ConsoleSource source) => state = {source};

  /// Shows every source.
  void showAll() => state = ConsoleSource.values.toSet();
}
