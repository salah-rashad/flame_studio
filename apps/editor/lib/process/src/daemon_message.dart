import 'dart:convert';

/// One message from `flutter run --machine`'s stdout (spec 005, research R4).
sealed class DaemonMessage {
  const DaemonMessage();
}

/// An event the daemon sent on its own, such as `app.started`.
final class DaemonEvent extends DaemonMessage {
  const DaemonEvent(this.name, this.params);

  /// The event's name, such as `app.log`.
  final String name;

  /// Its parameters; empty when it had none.
  final Map<String, Object?> params;
}

/// The daemon's answer to a request the client sent with [id].
final class DaemonResponse extends DaemonMessage {
  const DaemonResponse(this.id, {this.result, this.error});

  /// The request's id.
  final int id;

  /// The result, when the request succeeded.
  final Object? result;

  /// The error, when it failed; null on success.
  final Object? error;
}

/// A line that isn't a daemon message: build output, or the game's own
/// stdout, which desktop targets pass through unchanged.
final class RawLine extends DaemonMessage {
  const RawLine(this.text);

  /// The line, as written.
  final String text;
}

/// Parses one stdout line. A daemon line is a JSON list of messages wrapped
/// in `[{` … `}]`; anything else, including such a line that fails to decode
/// or holds something unexpected, is one [RawLine]. Never throws.
List<DaemonMessage> parseDaemonLine(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('[{') || !trimmed.endsWith('}]')) {
    return [RawLine(line)];
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    return [RawLine(line)];
  }
  if (decoded is! List<Object?>) return [RawLine(line)];
  final messages = <DaemonMessage>[];
  for (final item in decoded) {
    final message = _message(item);
    if (message == null) return [RawLine(line)];
    messages.add(message);
  }
  return messages;
}

DaemonMessage? _message(Object? item) {
  if (item is! Map<String, Object?>) return null;
  final event = item['event'];
  if (event is String) {
    final params = item['params'];
    return DaemonEvent(
      event,
      params is Map<String, Object?> ? params : const {},
    );
  }
  final id = item['id'];
  if (id is int) {
    return DaemonResponse(id, result: item['result'], error: item['error']);
  }
  return null;
}
