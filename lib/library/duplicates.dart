import '../metadata/enricher.dart';
import 'audio_info.dart';
import 'db.dart';
import 'taste.dart';

enum DuplicateKind {
  /// The identical file, posted more than once.
  sameFile,

  /// Matching title, artist and length, in different files. Can occasionally be wrong.
  likelySameSong,
}

/// One post of a song in a chat.
class DuplicatePost {
  const DuplicatePost({
    required this.chatId,
    required this.messageId,
    required this.fileName,
    required this.size,
    required this.topicId,
    required this.lossless,
    required this.format,
    required this.date,
    this.song,
  });
  final int chatId, messageId, size;

  /// When it was posted, in seconds.
  final int date;
  final String fileName, format;
  final int? topicId;
  final bool lossless;

  /// The library's row for this post. Null for a repeat the library doesn't list.
  final Song? song;
}

class DuplicateGroup {
  const DuplicateGroup(this.kind, this.title, this.artist, this.keep, this.others, this.suggested);
  final DuplicateKind kind;
  final String title, artist;

  /// The copy suggested to keep.
  final DuplicatePost keep;
  final List<DuplicatePost> others;

  /// Those of [others] safe to suggest deleting. Someone still has to confirm.
  final Set<int> suggested;
}

DuplicatePost _postOf(Song s) {
  final format = songFormat(s);
  return DuplicatePost(
    chatId: s.chatId,
    messageId: s.messageId,
    fileName: s.fileName,
    size: s.size,
    topicId: s.topicId,
    lossless: isLossless(format),
    format: format,
    date: s.date,
    song: s,
  );
}

/// What kind of decision a group of repeats is, for grouping them on screen.
enum DuplicateSection { extras, otherTopics, maybe }

DuplicateSection sectionOf(DuplicateGroup g) => g.suggested.isNotEmpty
    ? DuplicateSection.extras
    : g.kind == DuplicateKind.sameFile
        ? DuplicateSection.otherTopics
        : DuplicateSection.maybe;

String _list(List<String> items) =>
    items.length < 2 ? items.join() : '${items.take(items.length - 1).join(', ')} and ${items.last}';

/// Says in plain words why these posts count as repeats.
String describeDuplicate(DuplicateGroup g, String? Function(DuplicatePost) topicOf) {
  final posts = [g.keep, ...g.others];
  if (g.kind == DuplicateKind.sameFile) {
    final places = {...posts.map(topicOf).nonNulls}.toList();
    if (places.length > 1) return 'The exact same file was posted in ${_list(places)}.';
    final where = places.isEmpty ? '' : ' in ${places.single}';
    return 'The exact same file was posted ${posts.length} times$where.';
  }
  final lossy = {for (final o in g.others) if (!o.lossless) o.format};
  if (g.keep.lossless && lossy.isNotEmpty) {
    return 'The same song in different quality: ${g.keep.format} is lossless, ${_list(lossy.toList())} isn\'t.';
  }
  return 'Same title, artist and length, but different files. They could be different versions.';
}

/// The post that stays when the [isTicked] ones go. Null if none would, which is
/// never allowed: every song keeps at least one post.
DuplicatePost? survivorOf(DuplicateGroup g, bool Function(DuplicatePost) isTicked) {
  for (final p in [g.keep, ...g.others]) {
    if (!isTicked(p)) return p;
  }
  return null;
}

/// Clearly worse than [keep], so safe to suggest deleting: lossy against lossless,
/// or under two-thirds of the size in the same kind of format.
bool _clearlyWorse(DuplicatePost post, DuplicatePost keep) {
  if (keep.lossless && !post.lossless) return true;
  return keep.lossless == post.lossless && post.size < keep.size * 2 / 3;
}

/// The same format at nearly the same size: a re-upload of the same track, so the
/// older one can go.
bool _reupload(DuplicatePost post, DuplicatePost keep) =>
    post.format == keep.format && (post.size - keep.size).abs() <= keep.size * 0.02;

/// A copy in General of a song already filed in a real topic: what's left when a move
/// couldn't delete the General post. General isn't a playlist someone chose, so it's safe
/// to suggest removing.
bool _leftoverInGeneral(DuplicatePost keep, DuplicatePost other) =>
    other.topicId == generalTopicId && keep.topicId != null && keep.topicId != generalTopicId;

const _lengthTolerance = 3;

/// Finds repeats, from the library's [songs] and the [copies] it found beyond them.
///
/// A repeat in another topic isn't suggested for deletion: filing a song under two
/// topics is usually on purpose, and topics act as playlists.
///
/// With [onlyChat], only posts in that chat count. A copy elsewhere isn't a repeat,
/// since the main chat is meant to hold what other channels also have.
List<DuplicateGroup> findDuplicates(List<Song> songs, List<PostCopy> copies, {int? onlyChat}) {
  final groups = <DuplicateGroup>[];
  final byUnique = {for (final s in songs) s.uniqueId: s};
  final copiesOf = <String, List<PostCopy>>{};
  for (final c in copies) {
    if (onlyChat == null || c.chatId == onlyChat) (copiesOf[c.uniqueId] ??= []).add(c);
  }
  for (final e in copiesOf.entries) {
    final song = byUnique[e.key];
    if (song == null) continue;
    final listedHere = onlyChat == null || song.chatId == onlyChat;
    // Listed under a post elsewhere, so one of these has to be the one that stays.
    if (!listedHere && e.value.length < 2) continue;
    final format = songFormat(song);
    DuplicatePost postOf(PostCopy c) => DuplicatePost(
          chatId: c.chatId,
          messageId: c.messageId,
          fileName: c.fileName,
          size: c.size,
          topicId: c.topicId,
          lossless: isLossless(format),
          format: format,
          date: c.date,
        );
    final keep = listedHere ? _postOf(song) : postOf(e.value.first);
    final others = [for (final c in listedHere ? e.value : e.value.skip(1)) postOf(c)];
    groups.add(DuplicateGroup(
      DuplicateKind.sameFile,
      song.title,
      song.artist,
      keep,
      others,
      {for (final o in others) if (o.topicId == keep.topicId || _leftoverInGeneral(keep, o)) o.messageId},
    ));
  }

  final byName = <String, List<Song>>{};
  for (final s in songs) {
    if (s.durationSec <= 0 || (onlyChat != null && s.chatId != onlyChat)) continue;
    final title = comparableText(searchTitle(cleanTitle(s.title, s.artist)));
    final artist = comparableText(firstArtist(s.artist));
    if (title.isEmpty) continue;
    (byName['$title|$artist'] ??= []).add(s);
  }
  for (final same in byName.values) {
    if (same.length < 2) continue;
    same.sort((a, b) => a.durationSec.compareTo(b.durationSec));
    // Runs of similar length, so an album version and a long mix stay apart.
    var run = <Song>[same.first];
    void flush() {
      if (run.length < 2) return;
      final posts = run.map(_postOf).toList()..sort((a, b) {
          // Best quality, then the larger file, then the newest post.
          final q = compareQuality(a.song!, b.song!);
          return q != 0 ? q : b.date.compareTo(a.date);
        });
      final keep = posts.first;
      final others = posts.skip(1).toList();
      groups.add(DuplicateGroup(
        DuplicateKind.likelySameSong,
        keep.song!.title,
        keep.song!.artist,
        keep,
        others,
        {
          for (final o in others)
            if (o.topicId == keep.topicId && (_clearlyWorse(o, keep) || _reupload(o, keep))) o.messageId,
        },
      ));
    }

    for (final s in same.skip(1)) {
      if (s.durationSec - run.last.durationSec <= _lengthTolerance) {
        run.add(s);
      } else {
        flush();
        run = [s];
      }
    }
    flush();
  }
  return groups;
}
