// Draws assets/images/ship.png, the example game's only image: a 32×32 ship
// made for this repository and MIT licensed like it (spec 005, FR-008).
//
// The PNG is encoded here with dart:io's zlib, so the image can be redrawn
// without an image package. Running it again writes identical bytes.
//
// Usage, from example/: dart run tool/draw_ship.dart
import 'dart:io';
import 'dart:typed_data';

const _size = 32;

void main() {
  final pixels = Uint8List(_size * _size * 4);
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final colour = _shipColour(x, y);
      if (colour == null) continue;
      final i = (y * _size + x) * 4;
      pixels
        ..[i] = colour >> 16 & 0xFF
        ..[i + 1] = colour >> 8 & 0xFF
        ..[i + 2] = colour & 0xFF
        ..[i + 3] = 0xFF;
    }
  }
  File('assets/images/ship.png').writeAsBytesSync(_encodePng(pixels));
  stdout.writeln('wrote assets/images/ship.png');
}

/// The ship points up: a hull narrowing to the nose, a cockpit, two fins and
/// an exhaust flame. Returns an RGB colour, or null for transparent.
int? _shipColour(int x, int y) {
  final dx = (x - 15.5).abs();
  if (y >= 26 && y <= 30 && dx < 2 + (30 - y) * 0.5) return 0xFF8A1E; // flame
  if (y >= 18 && y <= 26 && dx >= 4 && dx < 4 + (y - 18) * 0.75) {
    return 0xC62828; // fins
  }
  if (y >= 2 && y <= 25 && dx < 1 + (y - 2) * 0.22) {
    final cockpit = y >= 9 && y <= 14 && dx < 1.5;
    return cockpit ? 0x4FC3F7 : 0xE0E0E0; // cockpit, hull
  }
  return null;
}

/// An 8-bit RGBA PNG: signature, IHDR, one IDAT (filter 0 on every row) and
/// IEND.
List<int> _encodePng(Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < _size; y++) {
    raw
      ..addByte(0)
      ..add(rgba.sublist(y * _size * 4, (y + 1) * _size * 4));
  }
  final header = ByteData(13)
    ..setUint32(0, _size)
    ..setUint32(4, _size)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6); // colour type: RGBA
  return [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    ..._chunk('IHDR', header.buffer.asUint8List()),
    ..._chunk('IDAT', ZLibEncoder(level: 9).convert(raw.takeBytes())),
    ..._chunk('IEND', const []),
  ];
}

List<int> _chunk(String type, List<int> data) {
  final typeAndData = [...type.codeUnits, ...data];
  return [
    ..._uint32(data.length),
    ...typeAndData,
    ..._uint32(_crc32(typeAndData)),
  ];
}

List<int> _uint32(int value) =>
    (ByteData(4)..setUint32(0, value)).buffer.asUint8List();

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var k = 0; k < 8; k++) {
      crc = crc & 1 == 1 ? 0xEDB88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
