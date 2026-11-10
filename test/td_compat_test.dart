import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/telegram/td_compat.dart';

void main() {
  tearDown(() => setTdVersion('1.8.52'));

  test('version decides the request shape', () {
    setTdVersion('1.8.52');
    expect(tdNewApi, isFalse);
    setTdVersion('1.8.70');
    expect(tdNewApi, isTrue);
    setTdVersion('garbage');
    expect(tdNewApi, isTrue, reason: 'an unreadable version keeps the last known shape');
  });

  test('topics', () {
    setTdVersion('1.8.52');
    expect(topicRequest(7, 1), {'message_thread_id': 7});
    expect(topicRequest(1, 1), isEmpty, reason: 'General is reached with no field');
    setTdVersion('1.8.70');
    expect(topicRequest(7, 1), {
      'topic_id': {'@type': 'messageTopicForum', 'forum_topic_id': 7},
    });
  });

  test('audio and document content nest their file in the new shape', () {
    final file = {'@type': 'inputFileRemote', 'id': 'x'};
    setTdVersion('1.8.52');
    expect(audioContent(file, duration: 1, title: 't', performer: 'p')['audio'], file);
    setTdVersion('1.8.70');
    final audio = audioContent(file, duration: 1, title: 't', performer: 'p', cover: {'@type': 'inputThumbnail'});
    expect((audio['audio'] as Map)['@type'], 'inputAudio');
    expect((audio['audio'] as Map)['album_cover_thumbnail'], isNotNull);
    expect(((documentContent(file)['document']) as Map)['@type'], 'inputDocument');
    expect(deleteForumTopicRequest(1, 2)['forum_topic_id'], 2);
  });
}
