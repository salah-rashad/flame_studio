/// Whether a diagnostic fails the build.
enum DiagnosticKind {
  /// Fails the build; the class it names is left out of both outputs.
  error,

  /// Reported, but the build succeeds and every type stays in the outputs.
  warning,
}

/// Every diagnostic the Generator reports, with the code the Manifest writes
/// (contracts/manifest-v1.md).
enum DiagnosticCode {
  /// Two or more annotated classes share a Type ID (FR-009).
  duplicateTypeId(DiagnosticKind.error),

  /// A class has both `@PyroBehavior` and `@PyroComponent`.
  bothAnnotations(DiagnosticKind.error),

  /// An annotated class is private.
  privateClass(DiagnosticKind.error),

  /// An annotated class is abstract or sealed.
  abstractClass(DiagnosticKind.error),

  /// An annotated class has type parameters.
  genericClass(DiagnosticKind.error),

  /// An annotated class has no unnamed constructor callable with no
  /// arguments.
  badConstructor(DiagnosticKind.error),

  /// A `@PyroComponent` class doesn't extend `PositionComponent`.
  notPositionComponent(DiagnosticKind.error),

  /// A `@PyroBehavior` class doesn't extend `Behavior`.
  notBehavior(DiagnosticKind.error),

  /// An explicit `id:` is empty or contains whitespace.
  badTypeId(DiagnosticKind.error),

  /// A Behavior's parent type is a mixin or interface-only type.
  parentTypeNotClass(DiagnosticKind.error),

  /// The package doesn't depend on `pyro_runtime`.
  missingRuntime(DiagnosticKind.error),

  /// An `@Editable` field's type isn't a v1 Field type.
  unsupportedFieldType(DiagnosticKind.error),

  /// No import of the declaring library makes the field's type available.
  unreachableFieldType(DiagnosticKind.error),

  /// An `@Editable` field is private.
  fieldNotPublic(DiagnosticKind.error),

  /// An `@Editable` field is final or const.
  fieldFinal(DiagnosticKind.error),

  /// An `@Editable` field is static.
  fieldStatic(DiagnosticKind.error),

  /// A non-nullable `@Editable` field has no initializer.
  fieldNoDefault(DiagnosticKind.error),

  /// An entity reference, `Sprite` or `SpriteAnimation` field isn't nullable.
  fieldMustBeNullable(DiagnosticKind.error),

  /// `@Editable` is on a getter or a setter.
  editableOnAccessor(DiagnosticKind.error),

  /// `@Editable` is on an abstract or external field.
  editableNotConcrete(DiagnosticKind.error),

  /// `min` or `max` is given on a non-numeric field.
  rangeOnNonNumeric(DiagnosticKind.error),

  /// `min` is greater than `max`.
  minAboveMax(DiagnosticKind.error),

  /// An evaluated default lies outside `[min, max]`.
  defaultOutOfRange(DiagnosticKind.warning),

  /// `@Editable` is in a class or mixin no annotated class uses (FR-014a).
  unusedEditable(DiagnosticKind.warning);

  const DiagnosticCode(this.kind);

  /// Whether this code fails the build.
  final DiagnosticKind kind;
}

/// A place in the package's sources: a class declaration, for
/// [Diagnostic.related].
final class SourcePlace {
  /// The class [className] declared at [file]:[line].
  const SourcePlace({
    required this.file,
    required this.line,
    required this.className,
  });

  /// Reads a place written by [toJson].
  factory SourcePlace.fromJson(Map<String, Object?> json) => SourcePlace(
    file: json['file']! as String,
    line: json['line']! as int,
    className: json['className']! as String,
  );

  /// The package-relative path, or a `package:` URI for another package.
  final String file;

  /// The 1-based line of the class name.
  final int line;

  /// The class's name.
  final String className;

  /// The JSON form, with the Manifest's keys.
  Map<String, Object?> toJson() => {
    'className': className,
    'file': file,
    'line': line,
  };
}

/// An error or warning the Generator reports in the build log and the
/// Manifest (research R8).
final class Diagnostic implements Comparable<Diagnostic> {
  /// A diagnostic of [code] at [file]:[line].
  const Diagnostic({
    required this.code,
    required this.message,
    required this.file,
    required this.line,
    this.typeId,
    this.className,
    this.field,
    this.related = const [],
  });

  /// Reads a diagnostic written by [toJson].
  factory Diagnostic.fromJson(Map<String, Object?> json) => Diagnostic(
    code: DiagnosticCode.values.byName(json['code']! as String),
    message: json['message']! as String,
    file: json['file']! as String,
    line: json['line']! as int,
    typeId: json['typeId'] as String?,
    className: json['className'] as String?,
    field: json['field'] as String?,
    related: [
      for (final place in (json['related'] as List<Object?>?) ?? const [])
        SourcePlace.fromJson(place! as Map<String, Object?>),
    ],
  );

  /// What went wrong.
  final DiagnosticCode code;

  /// What is wrong and how to fix it, naming the class and field.
  final String message;

  /// The package-relative path, or a `package:` URI for a declaration in
  /// another package.
  final String file;

  /// The 1-based line of the declaration's name.
  final int line;

  /// The Type ID of the type concerned, if any.
  final String? typeId;

  /// The class concerned, if any.
  final String? className;

  /// The field concerned, if any.
  final String? field;

  /// Every class sharing the Type ID, for [DiagnosticCode.duplicateTypeId].
  final List<SourcePlace> related;

  /// Whether this diagnostic fails the build.
  bool get isError => code.kind == DiagnosticKind.error;

  /// The Manifest form (contracts/manifest-v1.md), without absent keys.
  Map<String, Object?> toJson() => {
    'className': ?className,
    'code': code.name,
    'field': ?field,
    'file': file,
    'line': line,
    'message': message,
    if (related.isNotEmpty) 'related': [for (final r in related) r.toJson()],
    'typeId': ?typeId,
  };

  /// The build log's line: code, place and message.
  String toLogLine() => '${code.name} $file:$line: $message';

  /// Orders by file, line, code, Type ID and field (contracts/manifest-v1.md).
  @override
  int compareTo(Diagnostic other) {
    int byText(String? a, String? b) => (a ?? '').compareTo(b ?? '');
    final keys = [
      file.compareTo(other.file),
      line.compareTo(other.line),
      code.name.compareTo(other.code.name),
      byText(typeId, other.typeId),
      byText(field, other.field),
    ];
    return keys.firstWhere((c) => c != 0, orElse: () => 0);
  }

  @override
  String toString() => toLogLine();
}
