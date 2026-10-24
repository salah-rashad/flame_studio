import 'package:flame/components.dart';
import 'package:studio_annotations/studio_annotations.dart';

/// A plain PositionComponent: placeable, but takes no Behaviors.
@StudioComponent(
  id: 'pickup.coin',
  label: 'Coin',
  preview: 'assets/images/coin.png',
)
class Coin extends PositionComponent {
  @Editable(min: 1, max: 100)
  int value = 1;
}
