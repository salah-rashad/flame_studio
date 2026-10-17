import 'dart:math' as math;

/// Whether a number editor holds an integer or a fractional value.
enum FsNumberKind {
  /// Whole numbers: shown without decimals, typed text and scrubbing round.
  int,

  /// Fractional numbers: shown with at least one decimal (`180.0`).
  double,
}

/// The number-editing core shared by the number editors: parsing (with
/// simple expressions), formatting, ↑/↓ steps and range checks. Scrub
/// maths is [FsScrub].
///
/// Internal; not exported.
abstract final class FsNumberEditing {
  /// Most decimals a formatted or rounded value keeps, which hides
  /// floating-point noise (`0.30000000000000004`).
  static const int maxDecimals = 6;

  /// The step when the caller gives none: 1, or a hundredth of the range for
  /// a bounded `double` (0.01 for 0…1).
  static double defaultStep(FsNumberKind kind, {double? min, double? max}) {
    if (kind == FsNumberKind.double && min != null && max != null) {
      final range = max - min;
      if (range > 0) return roundTo(range / 100, maxDecimals);
    }
    return 1;
  }

  /// The ↑/↓ and scrub multiplier for the held modifiers: Shift ×10,
  /// Alt ×0.1, both or neither ×1.
  static double modifierMultiplier({required bool shift, required bool alt}) {
    if (shift == alt) return 1;
    return shift ? 10 : 0.1;
  }

  /// The text shown in the field: `10` for ints; `180.0`, `9.81`, `0.85`
  /// for doubles (at least one decimal, at most [maxDecimals]).
  static String format(double value, FsNumberKind kind) {
    if (kind == FsNumberKind.int) return value.round().toString();
    var rounded = roundTo(value, maxDecimals);
    if (rounded == 0) rounded = 0; // no "-0.0"
    final text = rounded.toString();
    if (text.contains('e') || text.contains('.')) return text;
    return '$text.0';
  }

  /// The value of typed [text], or null when it isn't a finite number. Ints
  /// round to the nearest whole number.
  ///
  /// [text] may be an expression ([evaluate]): `32*2`, `(10+6)/4`, or
  /// `+=8` relative to [current].
  static double? parse(String text, FsNumberKind kind, {double? current}) {
    final trimmed = text.trim();
    final value = double.tryParse(trimmed) ?? evaluate(trimmed, current);
    if (value == null || !value.isFinite) return null;
    return kind == FsNumberKind.int ? value.roundToDouble() : value;
  }

  /// The value of a simple expression, or null when [text] isn't one.
  ///
  /// Numbers (`12`, `0.5`, `.5`, `1e3`), `+ - * /` with the usual
  /// precedence, unary `+`/`-`, parentheses and spaces. A leading
  /// `+= -= *= /=` applies the rest to [current] (`+=8` on 32 is 40); it
  /// needs a [current] value. Division by zero gives null.
  static double? evaluate(String text, [double? current]) {
    var source = text.trim();
    String? compound;
    if (source.length >= 2 && source[1] == '=' && '+-*/'.contains(source[0])) {
      compound = source[0];
      source = source.substring(2);
      if (current == null) return null;
    }
    final parser = _Expression(source);
    final value = parser.parse();
    if (value == null) return null;
    final result = switch (compound) {
      null => value,
      '+' => current! + value,
      '-' => current! - value,
      '*' => current! * value,
      _ => current! / value,
    };
    return result.isFinite ? result : null;
  }

  /// Whether [value] lies within the optional bounds.
  static bool inRange(double value, {double? min, double? max}) =>
      (min == null || value >= min) && (max == null || value <= max);

  /// [value] limited to the optional bounds.
  static double clamp(double value, {double? min, double? max}) {
    if (min != null && value < min) return min;
    if (max != null && value > max) return max;
    return value;
  }

  /// One ↑ ([direction] 1) or ↓ (-1) step from [value], times [multiplier],
  /// kept inside the bounds.
  static double step(
    double value,
    int direction, {
    required double step,
    double multiplier = 1,
    FsNumberKind kind = FsNumberKind.double,
    double? min,
    double? max,
  }) {
    final increment = _increment(step * multiplier, kind);
    final next = value + direction * increment;
    final decimals = math.max(decimalsOf(increment), decimalsOf(value));
    return clamp(
      kind == FsNumberKind.int ? next.roundToDouble() : roundTo(next, decimals),
      min: min,
      max: max,
    );
  }

  /// [value] rounded to [decimals] places.
  static double roundTo(double value, int decimals) =>
      double.parse(value.toStringAsFixed(decimals));

  /// How many decimals [value] has (up to [maxDecimals]): 0 for 180, 2 for
  /// 0.85.
  static int decimalsOf(double value) {
    final text = value.abs().toStringAsFixed(maxDecimals);
    final fraction = text.substring(text.indexOf('.') + 1);
    var n = fraction.length;
    while (n > 0 && fraction[n - 1] == '0') {
      n--;
    }
    return n;
  }

  static double _increment(double increment, FsNumberKind kind) =>
      kind == FsNumberKind.int
      ? math.max(1, increment.roundToDouble())
      : increment;
}

/// The maths of one scrub gesture: 1 step per [pixelsPerStep] pixels of
/// horizontal drag, times the modifier multiplier.
///
/// The value moves in whole increments from where the gesture (or the last
/// modifier change) started, so 412.5 scrubs to 413.5, not 413. The raw
/// position is clamped to the bounds, so dragging past an end and back
/// responds at once.
class FsScrub {
  /// Starts a gesture at [start].
  FsScrub({
    required double start,
    required this.step,
    this.kind = FsNumberKind.double,
    this.min,
    this.max,
  }) : _base = start,
       _raw = start,
       value = start;

  /// Drag distance per step.
  static const double pixelsPerStep = 2;

  /// The step at ×1.
  final double step;

  /// Int or double.
  final FsNumberKind kind;

  /// Lower bound.
  final double? min;

  /// Upper bound.
  final double? max;

  /// The current value.
  double value;

  double _base;
  double _raw;
  double? _multiplier;

  /// Moves by [dx] pixels with [multiplier] (see
  /// [FsNumberEditing.modifierMultiplier]) and returns the new value.
  double update(double dx, {double multiplier = 1}) {
    if (_multiplier != multiplier) {
      // A modifier change continues from the current value, without a jump.
      _multiplier = multiplier;
      _base = value;
      _raw = value;
    }
    _raw = FsNumberEditing.clamp(
      _raw + dx / pixelsPerStep * step * multiplier,
      min: min,
      max: max,
    );
    final increment = FsNumberEditing._increment(step * multiplier, kind);
    final steps = ((_raw - _base) / increment).round();
    final decimals = math.max(
      FsNumberEditing.decimalsOf(increment),
      FsNumberEditing.decimalsOf(_base),
    );
    final next = _base + steps * increment;
    value = FsNumberEditing.clamp(
      kind == FsNumberKind.int
          ? next.roundToDouble()
          : FsNumberEditing.roundTo(next, decimals),
      min: min,
      max: max,
    );
    return value;
  }
}

/// A recursive-descent parser for [FsNumberEditing.evaluate]:
///
/// ```text
/// expression := term (('+' | '-') term)*
/// term       := factor (('*' | '/') factor)*
/// factor     := ('+' | '-') factor | number | '(' expression ')'
/// ```
class _Expression {
  _Expression(this.source);

  final String source;
  int _at = 0;

  /// The value, or null for anything that isn't a whole expression.
  double? parse() {
    try {
      final value = _expression();
      _skipSpaces();
      return _at == source.length ? value : null;
    } on FormatException {
      return null;
    }
  }

  void _skipSpaces() {
    while (_at < source.length && source[_at] == ' ') {
      _at++;
    }
  }

  String? _peek() {
    _skipSpaces();
    return _at < source.length ? source[_at] : null;
  }

  double _expression() {
    var value = _term();
    for (var op = _peek(); op == '+' || op == '-'; op = _peek()) {
      _at++;
      final right = _term();
      value = op == '+' ? value + right : value - right;
    }
    return value;
  }

  double _term() {
    var value = _factor();
    for (var op = _peek(); op == '*' || op == '/'; op = _peek()) {
      _at++;
      final right = _factor();
      value = op == '*' ? value * right : value / right;
    }
    return value;
  }

  double _factor() {
    final next = _peek();
    if (next == '+' || next == '-') {
      _at++;
      final value = _factor();
      return next == '-' ? -value : value;
    }
    if (next == '(') {
      _at++;
      final value = _expression();
      if (_peek() != ')') throw const FormatException('expected )');
      _at++;
      return value;
    }
    return _number();
  }

  static final RegExp _numberPattern = RegExp(
    r'(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?',
  );

  double _number() {
    _skipSpaces();
    final match = _numberPattern.matchAsPrefix(source, _at);
    if (match == null) throw const FormatException('expected a number');
    _at = match.end;
    return double.parse(match.group(0)!);
  }
}
