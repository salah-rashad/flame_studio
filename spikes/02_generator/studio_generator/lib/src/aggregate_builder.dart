import 'dart:convert';

import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';

/// `$lib$` aggregator: reads every `.studio.json` from the build cache and
/// writes the Registry and the Manifest into `lib/` (*Q68*).
class StudioAggregateBuilder implements Builder {
  @override
  final buildExtensions = const {
    r'$lib$': ['flame_studio.g.dart', 'flame_studio.manifest.json'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final fragments = await buildStep
        .findAssets(Glob('lib/**.studio.json'))
        .toList();
    fragments.sort((a, b) => a.path.compareTo(b.path));

    final types = <Map<String, Object?>>[];
    final errors = <String>[];
    for (final id in fragments) {
      final json =
          jsonDecode(await buildStep.readAsString(id)) as Map<String, Object?>;
      types.addAll((json['types'] as List).cast<Map<String, Object?>>());
      errors.addAll((json['errors'] as List).cast<String>());
    }

    // Type IDs must be unique across the package (Q45). Drop every class
    // sharing an ID, so the Registry never builds the wrong one.
    final byId = <String, List<Map<String, Object?>>>{};
    for (final t in types) {
      (byId[_id(t)] ??= []).add(t);
    }
    final unique = <Map<String, Object?>>[];
    for (final MapEntry(key: id, value: ts) in byId.entries) {
      if (ts.length == 1) {
        unique.add(ts.single);
        continue;
      }
      final sources = [
        for (final t in ts) (t['manifest'] as Map<String, Object?>)['source'],
      ];
      errors.add('Duplicate Type ID "$id": ${sources.join(' and ')}');
    }
    unique.sort((a, b) => _id(a).compareTo(_id(b)));

    final lib = buildStep.inputId.package;
    final manifest = {
      'manifestVersion': 1,
      'types': [for (final t in unique) t['manifest']],
      'errors': errors,
    };
    await buildStep.writeAsString(
      AssetId(lib, 'lib/flame_studio.manifest.json'),
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
    await buildStep.writeAsString(
      AssetId(lib, 'lib/flame_studio.g.dart'),
      _registry(unique),
    );

    if (errors.isNotEmpty) {
      log.severe('Flame Studio generator errors:\n  ${errors.join('\n  ')}');
    }
  }
}

String _id(Map<String, Object?> t) =>
    (t['manifest'] as Map<String, Object?>)['id'] as String;

String _registry(List<Map<String, Object?>> types) {
  final libs = <String>{};
  for (final t in types) {
    final r = t['registry'] as Map<String, Object?>;
    libs.add(r['library'] as String);
    for (final s in (r['setters'] as List).cast<Map<String, Object?>>()) {
      final uri = s['typeLibrary'] as String;
      if (uri != 'dart:core') libs.add(uri);
    }
  }
  final sorted = libs.toList()..sort();
  final prefix = {for (var i = 0; i < sorted.length; i++) sorted[i]: 'i$i'};

  final b = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Flame Studio Registry (spike #2).')
    ..writeln('// ignore_for_file: type=lint, implementation_imports')
    ..writeln();
  for (final uri in sorted) {
    b.writeln("import '$uri' as ${prefix[uri]};");
  }
  b
    ..writeln()
    ..writeln(
      'typedef StudioSetter = void Function(Object target, '
      'Object? value);',
    )
    ..writeln()
    ..writeln('class StudioType {')
    ..writeln('  const StudioType(this.id, this.create, this.setters);')
    ..writeln('  final String id;')
    ..writeln('  final Object Function() create;')
    ..writeln('  final Map<String, StudioSetter> setters;')
    ..writeln('}')
    ..writeln()
    ..writeln('final studioRegistry = <String, StudioType>{');
  for (final t in types) {
    final r = t['registry'] as Map<String, Object?>;
    final cls = '${prefix[r['library']]}.${r['className']}';
    b.writeln("'${_id(t)}': StudioType('${_id(t)}', $cls.new, {");
    for (final s in (r['setters'] as List).cast<Map<String, Object?>>()) {
      b.writeln(
        "'${s['name']}': (t, v) => (t as $cls).${s['name']} = "
        '${_convert(s, prefix)},',
      );
    }
    b.writeln('}),');
  }
  b.writeln('};');
  return DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  ).format(b.toString());
}

String _convert(Map<String, Object?> s, Map<String, String> prefix) {
  final nullable = s['nullable'] as bool;
  final q = nullable ? '?' : '';
  final uri = s['typeLibrary'] as String;
  final type = uri == 'dart:core'
      ? s['typeName'] as String
      : '${prefix[uri]}.${s['typeName']}';
  return switch (s['kind']) {
    'double' => '(v as num$q)$q.toDouble()',
    'int' => '(v as num$q)$q.toInt()',
    'enum' when nullable =>
      'v == null ? null : $type.values.byName(v as String)',
    'enum' => '$type.values.byName(v as String)',
    _ => 'v as $type$q',
  };
}
