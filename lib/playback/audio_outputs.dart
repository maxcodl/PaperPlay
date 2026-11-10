import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:media_kit/media_kit.dart';

import '../library/db.dart';

enum OutputKind { speaker, bluetooth, wired, usb, other }

/// A sound device this device could play through.
class SoundOutput {
  const SoundOutput(this.id, this.name, this.kind);
  final String id, name;
  final OutputKind kind;
}

/// Where this device's sound comes out.
///
/// Windows lets an app choose, through its player. Android doesn't let a media
/// app switch routes itself, so it reports the current one and opens the system's
/// own switcher.
class SoundOutputs {
  SoundOutputs(this._db);

  final AppDb _db;
  static const _channel = MethodChannel('teleplayer/audio_output');
  static const _deviceKey = 'audio_device';

  /// The name of the device in use; null while unknown.
  final current = ValueNotifier<SoundOutput?>(null);

  /// What can be chosen here. Empty on Android, where the system chooses.
  final available = ValueNotifier<List<SoundOutput>>(const []);

  Player? _player;

  /// Told when the Windows player exists.
  void Function(Player)? onNativePlayer;

  void start() {
    if (Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'changed') _showRoute(call.arguments as Map<Object?, Object?>?);
      });
      unawaited(_refreshRoute());
    } else if (Platform.isWindows) {
      // Set before the first player exists, which is created on first use.
      JustAudioMediaKit.onPlayerCreated = (p) => unawaited(_attach(p));
      // The real player doesn't exist until a song plays, and the list should
      // be there before that. This one only reads the devices, and never plays.
      final lister = Player();
      _lister = lister;
      lister.stream.audioDevices.listen(_showDevices);
      _showDevices(lister.state.audioDevices);
      unawaited(_restoreChoice());
    }
  }

  Player? _lister;

  void _showDevices(List<AudioDevice> devices) {
    // mpv also lists its other sound backends, which aren't devices.
    available.value = [
      for (final d in devices)
        if (d.name == 'auto' || d.name.startsWith('wasapi/')) _describe(d),
    ];
    final id = _chosen ?? 'auto';
    current.value = available.value.where((d) => d.id == id).firstOrNull ?? current.value;
  }

  String? _chosen;

  Future<void> _restoreChoice() async {
    _chosen = await _db.pref(_deviceKey);
    final lister = _lister;
    if (lister != null) _showDevices(lister.state.audioDevices);
  }

  Future<void> _refreshRoute() async {
    try {
      _showRoute(await _channel.invokeMethod<Map<Object?, Object?>>('current'));
    } on MissingPluginException {
      // Older build of the native side.
    }
  }

  void _showRoute(Map<Object?, Object?>? route) {
    if (route == null) return;
    current.value = SoundOutput(
      '',
      route['name'] as String? ?? 'This phone',
      OutputKind.values.byName(route['kind'] as String? ?? 'other'),
    );
  }

  Future<void> _attach(Player player) async {
    _player = player;
    onNativePlayer?.call(player);
    final saved = _chosen ?? await _db.pref(_deviceKey);
    if (saved != null) await player.setAudioDevice(AudioDevice(saved, ''));
  }

  static SoundOutput _describe(AudioDevice d) => SoundOutput(
        d.name,
        d.name == 'auto' || d.description.isEmpty ? 'System default' : d.description,
        _guessKind(d.description),
      );

  /// Windows device names are all that say what a device is.
  static OutputKind _guessKind(String description) {
    final d = description.toLowerCase();
    if (d.contains('bluetooth') || d.contains('hands-free') || d.contains('buds') || d.contains('airpods')) {
      return OutputKind.bluetooth;
    }
    if (d.contains('headphone') || d.contains('headset')) return OutputKind.wired;
    if (d.contains('usb')) return OutputKind.usb;
    if (d.contains('speaker') || d.isEmpty) return OutputKind.speaker;
    return OutputKind.other;
  }

  /// Plays through [output] here, and remembers it on this device.
  Future<void> select(SoundOutput output) async {
    _chosen = output.id;
    current.value = output;
    await _player?.setAudioDevice(AudioDevice(output.id, output.name));
    await _db.setPref(_deviceKey, output.id);
  }

  /// Opens the system's output switcher. Returns false if there isn't one.
  Future<bool> openSystemSwitcher() async => await _invoke('openSwitcher');

  Future<bool> openBluetoothSettings() async => await _invoke('openBluetooth');

  Future<bool> _invoke(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
