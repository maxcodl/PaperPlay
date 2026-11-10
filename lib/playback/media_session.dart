import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../library/db.dart';
import 'player.dart';

/// Makes Windows treat the app as a media player. Android's equivalent comes
/// from `just_audio_background`. Controls go through [PlayerController.out], so
/// media keys also work while another device is the output.
class MediaSession {
  MediaSession(this._player);

  final PlayerController _player;
  static const _channel = MethodChannel('teleplayer/media_controls');

  Song? _song;
  bool _playing = false;

  void start() {
    if (!Platform.isWindows) return;
    _channel.setMethodCallHandler(_onCommand);
    _player.current.addListener(_onSong);
    _player.out.playingStream.listen((playing) {
      _playing = playing;
      unawaited(_push());
    });
    _onSong();
  }

  void _onSong() {
    _song = _player.current.value;
    unawaited(_push());
  }

  Future<void> _push() async {
    final song = _song;
    try {
      await _channel.invokeMethod<void>('update', {
        'title': song?.title ?? '',
        'artist': song?.artist ?? '',
        'album': song?.album ?? '',
        'cover': song?.coverPath ?? '',
        'playing': _playing,
      });
    } on MissingPluginException {
      // A runner built before media controls existed.
    }
  }

  Future<void> _onCommand(MethodCall call) async {
    final out = _player.out;
    switch (call.method) {
      case 'play':
        unawaited(out.play());
      case 'pause':
        await out.pause();
      case 'next':
        await out.seekToNext();
      case 'previous':
        await out.seekToPrevious();
    }
  }
}
