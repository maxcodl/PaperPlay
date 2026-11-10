import '../metadata/enricher.dart';
import 'db.dart';
import 'mood.dart';
import 'taste.dart';

/// A topic someone can choose, under the name they know it by.
class TopicChoice {
  const TopicChoice(this.id, this.name);
  final int id;
  final String name;

  bool get isGeneral => id == generalTopicId;
}

/// A chat's topics, General first. A name given in the app beats Telegram's. Empty
/// or General alone means the chat has no topics worth choosing between.
List<TopicChoice> topicChoices(List<ForumTopic> topics, int chatId, Map<String, String> names) {
  final known = [
    for (final t in topics)
      if (t.chatId == chatId && t.topicId != generalTopicId)
        TopicChoice(t.topicId, names[TasteSettings.topicKey(chatId, t.topicId)] ?? t.name),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  if (known.isEmpty) return known;
  final general = names[TasteSettings.topicKey(chatId, generalTopicId)] ?? 'General';
  return [TopicChoice(generalTopicId, general), ...known];
}

enum LyricScript {
  japanese('Japanese', ['japan', 'j-pop', 'jpop']),
  devanagari('Devanagari', ['bollywood', 'hindi']),
  tamil('Tamil', ['tamil', 'kollywood']),
  telugu('Telugu', ['tollywood', 'telugu']),
  malayalam('Malayalam', ['mollywood', 'malayalam']);

  const LyricScript(this.label, this.topicWords);
  final String label;

  /// Topic names this script clearly belongs to. Tamil isn't Tollywood (that's
  /// Telugu), so a Tamil song only goes there if the topic already holds Tamil songs.
  final List<String> topicWords;
}

LyricScript? _scriptOfRune(int c) {
  if (c >= 0x3040 && c <= 0x30FF) return LyricScript.japanese; // Kana. Kanji alone could be Chinese.
  if (c >= 0x0900 && c <= 0x097F) return LyricScript.devanagari;
  if (c >= 0x0B80 && c <= 0x0BFF) return LyricScript.tamil;
  if (c >= 0x0C00 && c <= 0x0C7F) return LyricScript.telugu;
  if (c >= 0x0D00 && c <= 0x0D7F) return LyricScript.malayalam;
  return null;
}

bool _isLetter(int c) =>
    (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || (c >= 0x4E00 && c <= 0x9FFF) || _scriptOfRune(c) != null;

LyricScript? _dominantScript(String text, {required int minChars, required double minShare}) {
  final counts = <LyricScript, int>{};
  var letters = 0;
  for (final c in text.runes) {
    if (!_isLetter(c)) continue;
    letters++;
    final script = _scriptOfRune(c);
    if (script != null) counts[script] = (counts[script] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return top.value >= minChars && top.value / letters >= minShare ? top.key : null;
}

/// The script a song is written in, from its lyrics or else its title and artist.
LyricScript? scriptOf(Song s) {
  final lyrics = s.lyrics;
  if (lyrics != null) {
    final script = _dominantScript(lyrics, minChars: 20, minShare: 0.2);
    if (script != null) return script;
  }
  return _dominantScript('${s.title} ${s.artist}', minChars: 2, minShare: 0.4);
}

enum TopicConfidence { high, medium }

class TopicSuggestion {
  const TopicSuggestion(this.song, this.topic, this.confidence, this.reason, {this.blocked = false});
  final Song song;

  /// Null when the evidence is too weak to suggest anything.
  final TopicChoice? topic;
  final TopicConfidence? confidence;
  final String reason;

  /// Moving it would file the same song twice, so it can't be moved from here.
  final bool blocked;
}

const _genreTopicWords = <String, List<String>>{
  'phonk': ['phonk'],
  'bollywood': ['bollywood'],
  'hindi': ['bollywood'],
  'tollywood': ['tollywood'],
  'telugu': ['tollywood'],
  'mollywood': ['mollywood'],
  'malayalam': ['mollywood'],
  'kollywood': ['kollywood', 'tamil'],
  'tamil': ['kollywood', 'tamil'],
  'j-pop': ['japan'],
  'j-rock': ['japan'],
  'japanese': ['japan'],
};

/// Topics named for a sound or a place, not a feeling: an intense song isn't phonk.
const _notMoodTopics = ['phonk', 'lofi', 'lo-fi'];

const _high = 3.0, _medium = 1.5, _tooClose = 0.7, _mostOf = 0.6, _enoughToLearn = 3, _moodFitNeeded = 0.7;

/// The topic holding most of [counts], if it holds at least [_mostOf] of them.
MapEntry<int, int>? _mainTopic(Map<int, int> counts) {
  if (counts.isEmpty) return null;
  final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  final total = counts.values.reduce((a, b) => a + b);
  return top.value / total >= _mostOf ? top : null;
}

/// Suggests a topic for each song in General, from what's already filed elsewhere.
/// Songs in other topics are only read for evidence and are never suggested.
///
/// Evidence is artists already in a topic, the lyrics' script, the genre, and mood
/// for topics named after one. A weak or evenly split case gets no suggestion.
List<TopicSuggestion> suggestTopics({
  required List<Song> songs,
  required List<TopicChoice> topics,
  List<PostCopy> copies = const [],
  List<Song>? incoming,
}) {
  final targets = topics.where((t) => !t.isGeneral).toList();
  // [incoming] are songs from elsewhere, judged by what's filed in [songs].
  final general = incoming ?? [for (final s in songs) if (s.topicId == generalTopicId) s];
  // Without other topics this isn't a sorted forum: a plain group's posts all count as General.
  if (targets.isEmpty) return const [];
  final names = {for (final t in targets) t.id: t};
  final filed = [for (final s in songs) if (names.containsKey(s.topicId)) s];

  final artistTopics = <String, Map<int, int>>{};
  final scriptTopics = <LyricScript, Map<int, int>>{};
  final genreTopics = <String, Map<int, int>>{};
  void count<K>(Map<K, Map<int, int>> map, K key, int topic) {
    final m = map[key] ??= {};
    m[topic] = (m[topic] ?? 0) + 1;
  }

  for (final s in filed) {
    final topic = s.topicId!;
    final artist = _artistKey(s);
    if (artist.isNotEmpty) count(artistTopics, artist, topic);
    final script = scriptOf(s);
    if (script != null) count(scriptTopics, script, topic);
    final genre = s.genre?.toLowerCase();
    if (genre != null && genre.isNotEmpty) count(genreTopics, genre, topic);
  }

  final copyTopics = <String, Set<int>>{};
  for (final c in copies) {
    final topic = c.topicId;
    if (topic != null && topic != generalTopicId) (copyTopics[c.uniqueId] ??= {}).add(topic);
  }

  TopicChoice? named(List<String> words) {
    for (final t in targets) {
      final n = t.name.toLowerCase();
      if (words.any(n.contains)) return t;
    }
    return null;
  }

  return [
    for (final s in general)
      copyTopics[s.uniqueId] == null
          ? _suggest(s, targets, named, artistTopics, scriptTopics, genreTopics, names)
          : TopicSuggestion(
              s,
              null,
              null,
              'Also posted in ${names[copyTopics[s.uniqueId]!.first]?.name ?? 'another topic'}. See Find duplicates.',
              blocked: true,
            ),
  ];
}

String _artistKey(Song s) {
  if (s.artist == 'Unknown artist') return '';
  return comparableText(firstArtist(s.artist));
}

TopicSuggestion _suggest(
  Song s,
  List<TopicChoice> targets,
  TopicChoice? Function(List<String>) named,
  Map<String, Map<int, int>> artistTopics,
  Map<LyricScript, Map<int, int>> scriptTopics,
  Map<String, Map<int, int>> genreTopics,
  Map<int, TopicChoice> names,
) {
  final scores = <int, double>{};
  final reasons = <int, List<String>>{};
  void add(int topic, double score, String reason) {
    scores[topic] = (scores[topic] ?? 0) + score;
    (reasons[topic] ??= []).add(reason);
  }

  final artist = _mainTopic(artistTopics[_artistKey(s)] ?? const {});
  if (artist != null) {
    final n = artist.value;
    add(
      artist.key,
      n >= 3 ? 3 : (n == 2 ? 2.5 : 1.5),
      '$n song${n == 1 ? '' : 's'} by ${firstArtist(s.artist)} ${n == 1 ? 'is' : 'are'} in ${names[artist.key]!.name}',
    );
  }

  final script = scriptOf(s);
  if (script != null) {
    final learned = _mainTopic(scriptTopics[script] ?? const {});
    final topic = learned != null && learned.value >= _enoughToLearn ? learned.key : named(script.topicWords)?.id;
    if (topic != null) add(topic, 2, '${script.label} lyrics or title');
  }

  final genre = s.genre?.toLowerCase();
  if (genre != null && genre.isNotEmpty) {
    TopicChoice? byName;
    for (final e in _genreTopicWords.entries) {
      if (genre.contains(e.key)) byName = named(e.value) ?? byName;
    }
    final learned = _mainTopic(genreTopics[genre] ?? const {});
    if (byName != null) {
      add(byName.id, 1.5, 'Genre is ${s.genre}');
    } else if (learned != null && learned.value >= _enoughToLearn) {
      add(learned.key, 1, 'Genre is ${s.genre}');
    }
  }

  final traits = analyzeSong(s);
  if (traits.confidence >= 0.5) {
    for (final t in targets) {
      final lower = t.name.toLowerCase();
      if (_notMoodTopics.any(lower.contains)) continue;
      for (final id in moodsForListName(t.name)) {
        final mood = moods.firstWhere((m) => m.id == id);
        final needsWords = mood.valence.abs() >= 0.5;
        if (needsWords && !traits.hasSentiment) continue;
        if (moodFit(traits, mood) >= _moodFitNeeded) {
          add(t.id, _medium, 'Lyrics and genre feel like ${mood.name.toLowerCase()}');
          break;
        }
      }
    }
  }

  if (scores.isEmpty) return TopicSuggestion(s, null, null, 'Not enough to go on');
  final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final best = ranked.first;
  if (best.value < _medium) return TopicSuggestion(s, null, null, 'Not enough to go on');
  if (ranked.length > 1 && ranked[1].value >= best.value * _tooClose) {
    return TopicSuggestion(s, null, null, 'Could be ${names[best.key]!.name} or ${names[ranked[1].key]!.name}');
  }
  return TopicSuggestion(
    s,
    names[best.key],
    best.value >= _high ? TopicConfidence.high : TopicConfidence.medium,
    reasons[best.key]!.join('; '),
  );
}
