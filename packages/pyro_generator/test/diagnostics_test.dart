import 'package:pyro_generator/src/diagnostics.dart';
import 'package:test/test.dart';

Diagnostic _d(
  DiagnosticCode code, {
  String file = 'lib/a.dart',
  int line = 1,
  String? typeId,
  String? field,
}) => Diagnostic(
  code: code,
  message: 'm',
  file: file,
  line: line,
  typeId: typeId,
  field: field,
);

void main() {
  test('every code has a kind: 23 errors and 2 warnings', () {
    final kinds = [for (final code in DiagnosticCode.values) code.kind];
    expect(kinds.where((k) => k == DiagnosticKind.error), hasLength(23));
    expect(kinds.where((k) => k == DiagnosticKind.warning), hasLength(2));
    expect(DiagnosticCode.defaultOutOfRange.kind, DiagnosticKind.warning);
    expect(DiagnosticCode.unusedEditable.kind, DiagnosticKind.warning);
  });

  test('sorts by file, line, code, Type ID and field', () {
    final sorted = [
      _d(DiagnosticCode.fieldFinal, file: 'lib/b.dart'),
      _d(DiagnosticCode.fieldStatic, line: 2),
      _d(DiagnosticCode.fieldStatic, typeId: 'B'),
      _d(DiagnosticCode.fieldStatic, typeId: 'A', field: 'y'),
      _d(DiagnosticCode.fieldStatic, typeId: 'A', field: 'x'),
      _d(DiagnosticCode.badConstructor),
    ]..sort();
    expect(
      [
        for (final d in sorted)
          '${d.file}:${d.line} ${d.code.name} ${d.typeId} ${d.field}',
      ],
      [
        'lib/a.dart:1 badConstructor null null',
        'lib/a.dart:1 fieldStatic A x',
        'lib/a.dart:1 fieldStatic A y',
        'lib/a.dart:1 fieldStatic B null',
        'lib/a.dart:2 fieldStatic null null',
        'lib/b.dart:1 fieldFinal null null',
      ],
    );
  });

  test('toJson omits absent keys and round-trips through fromJson', () {
    final d = _d(DiagnosticCode.fieldFinal, typeId: 'Patrol', field: 'speed');
    expect(d.toJson().keys, [
      'code',
      'field',
      'file',
      'line',
      'message',
      'typeId',
    ]);
    final back = Diagnostic.fromJson(d.toJson());
    expect(back.toJson(), d.toJson());
  });
}
