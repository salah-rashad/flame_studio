import 'package:flutter/material.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

/// The editor's dialogs on `showFsDialog` (spec 006, T014): unsaved
/// changes, new scene, save refused, recovery *Restore*.

/// The unsaved-changes dialog's answers (FR-007).
enum UnsavedChangesAnswer { save, discard, cancel }

/// Asks what to do with the unsaved changes of [sceneName]: primary
/// *Save*, destructive *Discard*, secondary *Cancel*.
Future<UnsavedChangesAnswer> showUnsavedChangesDialog(
  BuildContext context,
  String sceneName,
) => showFsDialog<UnsavedChangesAnswer>(
      context,
      dialog: PrDialog(
        title: 'Save changes to "$sceneName"?',
        body:
            'The Scene has unsaved changes. They are kept in a recovery '
            'copy only after a while.',
        primary: const PrDialogAction(
          label: 'Save',
          value: UnsavedChangesAnswer.save,
        ),
        secondary: const PrDialogAction(
          label: 'Cancel',
          value: UnsavedChangesAnswer.cancel,
        ),
        destructive: const PrDialogAction(
          label: 'Discard',
          value: UnsavedChangesAnswer.discard,
        ),
      ),
    ).then((answer) => answer ?? UnsavedChangesAnswer.cancel);

/// The new-scene dialog's result (FR-008).
class NewSceneResult {
  /// Creates the result.
  const NewSceneResult({required this.name, required this.folder});

  /// The Scene's name, without the extension.
  final String name;

  /// The project-relative folder to save into, such as `assets/scenes/`.
  final String folder;
}

/// Asks for the new Scene's [defaultName] and folder; [folders] lists the
/// declared asset folders, [defaultFolder] the offered one
/// (`assets/scenes/`, *Q53*). When [folderDeclared] is false the dialog
/// carries the warning that the game cannot load from an undeclared folder
/// — never a pubspec edit (FR-008).
Future<NewSceneResult?> showNewSceneDialog(
  BuildContext context, {
  required String defaultName,
  required List<String> folders,
  required String defaultFolder,
  required bool folderDeclared,
}) {
  var name = defaultName;
  var folder = defaultFolder;
  return showFsDialog<NewSceneResult>(
    context,
    dialog: PrDialog<NewSceneResult>(
      title: 'New Scene',
      width: PrDialogWidth.form,
      content: _NewSceneForm(
        folders: folders,
        initialFolder: defaultFolder,
        folderDeclared: folderDeclared,
        onName: (value) => name = value,
        onFolder: (value) => folder = value,
      ),
      primary: PrDialogAction(
        label: 'Create',
        value: NewSceneResult(name: defaultName, folder: defaultFolder),
      ),
      secondary: const PrDialogAction(label: 'Cancel'),
    ),
  ).then((result) {
    if (result == null) return null;
    // The form's latest values win over the primary action's snapshot,
    // taken when the button was built.
    return NewSceneResult(
      name: name.isEmpty ? defaultName : name,
      folder: folder,
    );
  });
}

class _NewSceneForm extends StatefulWidget {
  const _NewSceneForm({
    required this.folders,
    required this.initialFolder,
    required this.folderDeclared,
    required this.onName,
    required this.onFolder,
  });

  final List<String> folders;
  final String initialFolder;
  final bool folderDeclared;
  final ValueChanged<String> onName;
  final ValueChanged<String> onFolder;

  @override
  State<_NewSceneForm> createState() => _NewSceneFormState();
}

class _NewSceneFormState extends State<_NewSceneForm> {
  late final TextEditingController _name;
  late String _folder;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController()..addListener(() => widget.onName(_name.text));
    _folder = widget.initialFolder;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PrSpacing.s3,
      children: [
        PrTextField(
          controller: _name,
          placeholder: 'Scene name',
          autofocus: true,
        ),
        if (widget.folders.isNotEmpty)
          PrDropdown<String>(
            value: _folder,
            onChanged: (folder) {
              setState(() => _folder = folder);
              widget.onFolder(folder);
            },
            options: [
              for (final folder in widget.folders)
                PrDropdownOption(value: folder, label: folder),
            ],
          ),
        if (!widget.folderDeclared)
          Row(
            spacing: PrSpacing.s2,
            children: [
              Icon(PrIcons.alertTriangle, size: 14, color: c.warning),
              Expanded(
                child: Text(
                  '"$_folder" is not declared in pubspec.yaml, so the game '
                  'cannot load Scenes from it. Pyro never edits the pubspec.',
                  style: PrText.small.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Asks how to answer a refused save (FR-010, *Q95*).
enum SaveRefusedAnswer { overwrite, reload, cancel }

/// The changed-on-disk dialog: *Overwrite* (destructive), *Reload from
/// disk*, *Cancel*.
Future<SaveRefusedAnswer> showSceneChangedOnDiskDialog(
  BuildContext context,
  String path,
) => showFsDialog<SaveRefusedAnswer>(
      context,
      dialog: PrDialog(
        title: 'The Scene file changed on disk',
        body: '"$path" changed since it was opened or last saved.',
        primary: const PrDialogAction(
          label: 'Reload from disk',
          value: SaveRefusedAnswer.reload,
        ),
        secondary: const PrDialogAction(
          label: 'Cancel',
          value: SaveRefusedAnswer.cancel,
        ),
        destructive: const PrDialogAction(
          label: 'Overwrite',
          value: SaveRefusedAnswer.overwrite,
        ),
      ),
    ).then((answer) => answer ?? SaveRefusedAnswer.cancel);

/// Shows why a save was refused without a way forward (*Q95*/*Q98*): the
/// Runtime gate messages.
Future<void> showSaveBlockedDialog(BuildContext context, SaveRefused reason) =>
    showFsDialog<void>(
      context,
      dialog: PrDialog(
        title: 'The Scene was not saved',
        body: '$reason',
        primary: const PrDialogAction(label: 'OK'),
      ),
    );

/// The recovery *Restore* prompt's answers (FR-009).
enum RestoreAnswer { restore, discard }

/// Offers the recovery copy of [scenePath] written at [writtenAt] (the
/// scene list on multi-copy days is v0.1; one copy per Scene today):
/// primary *Restore*, destructive *Discard*.
Future<RestoreAnswer> showRestoreDialog(
  BuildContext context, {
  required String scenePath,
  required DateTime writtenAt,
}) => showFsDialog<RestoreAnswer>(
      context,
      dialog: PrDialog(
        title: 'Recover unsaved changes?',
        body:
            'Pyro kept a recovery copy of "$scenePath" from '
            '${writtenAt.toLocal()}. Restoring it opens the Scene with '
            'those changes, unsaved.',
        primary: const PrDialogAction(
          label: 'Restore',
          value: RestoreAnswer.restore,
        ),
        secondary: const PrDialogAction(
          label: 'Cancel',
          value: RestoreAnswer.discard,
        ),
        destructive: const PrDialogAction(
          label: 'Discard',
          value: RestoreAnswer.discard,
        ),
      ),
    ).then((answer) => answer ?? RestoreAnswer.discard);

/// Shows the repair report of a hand-broken tree (FR-009, *Q96*): every
/// issue on its own line.
Future<void> showRepairReportDialog(
  BuildContext context, {
  required String scenePath,
  required RepairReport repairs,
}) => showFsDialog<void>(
      context,
      dialog: PrDialog(
        title: 'The Scene was repaired on open',
        body: '"$scenePath" had a broken tree; Pyro repaired it. The Scene '
            'is open with unsaved changes — save to write the repaired '
            'form.',
        content: Text(
          repairs.describe(),
          style: PrText.monoSmall.copyWith(
            color: PrColors.of(context).textSecondary,
          ),
        ),
        primary: const PrDialogAction(label: 'OK'),
      ),
    );
