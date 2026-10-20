import 'package:flame/components.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

@PyroComponent()
class _Hidden extends PositionComponent {}

// Keeps the analyzer from calling _Hidden unused.
Object make() => _Hidden();
