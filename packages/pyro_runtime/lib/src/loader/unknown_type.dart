/// What a Scene load does with a Type ID or Node kind it doesn't know
/// (*Q58*).
enum UnknownType {
  /// Fail the load with an error naming the Scene, the Node and the Type ID
  /// or kind (the default).
  error,

  /// Leave it out: an unknown Behavior alone, an unknown Custom component or
  /// Node kind with everything under it. A debug warning lists what was
  /// left out, and references to left-out Nodes become null.
  skip,
}
