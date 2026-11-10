import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'activity.dart';
import 'library/db.dart';
import 'log.dart';
import 'playback/player.dart';

/// Keeps the app working once it's out of sight. On Windows the window hides in the
/// system tray instead of closing. On Android a notification keeps the process in the
/// foreground, and the person can exempt it from battery limits.
///
/// Phone makers add their own killers on top of Android's, and no code can switch
/// those off. The settings screen sends the person to where they are.
class Background with TrayListener, WindowListener {
  Background(this._db, this._player, {required this.activity});

  final AppDb _db;
  final PlayerController _player;

  /// What the app is doing right now, shown in the notification and the tray tooltip.
  final ActivitySummary Function() activity;
  String? _lastPushed;

  static const _key = 'keep_running';
  static const _channel = MethodChannel('teleplayer/background');

  final keepRunning = ValueNotifier(true);

  /// What a notification tap asked to open while the app was running (`tasks`, `copy:...`).
  final opened = StreamController<String>.broadcast();

  Future<void> start() async {
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'open' && call.arguments is String) opened.add(call.arguments as String);
      });
    }
    keepRunning.value = await _db.pref(_key) != 'false';
    if (Platform.isWindows) {
      await _startTray();
    } else if (Platform.isAndroid && keepRunning.value) {
      await _android('start');
    }
    unawaited(_loop());
  }

  /// Looks every 2 s while the app is busy and every 15 s when idle, so a resting app
  /// isn't woken twice a second to find nothing changed.
  Future<void> _loop() async {
    while (true) {
      try {
        await _push();
      } catch (_) {
        // Next round.
      }
      await Future<void>.delayed(activity().busy ? const Duration(seconds: 2) : const Duration(seconds: 15));
    }
  }

  Future<void> setKeepRunning(bool on) async {
    keepRunning.value = on;
    await _db.setPref(_key, '$on');
    logEvent('app', on ? 'Keeping running in the background' : 'No longer keeping running in the background');
    if (Platform.isWindows) await windowManager.setPreventClose(on);
    if (Platform.isAndroid) {
      await _android(on ? 'start' : 'stop');
      _lastPushed = null; // A new notification needs the current status.
    }
  }

  /// Shows what the app is doing in the notification, or on Windows the tray tooltip. Only
  /// when it changed, so a busy app doesn't redraw it for nothing.
  var _pushedAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _push() async {
    final a = activity();
    // Android drops updates when an app posts too often (the player's notification
    // counts too), so the same text is still resent now and then, or a dropped one
    // would leave the notification stuck on an old reading.
    final now = DateTime.now();
    if (a.key == _lastPushed && now.difference(_pushedAt) < const Duration(seconds: 10)) return;
    _lastPushed = a.key;
    _pushedAt = now;
    if (Platform.isAndroid) {
      if (!keepRunning.value) return;
      final measured = a.done != null && a.total != null && a.total! > 0;
      await _android('update', {
        'title': a.title,
        'text': a.detail,
        'progress': measured ? a.done : null,
        'max': measured ? a.total : null,
        'indeterminate': a.busy && !measured,
      });
    } else if (Platform.isWindows) {
      final tip = a.busy ? 'Paper Play: ${a.title}' : 'Paper Play';
      await trayManager.setToolTip(tip.length > 120 ? '${tip.substring(0, 117)}...' : tip);
    }
  }

  /// Null off Android, or if Android doesn't answer.
  Future<T?> _android<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } catch (e) {
      // Not available when Android woke the app without a screen.
      logEvent('app', 'Background $method: ${e.runtimeType}', level: LogLevel.warning);
      return null;
    }
  }

  /// Whether the phone is on a charger. Null off Android.
  Future<bool?> charging() => _android<bool>('charging');
  Future<bool?> batteryUnrestricted() => _android<bool>('batteryExempt');
  Future<bool?> askBatteryExemption() => _android<bool>('requestBatteryExemption');
  Future<bool?> openAppSettings() => _android<bool>('openAppSettings');

  /// The copying notification, separate from the main one. Null [max] marks it finished.
  Future<void> copyNotify(String title, String text, {int? progress, int? max, required String open}) async {
    if (!Platform.isAndroid) return;
    await _android('copyProgress', {'title': title, 'text': text, 'progress': progress, 'max': max, 'open': open});
  }

  /// What a tapped notification asked to open, once.
  Future<String?> takeOpen() => Platform.isAndroid ? _android<String>('takeOpen') : Future.value();
  /// Lets the person choose where to put the file at [path] and copies it there from disk, so a
  /// large file never goes through memory. True when saved; false if they backed out or it failed.
  Future<bool> saveFile(String name, String path) async => await _android<bool>('saveFile', {'name': name, 'path': path}) == true;

  Future<bool?> askNotifications() => _android<bool>('requestNotifications');

  // Windows.

  Future<void> _startTray() async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(keepRunning.value);
    windowManager.addListener(this);
    await trayManager.setIcon('assets/icon/tray.ico');
    await trayManager.setToolTip('Paper Play');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'Show Paper Play'),
          MenuItem.separator(),
          MenuItem(key: 'toggle', label: 'Play / Pause'),
          MenuItem(key: 'next', label: 'Next'),
          MenuItem(key: 'previous', label: 'Previous'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      ),
    );
    trayManager.addListener(this);
  }

  Future<void> _show() async {
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    logEvent('app', 'Quit from the tray');
    await appLog.flush();
    await windowManager.setPreventClose(false);
    await trayManager.destroy();
    await windowManager.destroy();
  }

  @override
  void onWindowClose() async {
    // Only called while closing is prevented, which is while keep running is on.
    await windowManager.hide();
    logEvent('app', 'Hidden in the system tray');
  }

  @override
  void onTrayIconMouseDown() => _show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem item) {
    final out = _player.out;
    switch (item.key) {
      case 'show':
        _show();
      case 'toggle':
        out.playing ? out.pause() : out.play();
      case 'next':
        out.seekToNext();
      case 'previous':
        out.seekToPrevious();
      case 'quit':
        _quit();
    }
  }
}
