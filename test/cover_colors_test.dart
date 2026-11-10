import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:teleplayer/ui/cover_colors.dart';

void main() {
  test('a cover gives a scheme from its main colour, worked out in another isolate', () async {
    final dir = Directory.systemTemp.createTempSync('cover');
    addTearDown(() => dir.deleteSync(recursive: true));
    final image = img.Image(width: 64, height: 64);
    img.fill(image, color: img.ColorRgb8(200, 20, 30));
    final file = File('${dir.path}/red.png')..writeAsBytesSync(img.encodePng(image));
    final scheme = await coverScheme(file.path, Brightness.dark);
    final hsl = HSLColor.fromColor(scheme.primary);
    // Reddish: near 0 or 360 degrees of hue.
    expect(hsl.hue < 40 || hsl.hue > 320, isTrue, reason: 'hue ${hsl.hue}');
    expect(coverSchemeNow(file.path, Brightness.dark), isNotNull);
  });
}
