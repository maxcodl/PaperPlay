import 'package:flutter/material.dart';

import '../../app.dart';
import 'glass_style.dart';
import 'glass_nav_bar.dart';
import 'nav_style.dart';

/// A labelled slider that updates live.
class _SliderRow extends StatelessWidget {
  const _SliderRow(this.label, this.value, this.range, this.unit, this.onChanged);

  final String label, unit;
  final double value;
  final (double, double) range;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = unit == 'dp' || unit == '%' ? value.toStringAsFixed(unit == '%' ? 0 : 0) : value.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              Text(
                unit.isEmpty ? shown : '$shown $unit',
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
          Slider(value: value.clamp(range.$1, range.$2), min: range.$1, max: range.$2, onChanged: onChanged),
        ],
      ),
    );
  }
}

Widget _heading(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );

/// Standard or floating, and how the bar looks in either.
class NavBarSettings extends StatelessWidget {
  const NavBarSettings({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([app.ui.floatingNav, app.ui.navStyle]),
        builder: (context, _) {
          final floating = app.ui.floatingNav.value;
          final nav = app.ui.navStyle.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Preview(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Standard')),
                    ButtonSegment(value: true, label: Text('Floating')),
                  ],
                  selected: {floating},
                  onSelectionChanged: (s) => app.ui.setFloating(s.first),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _heading(context, 'Layout'),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SegmentedButton<NavLayout>(
                              showSelectedIcon: false,
                              segments: [for (final l in NavLayout.values) ButtonSegment(value: l, label: Text(l.label))],
                              selected: {nav.layout},
                              onSelectionChanged: (s) => app.ui.setNavStyle(nav.copyWith(layout: s.first)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Text(nav.layout.hint, style: Theme.of(context).textTheme.bodySmall),
                          ),
                          _SliderRow('Bar radius', nav.barRadius, (0, 100), '%',
                              (v) => app.ui.setNavStyle(nav.copyWith(barRadius: v))),
                          _SliderRow('Selection radius', nav.selectionRadius, (0, 100), '%',
                              (v) => app.ui.setNavStyle(nav.copyWith(selectionRadius: v))),
                          _heading(context, 'Selection look'),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SegmentedButton<SelectionLook>(
                              showSelectedIcon: false,
                              segments: [for (final l in SelectionLook.values) ButtonSegment(value: l, label: Text(l.label))],
                              selected: {nav.look},
                              onSelectionChanged: (s) => app.ui.setNavStyle(nav.copyWith(look: s.first)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Text(nav.look.hint, style: Theme.of(context).textTheme.bodySmall),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      );
}

/// How the floating bar's glass looks, with a preview since the bar isn't on this screen.
class GlassSettings extends StatelessWidget {
  const GlassSettings({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: app.ui.glass,
        builder: (context, g, _) {
          void set(GlassStyle s) => app.ui.setGlass(s);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Preview(),
              _heading(context, 'Material'),
              _SliderRow('Blur', g.blur, GlassStyle.blurRange, 'dp', (v) => set(g.copyWith(blur: v))),
              _SliderRow('Refraction height', g.lensHeight, GlassStyle.lensRange, 'dp', (v) => set(g.copyWith(lensHeight: v))),
              _SliderRow('Refraction amount', g.lensAmount, GlassStyle.lensRange, 'dp', (v) => set(g.copyWith(lensAmount: v))),
              _SliderRow('Colour saturation', g.saturation, GlassStyle.saturationRange, '', (v) => set(g.copyWith(saturation: v))),
              _SliderRow('Tint', g.tint, (0, 1), '', (v) => set(g.copyWith(tint: v))),
              SwitchListTile(
                title: const Text('Depth effect'),
                value: g.depth,
                onChanged: (v) => set(g.copyWith(depth: v)),
              ),
              SwitchListTile(
                title: const Text('Colour fringing'),
                value: g.chromatic,
                onChanged: (v) => set(g.copyWith(chromatic: v)),
              ),
              _heading(context, 'Edge'),
              _SliderRow('Edge line width', g.edgeWidth, GlassStyle.edgeWidthRange, 'dp', (v) => set(g.copyWith(edgeWidth: v))),
              _SliderRow('Edge brightness', g.edgeAlpha, (0, 1), '', (v) => set(g.copyWith(edgeAlpha: v))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Edge reflection', style: Theme.of(context).textTheme.bodyLarge),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SegmentedButton<EdgeReflection>(
                  showSelectedIcon: false,
                  segments: [for (final e in EdgeReflection.values) ButtonSegment(value: e, label: Text(e.label))],
                  selected: {g.edge},
                  onSelectionChanged: (s) => set(g.copyWith(edge: s.first)),
                ),
              ),
              _heading(context, 'Inner glow'),
              _SliderRow('Inner glow size', g.innerRadius, GlassStyle.glowRadiusRange, 'dp', (v) => set(g.copyWith(innerRadius: v))),
              _SliderRow('Inner glow strength', g.innerAlpha, GlassStyle.glowAlphaRange, '', (v) => set(g.copyWith(innerAlpha: v))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: OutlinedButton(
                  onPressed: () => set(const GlassStyle()),
                  child: const Text('Reset to defaults'),
                ),
              ),
            ],
          );
        },
      );
}

/// The real bar, floating or standard as chosen, over stripes so the bending is easy to see
/// while the sliders move. It follows every setting that changes the bar, as it changes.
class _Preview extends StatelessWidget {
  const _Preview();

  static const _items = [
    NavEntry(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
    NavEntry(icon: Icons.search_rounded, selectedIcon: Icons.manage_search_rounded, label: 'Search'),
    NavEntry(icon: Icons.library_music_outlined, selectedIcon: Icons.library_music_rounded, label: 'Library'),
    NavEntry(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([app.ui.floatingNav, app.ui.navStyle, app.ui.glass]),
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 150,
              child: Stack(
                children: [
                  const Positioned.fill(child: CustomPaint(painter: _StripePainter())),
                  Align(
                    alignment: Alignment.bottomCenter,
                    // The page's own bottom inset doesn't belong inside the preview.
                    child: MediaQuery.removePadding(
                      context: context,
                      removeBottom: true,
                      child: GlassNavBar(
                        items: _items,
                        selected: 1,
                        onSelected: (_) {},
                        floating: app.ui.floatingNav.value,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [Color(0xFFE53935), Color(0xFFFB8C00), Color(0xFFFDD835), Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFF8E24AA)];
    const band = 20.0;
    for (var i = 0; i * band < size.height; i++) {
      canvas.drawRect(Rect.fromLTWH(0, i * band, size.width, band), Paint()..color = colors[i % colors.length]);
    }
    final line = Paint()
      ..color = Colors.black
      ..strokeWidth = 3;
    for (var x = 0.0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => false;
}
