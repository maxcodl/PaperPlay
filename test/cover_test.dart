import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/library/db.dart';
import 'package:teleplayer/metadata/enricher.dart';

Song _song({String? path, String? release, String? url, bool hiRes = false, int chosenAt = 0, bool edited = false}) => Song(
      chatId: 1,
      messageId: 1,
      uniqueId: 'u',
      remoteId: 'r',
      title: 't',
      artist: 'a',
      album: '',
      durationSec: 200,
      size: 1,
      mime: 'audio/flac',
      fileName: 'f',
      date: 0,
      coverPath: path,
      releaseId: release,
      coverUrl: url,
      favorite: false,
      coverHiRes: hiRes,
      userEdited: edited,
      enrichState: 1,
      cachedBytes: 0,
      pinned: false,
      tagsAt: 0,
      favoriteAt: 0,
      coverAt: chosenAt,
      instrumental: false,
      moodScannedAt: 0,
      plays: 0,
      skips: 0,
    );

void main() {
  test('a song with no cover needs one', () {
    expect(coverWorkFor(_song()), CoverWork.first);
    expect(coverWorkFor(_song(url: 'https://x')), CoverWork.first);
  });

  test('a thumbnail with a full-size source upgrades without being played', () {
    expect(coverWorkFor(_song(path: '/thumb.jpg', url: 'https://x')), CoverWork.upgrade);
    expect(coverWorkFor(_song(path: '/thumb.jpg', release: 'r1')), CoverWork.upgrade);
  });

  test('nothing to do once it is full size, or with no source to upgrade from', () {
    expect(coverWorkFor(_song(path: '/full.jpg', url: 'https://x', hiRes: true)), CoverWork.none);
    expect(coverWorkFor(_song(path: '/thumb.jpg')), CoverWork.none);
  });

  test('a cover someone chose or edited is never replaced automatically', () {
    expect(coverWorkFor(_song(path: '/mine.jpg', url: 'https://x', chosenAt: 5)), CoverWork.none);
    expect(coverWorkFor(_song(path: '/thumb.jpg', url: 'https://x', edited: true)), CoverWork.none);
  });
}
