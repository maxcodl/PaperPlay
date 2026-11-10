import 'dart:math';

import 'package:flutter/material.dart';

import '../library/audio_info.dart';
import '../library/db.dart';

/// A small mark for a quality tier, drawn in the surrounding text colour. Waves for
/// lossless, with one more for Hi-Res; bars for lossy, with one more for high quality.
class QualityGlyph extends StatelessWidget {
  const QualityGlyph(this.tier, {super.key, this.size = 14, this.color});
  final QualityTier tier;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: _GlyphPainter(tier, color ?? DefaultTextStyle.of(context).style.color ?? IconTheme.of(context).color!),
        ),
      );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.tier, this.color);
  final QualityTier tier;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.height * 0.12;
    switch (tier) {
      case QualityTier.hiRes:
        _waves(canvas, size, pen, const [0.2, 0.5, 0.8]);
      case QualityTier.lossless:
        _waves(canvas, size, pen, const [0.32, 0.68]);
      case QualityTier.high:
        _bars(canvas, size, pen, const [0.4, 0.8, 0.55, 1]);
      case QualityTier.standard:
        _bars(canvas, size, pen, const [0.4, 0.8, 0.55]);
    }
  }

  void _waves(Canvas canvas, Size size, Paint pen, List<double> rows) {
    final inset = pen.strokeWidth / 2;
    final width = size.width - inset * 2;
    final height = size.height * 0.09;
    for (final row in rows) {
      final path = Path();
      for (var i = 0; i <= 24; i++) {
        final t = i / 24;
        final x = inset + t * width;
        final y = size.height * row + sin(t * 2 * pi) * height;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, pen);
    }
  }

  void _bars(Canvas canvas, Size size, Paint pen, List<double> heights) {
    final step = size.width / heights.length;
    for (var i = 0; i < heights.length; i++) {
      final x = step * (i + 0.5);
      final half = (size.height - pen.strokeWidth) * heights[i] / 2;
      canvas.drawLine(Offset(x, size.height / 2 - half), Offset(x, size.height / 2 + half), pen);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.tier != tier || old.color != color;
}

/// A song's quality: mark and format in lists, with the details in the player.
class QualityLabel extends StatelessWidget {
  const QualityLabel(this.song, {super.key, this.detailed = false, this.style, this.color});
  final Song song;
  final bool detailed;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = detailed ? qualityLine(song) : songFormat(song);
    final resolved = (style ?? DefaultTextStyle.of(context).style).copyWith(color: color ?? style?.color);
    return Semantics(
      label: '${songTier(song).label}, $text',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          QualityGlyph(songTier(song), size: (resolved.fontSize ?? 12) * 1.1, color: resolved.color),
          const SizedBox(width: 4),
          Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: resolved),
        ],
      ),
    );
  }
}
