import 'package:flutter/material.dart';

import '../app.dart';
import '../playback/equalizer.dart';

String _hz(double f) => f >= 1000 ? '${(f / 1000).toStringAsFixed(f % 1000 == 0 ? 0 : 1)}k' : '${f.round()}';

/// Five-band equalizer for this device.
class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final eq = app.player.equalizer;
    return Scaffold(
      appBar: AppBar(title: const Text('Equalizer')),
      body: ListenableBuilder(
        listenable: Listenable.merge([eq.enabled, eq.gains]),
        builder: (context, _) {
          final g = eq.gains.value;
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Equalizer'),
                subtitle: const Text('This device only'),
                value: eq.enabled.value,
                onChanged: eq.setEnabled,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final e in eqPresets.entries)
                      ChoiceChip(
                        label: Text(e.key),
                        selected: [for (var i = 0; i < 5; i++) (g[i] - e.value[i]).abs() < 0.05].every((b) => b),
                        onSelected: (_) => eq.setGains(e.value),
                      ),
                  ],
                ),
              ),
              for (var i = 0; i < 5; i++)
                ListTile(
                  title: Text('${_hz(eqFreqs[i])} Hz  ·  ${g[i].toStringAsFixed(1)} dB'),
                  subtitle: Slider(
                    min: -eqRange,
                    max: eqRange,
                    divisions: (eqRange * 4).round(),
                    value: g[i],
                    onChanged: eq.enabled.value
                        ? (v) => eq.setGains([...g]..[i] = v)
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
