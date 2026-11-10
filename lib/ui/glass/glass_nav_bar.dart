import 'package:flutter/material.dart';

import '../../app.dart';
import '../look.dart';
import 'glass_surface.dart';
import 'nav_style.dart';

class NavEntry {
  const NavEntry({required this.icon, required this.selectedIcon, required this.label});
  final IconData icon, selectedIcon;
  final String label;
}

/// The bottom bar. Floating, it is glass; standard, it spans the width on a plain surface.
/// Either way, how it's laid out comes from [NavStyle] (live from the settings), and the
/// glass look from `GlassStyle` applies to the floating bar only.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.floating = true,
  });

  final List<NavEntry> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool floating;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([app.ui.navStyle, app.ui.glass, app.ui.looks[LookGroup.nav]!]),
        builder: (context, _) {
          final nav = app.ui.navStyle.value;
          final withLabels = nav.layout == NavLayout.labels || nav.layout == NavLayout.dock;
          final side = nav.layout == NavLayout.dock ? 12.0 : 24.0;
          final isGlass = app.ui.look(LookGroup.nav) == Look.glass;
          // Glass, or the plain tonal surface of Material 3.
          Widget surface(double corner, Widget child) => isGlass
              ? GlassSurface(style: app.ui.glass.value, cornerPercent: corner, child: child)
              : LayoutBuilder(
                  builder: (context, box) => Material(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(corner.clamp(0, 100) / 100 * box.biggest.shortestSide / 2),
                    child: child,
                  ),
                );
          final row = Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final (i, item) in items.indexed)
                withLabels && nav.layout == NavLayout.dock
                    ? Expanded(child: _Item(item: item, selected: i == selected, nav: nav, onTap: () => onSelected(i)))
                    : _Item(item: item, selected: i == selected, nav: nav, onTap: () => onSelected(i)),
            ],
          );
          if (!floating) {
            // Docked to the bottom and the edges, as glass like the floating bar: only the
            // top corners round, and the bar covers the safe area under it.
            final top = Radius.circular(28 * nav.barRadius / 100);
            final inset = MediaQuery.paddingOf(context).bottom;
            return SizedBox(
              height: (withLabels ? 76 : 64) + inset,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: top),
                child: surface(
                  0,
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, 6, 12, 6 + inset),
                    child: Material(type: MaterialType.transparency, child: row),
                  ),
                ),
              ),
            );
          }
          return SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(side, 0, side, 12),
            child: SizedBox(
              height: withLabels ? 76 : 64,
              child: surface(
                nav.barRadius,
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Material(type: MaterialType.transparency, child: row),
                ),
              ),
            ),
          );
        },
      );
}

class _Item extends StatelessWidget {
  const _Item({required this.item, required this.selected, required this.nav, required this.onTap});

  final NavEntry item;
  final bool selected;
  final NavStyle nav;
  final VoidCallback onTap;

  // The most a selection's corners can round: half an item's height.
  static const _fullRound = 28.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final look = nav.look;
    final filled = look == SelectionLook.fill;
    final ink = selected ? (filled ? scheme.onPrimaryContainer : scheme.primary) : scheme.onSurface;
    final radius = BorderRadius.circular(_fullRound * nav.selectionRadius / 100);

    final icon = AnimatedScale(
      scale: selected ? 1.18 : 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      child: Icon(selected ? item.selectedIcon : item.icon, color: ink),
    );
    final name = Text(
      item.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ink, fontWeight: selected ? FontWeight.w700 : null),
    );

    final (Widget content, EdgeInsets padding) = switch (nav.layout) {
      NavLayout.pill => (
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                if (selected) ...[
                  const SizedBox(width: 8),
                  Text(item.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: ink)),
                ],
              ],
            ),
          ),
          EdgeInsets.symmetric(horizontal: selected ? 20 : 16, vertical: 12),
        ),
      NavLayout.icons => (icon, const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
      NavLayout.labels || NavLayout.dock => (
          Column(mainAxisSize: MainAxisSize.min, children: [icon, const SizedBox(height: 2), name]),
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
    };

    final box = switch ((selected, look)) {
      (true, SelectionLook.fill) => BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.9), borderRadius: radius),
      (true, SelectionLook.ring) => BoxDecoration(border: Border.all(color: scheme.primary, width: 1.5), borderRadius: radius),
      (true, SelectionLook.soft) => BoxDecoration(color: scheme.onSurface.withValues(alpha: 0.16), borderRadius: radius),
      _ => BoxDecoration(borderRadius: radius),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: padding,
          decoration: box,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              content,
              if (selected && look == SelectionLook.dot)
                Positioned(
                  bottom: -7,
                  child: Container(width: 5, height: 5, decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
