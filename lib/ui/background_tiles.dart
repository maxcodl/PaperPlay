import 'dart:io';

import 'package:flutter/material.dart';

import '../app.dart';
import 'widgets.dart';

/// Settings for staying alive once the app is out of sight.
class BackgroundTiles extends StatefulWidget {
  const BackgroundTiles({super.key});

  @override
  State<BackgroundTiles> createState() => _BackgroundTilesState();
}

class _BackgroundTilesState extends State<BackgroundTiles> with WidgetsBindingObserver {
  Future<bool?>? _unrestricted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from Android's own screens, where the answer may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  void _check() {
    if (Platform.isAndroid) setState(() => _unrestricted = app.background.batteryUnrestricted());
  }

  Future<void> _toggle(bool on) async {
    await app.background.setKeepRunning(on);
    if (on && Platform.isAndroid) {
      await app.background.askNotifications();
      if (await app.background.batteryUnrestricted() != true) await app.background.askBatteryExemption();
      _check();
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: app.background.keepRunning,
        builder: (context, on, _) => Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.layers_rounded),
              title: Row(children: [Flexible(child: Text('Keep running in the background')), const SizedBox(width: 4), InfoText(Platform.isWindows
                    ? "Closing the window just hides it in the tray, so music and syncing keep going. Quit from the tray icon."
                    : "Keeps a notification up so Android doesn't kill the app while it syncs and files songs.")]),
              value: on,
              onChanged: _toggle,
            ),
            if (Platform.isAndroid) ...[
              FutureBuilder<bool?>(
                future: _unrestricted,
                builder: (context, snap) {
                  final ok = snap.data == true;
                  return ListTile(
                    leading: Icon(ok ? Icons.battery_full_rounded : Icons.battery_alert_rounded),
                    title: const Text('Battery limits'),
                    subtitle: Text(ok ? 'Unrestricted' : 'Android may stop Paper Play to save battery. Tap to allow it.'),
                    onTap: ok
                        ? null
                        : () async {
                            await app.background.askBatteryExemption();
                            _check();
                          },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_applications_rounded),
                title: const Text('Your phone\'s own limits'),
                subtitle: const Text(
                  'Many phones also stop apps by themselves. Open the app\'s settings, turn Auto-launch on and '
                  'set Battery to Unrestricted, then lock Paper Play in recent apps.',
                ),
                onTap: app.background.openAppSettings,
              ),
            ],
          ],
        ),
      );
}
