import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';

import 'checkers.dart';
import 'fields.dart';

/// A field's default for the Manifest (research R6).
final class FieldDefault {
  /// A default of [value] in its Scene written form, or of [source] text.
  const FieldDefault({this.value, this.source, this.hasInitializer = true});

  /// The field has no initializer.
  const FieldDefault.none()
    : value = null,
      source = null,
      hasInitializer = false;

  /// The evaluated value in its Scene written form (*Q91*), or null.
  final Object? value;

  /// The initializer's source text when it isn't evaluated.
  final String? source;

  /// Whether the field has an initializer.
  final bool hasInitializer;

  /// The evaluated numeric value, for the range check.
  num? get number => value is num ? value! as num : null;
}

/// Reads the default of a field of [field] class from its [initializer].
///
/// Literals, negated number literals, the field's enum values and
/// `ImagePath` literals are evaluated; anything else keeps its source text.
FieldDefault readDefault(Expression? initializer, FieldClass field) {
  if (initializer == null) return const FieldDefault.none();
  final value = switch (initializer) {
    NullLiteral() => null,
    IntegerLiteral(:final value?) => value,
    DoubleLiteral(:final value) => value,
    BooleanLiteral(:final value) => value,
    SimpleStringLiteral(:final value) => value,
    PrefixExpression(
      operator: Token(type: TokenType.MINUS),
      operand: IntegerLiteral(:final value?),
    ) =>
      -value,
    PrefixExpression(
      operator: Token(type: TokenType.MINUS),
      operand: DoubleLiteral(:final value),
    ) =>
      -value,
    _ when field.kind == FieldKind.enumeration =>
      _enumValue(initializer, field.element) ?? _notEvaluated,
    _ when field.kind == FieldKind.imagePath =>
      _imagePath(initializer) ?? _notEvaluated,
    _ => _notEvaluated,
  };
  if (identical(value, _notEvaluated)) {
    return FieldDefault(source: initializer.toSource());
  }
  return FieldDefault(value: value);
}

const Object _notEvaluated = Object();

/// The name of the enum value [expression] refers to, if it is one of
/// [enumElement]'s values (`Mode.loop`, `prefix.Mode.loop` or `.loop`).
String? _enumValue(Expression expression, InterfaceElement enumElement) {
  final element = switch (expression) {
    PrefixedIdentifier(:final identifier) => identifier.element,
    PropertyAccess(:final propertyName) => propertyName.element,
    DotShorthandPropertyAccess(:final propertyName) => propertyName.element,
    SimpleIdentifier() => expression.element,
    _ => null,
  };
  final variable = switch (element) {
    GetterElement(:final variable) => variable,
    FieldElement() => element,
    _ => null,
  };
  if (variable is FieldElement &&
      variable.isEnumConstant &&
      variable.enclosingElement == enumElement) {
    return variable.name;
  }
  return null;
}

/// `{"asset": path}` for `ImagePath('path')` or `const ImagePath('path')`.
Map<String, Object?>? _imagePath(Expression expression) {
  if (expression case InstanceCreationExpression(
    :final constructorName,
    argumentList: ArgumentList(arguments: [SimpleStringLiteral(:final value)]),
  )) {
    final element = constructorName.type.element;
    if (constructorName.name == null &&
        element is InterfaceElement &&
        imagePathChecker.isExactly(element)) {
      return {'asset': value};
    }
  }
  return null;
}
