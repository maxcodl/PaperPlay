import 'dart:math';

import 'package:flutter/material.dart';

/// Seek bar in the Material 3 Expressive style: the played part is a moving
/// wave while audio plays and flattens when paused. Also shows what's buffered.
class WavySeek extends StatefulWidget {
  const WavySeek({
    super.key,
    required this.value,
    required this.buffered,
    required this.playing,
    required this.onSeek,
    this.label,
  });

  /// Played and buffered shares, 0 to 1.
  final double value, buffered;
  final bool playing;
  final ValueChanged<double>? onSeek;
  final String? label;

  @override
  State<WavySeek> createState() => _WavySeekState();
}

class _WavySeekState extends State<WavySeek> with TickerProviderStateMixin {
  late final _phase = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  late final _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: widget.playing ? 1 : 0,
  );
  double? _dragging;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(WavySeek old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) _sync();
  }

  void _sync() {
    final moving = widget.playing && _dragging == null;
    moving ? _phase.repeat() : _phase.stop();
    moving ? _wave.forward() : _wave.reverse();
  }

  @override
  void dispose() {
    _phase.dispose();
    _wave.dispose();
    super.dispose();
  }

  double _at(Offset local, double width) => (local.dx / width).clamp(0.0, 1.0);

  void _start(double v) {
    setState(() => _dragging = v);
    _sync();
  }

  void _end() {
    final v = _dragging;
    setState(() => _dragging = null);
    _sync();
    if (v != null) widget.onSeek?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = (_dragging ?? widget.value).clamp(0.0, 1.0);
    return Semantics(
      label: 'Seek',
      value: widget.label,
      slider: true,
      child: LayoutBuilder(
        builder: (context, box) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _start(_at(d.localPosition, box.maxWidth)),
          onHorizontalDragUpdate: (d) => setState(() => _dragging = _at(d.localPosition, box.maxWidth)),
          onHorizontalDragEnd: (_) => _end(),
          onTapDown: (d) => _start(_at(d.localPosition, box.maxWidth)),
          onTapUp: (_) => _end(),
          onTapCancel: () => setState(() => _dragging = null),
          child: RepaintBoundary(
            child: SizedBox(
              height: 36,
              width: double.infinity,
              child: CustomPaint(
                painter: _WavePainter(
                  phase: _phase,
                  wave: _wave,
                  value: value,
                  buffered: widget.buffered.clamp(0.0, 1.0),
                  active: scheme.primary,
                  track: scheme.onSurface.withValues(alpha: 0.16),
                  bufferedColor: scheme.onSurface.withValues(alpha: 0.34),
                  thumb: _dragging != null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.phase,
    required this.wave,
    required this.value,
    required this.buffered,
    required this.active,
    required this.track,
    required this.bufferedColor,
    required this.thumb,
  }) : super(repaint: Listenable.merge([phase, wave]));

  final Animation<double> phase, wave;
  final double value, buffered;
  final Color active, track, bufferedColor;
  final bool thumb;

  static const _stroke = 5.0, _amplitude = 3.5, _wavelength = 34.0, _gap = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final x = value * size.width;
    Paint line(Color c) => Paint()
      ..color = c
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final trackStart = min(x + _gap, size.width);
    if (trackStart < size.width) {
      canvas.drawLine(Offset(trackStart, mid), Offset(size.width, mid), line(track));
      final bufferedEnd = buffered * size.width;
      if (bufferedEnd > trackStart) {
        canvas.drawLine(Offset(trackStart, mid), Offset(bufferedEnd, mid), line(bufferedColor));
      }
    }

    final amplitude = _amplitude * wave.value;
    final path = Path()..moveTo(0, mid);
    for (var px = 2.0; px <= x; px += 2) {
      // Tapers to flat at the thumb, so the wave meets it cleanly.
      final taper = min(1.0, (x - px) / 12);
      final y = sin((px / _wavelength - phase.value) * 2 * pi) * amplitude * taper;
      path.lineTo(px, mid + y);
    }
    path.lineTo(x, mid);
    canvas.drawPath(path, line(active));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, mid), width: 6, height: thumb ? 30 : 22),
        const Radius.circular(3),
      ),
      Paint()..color = active,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.value != value ||
      old.buffered != buffered ||
      old.active != active ||
      old.thumb != thumb;
}
