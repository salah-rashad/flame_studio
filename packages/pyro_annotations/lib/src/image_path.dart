/// A project-root-relative image path, such as `assets/images/fx.png`: the
/// Field type of an Editable field that holds an image.
///
/// A plain `String` field is always text; declare the field as an
/// [ImagePath] for Pyro to offer images and keep the path up to date.
final class ImagePath {
  /// The image at [path], relative to the project root.
  const ImagePath(this.path);

  /// The path relative to the project root, the same key the game declares
  /// in `pubspec.yaml`.
  final String path;

  @override
  bool operator ==(Object other) => other is ImagePath && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'ImagePath($path)';
}
