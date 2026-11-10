import 'package:flutter/material.dart';

import '../app.dart';
import 'cover_colors.dart';

/// Behind the whole app when "Cover gradient background" is on: the colours of the song's
/// cover at the top, fading into the plain background lower down. Follows the song, and
/// keeps the last cover's colours until the next one is ready.
class CoverGradient extends StatelessWidget {
  const CoverGradient({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: app.ui.coverGradient,
        builder: (context, on, _) => !on
            ? child
            : ValueListenableBuilder(
                valueListenable: app.player.current,
                builder: (context, song, _) {
                  final theme = Theme.of(context);
                  return CoverColors(
                    path: song?.coverPath,
                    brightness: theme.brightness,
                    builder: (context, cover) {
                      final base = theme.colorScheme.surface;
                      // The container colour is the deep one in dark mode and the pale one in light.
                      final tint = (cover ?? theme.colorScheme).primaryContainer;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color.alphaBlend(tint.withValues(alpha: 0.85), base),
                                  Color.alphaBlend(tint.withValues(alpha: 0.32), base),
                                  base,
                                ],
                                stops: const [0, 0.45, 1],
                              ),
                            ),
                          ),
                          child,
                        ],
                      );
                    },
                  );
                },
              ),
      );
}
