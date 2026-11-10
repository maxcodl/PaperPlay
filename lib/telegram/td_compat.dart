/// TDLib changed the shape of a few requests between 1.8.52 and 1.8.70: a topic is now
/// `topic_id: messageTopicForum`, and audio and document content nest their file details.
/// A field TDLib doesn't know is ignored without an error, so a wrong shape would post to
/// General silently. The shape follows the version the loaded library reports, since the
/// phone and PC libraries are replaced separately.
library;


/// Set from `getOption version` when a client opens. Until it's known the old shape is used.
var tdNewApi = false;

/// 1.8.60 and later use the new shapes (1.8.70 was checked against its td_api.tl).
void setTdVersion(String? version) {
  final parts = (version ?? '').split('.');
  if (parts.length < 3) return;
  final minor = int.tryParse(parts[1]), patch = int.tryParse(parts[2]);
  if (minor == null || patch == null) return;
  tdNewApi = minor > 8 || (minor == 8 && patch >= 60);
}

/// What `sendMessage` and `forwardMessages` need to post in a topic. Posting without one
/// is what reaches General itself.
Map<String, Object> topicRequest(int? topicId, int generalTopicId) {
  if (topicId == null || topicId == generalTopicId) return const {};
  return tdNewApi
      ? {'topic_id': {'@type': 'messageTopicForum', 'forum_topic_id': topicId}}
      : {'message_thread_id': topicId};
}

/// `inputMessageAudio` for [file] (an input file), with the tags and an optional cover
/// (`inputThumbnail`).
Map<String, dynamic> audioContent(
  Map<String, dynamic> file, {
  required Object? duration,
  required Object? title,
  required Object? performer,
  Object? caption,
  Map<String, dynamic>? cover,
}) =>
    tdNewApi
        ? {
            '@type': 'inputMessageAudio',
            'audio': {
              '@type': 'inputAudio',
              'audio': file,
              'duration': duration,
              'title': title,
              'performer': performer,
              'album_cover_thumbnail': ?cover,
            },
            'caption': ?caption,
          }
        : {
            '@type': 'inputMessageAudio',
            'audio': file,
            'duration': duration,
            'title': title,
            'performer': performer,
            'album_cover_thumbnail': ?cover,
            'caption': ?caption,
          };

/// `inputMessageDocument` that stays a plain file.
Map<String, dynamic> documentContent(Map<String, dynamic> file, {Object? caption}) => tdNewApi
    ? {
        '@type': 'inputMessageDocument',
        'document': {'@type': 'inputDocument', 'document': file, 'disable_content_type_detection': true},
        'caption': ?caption,
      }
    : {
        '@type': 'inputMessageDocument',
        'document': file,
        'disable_content_type_detection': true,
        'caption': ?caption,
      };

Map<String, dynamic> deleteForumTopicRequest(int chatId, int topicId) => {
      '@type': 'deleteForumTopic',
      'chat_id': chatId,
      tdNewApi ? 'forum_topic_id' : 'message_thread_id': topicId,
    };
