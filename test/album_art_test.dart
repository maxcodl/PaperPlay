import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:teleplayer/library/album_art.dart';

Uint8List _png(int width, int height) {
  final image = img.Image(width: width, height: height);
  // Noise, so the JPEG isn't tiny by accident.
  for (final p in image) {
    p
      ..r = (p.x * 7 + p.y * 3) % 256
      ..g = (p.x * 5) % 256
      ..b = (p.y * 11) % 256;
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('a large cover becomes a JPEG within Telegram\'s limits, keeping its shape', () {
    final thumb = shrinkCover(_png(1200, 800))!;
    expect(thumb.width, 320);
    expect(thumb.height, 213);
    expect(thumb.bytes.length, lessThanOrEqualTo(maxBytes));
    expect(thumb.bytes.sublist(0, 2), [0xFF, 0xD8], reason: 'JPEG, which Telegram requires');
    final back = img.decodeJpg(thumb.bytes)!;
    expect([back.width, back.height], [thumb.width, thumb.height]);
  });

  test('a small cover is kept at its size', () {
    final thumb = shrinkCover(_png(100, 100))!;
    expect([thumb.width, thumb.height], [100, 100]);
  });

  test('something that isn\'t an image gives no cover instead of an error', () {
    expect(shrinkCover(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });
}
