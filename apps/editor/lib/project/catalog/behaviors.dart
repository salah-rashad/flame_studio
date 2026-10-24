import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import 'manifest_parse.dart';
import 'parenting.dart';

/// Whether a Node of [parent]'s type satisfies the Behavior parent type
/// [required]: it is that type, or has it among its supertypes (*Q57*).
bool satisfiesParentType(TypeDescriptor parent, TypeId required) =>
    parent.id == required || parent.supertypes.contains(required.value);

/// Why [behavior] can't go on a Node of type [parent], or null when it can:
/// the parent holds no Behaviors at all (*Q50*), or isn't the type the
/// Behavior requires (*Q57*).
///
/// A [parent] of null is a type the catalog doesn't know; nothing can be
/// said about it, so the answer is "it fits" — the catalog is derived
/// state, never a gate on keeping data.
String? behaviorRefusal(TypeDescriptor? parent, TypeDescriptor behavior) {
  if (parent == null) return null;
  if (!parent.acceptsBehaviors) {
    return '${parent.label} does not accept Behaviors.';
  }
  final required = behavior.parentType;
  if (required == null || satisfiesParentType(parent, required)) return null;
  return '${behavior.label} needs a ${required.value}, which '
      '${parent.label} is not.';
}

/// Every Behavior type of [catalog] with its refusal for a Node of type
/// [parent] (null when the parent is unknown — see [behaviorRefusal]); the
/// Add Behavior list offers the ones without a refusal, grouped by
/// category (FR-035).
IList<OfferedChild> behaviorOffers(
  TypeCatalog catalog,
  TypeDescriptor? parent,
) => IList([
  for (final type in catalog.sorted)
    if (type.role == TypeRole.behavior)
      OfferedChild(type: type, refusal: behaviorRefusal(parent, type)),
]);
