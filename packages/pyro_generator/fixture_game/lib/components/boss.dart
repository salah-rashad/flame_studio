import 'package:pyro_annotations/pyro_annotations.dart';

import 'enemy.dart';

/// A tougher enemy with a minion.
@PyroComponent(category: 'Enemies')
class Boss extends Enemy {
  @Editable()
  Enemy? minion;

  // Redeclaring an inherited field is covered by the generator's goldens;
  // here it would trip the overridden_fields lint.
  @Editable(tooltip: 'Bosses get angrier')
  int rage = 1;
}
