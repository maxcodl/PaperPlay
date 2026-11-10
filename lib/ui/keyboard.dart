import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../playback/player.dart';

/// What each key does. Plain keys are ignored while typing; media keys never are.
abstract final class PlayerKeys {
  static const seekStep = Duration(seconds: 5);
  static const volumeStep = 0.05;
}

/// True while the keyboard is entering text somewhere.
bool _typing() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;

/// Player shortcuts for the whole app, on every screen and sheet. Registered with
/// the keyboard directly, because a shortcut widget only hears keys while focus
/// is inside it, and focus moves away whenever a page or sheet opens.
///
/// [onSearch] runs for Ctrl+F.
void installPlayerKeys(PlayerOutput Function() output, {VoidCallback? onSearch}) {
  HardwareKeyboard.instance.addHandler((event) {
    if (event is KeyUpEvent) return false;
    final key = event.logicalKey;
    final out = output();
    final repeat = event is KeyRepeatEvent;

    // Media keys, when Windows or Android sends them to the focused app.
    if (!repeat) {
      if (key == LogicalKeyboardKey.mediaPlayPause) {
        _toggle(out);
        return true;
      }
      if (key == LogicalKeyboardKey.mediaPlay) {
        out.play();
        return true;
      }
      if (key == LogicalKeyboardKey.mediaPause || key == LogicalKeyboardKey.mediaStop) {
        out.pause();
        return true;
      }
      if (key == LogicalKeyboardKey.mediaTrackNext) {
        out.seekToNext();
        return true;
      }
      if (key == LogicalKeyboardKey.mediaTrackPrevious) {
        out.seekToPrevious();
        return true;
      }
    }

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed) {
      if (key == LogicalKeyboardKey.keyF && !repeat && onSearch != null) {
        onSearch();
        return true;
      }
      if (_typing()) return false;
      if (key == LogicalKeyboardKey.arrowRight && !repeat) {
        out.seekToNext();
        return true;
      }
      if (key == LogicalKeyboardKey.arrowLeft && !repeat) {
        out.seekToPrevious();
        return true;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        out.setVolume((out.volume + PlayerKeys.volumeStep).clamp(0.0, 1.0));
        return true;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        out.setVolume((out.volume - PlayerKeys.volumeStep).clamp(0.0, 1.0));
        return true;
      }
      return false;
    }

    if (_typing() || keyboard.isAltPressed || keyboard.isMetaPressed) return false;
    if (key == LogicalKeyboardKey.space && !repeat) {
      _toggle(out);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _seekBy(out, PlayerKeys.seekStep);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _seekBy(out, -PlayerKeys.seekStep);
      return true;
    }
    if (key == LogicalKeyboardKey.keyM && !repeat) {
      out.setVolume(out.volume == 0 ? 1 : 0);
      return true;
    }
    return false;
  });
}

void _toggle(PlayerOutput out) => out.playing ? out.pause() : out.play();

void _seekBy(PlayerOutput out, Duration by) {
  final total = out.duration;
  if (total == null) return;
  final target = out.position + by;
  out.seek(target < Duration.zero ? Duration.zero : (target > total ? total : target));
}
