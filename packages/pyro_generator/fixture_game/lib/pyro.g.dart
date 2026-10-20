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
import 'package:pyro_runtime/pyro_runtime.dart' as i9;

/// Every Behavior and Custom component in this package, for the Runtime.
final pyroRegistry = i9.PyroRegistry([
  i9.RegistryType(
    id: const i9.TypeId('Blink'),
    role: i9.TypeRole.behavior,
    create: i1.Blink.new,
    fields: {
      'visible': i9.RegistryField(
        name: 'visible',
        type: i9.FieldType.bool,
        nullable: false,
        accepts: (v) => v is bool,
        set: (t, v) => (t as i1.Blink).visible = v as bool,
      ),
      'times': i9.RegistryField(
        name: 'times',
        type: i9.FieldType.int,
        nullable: false,
        accepts: (v) => v is int,
        set: (t, v) => (t as i1.Blink).times = v as int,
      ),
    },
  ),
  i9.RegistryType(
    id: const i9.TypeId('Boss'),
    role: i9.TypeRole.component,
    create: i3.Boss.new,
    fields: {
      'health': i9.RegistryField(
        name: 'health',
        type: i9.FieldType.int,
        nullable: false,
        accepts: (v) => v is int,
        set: (t, v) => (t as i3.Boss).health = v as int,
      ),
      'glow': i9.RegistryField(
        name: 'glow',
        type: i9.FieldType.double,
        nullable: false,
        accepts: (v) => v is double,
        set: (t, v) => (t as i3.Boss).glow = v as double,
      ),
      'minion': i9.RegistryField(
        name: 'minion',
        type: i9.FieldType.entityRef,
        nullable: true,
        accepts: (v) => v == null || v is i4.Enemy,
        set: (t, v) => (t as i3.Boss).minion = v as i4.Enemy?,
      ),
      'rage': i9.RegistryField(
        name: 'rage',
        type: i9.FieldType.int,
        nullable: false,
        accepts: (v) => v is int,
        set: (t, v) => (t as i3.Boss).rage = v as int,
      ),
    },
  ),
  i9.RegistryType(
    id: const i9.TypeId('Lamp'),
    role: i9.TypeRole.component,
    create: i5.Lamp.new,
    fields: {
      'tint': i9.RegistryField(
        name: 'tint',
        type: i9.FieldType.color,
        nullable: false,
        accepts: (v) => v is i0.Color,
        set: (t, v) => (t as i5.Lamp).tint = v as i0.Color,
      ),
      'glow': i9.RegistryField(
        name: 'glow',
        type: i9.FieldType.color,
        nullable: true,
        accepts: (v) => v == null || v is i0.Color,
        set: (t, v) => (t as i5.Lamp).glow = v as i0.Color?,
      ),
    },
  ),
  i9.RegistryType(
    id: const i9.TypeId('Patrol'),
    role: i9.TypeRole.behavior,
    create: i2.Patrol.new,
    fields: {
      'speed': i9.RegistryField(
        name: 'speed',
        type: i9.FieldType.double,
        nullable: false,
        accepts: (v) => v is double,
        set: (t, v) => (t as i2.Patrol).speed = v as double,
      ),
      'direction': i9.RegistryField(
        name: 'direction',
        type: i9.FieldType.vector2,
        nullable: false,
        accepts: (v) => v is i8.Vector2,
        set: (t, v) => (t as i2.Patrol).direction = v as i8.Vector2,
      ),
      'mode': i9.RegistryField(
        name: 'mode',
        type: i9.FieldType.enumeration,
        nullable: false,
        values: i2.PatrolMode.values,
        accepts: (v) => v is i2.PatrolMode,
        set: (t, v) => (t as i2.Patrol).mode = v as i2.PatrolMode,
      ),
      'target': i9.RegistryField(
        name: 'target',
        type: i9.FieldType.entityRef,
        nullable: true,
        accepts: (v) => v == null || v is i7.Player,
        set: (t, v) => (t as i2.Patrol).target = v as i7.Player?,
      ),
      'oldTarget': i9.RegistryField(
        name: 'oldTarget',
        type: i9.FieldType.entityRef,
        nullable: true,
        accepts: (v) => v == null || v is i6.Player,
        set: (t, v) => (t as i2.Patrol).oldTarget = v as i6.Player?,
      ),
      'hitEffect': i9.RegistryField(
        name: 'hitEffect',
        type: i9.FieldType.spriteAnimation,
        nullable: true,
        accepts: (v) => v == null || v is i8.SpriteAnimation,
        set: (t, v) => (t as i2.Patrol).hitEffect = v as i8.SpriteAnimation?,
      ),
      'trail': i9.RegistryField(
        name: 'trail',
        type: i9.FieldType.imagePath,
        nullable: false,
        accepts: (v) => v is i9.ImagePath,
        set: (t, v) => (t as i2.Patrol).trail = v as i9.ImagePath,
      ),
    },
  ),
  i9.RegistryType(
    id: const i9.TypeId('Player'),
    role: i9.TypeRole.component,
    create: i7.Player.new,
    fields: {
      'lives': i9.RegistryField(
        name: 'lives',
        type: i9.FieldType.int,
        nullable: false,
        accepts: (v) => v is int,
        set: (t, v) => (t as i7.Player).lives = v as int,
      ),
      'nickname': i9.RegistryField(
        name: 'nickname',
        type: i9.FieldType.string,
        nullable: false,
        accepts: (v) => v is String,
        set: (t, v) => (t as i7.Player).nickname = v as String,
      ),
      'icon': i9.RegistryField(
        name: 'icon',
        type: i9.FieldType.sprite,
        nullable: true,
        accepts: (v) => v == null || v is i8.Sprite,
        set: (t, v) => (t as i7.Player).icon = v as i8.Sprite?,
      ),
      'buddy': i9.RegistryField(
        name: 'buddy',
        type: i9.FieldType.entityRef,
        nullable: true,
        accepts: (v) => v == null || v is i6.Player,
        set: (t, v) => (t as i7.Player).buddy = v as i6.Player?,
      ),
    },
  ),
  i9.RegistryType(
    id: const i9.TypeId('enemy.base'),
    role: i9.TypeRole.component,
    create: i4.Enemy.new,
    fields: {
      'health': i9.RegistryField(
        name: 'health',
        type: i9.FieldType.int,
        nullable: false,
        accepts: (v) => v is int,
        set: (t, v) => (t as i4.Enemy).health = v as int,
      ),
      'glow': i9.RegistryField(
        name: 'glow',
        type: i9.FieldType.double,
        nullable: false,
        accepts: (v) => v is double,
        set: (t, v) => (t as i4.Enemy).glow = v as double,
      ),
    },
  ),
  i9.RegistryType(
    id: const i9.TypeId('legacy.player'),
    role: i9.TypeRole.component,
    create: i6.Player.new,
    fields: {
      'note': i9.RegistryField(
        name: 'note',
        type: i9.FieldType.string,
        nullable: true,
        accepts: (v) => v == null || v is String,
        set: (t, v) => (t as i6.Player).note = v as String?,
      ),
    },
  ),
]);
