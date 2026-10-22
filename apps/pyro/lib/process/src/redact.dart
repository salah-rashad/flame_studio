/// A VM service address and its auth code: `http://127.0.0.1:50300/AbC=/`,
/// `ws://…/AbC=/ws`, or the Dart Tooling Daemon's `ws://…/AbC=` at the end of
/// a line (spike #1's pattern).
final _authCode = RegExp(
  r'((?:https?|wss?)://[^/\s"]+/)[A-Za-z0-9_\-]+=(?=[/"\s]|$)',
);

/// Masks VM service auth codes in [line]: `ws://127.0.0.1:1234/AbC=/ws`
/// becomes `ws://127.0.0.1:1234/<auth-code>=/ws`.
///
/// The address grants full control of the game process, so it must never
/// reach a log (project plan §9.3, Q81). On desktop the engine prints it to
/// stdout as a raw line, so every line the Play client passes on goes through
/// here.
String redactAuthCodes(String line) =>
    line.replaceAllMapped(_authCode, (match) => '${match[1]}<auth-code>=');
