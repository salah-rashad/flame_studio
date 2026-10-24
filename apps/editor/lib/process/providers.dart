/// The Riverpod layer over Play, the generator and the Console (spec 007).
///
/// A library of its own: `process.dart` stays free of Flutter so
/// `bin/play.dart` still runs with `dart run`; the editor window reaches
/// the process units only through these providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import 'process.dart';

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
