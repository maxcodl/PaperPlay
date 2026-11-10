import 'db.dart';

enum DeleteStatus { queued, deleting, done, failed }

/// One song in a bulk delete, kept so the Tasks page can show how far it got.
class DeleteJob {
  DeleteJob(this.song, {this.postChat, this.postMessage, this.keepChat, this.keepMessage});

  /// One repeated post of [song], kept apart from the post at [keepChat]/[keepMessage].
  DeleteJob.duplicate(this.song, {required int chat, required int message, required int this.keepChat, required int this.keepMessage})
      : postChat = chat,
        postMessage = message;

  final Song song;
  final int? postChat, postMessage, keepChat, keepMessage;
  bool get isDuplicate => postMessage != null;

  /// Stable key: a duplicate's song also has other posts in the list.
  String get key => isDuplicate ? '${postChat}_$postMessage' : song.uniqueId;
  var status = DeleteStatus.queued;
  String? error;
}
