import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/library/profile_stats.dart';
import 'package:teleplayer/ui/glass/glass_style.dart';
import 'package:teleplayer/ui/glass/nav_style.dart';

void main() {
  group('glass style', () {
    test('defaults are the clear glass the owner tuned, with no shadow field at all', () {
      const g = GlassStyle();
      expect([g.blur, g.lensHeight, g.lensAmount, g.tint, g.depth, g.chromatic], [0, 11, 7, 0, true, true]);
      expect(g.toJson().keys.any((k) => k.toLowerCase().contains('shadow')), isFalse);
    });

    test('saves and loads unchanged', () {
      final g = const GlassStyle().copyWith(blur: 4, edge: EdgeReflection.plain, depth: false, innerAlpha: 0.2);
      expect(GlassStyle.fromJson(g.toJson()), g);
    });

    test('a damaged or old saved value gives a usable style', () {
      final g = GlassStyle.fromJson({'blur': 'lots', 'lensAmount': 9999, 'edge': 'sideways', 'shadowAlpha': 0.5});
      expect(g.blur, const GlassStyle().blur, reason: 'wrong type: the default');
      expect(g.lensAmount, GlassStyle.lensRange.$2, reason: 'held in range');
      expect(g.edge, EdgeReflection.directional);
    });
  });

  group('nav style', () {
    test('radii are percentages held between 0 and 100', () {
      final n = const NavStyle().copyWith(barRadius: 250, selectionRadius: -5);
      expect([n.barRadius, n.selectionRadius], [100, 0]);
    });

    test('saves and loads unchanged, and bad values fall back', () {
      final n = const NavStyle().copyWith(layout: NavLayout.labels, look: SelectionLook.dot, barRadius: 40);
      expect(NavStyle.fromJson(n.toJson()), n);
      expect(NavStyle.fromJson({'layout': 'tower', 'look': 7, 'barRadius': 'x'}), const NavStyle());
    });
  });

  test('profile counts songs, favorites and playlists', () {
    final c = profileCounts(const [], 3);
    expect([c.songs, c.favorites, c.playlists], [0, 0, 3]);
  });
}
