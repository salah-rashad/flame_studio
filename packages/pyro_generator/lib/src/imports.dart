import 'package:analyzer/dart/element/element.dart';

/// The URI the Registry imports [type] from, or null when none is
/// available (research R10).
///
/// The package's own types are imported from their declaring library. Any
/// other type is imported through a library that one of [searchIn] (in
/// order) already imports and that exports it, skipping another package's
/// `src/` libraries, so the Registry never needs an implementation import
/// and names types the way the developer's code does.
String? importFor(
  InterfaceElement type,
  List<LibraryElement> searchIn,
  String rootPackage,
) {
  final declaring = type.library.uri;
  if (_packageOf(declaring) == rootPackage) return declaring.toString();
  final name = type.name;
  if (name == null) return null;
  for (final library in searchIn) {
    for (final fragment in library.fragments) {
      for (final import in fragment.libraryImports) {
        final imported = import.importedLibrary;
        if (imported == null) continue;
        if (imported.exportNamespace.get2(name) != type) continue;
        if (_isOtherPackagesSrc(imported.uri, rootPackage)) continue;
        return imported.uri.toString();
      }
    }
  }
  return null;
}

String? _packageOf(Uri uri) =>
    uri.scheme == 'package' ? uri.pathSegments.first : null;

bool _isOtherPackagesSrc(Uri uri, String rootPackage) {
  final package = _packageOf(uri);
  return package != null &&
      package != rootPackage &&
      uri.pathSegments.length > 1 &&
      uri.pathSegments[1] == 'src';
}
