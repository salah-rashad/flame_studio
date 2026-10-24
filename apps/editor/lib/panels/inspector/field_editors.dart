import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro/viewport/viewport.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'field_values.dart';
import 'inspector_edits.dart';

/// The image files under the project's declared asset folders (*Q31*),
/// read from disk each time a row asks, so a file added meanwhile shows up
/// without a restart.
final projectImagesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final root = ref.watch(projectProvider.select((project) => project?.root));
  if (root == null) return const [];
  final images = await discoverImages(
    root,
    fileSystem: ref.watch(assetFileSystemProvider),
  );
  return images.unlock;
});

/// One Editable field of the selected Node (FR-029–FR-033): the editor its
/// Field type calls for, the Override marker and *Reset to default*, and
/// the type · default · tooltip line. Watches only its own Node.
class FieldRow extends ConsumerWidget {
  /// Creates the row of [field] on Node [nodeId].
  const FieldRow({
    super.key,
    required this.sceneId,
    required this.nodeId,
    required this.field,
    required this.gestures,
  });

  /// The Scene's provider key.
  final String sceneId;

  /// The Node the field belongs to.
  final NodeId nodeId;

  /// The Manifest's description of the field.
  final FieldDescriptor field;

  /// The panel's edit runs.
  final GestureKeys gestures;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final node = ref.watch(nodeProvider((sceneId, nodeId)));
    if (node == null) return const SizedBox.shrink();
    final reading = readField(node, field);
    final edits = NodeEdits(ref, sceneId, nodeId, gestures);
    final source = reading.overridden
        ? PrValueSource.overridden
        : PrValueSource.codeDefault;
    final onReset = reading.overridden
        ? () => edits.reset(field.name, (n) => resetField(n, field))
        : null;
    final tooltip = fieldTooltip(field);
    final value = reading.value;
    final defaultSource = defaultSourceOf(field);

    void set(Object? next, {bool end = false}) =>
        edits.edit(field.name, (n) => writeField(n, field, next), end: end);

    if (!isEditable(node, field)) {
      return _ReadOnlyRow(
        label: field.name,
        tooltip: tooltip,
        source: source,
        text: value == null ? (defaultSource ?? '—') : _describe(value),
      );
    }
    // A default the Manifest couldn't evaluate (§7.3) shows as its source
    // text; clicking it starts an Override from a neutral value.
    if (value == null && !reading.overridden && defaultSource != null) {
      return _ReadOnlyRow(
        label: field.name,
        tooltip: tooltip,
        source: source,
        text: defaultSource,
        hint: 'default from code',
        onPressed: () => set(seedValue(field)),
      );
    }

    switch (field.type) {
      case FieldType.int || FieldType.double:
        final number = numberOf(value);
        return PrNumberProperty(
          label: field.name,
          value: number,
          mixed: number == null,
          kind: field.type == FieldType.int
              ? PrNumberKind.int
              : PrNumberKind.double,
          min: field.min,
          max: field.max,
          source: source,
          onReset: onReset,
          resetTooltip: 'Reset to default',
          tooltip: tooltip,
          invalidMessage: _rangeMessage(field),
          onChanged: (v) => set(clampField(field, v)),
          onCommit: (v) => set(clampField(field, v), end: true),
        );
      case FieldType.bool:
        return PrBoolProperty(
          label: field.name,
          value: value is bool ? value : null,
          mixed: value is! bool,
          source: source,
          onReset: onReset,
          resetTooltip: 'Reset to default',
          tooltip: tooltip,
          onChanged: (v) => set(v, end: true),
        );
      case FieldType.string:
        return PrPropertyRow(
          label: field.name,
          source: source,
          onReset: onReset,
          resetTooltip: 'Reset to default',
          tooltip: tooltip,
          editor: PrTextField(
            value: value is String ? value : '',
            size: PrFieldSize.dense,
            onChanged: set,
            onSubmitted: (text) => set(text, end: true),
          ),
        );
      case FieldType.enumeration:
        final current = value is String ? value : null;
        final values = field.enumValues?.unlock ?? const <String>[];
        return PrPropertyRow(
          label: field.name,
          source: source,
          onReset: onReset,
          resetTooltip: 'Reset to default',
          tooltip: tooltip,
          editor: PrDropdown<String>(
            size: PrFieldSize.dense,
            monoOptions: true,
            // A kept value from code that has since changed still shows.
            options: [
              for (final name in [
                ...values,
                if (current != null && !values.contains(current)) current,
              ])
                PrDropdownOption(value: name, label: name),
            ],
            value: current,
            onChanged: (name) => set(name, end: true),
          ),
        );
      case FieldType.vector2:
        final vector = vectorOf(value);
        return PrVector2Property(
          label: field.name,
          x: vector?.$1,
          y: vector?.$2,
          mixedX: vector == null,
          mixedY: vector == null,
          source: source,
          onReset: onReset,
          resetTooltip: 'Reset to default',
          tooltip: tooltip,
          onChanged: (x, y) =>
              set([x ?? vector?.$1 ?? 0.0, y ?? vector?.$2 ?? 0.0]),
          onCommit: (x, y) =>
              set([x ?? vector?.$1 ?? 0.0, y ?? vector?.$2 ?? 0.0], end: true),
        );
      case FieldType.imagePath:
        return _ImagePathRow(
          label: field.name,
          path: imagePathOf(value),
          source: source,
          onReset: onReset,
          tooltip: tooltip,
          onChanged: (path) => set({'asset': path}, end: true),
        );
      case FieldType.color ||
          FieldType.sprite ||
          FieldType.spriteAnimation ||
          FieldType.entityRef:
        throw StateError('${field.type} is read-only, handled above');
    }
  }
}

String? _rangeMessage(FieldDescriptor field) {
  final min = field.min;
  final max = field.max;
  final kind = field.type == FieldType.int ? 'a whole number' : 'a number';
  return switch ((min, max)) {
    (final low?, final high?) => 'Expected $kind from $low to $high',
    (final low?, null) => 'Expected $kind of at least $low',
    (null, final high?) => 'Expected $kind of at most $high',
    _ => 'Expected $kind',
  };
}

/// A value for a read-only row, as the file writes it.
String _describe(Object value) {
  final ref = AssetRef.fromJson(value);
  if (ref != null) {
    return ref.animation == null ? ref.path : '${ref.path} · ${ref.animation}';
  }
  return switch (value) {
    final List<Object?> list => '[${list.join(', ')}]',
    _ => '$value',
  };
}

/// A read-only value (FR-033), or a default shown as its source text: the
/// label, the text in mono, and a lock where nothing can be done with it.
class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.tooltip,
    required this.source,
    required this.text,
    this.hint,
    this.onPressed,
  });

  final String label;
  final String tooltip;
  final PrValueSource source;
  final String text;
  final String? hint;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = PrColors.of(context);
    Widget value = Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PrText.monoSmall.copyWith(color: c.textSecondary),
          ),
        ),
        if (onPressed == null)
          Icon(PrIcons.lock, size: PrSizes.iconSm, color: c.textDisabled),
      ],
    );
    if (onPressed != null) {
      value = PrTooltip(
        message: 'Override the default from code',
        details: [?hint],
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: value,
        ),
      );
    }
    return PrPropertyRow(
      label: label,
      source: source,
      readOnly: onPressed == null,
      tooltip: tooltip,
      editor: value,
    );
  }
}

/// An image-path Field: a dropdown of the image files under the declared
/// asset folders. The stored value is the project-relative path.
class _ImagePathRow extends ConsumerWidget {
  const _ImagePathRow({
    required this.label,
    required this.path,
    required this.source,
    required this.onReset,
    required this.tooltip,
    required this.onChanged,
  });

  final String label;
  final String? path;
  final PrValueSource source;
  final VoidCallback? onReset;
  final String tooltip;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(projectImagesProvider).value ?? const <String>[];
    final current = path;
    return PrPropertyRow(
      label: label,
      source: source,
      onReset: onReset,
      resetTooltip: 'Reset to default',
      tooltip: tooltip,
      editor: PrDropdown<String>(
        size: PrFieldSize.dense,
        monoOptions: true,
        placeholder: 'No image',
        // The current file shows even when the folders no longer list it.
        options: [
          for (final file in [
            ...images,
            if (current != null && !images.contains(current)) current,
          ])
            PrDropdownOption(
              value: file,
              label: file.split('/').last,
              detail: file,
            ),
        ],
        value: current,
        onChanged: onChanged,
      ),
    );
  }
}
