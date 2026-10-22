// GENERATED CODE - DO NOT MODIFY BY HAND.
// pyro_generator: the Registry of this package's annotated types.
// ignore_for_file: type=lint

import 'dart:ui' as i0;
import 'package:pyro_example/behaviors/spin.dart' as i1;
import 'package:pyro_example/components/banner.dart' as i2;
import 'package:pyro_runtime/pyro_runtime.dart' as i3;

/// Every Behavior and Custom component in this package, for the Runtime.
final pyroRegistry = i3.PyroRegistry([
  i3.RegistryType(
    id: const i3.TypeId('Banner'),
    role: i3.TypeRole.component,
    create: i2.Banner.new,
    fields: {
      'message': i3.RegistryField(
        name: 'message',
        type: i3.FieldType.string,
        nullable: false,
        accepts: (v) => v is String,
        set: (t, v) => (t as i2.Banner).message = v as String,
      ),
      'color': i3.RegistryField(
        name: 'color',
        type: i3.FieldType.color,
        nullable: false,
        accepts: (v) => v is i0.Color,
        set: (t, v) => (t as i2.Banner).color = v as i0.Color,
      ),
    },
  ),
  i3.RegistryType(
    id: const i3.TypeId('Spin'),
    role: i3.TypeRole.behavior,
    create: i1.Spin.new,
    fields: {
      'turnsPerSecond': i3.RegistryField(
        name: 'turnsPerSecond',
        type: i3.FieldType.double,
        nullable: false,
        accepts: (v) => v is double,
        set: (t, v) => (t as i1.Spin).turnsPerSecond = v as double,
      ),
      'clockwise': i3.RegistryField(
        name: 'clockwise',
        type: i3.FieldType.bool,
        nullable: false,
        accepts: (v) => v is bool,
        set: (t, v) => (t as i1.Spin).clockwise = v as bool,
      ),
    },
    acceptsParent: (parent) => parent is i3.PyroEntity,
  ),
]);
