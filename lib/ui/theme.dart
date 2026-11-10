import 'package:flutter/material.dart';
import 'package:m3e_design/m3e_design.dart';

import 'look.dart';

/// Material 3 Expressive's fast spatial easing: it overshoots slightly, then settles.
const expressiveSpring = Cubic(0.42, 1.67, 0.21, 0.90);

const fallbackSeed = Color(0xFF7C5CFF);

/// True-black surfaces for OLED, with containers stepping up so cards stay visible.
ColorScheme _amoled(ColorScheme s) => s.copyWith(
      surface: Colors.black,
      surfaceDim: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF101010),
      surfaceContainer: const Color(0xFF1B1B1B),
      surfaceContainerHigh: const Color(0xFF232323),
      surfaceContainerHighest: const Color(0xFF2C2C2C),
      surfaceBright: const Color(0xFF343434),
    );

TextStyle? _w(TextStyle? style, double weight) => style?.copyWith(
      fontFamily: 'Nunito',
      // Nunito is a variable font, so weights must be set as variations too.
      fontVariations: [FontVariation('wght', weight)],
      fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
    );

TextTheme _nunito(TextTheme t) => t.copyWith(
      displayLarge: _w(t.displayLarge, 800),
      displayMedium: _w(t.displayMedium, 800),
      displaySmall: _w(t.displaySmall, 800),
      headlineLarge: _w(t.headlineLarge, 800),
      headlineMedium: _w(t.headlineMedium, 800),
      headlineSmall: _w(t.headlineSmall, 700),
      titleLarge: _w(t.titleLarge, 700),
      titleMedium: _w(t.titleMedium, 700),
      titleSmall: _w(t.titleSmall, 700),
      bodyLarge: _w(t.bodyLarge, 500),
      bodyMedium: _w(t.bodyMedium, 500),
      bodySmall: _w(t.bodySmall, 500),
      labelLarge: _w(t.labelLarge, 700),
      labelMedium: _w(t.labelMedium, 700),
      labelSmall: _w(t.labelSmall, 700),
    );

/// [seeThrough] leaves pages and bars unpainted, so a background behind the whole app (the
/// cover gradient) shows through them.
ThemeData buildTheme(
  ColorScheme base, {
  bool amoled = true,
  bool seeThrough = false,
  Map<LookGroup, Look> looks = const {},
}) {
  bool glass(LookGroup g) => looks[g] == Look.glass;
  final dark = base.brightness == Brightness.dark;
  final scheme = dark && amoled ? _amoled(base) : base;
  final type = Typography.material2021(platform: TargetPlatform.android);
  // white and black only set colours; englishLike adds the sizes. Styles read
  // directly from here, like the app bar title, would be tiny without it.
  final text = _nunito(type.englishLike.merge(dark ? type.white : type.black))
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  // Glass: a veil over what's behind, with a faint light rim. Material: solid tonal colour.
  Color veil(Color c, bool g) => g ? c.withValues(alpha: 0.55) : c;
  BorderSide rim(bool g) => g ? BorderSide(color: Colors.white.withValues(alpha: 0.18)) : BorderSide.none;
  final overlays = glass(LookGroup.overlays), cards = glass(LookGroup.cards), bars = glass(LookGroup.bars);
  final round = RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: rim(overlays));
  return withM3ETheme(
    ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: seeThrough ? Colors.transparent : scheme.surface,
      textTheme: text,
      pageTransitionsTheme: const PageTransitionsTheme(
        // The page follows your finger during a back swipe on Android 14+.
        builders: {TargetPlatform.android: PredictiveBackPageTransitionsBuilder()},
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: seeThrough || bars ? Colors.transparent : scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: text.headlineMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        height: 76,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      cardTheme: CardThemeData(
        color: veil(scheme.surfaceContainerLow, cards),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: rim(cards)),
      ),
      dialogTheme: DialogThemeData(backgroundColor: veil(scheme.surfaceContainerHigh, overlays), shape: round),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: veil(scheme.surfaceContainer, overlays),
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: rim(overlays),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: veil(scheme.surfaceContainerHigh, overlays),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: rim(overlays)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}
