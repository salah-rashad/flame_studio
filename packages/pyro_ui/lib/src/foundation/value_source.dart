/// Where an inspector value comes from, which decides how its row is drawn.
///
/// The words are the design system's; the widgets don't know what an
/// override is, only how to draw one.
enum PrValueSource {
  /// "Default from code": the value the component's constructor gives. Label
  /// and value in `text-secondary`, no marker, no reset button.
  codeDefault,

  /// "Overridden": set in this scene or prefab. A 2px `accent-text` bar at
  /// the left edge, the label in `text-primary` 500, the value in
  /// `text-primary`, and the reset button.
  overridden,
}
