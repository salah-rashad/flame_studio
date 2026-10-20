import 'diagnostics.dart';
import 'fragment.dart';
import 'manifest_json.dart';

/// The Manifest's `manifestVersion`; it goes up only for a change an older
/// reader would misread (FR-015a).
const manifestVersion = 1;

/// The text of `lib/pyro.manifest.json` (contracts/manifest-v1.md): [types]
/// in the given order, [diagnostics] split into errors and warnings, in the
/// given order.
String emitManifest(List<TypeRecord> types, List<Diagnostic> diagnostics) =>
    canonicalJson({
      'errors': [
        for (final d in diagnostics)
          if (d.isError) d.toJson(),
      ],
      'manifestVersion': manifestVersion,
      'types': [for (final type in types) type.manifest],
      'warnings': [
        for (final d in diagnostics)
          if (!d.isError) d.toJson(),
      ],
    });
