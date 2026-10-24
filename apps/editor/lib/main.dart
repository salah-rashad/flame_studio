import 'dart:async';
import 'dart:io' show Platform;

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'app/app.dart';
import 'viewport/viewport.dart';

void main() {
  runApp(const PyroApp());
}

/// Pyro's settings folder: the user's application-support folder, never
/// inside a user project (research §3).
String pyroSupportFolder(FileSystem fileSystem) {
  final home = Platform.environment['HOME'];
  if (home == null) return fileSystem.path.join('/tmp', 'pyro');
  return fileSystem.path.join(
    home,
    'Library',
    'Application Support',
    'io.github.salah-rashad.pyro',
  );
}

/// The Pyro desktop app (spec 006, T017): the project list / welcome
/// window over the recent projects, and the editor window once a project
/// opens. One container owns the whole app.
class PyroApp extends StatefulWidget {
  /// Creates the app.
  const PyroApp({super.key, this.fileSystem = const LocalFileSystem()});

  /// The file system everything reads; tests inject a memory FS.
  final FileSystem fileSystem;

  @override
  State<PyroApp> createState() => _PyroAppState();
}

class _PyroAppState extends State<PyroApp> {
  late final ProviderContainer _container;
  late final RecentProjectsStore _settings;
  OpenSceneCommand? _command;

  @override
  void initState() {
    super.initState();
    _container = ProviderContainer();
    _settings = RecentProjectsStore(
      widget.fileSystem.file(
        widget.fileSystem.path.join(
          pyroSupportFolder(widget.fileSystem),
          'recent_projects.json',
        ),
      ),
      fileSystem: widget.fileSystem,
    );
  }

  @override
  void dispose() {
    _container.dispose();
    super.dispose();
  }

  Future<void> _openProject(String root) async {
    final sdk = await detectSdk(
      root,
      fileSystem: widget.fileSystem,
      pathVersion: flutterPathVersion,
    );
    final compatibility = await checkRuntimeCompatibility(
      root,
      fileSystem: widget.fileSystem,
    );
    if (!mounted) return;
    setState(() {
      _command = OpenSceneCommand(
        projectRoot: root,
        recoveryFolder: widget.fileSystem.path.join(
          pyroSupportFolder(widget.fileSystem),
          'recovery',
        ),
        fileSystem: widget.fileSystem,
      );
    });
    _container
        .read(projectProvider.notifier)
        .open(ProjectState(root: root, sdk: sdk, compatibility: compatibility));
    final recent = await _settings.read();
    await _settings.write(
      recent.copyWith(
        paths: IList([root, ...recent.paths.where((p) => p != root)]),
        lastOpened: root,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        title: 'Pyro',
        theme: PrTheme.dark(),
        home: _command == null
            ? _WelcomeWindow(onOpen: _openProject, settings: _settings)
            : _EditorWindow(command: _command!, settings: _settings),
      ),
    );
  }
}

/// The editor window: the app's shortcuts over the shell with the scene
/// tabs.
class _EditorWindow extends StatelessWidget {
  const _EditorWindow({required this.command, required this.settings});

  final OpenSceneCommand command;
  final RecentProjectsStore settings;

  @override
  Widget build(BuildContext context) {
    return PyroEditorWindow(
      command: command,
      settings: settings,
      tabs: SceneTabs(command: command),
      center: const ViewportPane(),
    );
  }
}

/// The welcome window (FR-001/FR-003): the recent projects with their
/// detected SDK, or the empty state, and open-by-path. A native folder
/// picker arrives with Settings (no new dependency this phase,
/// constitution II).
class _WelcomeWindow extends StatefulWidget {
  const _WelcomeWindow({required this.onOpen, required this.settings});

  final Future<void> Function(String root) onOpen;
  final RecentProjectsStore settings;

  @override
  State<_WelcomeWindow> createState() => _WelcomeWindowState();
}

class _WelcomeWindowState extends State<_WelcomeWindow> {
  List<(String, SdkInfo)> _recent = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final recent = await widget.settings.read();
    final entries = <(String, SdkInfo)>[];
    for (final root in recent.paths) {
      entries.add((
        root,
        await detectSdk(root, pathVersion: flutterPathVersion),
      ));
    }
    if (mounted) setState(() => _recent = entries);
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    return Scaffold(
      backgroundColor: c.bgApp,
      body: Center(
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: PrSpacing.s6,
            children: [
              Text('Pyro', style: PrText.title.copyWith(color: c.textPrimary)),
              if (_recent.isEmpty)
                PrEmptyState(
                  icon: PrIcons.layers,
                  title: 'No recent projects',
                  message: 'Open a Flutter project folder to begin.',
                  action: _openByPathButton(context, widget.onOpen),
                )
              else ...[
                for (final (root, sdk) in _recent)
                  _RecentProjectTile(
                    root: root,
                    sdk: sdk,
                    onOpen: () => widget.onOpen(root),
                  ),
                _openByPathButton(context, widget.onOpen),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The "Open project…" button (v0.1 opens by path; a native folder
  /// picker arrives with Settings — no new dependency this phase,
  /// constitution II).
  PrButton _openByPathButton(
    BuildContext context,
    Future<void> Function(String root) onOpen,
  ) => PrButton(
    label: 'Open project…',
    onPressed: () async {
      final controller = TextEditingController();
      final opened = await showFsDialog<bool>(
        context,
        dialog: PrDialog<bool>(
          title: 'Open project',
          width: PrDialogWidth.form,
          content: PrTextField(
            controller: controller,
            placeholder: '/path/to/project',
            autofocus: true,
          ),
          primary: const PrDialogAction(label: 'Open', value: true),
          secondary: const PrDialogAction(label: 'Cancel'),
        ),
      );
      if (opened != true || controller.text.isEmpty) return;
      await onOpen(controller.text.trim());
    },
  );
}

class _RecentProjectTile extends StatelessWidget {
  const _RecentProjectTile({
    required this.root,
    required this.sdk,
    required this.onOpen,
  });

  final String root;
  final SdkInfo sdk;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    final name = root.split('/').where((p) => p.isNotEmpty).last;
    final none = sdk.version == null;
    return PrButton(
      label: name,
      onPressed: onOpen,
      leading: Icon(
        none ? PrIcons.alertTriangle : PrIcons.terminal,
        size: 14,
        color: none ? c.warning : c.textSecondary,
      ),
      tooltip: none
          ? '$root — no Flutter SDK found'
          : '$root — Flutter ${sdk.version}',
    );
  }
}
