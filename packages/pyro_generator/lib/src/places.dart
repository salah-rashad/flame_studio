import 'package:analyzer/dart/element/element.dart';

/// Where a declaration is, for the Manifest's `source` and diagnostics.
typedef Place = ({String file, int line});

/// The file and 1-based line of [fragment]'s name.
///
/// The file is the one holding the declaration, so a class in a `part` file
/// reports the part file (spec Edge Cases). See [packagePath].
Place placeOf(Fragment fragment, String rootPackage) {
  final library = fragment.libraryFragment!;
  final offset = fragment.nameOffset ?? fragment.offset;
  return (
    file: packagePath(library.source.uri, rootPackage),
    line: library.lineInfo.getLocation(offset).lineNumber,
  );
}

/// [uri] as a path relative to the root package (`lib/a/b.dart`) when it is
/// in the root package, and as the URI itself otherwise.
String packagePath(Uri uri, String rootPackage) {
  if (uri.scheme == 'package' && uri.pathSegments.first == rootPackage) {
    return ['lib', ...uri.pathSegments.skip(1)].join('/');
  }
  return uri.toString();
}

/// The key identifying [element] across libraries: `<library URI>#<name>`.
String classKey(InterfaceElement element) =>
    '${element.library.uri}#${element.name}';
