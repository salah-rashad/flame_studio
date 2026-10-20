import 'package:pyro_annotations/pyro_annotations.dart';

import 'enemy.dart';

@PyroComponent(category: 'Enemies')
class Boss extends Enemy {
  @Editable()
  Enemy? minion;

  // Redeclared: listed once, at Hurtable's position, with this declaration.
  @Editable(tooltip: 'Bosses are tougher')
  @override
  int health = 100;
}
