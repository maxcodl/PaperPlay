import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:material_color_utilities/material_color_utilities.dart' as mcu;

import 'theme.dart';

final _schemes = <String, Future<ColorScheme>>{};
final _ready = <String, ColorScheme>{};
final _themes = <ColorScheme, ThemeData>{};

String _key(String path, Brightness b) => '${b.name}:$path';

final _seeds = <String, Future<int?>>{};

/// The cover's main colour, found in another isolate: decoding and quantizing an image is the
/// work that stuttered the UI when songs changed. The same method as
/// [ColorScheme.fromImageProvider], on a small copy of the picture.
Future<int?> _seedOf(String path) => _seeds[path] ??= Isolate.run(() async {
      final image = img.decodeImage(File(path).readAsBytesSync());
      if (image == null) return null;
      final small = img.copyResize(image, width: 112);
      final pixels = <int>[
        for (final p in small)
          // ARGB, and a transparent pixel says nothing about the cover.
          if (p.a > 0) (p.a.toInt() << 24) | (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt(),
      ];
      if (pixels.isEmpty) return null;
      final result = await mcu.QuantizerCelebi().quantize(pixels, 128);
      final ranked = mcu.Score.score(result.colorToCount, desired: 1);
      return ranked.first;
    }).catchError((Object _) => null);

/// Colours taken from a cover, kept so revisiting a song is instant.
Future<ColorScheme> coverScheme(String path, Brightness brightness) {
  final key = _key(path, brightness);
  return _schemes[key] ??= _seedOf(path).then((seed) {
    if (seed == null) throw StateError('No colour in $path');
    return _ready[key] = ColorScheme.fromSeed(seedColor: Color(seed), brightness: brightness);
  });
}

/// The colours for [path], if they've already been worked out.
ColorScheme? coverSchemeNow(String? path, Brightness brightness) =>
    path == null ? null : _ready[_key(path, brightness)];

/// A dark theme in a cover's colours, for surfaces tinted by it.
ThemeData coverDarkTheme(ColorScheme scheme) => _themes[scheme] ??= buildTheme(scheme, amoled: false);

/// Builds with the colours of the cover at [path]. Keeps the last cover's colours
/// until the new ones are ready, so a change never flashes the plain theme. Null
/// only when there's nothing to show yet.
class CoverColors extends StatefulWidget {
  const CoverColors({super.key, required this.path, required this.brightness, required this.builder});
  final String? path;
  final Brightness brightness;
  final Widget Function(BuildContext, ColorScheme?) builder;

  @override
  State<CoverColors> createState() => _CoverColorsState();
}

class _CoverColorsState extends State<CoverColors> {
  ColorScheme? _scheme;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CoverColors old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.brightness != widget.brightness) _load();
  }

  void _load() {
    final path = widget.path, brightness = widget.brightness;
    if (path == null) {
      _scheme = null;
      return;
    }
    final ready = coverSchemeNow(path, brightness);
    if (ready != null) {
      _scheme = ready;
      return;
    }
    coverScheme(path, brightness).then((s) {
      if (mounted && widget.path == path && widget.brightness == brightness) setState(() => _scheme = s);
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _scheme);
}
