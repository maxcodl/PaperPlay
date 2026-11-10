import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;

import 'player.dart';

/// The Android media card, lock screen and headset buttons. It follows the chosen output,
/// so it shows the song and its controls work whether it plays on this phone or on another
/// connected device.
class TeleplayerHandler extends BaseAudioHandler with SeekHandler {
  TeleplayerHandler(this._player) {
    _player.current.addListener(_song);
    _player.target.addListener(_state);
    _player.out.playerStateStream.listen((_) => _state());
    // Android moves the bar by itself between updates; this keeps it from drifting.
    _player.out.playerStateStream.listen((s) {
      _drift?.cancel();
      _drift = s.playing
          ? Timer.periodic(const Duration(seconds: 5), (_) => _state())
          : null; // Paused: nothing to correct, so no timer.
    });
    _song();
  }

  final PlayerController _player;
  Timer? _drift;

  void _song() {
    final s = _player.current.value;
    mediaItem.add(
      s == null
          ? null
          : MediaItem(
              id: '${s.chatId}_${s.messageId}',
              title: s.title,
              artist: s.artist,
              album: s.album,
              artUri: s.coverPath == null ? null : Uri.file(s.coverPath!),
              duration: s.durationSec > 0 ? Duration(seconds: s.durationSec) : _player.out.duration,
            ),
    );
    _state();
  }

  void _state() {
    final out = _player.out;
    final now = _player.current.value;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          out.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek, MediaAction.skipToNext, MediaAction.skipToPrevious},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: now == null
            ? AudioProcessingState.idle
            : switch (out.playerStateSnapshot.processingState) {
                ProcessingState.idle => AudioProcessingState.idle,
                ProcessingState.loading => AudioProcessingState.loading,
                ProcessingState.buffering => AudioProcessingState.buffering,
                ProcessingState.ready => AudioProcessingState.ready,
                ProcessingState.completed => AudioProcessingState.completed,
              },
        playing: out.playing,
        updatePosition: out.position,
        bufferedPosition: out.bufferedPosition,
        speed: out.speed,
      ),
    );
  }

  @override
  Future<void> play() => _player.out.play();

  @override
  Future<void> pause() => _player.out.pause();

  @override
  Future<void> seek(Duration position) => _player.out.seek(position);

  @override
  Future<void> skipToNext() => _player.out.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.out.seekToPrevious();

  @override
  Future<void> stop() async {
    await _player.out.pause();
  }
}
