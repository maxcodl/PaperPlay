import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:teleplayer/pace.dart';
import 'package:teleplayer/library/scanner.dart';
import 'package:teleplayer/library/upload.dart';
import 'package:teleplayer/playback/player.dart';

void main() {
  group('pacing', () {
    test('files are spaced by an uneven pause, with a long rest every 20', () {
      rates[Work.filing]!.value = 6; // 10 s apart on average.
      final random = Random(1);
      final short = [for (var i = 1; i < 20; i++) uploadPause(i, random).inSeconds];
      expect(short.every((s) => s >= 7 && s <= 13), isTrue);
      expect(short.toSet().length, greaterThan(1), reason: 'an even gap looks like a script');
      final long = uploadPause(20, random).inSeconds;
      expect(long, inInclusiveRange(40, 80));
      expect(uploadPause(0, random).inSeconds, lessThanOrEqualTo(13), reason: 'no rest before anything was sent');
    });

    test('Telegram\'s wait is read from either form of its rate limit message', () {
      expect(retryAfterOf('Too Many Requests: retry after 37'), const Duration(seconds: 37));
      expect(retryAfterOf(Exception('FLOOD_WAIT_120')), const Duration(seconds: 120));
      expect(retryAfterOf('Bad Request: file is too big'), isNull);
    });
  });

  group('formats', () {
    test('accepts formats beyond the common ones, in any case', () {
      for (final name in ['a.flac', 'b.MP3', 'c.m4b', 'd.dsf', 'e.ape', 'f.wv', 'g.opus', 'h.aiff', 'i.Tta']) {
        expect(isAudioFile(name), isTrue, reason: name);
      }
    });

    test('refuses what isn\'t audio', () {
      for (final name in ['a.jpg', 'b.txt', 'c.cue', 'd.nfo', 'noextension', 'mp3']) {
        expect(isAudioFile(name), isFalse, reason: name);
      }
    });

    test('an uploaded format stored as a plain file is still recognised as a song', () {
      final message = {
        'content': {
          '@type': 'messageDocument',
          'document': {'mime_type': 'application/octet-stream', 'file_name': 'Song.dsf'},
        },
      };
      expect(audioPayload(message), isNotNull);
    });
  });

  test('a folder is searched through its subfolders, taking only audio', () async {
    final dir = await Directory.systemTemp.createTemp('teleplayer_upload');
    addTearDown(() => dir.delete(recursive: true));
    final sub = await Directory(p.join(dir.path, 'Album')).create();
    for (final f in [p.join(dir.path, 'one.mp3'), p.join(sub.path, 'two.FLAC'), p.join(sub.path, 'cover.jpg')]) {
      await File(f).writeAsString('x');
    }
    final found = await audioFilesIn(dir);
    expect(found.map(p.basename).toSet(), {'one.mp3', 'two.FLAC'});
  });

  test('files are checked by their content, not only their name', () async {
    final dir = await Directory.systemTemp.createTemp('teleplayer_audio');
    addTearDown(() => dir.delete(recursive: true));
    Future<String> make(String name, List<int> head) async {
      final path = p.join(dir.path, name);
      await File(path).writeAsBytes([...head, ...List.filled(64, 0)]);
      return path;
    }

    final mp3 = await make('a.mp3', 'ID3'.codeUnits);
    final flac = await make('b.flac', 'fLaC'.codeUnits);
    final m4a = await make('c.m4a', [0, 0, 0, 0x20, ...'ftypM4A '.codeUnits]);
    final video = await make('d.mp4', [0, 0, 0, 0x20, ...'ftypisom'.codeUnits]);
    final sticker = await make('sticker.webm', [0x1A, 0x45, 0xDF, 0xA3]);
    final fake = await make('fake.mp3', 'PK\x03\x04'.codeUnits);
    final checked = await checkAudio([mp3, flac, m4a, video, sticker, fake]);
    expect(checked.audio.map(p.basename), ['a.mp3', 'b.flac', 'c.m4a']);
    expect(checked.rejected, 3);
  });

  group('which device the list opens on', () {
    RemoteState state(bool playing) => RemoteState({'playing': playing}, const []);

    test('a connected device that\'s playing, when nothing plays here', () {
      expect(defaultOutput(null, false, {'pc': state(true)}), 'pc');
    });

    test('this device, if it\'s the one playing', () {
      expect(defaultOutput(null, true, {'pc': state(true)}), isNull);
    });

    test('stays on what was already chosen', () {
      expect(defaultOutput('phone', false, {'pc': state(true)}), 'phone');
    });

    test('this device, if nothing is playing anywhere', () {
      expect(defaultOutput(null, false, {'pc': state(false)}), isNull);
      expect(defaultOutput(null, false, const {}), isNull);
    });
  });
}
