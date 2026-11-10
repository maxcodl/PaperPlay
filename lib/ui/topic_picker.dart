import 'package:flutter/material.dart';

import '../app.dart';
import '../library/topic_sort.dart';

/// [chatId]'s topics as they should be shown here.
Future<List<TopicChoice>> chatTopics(int chatId) async =>
    topicChoices(await app.db.select(app.db.forumTopics).get(), chatId, app.taste.value.topicNames);

/// Asks which topic. Null if the owner backed out.
Future<TopicChoice?> pickTopic(BuildContext context, List<TopicChoice> topics, String title) =>
    showDialog<TopicChoice>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text(title),
        children: [
          for (final t in topics)
            SimpleDialogOption(onPressed: () => Navigator.pop(dialog, t), child: Text(t.name)),
        ],
      ),
    );
