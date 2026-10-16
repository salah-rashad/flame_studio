/// Spike #2 stand-in for `flame_studio_annotations` (project-plan §6.1).
library;

/// Marks a Behavior class the Studio can add to a Node.
class StudioBehavior {
  final String? label;
  final String? category;

  /// Explicit Type ID; defaults to the class name.
  final String? id;

  const StudioBehavior({this.label, this.category, this.id});
}

/// Marks a PositionComponent subclass the Studio can place in a scene.
class StudioComponent {
  final String? label;
  final String? category;
  final String? id;
  final String? preview;

  const StudioComponent({this.label, this.category, this.id, this.preview});
}

/// Marks a field shown in the Studio's inspector.
class Editable {
  final num? min;
  final num? max;
  final String? tooltip;

  const Editable({this.min, this.max, this.tooltip});
}
