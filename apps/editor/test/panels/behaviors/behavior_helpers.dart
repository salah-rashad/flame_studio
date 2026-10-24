import 'dart:convert';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:pyro/project/project.dart';
import 'package:pyro_runtime/pyro_runtime.dart';

import '../inspector/harness.dart';

/// A Behavior type of the project; [parentType] is its `Behavior<T>`.
TypeDescriptor behaviorType(
  String id, {
  String? parentType,
  String? category,
  List<FieldDescriptor> fields = const [],
}) => TypeDescriptor(
  id: TypeId(id),
  role: TypeRole.behavior,
  label: id,
  category: category,
  parentType: parentType == null ? null : TypeId(parentType),
  supertypes: ISet(const ['Behavior']),
  acceptsBehaviors: false,
  builtIn: false,
  fields: IList(fields),
);

/// `example/`'s `Spin`: turns any entity.
TypeDescriptor spinType() => behaviorType(
  'Spin',
  parentType: 'PyroEntity',
  category: 'Motion',
  fields: [
    field(
      'turnsPerSecond',
      FieldType.double,
      defaultValue: 0.25,
      min: 0,
      max: 4,
    ),
    field('clockwise', FieldType.bool, defaultValue: true),
  ],
);

/// A Behavior with one `speed` field, for the Missing drill.
TypeDescriptor patrolType() => behaviorType(
  'Patrol',
  parentType: 'PyroEntity',
  fields: [field('speed', FieldType.double, defaultValue: 1)],
);

/// A Custom component that accepts Behaviors, and a Behavior only it fits.
TypeDescriptor enemyType() => TypeDescriptor(
  id: const TypeId('Enemy'),
  role: TypeRole.component,
  label: 'Enemy',
  supertypes: ISet(const ['PositionComponent']),
  acceptsBehaviors: true,
  builtIn: false,
  fields: const IList.empty(),
);

/// [inspectorScene] with [behaviors] on its `box` entity.
Scene sceneWithBehaviors(List<BehaviorAttachment> behaviors) {
  final base = inspectorScene();
  final box = base.nodes[const NodeId('box')]! as EntityNode;
  return Scene(
    rootId: base.rootId,
    nodes: {
      ...base.nodes,
      const NodeId('box'): box.copyWith(behaviors: behaviors),
    },
  );
}

/// The `behaviors` of node [id] in a saved Scene's JSON.
List<Object?> savedBehaviors(String text, String id) {
  final json = jsonDecode(text) as Map<String, Object?>;
  final nodes = json['nodes']! as Map<String, Object?>;
  return (nodes[id]! as Map<String, Object?>)['behaviors']! as List<Object?>;
}
