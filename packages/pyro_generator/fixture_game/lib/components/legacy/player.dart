import 'package:flame/components.dart';
import 'package:pyro_annotations/pyro_annotations.dart';

/// The old player, kept under its own Type ID beside the new one, so the
/// Registry must name two classes called Player (FR-025).
@PyroComponent(id: 'legacy.player')
class Player extends PositionComponent {
  @Editable()
  String? note;
}
