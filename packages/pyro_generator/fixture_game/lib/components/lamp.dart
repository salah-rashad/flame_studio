import 'dart:ui';

import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

/// A light, for the Color Field type (only real Flutter has dart:ui).
@PyroComponent()
class Lamp extends PositionComponent {
  @Editable()
  Color tint = const Color(0xFFFFFFFF);

  @Editable()
  Color? glow;
}
