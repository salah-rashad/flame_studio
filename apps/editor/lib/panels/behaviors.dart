import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'inspector/field_editors.dart';
import 'inspector/field_values.dart';
import 'inspector/inspector_edits.dart';

/// The Behaviors of the selected entity or Custom component, as cards in
/// the inspector (spec 006, work item 9; FR-035–FR-038): *Add Behavior*
/// from the catalog, each Behavior's fields through the same editors as the
/// Node's own, and *Remove*.
///
/// A Behavior whose type left the project, or no longer fits its Node, is
/// marked and keeps every value — shown, never edited, saved verbatim
/// (*Q32*) — and comes back to normal when the type returns (FR-038).
class BehaviorsSection extends ConsumerStatefulWidget {
  /// Creates the section of Node [nodeId], whose own type is [nodeType].
  const BehaviorsSection({
    super.key,
    required this.sceneId,
    required this.nodeId,
    required this.nodeType,
    required this.gestures,
  });

  /// The Scene's provider key.
  final String sceneId;

  /// The Node holding the Behaviors.
  final NodeId nodeId;

  /// The Node's type; null when it has none the catalog could name.
  final TypeId? nodeType;

  /// The panel's edit runs.
  final GestureKeys gestures;

  @override
  ConsumerState<BehaviorsSection> createState() => _BehaviorsSectionState();
}

class _BehaviorsSectionState extends ConsumerState<BehaviorsSection> {
  bool _expanded = true;

  void _add(TypeDescriptor behavior) {
    final nodeId = widget.nodeId;
    ref.read(documentProvider(widget.sceneId).notifier).transact(
      'Add ${behavior.label}',
      (doc) {
        final node = doc.node(nodeId);
        if (node == null) return doc;
        return doc.replaceNode(
          withBehaviors(node, [
            ...behaviorsOf(node),
            BehaviorAttachment(type: behavior.id),
          ]),
        );
      },
    );
    setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(
      nodeProvider((widget.sceneId, widget.nodeId)).select(
        (node) => node == null
            ? const IList<TypeId>.empty()
            : IList([for (final b in behaviorsOf(node)) b.type]),
      ),
    );
    final catalog = ref.watch(typeCatalogProvider);
    final nodeType = widget.nodeType;
    final parent = nodeType == null ? null : catalog[nodeType];
    final offers = [
      for (final offer in behaviorOffers(catalog, parent))
        if (offer.offered) offer.type,
    ];
    final blocked = _addBlocked(parent, offers);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrSectionHeader(
          title: 'Behaviors',
          icon: PrIcons.zap,
          subtitle: types.isEmpty ? null : '${types.length}',
          expanded: _expanded,
          onExpandedChanged: (expanded) => setState(() => _expanded = expanded),
          actions: [
            if (blocked != null)
              PrIconButton(
                size: PrIconButtonSize.small,
                icon: PrIcons.plus,
                tooltip: 'Add Behavior',
                disabledReason: blocked,
                onPressed: null,
              )
            else
              PrMenuButton<void>(
                entries: _menuEntries(offers),
                builder: (context, controller) => PrIconButton(
                  size: PrIconButtonSize.small,
                  icon: PrIcons.plus,
                  tooltip: 'Add Behavior',
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                ),
              ),
          ],
        ),
        if (_expanded)
          if (types.isEmpty)
            Padding(
              padding: const EdgeInsets.all(PrSpacing.s3),
              child: Text(
                blocked ?? 'No Behaviors yet.',
                style: PrText.small.copyWith(
                  color: PrColors.of(context).textSecondary,
                ),
              ),
            )
          else
            for (var i = 0; i < types.length; i++)
              _BehaviorCard(
                key: ValueKey('${widget.nodeId}/$i/${types[i]}'),
                sceneId: widget.sceneId,
                nodeId: widget.nodeId,
                index: i,
                type: types[i],
                nodeType: nodeType,
                gestures: widget.gestures,
              ),
      ],
    );
  }

  /// Why nothing can be added, or null when something can (*Q50*).
  String? _addBlocked(TypeDescriptor? parent, List<TypeDescriptor> offers) {
    if (parent == null) {
      return "Behaviors can't be added to a Node whose type is missing.";
    }
    if (!parent.acceptsBehaviors) {
      return '${parent.label} does not accept Behaviors.';
    }
    if (offers.isEmpty) {
      return 'No Behavior in your project fits ${parent.label}.';
    }
    return null;
  }

  /// The Add Behavior menu: the offered Behaviors grouped by category,
  /// uncategorised ones last (FR-035).
  List<PrMenuEntry<void>> _menuEntries(List<TypeDescriptor> offers) {
    final groups = <String?, List<TypeDescriptor>>{};
    for (final type in offers) {
      groups.putIfAbsent(type.category, () => []).add(type);
    }
    final categories = groups.keys.toList()
      ..sort((a, b) {
        if (a == null || b == null) return a == null ? (b == null ? 0 : 1) : -1;
        return a.compareTo(b);
      });
    final grouped = categories.any((category) => category != null);
    return [
      for (final category in categories) ...[
        if (grouped) PrMenuHeader<void>(category ?? 'Other'),
        for (final type in groups[category]!)
          PrMenuItem<void>(
            label: type.label,
            icon: PrIcons.zap,
            onSelected: () => _add(type),
          ),
      ],
    ];
  }
}

/// One attached Behavior: its header with *Remove*, the Missing or
/// incompatible notice, and its fields (or, when its type is gone, the
/// values it keeps).
class _BehaviorCard extends ConsumerStatefulWidget {
  const _BehaviorCard({
    super.key,
    required this.sceneId,
    required this.nodeId,
    required this.index,
    required this.type,
    required this.nodeType,
    required this.gestures,
  });

  final String sceneId;
  final NodeId nodeId;
  final int index;
  final TypeId type;
  final TypeId? nodeType;
  final GestureKeys gestures;

  @override
  ConsumerState<_BehaviorCard> createState() => _BehaviorCardState();
}

class _BehaviorCardState extends ConsumerState<_BehaviorCard> {
  bool _expanded = true;

  /// Removes the Behavior and its Overrides in one named transaction
  /// (FR-036); one undo brings both back.
  void _remove(String label) {
    final nodeId = widget.nodeId;
    final index = widget.index;
    final type = widget.type;
    ref.read(documentProvider(widget.sceneId).notifier).transact(
      'Remove $label',
      (doc) {
        final node = doc.node(nodeId);
        if (node == null) return doc;
        final behaviors = [...behaviorsOf(node)];
        if (index >= behaviors.length || behaviors[index].type != type) {
          return doc;
        }
        behaviors.removeAt(index);
        return doc.replaceNode(withBehaviors(node, behaviors));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(typeCatalogProvider);
    final descriptor = catalog[widget.type];
    final nodeType = widget.nodeType;
    final parent = nodeType == null ? null : catalog[nodeType];
    final missing = descriptor == null;
    final refusal = missing ? null : behaviorRefusal(parent, descriptor);
    final label = descriptor?.label ?? widget.type.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrSectionHeader(
          title: label,
          icon: PrIcons.zap,
          subtitle: missing
              ? 'Missing'
              : refusal != null
              ? 'incompatible'
              : null,
          error: missing || refusal != null,
          expanded: _expanded,
          onExpandedChanged: (expanded) => setState(() => _expanded = expanded),
          menuTooltip: 'Behavior actions',
          menu: [
            PrMenuItem<void>(
              label: 'Remove Behavior',
              icon: PrIcons.trash,
              destructive: true,
              onSelected: () => _remove(label),
            ),
          ],
        ),
        if (_expanded) ...[
          if (missing) ...[
            _Notice(
              badge: const PrBadge(kind: PrBadgeKind.missing, label: 'Missing'),
              message:
                  '${widget.type.value} no longer exists in your code. Its '
                  'values are kept.',
            ),
            Consumer(
              builder: (context, ref, _) {
                final overrides = ref.watch(
                  nodeProvider((widget.sceneId, widget.nodeId)).select(
                    (node) => node == null
                        ? null
                        : behaviorsOf(
                            node,
                          ).elementAtOrNull(widget.index)?.fields,
                  ),
                );
                return KeptValues(values: overrides?.values ?? const {});
              },
            ),
          ] else ...[
            if (refusal != null)
              _Notice(
                badge: const PrBadge(
                  kind: PrBadgeKind.warning,
                  label: 'Incompatible',
                ),
                message: '$refusal Its values are kept.',
              ),
            PrPropertyList(
              children: [
                for (final field in descriptor.fields)
                  FieldRow(
                    key: ValueKey(
                      '${widget.nodeId}/${widget.index}/${field.name}',
                    ),
                    sceneId: widget.sceneId,
                    nodeId: widget.nodeId,
                    field: field,
                    gestures: widget.gestures,
                    behavior: widget.index,
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// A badge and the sentence that explains it.
class _Notice extends StatelessWidget {
  const _Notice({required this.badge, required this.message});

  final Widget badge;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PrSpacing.s3,
        vertical: PrSpacing.s2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          badge,
          const SizedBox(width: PrSpacing.s2),
          Expanded(
            child: Text(
              message,
              style: PrText.small.copyWith(
                color: PrColors.of(context).textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
