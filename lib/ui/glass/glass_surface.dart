import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../log.dart';
import 'glass_style.dart';

/// The glass lens shader, loaded once at startup.
abstract final class GlassShaders {
  static ui.FragmentProgram? _program;

  static Future<void> load() async {
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
    } catch (e) {
      logEvent('app', 'Glass shader unavailable: ${e.runtimeType}', level: LogLevel.warning);
    }
  }

  /// False where the engine can't filter the backdrop with a shader, such as Windows on
  /// the older renderer. The glass is then blur, tint and a rim, with no refraction.
  static bool get supported => _program != null && ui.ImageFilter.isShaderFilterSupported;
}

/// Frosted glass that bends what's behind it at the edges. Needs a bounded size.
/// [cornerPercent] is 0 to 100 of half the shorter side, so 100 is a full pill.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.style,
    required this.child,
    this.cornerPercent = 100,
    this.tintColor,
    this.debug = false,
    this.fromOutside = true,
    this.circularBend = true,
  });

  final GlassStyle style;
  final Widget child;
  final double cornerPercent;
  final Color? tintColor;

  /// Paints where each pixel thinks it is, for checking the shader.
  final bool debug;

  /// Whether the rim shows what's outside the edge (true) or inside it, and whether the
  /// bend follows a circle's curve or a smooth one. Being tuned by eye.
  final bool fromOutside, circularBend;

  // The blur is a gaussian whose spread is this part of the radius. Tuned by eye.
  static const _sigmaPerRadius = 0.5;
  static const _minSigma = 0.05;

  ui.ImageFilter? _lens(Color tint, double radius, double dpr) {
    if (!GlassShaders.supported) return null;
    final shader = GlassShaders._program!.fragmentShader();
    // The engine fills the first two floats with the backdrop's size.
    var i = 2;
    void set(double v) => shader.setFloat(i++, v);
    set(radius * dpr);
    set(style.lensHeight * dpr);
    set(style.lensAmount * dpr);
    set(style.saturation);
    set(tint.r);
    set(tint.g);
    set(tint.b);
    set(style.tint);
    set(style.depth ? 1 : 0);
    set(style.chromatic ? 1 : 0);
    set(style.edgeWidth * dpr);
    set(style.edgeAlpha);
    set(style.edge.index.toDouble());
    set(style.innerRadius * dpr);
    set(style.innerAlpha);
    set(debug ? 1 : 0);
    set(fromOutside ? 1 : -1);
    set(circularBend ? 0 : 1);
    return ui.ImageFilter.shader(shader);
  }

  @override
  Widget build(BuildContext context) {
    // Lighter than the surface, so any tint veils the colours behind and doesn't darken them.
    final tint = tintColor ??
        Color.lerp(Theme.of(context).colorScheme.surfaceContainerHighest, Colors.white, 0.4)!;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final radius = cornerPercent.clamp(0, 100) / 100 * min(size.width, size.height) / 2;
        final shape = BorderRadius.circular(radius);
        final lens = _lens(tint, radius, dpr);
        // The lens only sees the glass's own area when it runs inside another backdrop filter.
        // On its own it sees the whole screen and finds no edge, so a barely-there blur always
        // sits under it. Seen on a phone: with none, the bend and rim disappeared.
        final sigma = max(style.blur * _sigmaPerRadius, lens != null ? _minSigma : 0.0);
        final blur = sigma > 0 ? ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp) : null;

        Widget glass = child;
        if (lens != null) {
          glass = BackdropFilter(filter: lens, child: glass);
          if (blur != null) glass = BackdropFilter(filter: blur, child: glass);
        } else {
          glass = DecoratedBox(
            decoration: BoxDecoration(
              color: tint.withValues(alpha: style.tint),
              borderRadius: shape,
              border: style.edgeWidth > 0
                  ? Border.all(color: Colors.white.withValues(alpha: 0.35 * style.edgeAlpha), width: style.edgeWidth)
                  : null,
            ),
            child: glass,
          );
          // No saturation here: the engine has no colour filter for a backdrop. The fallback is
          // blur, tint and rim.
          if (blur != null) glass = BackdropFilter(filter: blur, child: glass);
        }
        // No shadow, anywhere: just the glass.
        return ClipRRect(borderRadius: shape, child: glass);
      },
    );
  }
}
