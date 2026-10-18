import 'dart:collection';

import '../errors.dart';

/// Parses [text] as JSON, more strictly than `jsonDecode` (research R1).
///
/// - Duplicate keys in an object throw [DuplicateKey] instead of silently
///   keeping the last value.
/// - Errors give a line and column as well as an offset ([MalformedJson]).
/// - Maps and lists come back unmodifiable, with object keys in file order.
/// - A leading byte-order mark is skipped and CR counts as whitespace.
///
/// Whole numbers without a fraction or exponent become `int`s; other numbers
/// become `double`s.
Object? readStrictJson(String text) => _StrictReader(text).readDocument();

const int _tab = 0x09;
const int _lf = 0x0A;
const int _cr = 0x0D;
const int _space = 0x20;
const int _quote = 0x22;
const int _plus = 0x2B;
const int _comma = 0x2C;
const int _minus = 0x2D;
const int _dot = 0x2E;
const int _zero = 0x30;
const int _nine = 0x39;
const int _colon = 0x3A;
const int _upperE = 0x45;
const int _openBracket = 0x5B;
const int _backslash = 0x5C;
const int _closeBracket = 0x5D;
const int _lowerE = 0x65;
const int _openBrace = 0x7B;
const int _closeBrace = 0x7D;
const int _bom = 0xFEFF;

final class _StrictReader {
  _StrictReader(this._text);

  final String _text;
  int _pos = 0;

  /// Keys and indices from the top level to the value being read.
  final List<Object> _path = [];

  Object? readDocument() {
    if (_text.isNotEmpty && _text.codeUnitAt(0) == _bom) _pos = 1;
    _skipWhitespace();
    final value = _readValue();
    _skipWhitespace();
    if (_pos != _text.length) _fail('Unexpected content after the JSON value');
    return value;
  }

  void _skipWhitespace() {
    while (_pos < _text.length) {
      final c = _text.codeUnitAt(_pos);
      if (c != _space && c != _lf && c != _cr && c != _tab) return;
      _pos++;
    }
  }

  Object? _readValue() {
    if (_pos >= _text.length) _fail('Unexpected end of input');
    final c = _text.codeUnitAt(_pos);
    switch (c) {
      case _openBrace:
        return _readObject();
      case _openBracket:
        return _readArray();
      case _quote:
        return _readString();
      case 0x74: // t
        return _readLiteral('true', true);
      case 0x66: // f
        return _readLiteral('false', false);
      case 0x6E: // n
        return _readLiteral('null', null);
      default:
        if (c == _minus || (c >= _zero && c <= _nine)) return _readNumber();
        _fail('Unexpected character "${String.fromCharCode(c)}"');
    }
  }

  Object? _readLiteral(String word, Object? value) {
    if (!_text.startsWith(word, _pos)) _fail('Unexpected character');
    _pos += word.length;
    return value;
  }

  Map<String, Object?> _readObject() {
    _pos++; // {
    _skipWhitespace();
    if (_peek() == _closeBrace) {
      _pos++;
      return const <String, Object?>{};
    }
    final map = <String, Object?>{};
    while (true) {
      _skipWhitespace();
      if (_peek() != _quote) _fail('Expected a key in double quotes');
      final keyStart = _pos;
      final key = _readString();
      if (map.containsKey(key)) {
        final (line, column) = _lineAndColumn(keyStart);
        throw DuplicateKey(
          key,
          path: _pathString(),
          line: line,
          column: column,
        );
      }
      _skipWhitespace();
      if (_peek() != _colon) _fail('Expected ":" after the key');
      _pos++;
      _skipWhitespace();
      _path.add(key);
      map[key] = _readValue();
      _path.removeLast();
      _skipWhitespace();
      final c = _peek();
      if (c == _comma) {
        _pos++;
      } else if (c == _closeBrace) {
        _pos++;
        return UnmodifiableMapView(map);
      } else {
        _fail('Expected "," or "}"');
      }
    }
  }

  List<Object?> _readArray() {
    _pos++; // [
    _skipWhitespace();
    if (_peek() == _closeBracket) {
      _pos++;
      return const <Object?>[];
    }
    final list = <Object?>[];
    while (true) {
      _skipWhitespace();
      _path.add(list.length);
      list.add(_readValue());
      _path.removeLast();
      _skipWhitespace();
      final c = _peek();
      if (c == _comma) {
        _pos++;
      } else if (c == _closeBracket) {
        _pos++;
        return UnmodifiableListView(list);
      } else {
        _fail('Expected "," or "]"');
      }
    }
  }

  String _readString() {
    _pos++; // opening quote
    final start = _pos;
    // Fast path: no escapes.
    while (_pos < _text.length) {
      final c = _text.codeUnitAt(_pos);
      if (c == _quote) {
        final value = _text.substring(start, _pos);
        _pos++;
        return value;
      }
      if (c == _backslash) break;
      if (c < _space) _fail('Control character in a string');
      _pos++;
    }
    final buffer = StringBuffer(_text.substring(start, _pos));
    while (_pos < _text.length) {
      final c = _text.codeUnitAt(_pos);
      if (c == _quote) {
        _pos++;
        return buffer.toString();
      }
      if (c < _space) _fail('Control character in a string');
      if (c != _backslash) {
        buffer.writeCharCode(c);
        _pos++;
        continue;
      }
      _pos++;
      if (_pos >= _text.length) break;
      final escaped = _text.codeUnitAt(_pos);
      switch (escaped) {
        case _quote || _backslash || 0x2F: // " \ /
          buffer.writeCharCode(escaped);
        case 0x62: // b
          buffer.writeCharCode(0x08);
        case 0x66: // f
          buffer.writeCharCode(0x0C);
        case 0x6E: // n
          buffer.writeCharCode(_lf);
        case 0x72: // r
          buffer.writeCharCode(_cr);
        case 0x74: // t
          buffer.writeCharCode(_tab);
        case 0x75: // u
          if (_pos + 4 >= _text.length) _fail('Incomplete \\u escape');
          final hex = int.tryParse(
            _text.substring(_pos + 1, _pos + 5),
            radix: 16,
          );
          if (hex == null) _fail('Invalid \\u escape');
          buffer.writeCharCode(hex);
          _pos += 4;
        default:
          _fail('Invalid escape');
      }
      _pos++;
    }
    _fail('Unterminated string');
  }

  num _readNumber() {
    final start = _pos;
    var isWhole = true;
    if (_peek() == _minus) _pos++;
    if (_peek() == _zero) {
      _pos++;
    } else if (_isDigit(_peek())) {
      _skipDigits();
    } else {
      _fail('Expected a digit');
    }
    if (_peek() == _dot) {
      isWhole = false;
      _pos++;
      if (!_isDigit(_peek())) _fail('Expected a digit after "."');
      _skipDigits();
    }
    final e = _peek();
    if (e == _lowerE || e == _upperE) {
      isWhole = false;
      _pos++;
      final sign = _peek();
      if (sign == _plus || sign == _minus) _pos++;
      if (!_isDigit(_peek())) _fail('Expected a digit in the exponent');
      _skipDigits();
    }
    final literal = _text.substring(start, _pos);
    if (isWhole) return int.tryParse(literal) ?? double.parse(literal);
    return double.parse(literal);
  }

  void _skipDigits() {
    while (_isDigit(_peek())) {
      _pos++;
    }
  }

  static bool _isDigit(int c) => c >= _zero && c <= _nine;

  /// The code unit at the current position, or -1 at the end.
  int _peek() => _pos < _text.length ? _text.codeUnitAt(_pos) : -1;

  String _pathString() {
    final buffer = StringBuffer();
    for (final segment in _path) {
      if (segment is int) {
        buffer.write('[$segment]');
      } else {
        if (buffer.isNotEmpty) buffer.write('.');
        buffer.write(segment);
      }
    }
    return buffer.toString();
  }

  (int, int) _lineAndColumn(int offset) {
    var line = 1;
    var lineStart = 0;
    for (var i = 0; i < offset && i < _text.length; i++) {
      if (_text.codeUnitAt(i) == _lf) {
        line++;
        lineStart = i + 1;
      }
    }
    return (line, offset - lineStart + 1);
  }

  Never _fail(String reason) {
    final (line, column) = _lineAndColumn(_pos);
    throw MalformedJson(reason, offset: _pos, line: line, column: column);
  }
}
