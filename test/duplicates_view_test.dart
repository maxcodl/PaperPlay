import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/library/duplicates.dart';
import 'package:teleplayer/metadata/enricher.dart';

DuplicatePost _post(int id, {int? topic, String format = 'MP3', bool lossless = false}) => DuplicatePost(
      chatId: 1,
      messageId: id,
      fileName: 'f$id',
      size: 100,
      topicId: topic,
      lossless: lossless,
      format: format,
      date: id,
    );

DuplicateGroup _group(DuplicateKind kind, DuplicatePost keep, List<DuplicatePost> others, [Set<int> suggested = const {}]) =>
    DuplicateGroup(kind, 'Song', 'Ann', keep, others, suggested);

void main() {
  const names = {5: 'Calm', 6: 'General'};
  String? topic(DuplicatePost p) => names[p.topicId];

  group('explaining a duplicate', () {
    test('the same file twice in one topic', () {
      final g = _group(DuplicateKind.sameFile, _post(1, topic: 5), [_post(2, topic: 5)], {2});
      expect(describeDuplicate(g, topic), 'The exact same file was posted 2 times in Calm.');
      expect(sectionOf(g), DuplicateSection.extras);
    });

    test('the same file across topics names them, and is not called an extra', () {
      final g = _group(DuplicateKind.sameFile, _post(1, topic: 6), [_post(2, topic: 5)]);
      expect(describeDuplicate(g, topic), 'The exact same file was posted in General and Calm.');
      expect(sectionOf(g), DuplicateSection.otherTopics);
    });

    test('a chat without topics still reads properly', () {
      final g = _group(DuplicateKind.sameFile, _post(1), [_post(2), _post(3)]);
      expect(describeDuplicate(g, topic), 'The exact same file was posted 3 times.');
    });

    test('a lossless and a lossy copy say which is which', () {
      final g = _group(DuplicateKind.likelySameSong, _post(1, format: 'FLAC', lossless: true), [_post(2)], {2});
      expect(describeDuplicate(g, topic), contains('FLAC is lossless, MP3 isn\'t'));
      expect(sectionOf(g), DuplicateSection.extras);
    });

    test('lookalikes warn they may be different versions', () {
      final g = _group(DuplicateKind.likelySameSong, _post(1), [_post(2)]);
      expect(describeDuplicate(g, topic), contains('different versions'));
      expect(sectionOf(g), DuplicateSection.maybe);
    });
  });

  group('what stays', () {
    final keep = _post(1), other = _post(2), third = _post(3);
    final g = _group(DuplicateKind.sameFile, keep, [other, third]);

    test('the suggested post stays when nothing is ticked', () {
      expect(survivorOf(g, (_) => false), keep);
    });

    test('ticking the suggested post leaves the next one', () {
      expect(survivorOf(g, (p) => p == keep), other);
    });

    test('ticking every post leaves none, which the screen refuses', () {
      expect(survivorOf(g, (_) => true), isNull);
    });
  });

  group('the cover queue', () {
    const fast = Duration(milliseconds: 20);

    test('a song that never answers doesn\'t hold up the rest', () async {
      final queue = [1, 2, 3];
      final done = <int>[], failed = <int>[];
      await drainNewestFirst<int>(
        queue,
        (i) => i == 3 ? Completer<void>().future : Future.sync(() => done.add(i)),
        timeout: fast,
        onChange: () {},
        onError: (i, e) {
          expect(e, isA<TimeoutException>());
          failed.add(i);
        },
      );
      expect(failed, [3]);
      expect(done, [2, 1]);
      expect(queue, isEmpty);
    });

    test('an unexpected error doesn\'t stop the rest or leave the count stuck', () async {
      final queue = [1, 2];
      final counts = <int>[], done = <int>[];
      await drainNewestFirst<int>(
        queue,
        (i) async {
          if (i == 2) throw const FormatException('bad reply');
          done.add(i);
        },
        timeout: fast,
        onChange: () => counts.add(queue.length),
        onError: (_, _) {},
      );
      expect(done, [1]);
      expect(counts, [1, 0]);
    });
  });
}
