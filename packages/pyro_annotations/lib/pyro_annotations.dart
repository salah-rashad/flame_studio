/// Annotations that mark Flame components and behaviors for Pyro.
///
/// Pure Dart with no dependencies (Q44), so `pyro_generator` can read them on
/// the plain Dart VM. `pyro_runtime` re-exports this library, so games
/// usually import it through the Runtime.
library;

export 'src/annotations.dart';
export 'src/image_path.dart';
