import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextStyle;
import 'package:pyro_runtime/pyro_runtime.dart';

/// A line of text placed in the Scene, for the `String` and `Color` Field
/// types (spec 005, contracts/example-game.md).
@PyroComponent()
class Banner extends TextComponent {
  /// The text it shows. Not called `text`, which `TextComponent` owns.
  @Editable()
  String message = 'Pyro';

  /// The text's colour.
  @Editable()
  Color color = const Color(0xFFFFFFFF);

  @override
  Future<void> onLoad() async {
    text = message;
    textRenderer = TextPaint(style: TextStyle(color: color, fontSize: 24));
  }
}
