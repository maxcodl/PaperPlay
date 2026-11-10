import 'package:flutter/foundation.dart';

enum EdgeReflection {
  directional('Directional'),
  ambient('Ambient'),
  plain('Plain');

  const EdgeReflection(this.label);
  final String label;
}

/// How the glass looks. Distances are in logical pixels. The defaults and ranges are the
/// ones the owner settled on in their other app. There's no shadow, by their choice.
@immutable
class GlassStyle {
  // Clear glass: the owner tuned these on a phone. Not the other app's defaults.
  const GlassStyle({
    this.blur = 0,
    this.lensHeight = 11,
    this.lensAmount = 7,
    this.saturation = 1.5,
    this.tint = 0,
    this.depth = true,
    this.chromatic = true,
    this.edgeWidth = 1,
    this.edgeAlpha = 1,
    this.edge = EdgeReflection.directional,
    this.innerRadius = 16,
    this.innerAlpha = 0,
  });

  /// Blur radius behind the glass.
  final double blur;

  /// How far in from the edge the lens bends what's behind, and by how much at most.
  final double lensHeight, lensAmount;
  final double saturation;

  /// How much of the surface colour covers the glass, 0 to 1.
  final double tint;

  /// A slight magnification toward the centre.
  final bool depth;

  /// Splits colours apart at the edge, like a real lens.
  final bool chromatic;

  final double edgeWidth, edgeAlpha;
  final EdgeReflection edge;

  /// A soft light along the inside of the edge.
  final double innerRadius, innerAlpha;

  static const blurRange = (0.0, 30.0);
  static const lensRange = (0.0, 48.0);
  static const saturationRange = (0.0, 2.5);
  static const edgeWidthRange = (0.0, 4.0);
  static const glowRadiusRange = (0.0, 40.0);
  static const glowAlphaRange = (0.0, 0.5);

  GlassStyle copyWith({
    double? blur,
    double? lensHeight,
    double? lensAmount,
    double? saturation,
    double? tint,
    bool? depth,
    bool? chromatic,
    double? edgeWidth,
    double? edgeAlpha,
    EdgeReflection? edge,
    double? innerRadius,
    double? innerAlpha,
  }) =>
      GlassStyle(
        blur: blur ?? this.blur,
        lensHeight: lensHeight ?? this.lensHeight,
        lensAmount: lensAmount ?? this.lensAmount,
        saturation: saturation ?? this.saturation,
        tint: tint ?? this.tint,
        depth: depth ?? this.depth,
        chromatic: chromatic ?? this.chromatic,
        edgeWidth: edgeWidth ?? this.edgeWidth,
        edgeAlpha: edgeAlpha ?? this.edgeAlpha,
        edge: edge ?? this.edge,
        innerRadius: innerRadius ?? this.innerRadius,
        innerAlpha: innerAlpha ?? this.innerAlpha,
      );

  /// Every value held inside its range, so a bad saved value can't break the shader.
  GlassStyle clamped() => GlassStyle(
        blur: blur.clamp(blurRange.$1, blurRange.$2),
        lensHeight: lensHeight.clamp(lensRange.$1, lensRange.$2),
        lensAmount: lensAmount.clamp(lensRange.$1, lensRange.$2),
        saturation: saturation.clamp(saturationRange.$1, saturationRange.$2),
        tint: tint.clamp(0.0, 1.0),
        depth: depth,
        chromatic: chromatic,
        edgeWidth: edgeWidth.clamp(edgeWidthRange.$1, edgeWidthRange.$2),
        edgeAlpha: edgeAlpha.clamp(0.0, 1.0),
        edge: edge,
        innerRadius: innerRadius.clamp(glowRadiusRange.$1, glowRadiusRange.$2),
        innerAlpha: innerAlpha.clamp(glowAlphaRange.$1, glowAlphaRange.$2),
      );

  Map<String, dynamic> toJson() => {
        'blur': blur,
        'lensHeight': lensHeight,
        'lensAmount': lensAmount,
        'saturation': saturation,
        'tint': tint,
        'depth': depth,
        'chromatic': chromatic,
        'edgeWidth': edgeWidth,
        'edgeAlpha': edgeAlpha,
        'edge': edge.name,
        'innerRadius': innerRadius,
        'innerAlpha': innerAlpha,
      };

  /// Anything missing or of the wrong type takes its default, so an old or damaged saved
  /// value still gives a usable style.
  factory GlassStyle.fromJson(Map<String, dynamic> json) {
    const d = GlassStyle();
    double num_(String key, double fallback) => json[key] is num ? (json[key] as num).toDouble() : fallback;
    return GlassStyle(
      blur: num_('blur', d.blur),
      lensHeight: num_('lensHeight', d.lensHeight),
      lensAmount: num_('lensAmount', d.lensAmount),
      saturation: num_('saturation', d.saturation),
      tint: num_('tint', d.tint),
      depth: json['depth'] is bool ? json['depth'] as bool : d.depth,
      chromatic: json['chromatic'] is bool ? json['chromatic'] as bool : d.chromatic,
      edgeWidth: num_('edgeWidth', d.edgeWidth),
      edgeAlpha: num_('edgeAlpha', d.edgeAlpha),
      edge: EdgeReflection.values.where((e) => e.name == json['edge']).firstOrNull ?? d.edge,
      innerRadius: num_('innerRadius', d.innerRadius),
      innerAlpha: num_('innerAlpha', d.innerAlpha),
    ).clamped();
  }

  @override
  bool operator ==(Object other) =>
      other is GlassStyle &&
      other.blur == blur &&
      other.lensHeight == lensHeight &&
      other.lensAmount == lensAmount &&
      other.saturation == saturation &&
      other.tint == tint &&
      other.depth == depth &&
      other.chromatic == chromatic &&
      other.edgeWidth == edgeWidth &&
      other.edgeAlpha == edgeAlpha &&
      other.edge == edge &&
      other.innerRadius == innerRadius &&
      other.innerAlpha == innerAlpha;

  @override
  int get hashCode => Object.hash(
        blur, lensHeight, lensAmount, saturation, tint, depth, chromatic,
        edgeWidth, edgeAlpha, edge, innerRadius, innerAlpha,
      );
}
