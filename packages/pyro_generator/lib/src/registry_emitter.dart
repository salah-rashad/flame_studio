import 'package:dart_style/dart_style.dart';

import 'fragment.dart';

const _runtimeImport = 'package:pyro_runtime/pyro_runtime.dart';

const _coreTypes = {'int', 'double', 'bool', 'string'};

/// The text of `lib/pyro.g.dart` (contracts/registry-api.md): one
/// `RegistryType` per entry of [types], in the given order.
String emitRegistry(List<({String typeId, RegistryEntry entry})> types) {
  final uris = <String>{_runtimeImport};
  for (final (typeId: _, :entry) in types) {
    uris.add(entry.classImport);
    for (final field in entry.fields) {
      if (field.typeImport case final uri?) uris.add(uri);
    }
  }
  final sorted = uris.toList()..sort();
  final prefixes = {for (var i = 0; i < sorted.length; i++) sorted[i]: 'i$i'};
  final rt = prefixes[_runtimeImport]!;

  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln(
      "// pyro_generator: the Registry of this package's annotated types.",
    )
    ..writeln('// ignore_for_file: type=lint')
    ..writeln();
  for (final uri in sorted) {
    out.writeln("import '$uri' as ${prefixes[uri]};");
  }
  out
    ..writeln()
    ..writeln(
      '/// Every Behavior and Custom component in this package, for the '
      'Runtime.',
    );
  if (types.isEmpty) {
    out.writeln('final pyroRegistry = $rt.PyroRegistry(const []);');
  } else {
    out.writeln('final pyroRegistry = $rt.PyroRegistry([');
    for (final (:typeId, :entry) in types) {
      final cls = '${prefixes[entry.classImport]}.${entry.className}';
      out
        ..writeln('$rt.RegistryType(')
        ..writeln('id: const $rt.TypeId(${_dartString(typeId)}),')
        ..writeln('role: $rt.TypeRole.${entry.role},')
        ..writeln('create: $cls.new,')
        ..writeln('fields: {');
      for (final field in entry.fields) {
        final type = _coreTypes.contains(field.kind)
            ? field.typeName
            : '${prefixes[field.typeImport]}.${field.typeName}';
        final q = field.nullable ? '?' : '';
        out
          ..writeln('${_dartString(field.name)}: $rt.RegistryField(')
          ..writeln('name: ${_dartString(field.name)},')
          ..writeln('type: $rt.FieldType.${field.kind},')
          ..writeln('nullable: ${field.nullable},');
        if (field.kind == 'enumeration') out.writeln('values: $type.values,');
        out
          ..writeln(
            field.nullable
                ? 'accepts: (v) => v == null || v is $type,'
                : 'accepts: (v) => v is $type,',
          )
          ..writeln('set: (t, v) => (t as $cls).${field.name} = v as $type$q,')
          ..writeln('),');
      }
      out
        ..writeln('},')
        ..writeln('),');
    }
    out.writeln(']);');
  }
  return DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  ).format(out.toString());
}

String _dartString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n');
  return "'$escaped'";
}
