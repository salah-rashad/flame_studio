// GENERATED CODE - DO NOT MODIFY BY HAND.
// pyro_generator: the Registry of this package's annotated types.
// ignore_for_file: type=lint

import 'dart:ui' as i0;
import 'package:fixture_game/behaviors/blink.dart' as i1;
import 'package:fixture_game/behaviors/patrol.dart' as i2;
import 'package:fixture_game/components/boss.dart' as i3;
import 'package:fixture_game/components/enemy.dart' as i4;
import 'package:fixture_game/components/lamp.dart' as i5;
import 'package:fixture_game/components/legacy/player.dart' as i6;
import 'package:fixture_game/components/player.dart' as i7;
import 'package:flame/components.dart' as i8;
import 'package:flame_behaviors/flame_behaviors.dart' as i9;
import 'package:pyro_runtime/pyro_runtime.dart' as i10;

/// Every Behavior and Custom component in this package, for the Runtime.
final pyroRegistry = i10.PyroRegistry([
  i10.RegistryType(
    id: const i10.TypeId('Blink'),
    role: i10.TypeRole.behavior,
    create: i1.Blink.new,
    fields: {
      'visible': i10.RegistryField(
        name: 'visible',
        type: i10.FieldType.bool,
        nullable: false,
        accepts: (v) => v is bool,
        set: (t, v) => (t as i1.Blink).visible = v as bool,
      ),
      'times': i10.RegistryField(
        name: 'times',
        type: i10.FieldType.int,
        nullable: false,
        accepts: (v) => v is int,
        set: (t, v) => (t as i1.Blink).times = v as int,
      ),
    },
    acceptsParent: (parent) => parent is i9.EntityMixin,
  ),
  i10.RegistryType(
    id: const i10.TypeId('Boss'),
    role: i10.TypeRole.component,
    create: i3.Boss.new,
    fields: {
      'health': i10.RegistryField(
        name: 'health',
        type: i10.FieldType.int,
        nullable: false,
        accepts: (v) => v is int,
        set: (t, v) => (t as i3.Boss).health = v as int,
      ),
      'glow': i10.RegistryField(
        name: 'glow',
        type: i10.FieldType.double,
        nullable: false,
        accepts: (v) => v is double,
        set: (t, v) => (t as i3.Boss).glow = v as double,
      ),
      'minion': i10.RegistryField(
        name: 'minion',
        type: i10.FieldType.entityRef,
        nullable: true,
        accepts: (v) => v == null || v is i4.Enemy,
        set: (t, v) => (t as i3.Boss).minion = v as i4.Enemy?,
      ),
      'rage': i10.RegistryField(
        name: 'rage',
        type: i10.FieldType.int,
        nullable: false,
        accepts: (v) => v is int,
        set: (t, v) => (t as i3.Boss).rage = v as int,
      ),
    },
  ),
  i10.RegistryType(
    id: const i10.TypeId('Lamp'),
    role: i10.TypeRole.component,
    create: i5.Lamp.new,
    fields: {
      'tint': i10.RegistryField(
        name: 'tint',
        type: i10.FieldType.color,
        nullable: false,
        accepts: (v) => v is i0.Color,
        set: (t, v) => (t as i5.Lamp).tint = v as i0.Color,
      ),
      'glow': i10.RegistryField(
        name: 'glow',
        type: i10.FieldType.color,
        nullable: true,
        accepts: (v) => v == null || v is i0.Color,
        set: (t, v) => (t as i5.Lamp).glow = v as i0.Color?,
      ),
    },
  ),
  i10.RegistryType(
    id: const i10.TypeId('Patrol'),
    role: i10.TypeRole.behavior,
    create: i2.Patrol.new,
    fields: {
      'speed': i10.RegistryField(
        name: 'speed',
        type: i10.FieldType.double,
        nullable: false,
        accepts: (v) => v is double,
        set: (t, v) => (t as i2.Patrol).speed = v as double,
      ),
      'direction': i10.RegistryField(
        name: 'direction',
        type: i10.FieldType.vector2,
        nullable: false,
        accepts: (v) => v is i8.Vector2,
        set: (t, v) => (t as i2.Patrol).direction = v as i8.Vector2,
      ),
      'mode': i10.RegistryField(
        name: 'mode',
        type: i10.FieldType.enumeration,
        nullable: false,
        values: i2.PatrolMode.values,
        accepts: (v) => v is i2.PatrolMode,
        set: (t, v) => (t as i2.Patrol).mode = v as i2.PatrolMode,
      ),
      'target': i10.RegistryField(
        name: 'target',
        type: i10.FieldType.entityRef,
        nullable: true,
        accepts: (v) => v == null || v is i7.Player,
        set: (t, v) => (t as i2.Patrol).target = v as i7.Player?,
      ),
      'oldTarget': i10.RegistryField(
        name: 'oldTarget',
        type: i10.FieldType.entityRef,
        nullable: true,
        accepts: (v) => v == null || v is i6.Player,
        set: (t, v) => (t as i2.Patrol).oldTarget = v as i6.Player?,
      ),
      'hitEffect': i10.RegistryField(
        name: 'hitEffect',
        type: i10.FieldType.spriteAnimation,
        nullable: true,
        accepts: (v) => v == null || v is i8.SpriteAnimation,
        set: (t, v) => (t as i2.Patrol).hitEffect = v as i8.SpriteAnimation?,
      ),
      'trail': i10.RegistryField(
        name: 'trail',
        type: i10.FieldType.imagePath,
        nullable: false,
        accepts: (v) => v is i10.ImagePath,
        set: (t, v) => (t as i2.Patrol).trail = v as i10.ImagePath,
      ),
    },
    acceptsParent: (parent) => parent is i9.PositionedEntity,
  ),
  i10.RegistryType(
    id: const i10.TypeId('Player'),
    role: i10.TypeRole.component,
    create: i7.Player.new,
    fields: {
      'lives': i10.RegistryField(
        name: 'lives',
        type: i10.FieldType.int,
        nullable: false,
        accepts: (v) => v is int,
        set: (t, v) => (t as i7.Player).lives = v as int,
      ),
      'nickname': i10.RegistryField(
        name: 'nickname',
        type: i10.FieldType.string,
        nullable: false,
        accepts: (v) => v is String,
        set: (t, v) => (t as i7.Player).nickname = v as String,
      ),
      'icon': i10.RegistryField(
        name: 'icon',
        type: i10.FieldType.sprite,
        nullable: true,
        accepts: (v) => v == null || v is i8.Sprite,
        set: (t, v) => (t as i7.Player).icon = v as i8.Sprite?,
      ),
      'buddy': i10.RegistryField(
        name: 'buddy',
        type: i10.FieldType.entityRef,
        nullable: true,
        accepts: (v) => v == null || v is i6.Player,
        set: (t, v) => (t as i7.Player).buddy = v as i6.Player?,
      ),
    },
  ),
  i10.RegistryType(
    id: const i10.TypeId('enemy.base'),
    role: i10.TypeRole.component,
    create: i4.Enemy.new,
    fields: {
      'health': i10.RegistryField(
        name: 'health',
        type: i10.FieldType.int,
        nullable: false,
        accepts: (v) => v is int,
        set: (t, v) => (t as i4.Enemy).health = v as int,
      ),
      'glow': i10.RegistryField(
        name: 'glow',
        type: i10.FieldType.double,
        nullable: false,
        accepts: (v) => v is double,
        set: (t, v) => (t as i4.Enemy).glow = v as double,
      ),
    },
  ),
  i10.RegistryType(
    id: const i10.TypeId('legacy.player'),
    role: i10.TypeRole.component,
    create: i6.Player.new,
    fields: {
      'note': i10.RegistryField(
        name: 'note',
        type: i10.FieldType.string,
        nullable: true,
        accepts: (v) => v == null || v is String,
        set: (t, v) => (t as i6.Player).note = v as String?,
      ),
    },
  ),
]);
