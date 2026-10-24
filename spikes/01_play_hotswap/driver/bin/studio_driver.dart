// Plays the Studio's part in spike #1 (project-plan §9.3, §14 v0.0):
// spawns `flutter run --machine`, edits the scene file, hot-reloads through the
// daemon (`app.restart`), and watches the game's `[studio_scene]` log lines to
// decide pass/fail. VM service auth codes stay on (Q81): each run's URI goes to
// `<game>/.dart_tool/flame_studio/vm_service.json` for the IDE's attach config.
//
// Usage: dart run bin/studio_driver.dart -d <device> [--auto | --ci]
//        [--dds-port <n>] [--disable-auth-codes] [--repoint-assets] [-v]
//        [--project ../game] [--project-root <dir>]
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const scenePath = 'assets/scenes/level1.scene.json';
const markerPath = 'lib/dart_marker.dart';
const infoFilePath = '.dart_tool/flame_studio/vm_service.json';

late final String projectDir;
late final Process flutter;
String? appId;
String? vmServiceUri;
String? devFsBaseUri;
var repointAssets = false;
var nextId = 1;
final pending = <int, Completer<Object?>>{};
final logs = StreamController<String>.broadcast();
final started = Completer<void>();
final originals = <String, String>{};
var editCount = 0;

Future<void> main(List<String> args) async {
  String? device;
  int? ddsPort;
  var disableAuthCodes = false;
  var auto = false;
  var ci = false;
  var verbose = false;
  var project = '../game';
  String? projectRoot;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '-d' || '--device':
        device = args[++i];
      case '--dds-port':
        ddsPort = int.parse(args[++i]);
      case '--disable-auth-codes':
        // Dev-only escape hatch (Q81): a stable, unauthenticated URL.
        disableAuthCodes = true;
      case '--auto':
        auto = true;
      case '--ci':
        auto = true;
        ci = true;
      case '--repoint-assets':
        repointAssets = true;
      case '-v' || '--verbose':
        verbose = true;
      case '--project-root':
        projectRoot = args[++i];
      case '--project':
        project = args[++i];
      default:
        stderr.writeln('Unknown argument ${args[i]}');
        exit(64);
    }
  }
  if (device == null) {
    stderr.writeln('Pass a device id: -d <id> (see `flutter devices`).');
    exit(64);
  }
  projectDir = Directory(project).absolute.path;
  // A file left by a killed run would send the IDE to a dead URI.
  _deleteInfoFile();
  if (disableAuthCodes) ddsPort ??= 8181;
  for (final p in [scenePath, markerPath]) {
    originals[p] = File('$projectDir/$p').readAsStringSync();
  }

  final runArgs = [
    'run',
    '--machine',
    '-d',
    device,
    if (ddsPort != null) ...['--dds-port', '$ddsPort'],
    if (disableAuthCodes) '--disable-service-auth-codes',
    if (verbose) '-v',
    // Hidden flutter_tools option; its basename names the DevFS (see README).
    if (projectRoot != null) ...['--project-root', projectRoot],
  ];
  say('spawn: flutter ${runArgs.join(' ')}  (in $projectDir)');
  final stopwatch = Stopwatch()..start();
  flutter = await Process.start(
    'flutter',
    runArgs,
    workingDirectory: projectDir,
  );
  flutter.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(_onStdout);
  flutter.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((l) => say('stderr: ${redact(l)}'));
  unawaited(
    flutter.exitCode.then((code) async {
      say('flutter run exited with $code');
      _deleteInfoFile();
      await _restoreFiles();
      await stdout.flush();
      exit(code == 0 ? 0 : 1);
    }),
  );
  ProcessSignal.sigint.watch().listen((_) => _quit());
  ProcessSignal.sigterm.watch().listen((_) => _quit());

  // Don't touch the scene until the game has loaded it, or the first edit
  // races the initial load.
  final loaded = logs.stream
      .firstWhere((l) => l.contains('[studio_scene] loaded'))
      .timeout(const Duration(minutes: 10));
  await started.future;
  await loaded;
  say('app started and scene loaded in ${stopwatch.elapsed.inSeconds}s');
  _printAttachHelp();

  if (auto) {
    final ok = await _runAutoChecks();
    say(
      ok
          ? 'AUTO CHECKS (a)+(b): PASS'
          : 'AUTO CHECKS (a)+(b): FAIL — see log above',
    );
    if (ci) {
      // Scripted run: nobody is there to do check (c), so stop here.
      await _quit(code: ok ? 0 : 1);
    }
    say('Now run check (c) from VS Code, or press q to quit.');
  }
  _printHelp();
  stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) => _onCommand(line.trim()));
}

void say(String message) {
  final t = DateTime.now().toIso8601String().substring(11, 23);
  stdout.writeln('\x1B[36m[driver $t]\x1B[0m $message');
}

/// Masks auth codes (`http://127.0.0.1:1234/AbCd123=/`, also DTD's
/// `ws://127.0.0.1:1235/AbCd123=`) in output we didn't write ourselves, e.g.
/// the engine's "listening on" line on desktop.
String redact(String line) => line.replaceAllMapped(
  RegExp(r'((?:https?|wss?)://[^/\s"]+/)[A-Za-z0-9_\-]+=(?=[/"\s]|$)'),
  (m) => '${m[1]}<auth-code>=',
);

void _printHelp() {
  say(
    'commands (type + Enter):  s = edit scene + reload   '
    'd = Dart-only edit + reload   t = touch scene + reload   '
    'r = hot reload   '
    'R = hot restart   u = print attach URI   q = quit',
  );
}

void _printAttachHelp() {
  say(
    vmServiceUri == null
        ? 'VM service not reported yet'
        : 'Debugger available: attach with the "info file" entry in '
              'game/.vscode/launch.json ($infoFilePath); u prints the URI',
  );
}

void _printAttachUri() {
  // Only on request: the URI grants full control of the game process.
  say('VM service URI: ${vmServiceUri ?? '(not reported yet)'}');
}

// ---------------------------------------------------------- VM service info

File get _infoFile => File('$projectDir/$infoFilePath');

/// Writes `{"uri": ...}` for the debug adapter's `vmServiceInfoFile`: temp
/// file made owner-only before the URI goes in, then renamed into place, so
/// the adapter never reads a half-written file.
void _writeInfoFile(String uri) {
  final dir = _infoFile.parent..createSync(recursive: true);
  final tmp = File('${_infoFile.path}.tmp')..writeAsStringSync('');
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['700', dir.path]);
    Process.runSync('chmod', ['600', tmp.path]);
  }
  tmp.writeAsStringSync(jsonEncode({'uri': uri}), flush: true);
  tmp.renameSync(_infoFile.path);
  say('wrote $infoFilePath');
}

/// Deletes only the file: the adapter watches its folder, so the folder must
/// already exist when an attach config starts before the game does.
void _deleteInfoFile() {
  final info = _infoFile;
  for (final f in [info, File('${info.path}.tmp')]) {
    try {
      if (f.existsSync()) {
        f.deleteSync();
        if (f == info) say('deleted $infoFilePath');
      }
    } on FileSystemException catch (e) {
      say('could not delete ${f.path}: ${e.message}');
    }
  }
}

// ---------------------------------------------------------------- protocol

void _onStdout(String line) {
  if (!(line.startsWith('[{') && line.endsWith('}]'))) {
    // Desktop targets pass the game's stdout through raw, not as app.log.
    stdout.writeln('  ${redact(line)}');
    logs.add(line);
    return;
  }
  final List<dynamic> messages;
  try {
    messages = jsonDecode(line) as List<dynamic>;
  } on FormatException {
    stdout.writeln('  ${redact(line)}');
    logs.add(line);
    return;
  }
  for (final m in messages.cast<Map<String, dynamic>>()) {
    if (m.containsKey('id') && !m.containsKey('event')) {
      final c = pending.remove(m['id']);
      if (m.containsKey('error')) {
        c?.completeError(m['error'] as Object);
      } else {
        c?.complete(m['result']);
      }
      continue;
    }
    _onEvent(m['event'] as String, (m['params'] ?? {}) as Map);
  }
}

void _onEvent(String event, Map params) {
  switch (event) {
    case 'app.start':
      appId = params['appId'] as String;
    case 'app.debugPort':
      vmServiceUri = params['wsUri'] as String?;
      devFsBaseUri = params['baseUri'] as String?;
      final authOn = redact(vmServiceUri ?? '') != vmServiceUri;
      say(
        'app.debugPort: debugger available (auth code '
        '${authOn ? 'on' : 'OFF'}) baseUri=${params['baseUri']}',
      );
      if (vmServiceUri != null) _writeInfoFile(vmServiceUri!);
    case 'app.started':
      if (!started.isCompleted) started.complete();
    case 'app.log':
      final log = (params['log'] as String).trimRight();
      stdout.writeln('  game: ${redact(log)}');
      logs.add(log);
    case 'app.progress':
      if (params['finished'] != true && params['message'] != null) {
        say('progress: ${redact('${params['message']}')}');
      }
    case 'daemon.logMessage':
      say('${params['level']}: ${redact('${params['message']}')}');
    case 'app.stop':
      say('app.stop received — game stopped');
      _deleteInfoFile();
    default:
      say('event $event ${redact(jsonEncode(params))}');
  }
}

Future<Object?> send(String method, Map<String, Object?> params) {
  final id = nextId++;
  final c = Completer<Object?>();
  pending[id] = c;
  flutter.stdin.writeln(
    jsonEncode([
      {'id': id, 'method': method, 'params': params},
    ]),
  );
  return c.future;
}

Future<bool> reload({bool full = false}) async {
  if (!repointAssets) return _restart(full: full);
  if (await repointAssetDirectory()) return _restart(full: full);
  // Our DevFS folder is missing: either we haven't synced an asset yet, or an
  // attached IDE recreated the DevFS and deleted it. This reload's sync
  // recreates it, but the game reads stale assets during it. So point the
  // engine at it afterwards, evict the scene and reload once more.
  final ok = await _restart(full: full);
  if (!await repointAssetDirectory()) return ok;
  await _evict(scenePath);
  say('reloading again with the engine pointed at our DevFS');
  return _restart(full: full);
}

Future<bool> _restart({bool full = false}) async {
  final sw = Stopwatch()..start();
  try {
    final result =
        await send('app.restart', {
              'appId': appId,
              'fullRestart': full,
              'pause': false,
              'reason': 'manual',
            })
            as Map?;
    final code = result?['code'];
    say(
      '${full ? 'hot restart' : 'hot reload'} → code=$code '
      '"${result?['message']}" in ${sw.elapsedMilliseconds}ms',
    );
    return code == 0;
  } catch (e) {
    say('${full ? 'hot restart' : 'hot reload'} failed: $e');
    return false;
  }
}

// ------------------------------------------------- asset directory re-point

WebSocket? _vmSocket;
var _vmNextId = 1;
final _vmPending = <String, Completer<Map<String, dynamic>>>{};

Future<Map<String, dynamic>> _vmCall(
  String method, [
  Map<String, Object?> params = const {},
]) async {
  if (_vmSocket == null) {
    final socket = await WebSocket.connect(vmServiceUri!);
    socket.listen((data) {
      final m = jsonDecode(data as String) as Map<String, dynamic>;
      final c = _vmPending.remove(m['id']);
      if (c == null) return;
      if (m.containsKey('error')) {
        c.completeError(m['error'] as Object);
      } else {
        c.complete(m['result'] as Map<String, dynamic>);
      }
    });
    _vmSocket = socket;
  }
  final id = 'driver-${_vmNextId++}';
  final c = Completer<Map<String, dynamic>>();
  _vmPending[id] = c;
  _vmSocket!.add(
    jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    }),
  );
  return c.future;
}

/// Each flutter_tools client (this `flutter run`, an attached IDE) syncs
/// assets into its own DevFS folder and points the engine at it once. After an
/// attached IDE reloads, the engine serves assets from the IDE's copy and our
/// edits are ignored. Point it back at our DevFS before every reload, the same
/// way flutter_tools does (`_flutter.setAssetBundlePath`).
Future<bool> repointAssetDirectory() async {
  try {
    final view = await _firstView();
    final assetDir = Uri.parse(
      devFsBaseUri!,
    ).resolve('build/flutter_assets').toFilePath();
    await _vmCall('_flutter.setAssetBundlePath', {
      'isolateId': ?(view['isolate'] as Map?)?['id'],
      'viewId': view['id'],
      'assetDirectory': assetDir,
    });
    say('re-pointed engine assets at $assetDir');
    return true;
  } catch (e) {
    // The engine can't open the folder (see reload()).
    say('asset re-point failed: ${e is Map ? e['message'] : e}');
    return false;
  }
}

Future<Map<String, dynamic>> _firstView() async {
  final views = (await _vmCall('_flutter.listViews'))['views'] as List;
  return views.first as Map<String, dynamic>;
}

Future<void> _evict(String asset) async {
  final view = await _firstView();
  await _vmCall('ext.flutter.evict', {
    'isolateId': (view['isolate'] as Map)['id'],
    'value': asset,
  });
}

// ------------------------------------------------------------------- edits

/// Moves the player, recolors the coin and retitles the scene, writing the
/// file atomically (temp + rename) like the Studio will.
void editScene() {
  editCount++;
  final file = File('$projectDir/$scenePath');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  for (final node in (json['nodes'] as List).cast<Map<String, dynamic>>()) {
    switch (node['name']) {
      case 'player':
        node['x'] = -120 + (editCount % 6) * 40;
      case 'coin':
        node['color'] = editCount.isEven ? '#ffc107' : '#e91e63';
      case 'title':
        // Unique per edit, so an edit is never a no-op even if a previous run
        // left the file modified.
        node['text'] =
            'Scene edit $editCount @ '
            '${DateTime.now().toIso8601String().substring(11, 19)}';
    }
  }
  final tmp = File('${file.path}.tmp');
  tmp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
  tmp.renameSync(file.path);
  say('scene edited #$editCount');
}

/// Same bytes, new mtime: flutter_tools sees a changed asset and syncs it.
void touchScene() {
  File('$projectDir/$scenePath').setLastModifiedSync(DateTime.now());
  say('scene touched (content unchanged)');
}

var markerVersion = 0;

void editDartOnly() {
  final file = File('$projectDir/$markerPath');
  final source = file.readAsStringSync();
  final pattern = RegExp(r"'dart-v(\d+)'");
  // Bump from whatever is on disk so the edit is never a no-op.
  markerVersion = int.parse(pattern.firstMatch(source)!.group(1)!) + 1;
  file.writeAsStringSync(
    source.replaceFirst(pattern, "'dart-v$markerVersion'"),
  );
  say('Dart marker bumped to dart-v$markerVersion (scene untouched)');
}

Future<void> _restoreFiles() async {
  for (final e in originals.entries) {
    File('$projectDir/${e.key}').writeAsStringSync(e.value);
  }
}

// ------------------------------------------------------------------ checks

/// Waits for a `[studio_scene] hot reload:` line and returns it.
Future<String?> nextHotReloadLog(Duration timeout) => logs.stream
    .firstWhere((l) => l.contains('[studio_scene] hot reload:'))
    .then<String?>((l) => l)
    .timeout(timeout, onTimeout: () => null);

Future<bool> _runAutoChecks() async {
  const timeout = Duration(seconds: 20);

  say('── check (a): scene edit + app.restart must rebuild the scene');
  var waiter = nextHotReloadLog(timeout);
  editScene();
  final reloadedA = await reload();
  final logA = await waiter;
  final passA = reloadedA && (logA?.contains('REBUILT') ?? false);
  say('check (a): ${passA ? 'PASS' : 'FAIL'}  (${logA ?? 'no log in 20s'})');

  say('── check (b): Dart-only edit + app.restart must NOT rebuild the scene');
  waiter = nextHotReloadLog(timeout);
  editDartOnly();
  final reloadedB = await reload();
  final logB = await waiter;
  final passB = reloadedB && (logB?.contains('unchanged') ?? false);
  say(
    'check (b): ${passB ? 'PASS' : 'FAIL'}  (${logB ?? 'no log in 20s'})'
    '  — HUD should now show "code: dart-v$markerVersion"',
  );

  return passA && passB;
}

// ----------------------------------------------------------------- commands

Future<void> _onCommand(String cmd) async {
  switch (cmd) {
    case 's':
      editScene();
      await reload();
    case 'd':
      editDartOnly();
      await reload();
    case 't':
      touchScene();
      await reload();
    case 'r':
      await reload();
    case 'R':
      await reload(full: true);
    case 'u':
      _printAttachUri();
    case 'q':
      await _quit();
    case '':
      break;
    default:
      _printHelp();
  }
}

Future<void> _quit({int code = 0}) async {
  say('stopping game (app.stop) and restoring edited files');
  await _restoreFiles();
  _deleteInfoFile();
  try {
    await send('app.stop', {
      'appId': appId,
    }).timeout(const Duration(seconds: 5));
  } catch (_) {}
  flutter.kill();
  await stdout.flush();
  exit(code);
}
