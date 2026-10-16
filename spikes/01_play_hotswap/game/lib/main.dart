import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'spike_game.dart';

void main() {
  // Created once, outside build(), so hot reload keeps the same game instance.
  final game = SpikeGame();
  runApp(GameWidget(game: game));
}
