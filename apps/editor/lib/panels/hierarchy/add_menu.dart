import 'package:flutter/widgets.dart';
import 'package:pyro/app/app.dart';
import 'package:pyro/document/document.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';
import 'package:pyro_ui/pyro_ui.dart';

import 'hierarchy_model.dart';

/// The side a new hitbox starts with, so it shows in the viewport: Flame's
/// zero size would leave it invisible.
const double newHitboxSide = 16;

/// The image a new sprite points at until the inspector picks one: the
/// format refuses an empty path, and the viewport shows a missing file as
/// an error, not as a crash.
const AssetPath newSpriteImage = AssetPath('assets/images/sprite.png');

/// What the Add menu offers under [parent]'s Node: the catalog's component
/// types, with the ones the parenting rules refuse disabled (FR-025).
AddParent addParentOf(Node parent) => switch (parent) {
  RootNode() => const AddParent.root(),
  EntityNode() => const AddParent.type(TypeId('entity')),
  SpriteNode() => const AddParent.type(TypeId('sprite')),
  RectangleHitboxNode() => const AddParent.type(TypeId('rectangleHitbox')),
  CircleHitboxNode() => const AddParent.type(TypeId('circleHitbox')),
  CustomNode(:final type) => AddParent.type(type),
  UnknownNode(:final kind) => AddParent.type(TypeId(kind)),
};

/// The Add menu's lines for [parent]: every component type, the refused
/// ones disabled; choosing one calls [onAdd] with its Type ID.
List<PrMenuEntry<void>> addMenuEntries(
  TypeCatalog catalog,
  AddParent parent, {
  required ValueChanged<TypeId> onAdd,
}) => [
  for (final offer in childOffers(catalog, parent))
    PrMenuItem<void>(
      label: offer.type.label,
      icon: iconOfType(offer.type.id),
      enabled: offer.offered,
      onSelected: () => onAdd(offer.type.id),
    ),
];

/// Why the disabled entries of the Add menu are disabled, each rule once —
/// the one a user can't guess (a hitbox under the root, *Q115*) goes in
/// the Add button's tooltip, since a menu line has no room for it.
List<String> addRefusals(TypeCatalog catalog, AddParent parent) => [
  ...{for (final offer in childOffers(catalog, parent)) ?offer.refusal},
];

/// A new Node of [type] with [id] and a default name.
Node newNode(TypeDescriptor type, NodeId id) {
  final name = type.label;
  return switch (type.id.value) {
    'entity' => EntityNode(id: id, name: name, transform: NodeTransform()),
    'sprite' => SpriteNode(
      id: id,
      name: name,
      transform: NodeTransform(),
      image: newSpriteImage,
    ),
    'rectangleHitbox' => RectangleHitboxNode(
      id: id,
      name: name,
      size: const Vec2(newHitboxSide, newHitboxSide),
    ),
    'circleHitbox' => CircleHitboxNode(
      id: id,
      name: name,
      radius: newHitboxSide / 2,
    ),
    _ => CustomNode(
      id: id,
      name: name,
      type: type.id,
      transform: NodeTransform(),
    ),
  };
}

/// Adds a Node of [type] last under [parentId] in one named transaction
/// (FR-025) and returns its ID.
NodeId addNodeOf(
  DocumentNotifier document,
  TypeDescriptor type,
  NodeId parentId, {
  NodeIdSource newId = uuidNodeIds,
}) {
  final id = newId();
  document.transact(
    'Add ${type.label}',
    (doc) => doc.addNode(newNode(type, id), parentId: parentId),
  );
  return id;
}
