import 'dart:typed_data';
import 'dart:ui';

/// An image of [width] × [height] pixels in one colour, made in memory so
/// tests need no image files.
Future<Image> makeImage(int width, int height) {
  final recorder = PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFFFF8800),
  );
  return recorder.endRecording().toImage(width, height);
}

/// The PNG bytes of a [makeImage] image, for tests that go through an
/// `AssetBundle`.
Future<Uint8List> makePng(int width, int height) async {
  final image = await makeImage(width, height);
  final data = await image.toByteData(format: ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
