import 'dart:convert';

import 'package:build/build.dart';
import 'package:glob/glob.dart';

import 'diagnostics.dart';
import 'fragment.dart';
import 'manifest_emitter.dart';
import 'registry_emitter.dart';

/// The `$lib$` step: merges every scan fragment, applies the rules that need
/// the whole package, and writes `lib/pyro.manifest.json` and
/// `lib/pyro.g.dart` (research R2, R8).
///
/// Both files are written before any error is logged, so the Manifest holds
/// the errors even though the build fails (FR-020).
class PyroAggregateBuilder implements Builder {
  /// Creates the aggregate step.
  const PyroAggregateBuilder();

  @override
  Map<String, List<String>> get buildExtensions => const {
    r'$lib$': ['pyro.g.dart', 'pyro.manifest.json'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final package = buildStep.inputId.package;
    final ids = await buildStep.findAssets(Glob('lib/**.pyro.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final records = <TypeRecord>[];
    final holders = <EditableHolder>[];
    final diagnostics = <Diagnostic>[];
    for (final id in ids) {
      final json = jsonDecode(await buildStep.readAsString(id));
      final fragment = ScanFragment.fromJson(json as Map<String, Object?>);
      records.addAll(fragment.types);
      holders.addAll(fragment.holders);
      diagnostics.addAll(fragment.diagnostics);
    }

    final valid = _dropCollisions(records, diagnostics)
      ..sort((a, b) => a.typeId.compareTo(b.typeId));
    diagnostics.addAll(_unusedHolders(records, holders));
    if (!await buildStep.canRead(
      AssetId('pyro_runtime', 'lib/pyro_runtime.dart'),
    )) {
      diagnostics.add(
        const Diagnostic(
          code: DiagnosticCode.missingRuntime,
          message:
              "This package uses pyro_generator but doesn't depend on "
              "pyro_runtime, so the generated Registry can't compile. Add "
              'pyro_runtime to dependencies in pubspec.yaml.',
          file: 'pubspec.yaml',
          line: 1,
        ),
      );
    }
    diagnostics.sort();

    await buildStep.writeAsString(
      AssetId(package, 'lib/pyro.manifest.json'),
      emitManifest(valid, diagnostics),
    );
    await buildStep.writeAsString(
      AssetId(package, 'lib/pyro.g.dart'),
      emitRegistry([
        for (final r in valid) (typeId: r.typeId, entry: r.registry!),
      ]),
    );

    for (final diagnostic in diagnostics) {
      if (diagnostic.isError) {
        log.severe(diagnostic.toLogLine());
      } else {
        log.warning(diagnostic.toLogLine());
      }
    }
  }
}

/// The valid records whose Type ID no other record shares. Every record of a
/// shared Type ID is dropped, erroneous ones counted too, and one
/// `duplicateTypeId` error names them all (FR-009, research R8).
List<TypeRecord> _dropCollisions(
  List<TypeRecord> records,
  List<Diagnostic> diagnostics,
) {
  final byId = <String, List<TypeRecord>>{};
  for (final record in records) {
    (byId[record.typeId] ??= []).add(record);
  }
  final valid = <TypeRecord>[];
  for (final MapEntry(key: id, value: group) in byId.entries) {
    if (group.length == 1) {
      if (group.single.isValid) valid.add(group.single);
      continue;
    }
    group.sort(
      (a, b) => a.file == b.file
          ? a.line.compareTo(b.line)
          : a.file.compareTo(b.file),
    );
    final first = group.first;
    final names = [
      for (final r in group) '${r.className} (${r.file}:${r.line})',
    ];
    diagnostics.add(
      Diagnostic(
        code: DiagnosticCode.duplicateTypeId,
        message:
            'Type ID "$id" is used by ${names.join(' and ')}, so a Scene '
            "can't tell them apart; none of them is in the Registry. Give "
            'all but one an explicit id: in its annotation.',
        file: first.file,
        line: first.line,
        typeId: id,
        className: first.className,
        related: [
          for (final r in group)
            SourcePlace(file: r.file, line: r.line, className: r.className),
        ],
      ),
    );
  }
  return valid;
}

/// An `unusedEditable` warning for every holder that is no annotated class's
/// superclass or mixin (FR-014a).
Iterable<Diagnostic> _unusedHolders(
  List<TypeRecord> records,
  List<EditableHolder> holders,
) {
  final used = {for (final r in records) ...r.linearization};
  return [
    for (final holder in holders)
      if (!used.contains(holder.key))
        Diagnostic(
          code: DiagnosticCode.unusedEditable,
          message:
              '@Editable on ${holder.className}.${holder.field} has no '
              'effect: ${holder.className} has no @PyroBehavior or '
              '@PyroComponent annotation, and no annotated class extends it '
              'or mixes it in. Annotate it, or remove @Editable.',
          file: holder.file,
          line: holder.line,
          className: holder.className,
          field: holder.field,
        ),
  ];
}
