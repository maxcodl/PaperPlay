import 'dart:math';

import '../metadata/enricher.dart';
import 'db.dart';
import 'taste.dart';

/// Today's weather, as far as a mix cares.
enum WeatherKind { clear, cloudy, rain, storm, snow }

/// A mood a mix can be made for, placed on two axes: how positive (valence) and
/// how intense (energy) it feels, from -1 to 1.
class Mood {
  const Mood(this.id, this.name, this.valence, this.energy, {this.theme, this.wantsInstrumental = false});
  final String id, name;
  final double valence, energy;

  /// Words about this in a song count towards the mood.
  final String? theme;
  final bool wantsInstrumental;
}

const moods = [
  Mood('happy', 'Happy', 0.7, 0.4, theme: 'happy'),
  Mood('sad', 'Sad', -0.7, -0.4, theme: 'sad'),
  Mood('drive', 'Drive', 0.2, 0.7, theme: 'drive'),
  Mood('rain', 'Rain', -0.2, -0.4, theme: 'rain'),
  Mood('chill', 'Chill', 0.3, -0.5),
  Mood('focus', 'Focus', 0.0, -0.6, wantsInstrumental: true),
  Mood('party', 'Party', 0.6, 0.9, theme: 'party'),
  Mood('night', 'Late night', -0.1, -0.2, theme: 'night'),
  Mood('love', 'Love', 0.5, -0.1, theme: 'love'),
  Mood('workout', 'Workout', 0.2, 0.95),
];

const _genres = <String, (double, double)>{
  'metal': (-0.2, 0.9),
  'punk': (0.0, 0.85),
  'hard rock': (0.0, 0.8),
  'rock': (0.1, 0.6),
  'alternative': (-0.1, 0.3),
  'indie': (0.0, 0.1),
  'j-pop': (0.3, 0.4),
  'k-pop': (0.4, 0.6),
  'anime': (0.2, 0.5),
  'pop': (0.4, 0.4),
  'dance': (0.6, 0.8),
  'house': (0.5, 0.8),
  'techno': (0.2, 0.9),
  'edm': (0.5, 0.85),
  'electronic': (0.2, 0.6),
  'hip-hop': (0.1, 0.6),
  'hip hop': (0.1, 0.6),
  'rap': (0.1, 0.65),
  'r&b': (0.2, -0.1),
  'soul': (0.2, -0.1),
  'singer/songwriter': (-0.1, -0.4),
  'folk': (0.0, -0.4),
  'acoustic': (0.1, -0.5),
  'downtempo': (0.0, -0.7),
  'ambient': (0.0, -0.8),
  'lo-fi': (0.1, -0.7),
  'classical': (0.0, -0.6),
  'jazz': (0.2, -0.4),
  'blues': (-0.3, -0.2),
  'soundtrack': (-0.1, -0.4),
  'reggae': (0.5, -0.1),
  'latin': (0.5, 0.6),
  'country': (0.2, 0.0),
  'bollywood': (0.3, 0.2),
  'tamil': (0.3, 0.3),
  'regional indian': (0.3, 0.2),
};

/// Positive and negative words, and themes. English and romanized Hindi are
/// whole words; Japanese, Hindi and Tamil script are matched inside the text.
const _positive = {
  'happy', 'happiness', 'joy', 'smile', 'smiling', 'laugh', 'laughing', 'sunshine', 'sunny', 'celebrate', 'beautiful',
  'wonderful', 'alive', 'free', 'freedom', 'shine', 'shining', 'bright', 'dream', 'dreams', 'hope', 'best', 'good',
  'great', 'fun', 'dance', 'dancing', 'lucky', 'golden', 'khushi', 'muskaan', 'hasna', 'sapna', 'sapne',
};
const _negative = {
  'sad', 'cry', 'crying', 'cried', 'tears', 'tear', 'alone', 'lonely', 'broken', 'hurt', 'hurts', 'pain', 'goodbye',
  'die', 'dead', 'dying', 'death', 'lost', 'miss', 'missing', 'gone', 'empty', 'hate', 'fear', 'afraid', 'sorry',
  'bleed', 'grave', 'regret', 'never', 'cold', 'numb', 'darkness', 'dard', 'tanha', 'tanhai', 'aansu', 'judaai',
  'bewafa', 'gham', 'alvida',
};
const _positiveScript = ['幸せ', '笑顔', '笑', '喜び', '嬉しい', '楽しい', '希望', '輝', 'खुशी', 'मुस्कान', 'சந்தோஷ'];
const _negativeScript = ['涙', '悲し', '寂し', '淋し', '泣', '痛', '苦し', '孤独', 'さよなら', 'サヨナラ', '別れ', '死', 'दर्द', 'आँसू', 'तन्हा', 'கண்ணீர்', 'சோக'];

const _themes = <String, Set<String>>{
  'happy': {'happy', 'sunshine', 'smile', 'joy', 'celebrate', 'khushi'},
  'sad': {'cry', 'tears', 'lonely', 'alone', 'goodbye', 'broken', 'dard', 'tanha', 'aansu'},
  'rain': {'rain', 'raining', 'rainy', 'rainfall', 'storm', 'thunder', 'umbrella', 'baarish', 'barish', 'barsaat', 'sawan', 'monsoon'},
  'night': {'night', 'nights', 'midnight', 'moon', 'moonlight', 'stars', 'dark', 'raat', 'chaand', 'chand'},
  'drive': {'drive', 'driving', 'road', 'highway', 'car', 'ride', 'riding', 'wheel', 'fast', 'speed', 'run', 'running', 'gaadi'},
  'party': {'party', 'club', 'dance', 'dancing', 'dancefloor', 'tonight', 'drink', 'shots', 'nachna', 'naach'},
  'love': {'love', 'lover', 'loving', 'baby', 'darling', 'heart', 'kiss', 'pyaar', 'pyar', 'ishq', 'mohabbat', 'dil', 'sanam', 'jaan'},
};
const _themeScript = <String, List<String>>{
  'rain': ['雨', 'बारिश', 'மழை'],
  'night': ['夜', '月', '星', 'रात', 'இரவு'],
  'love': ['愛', '恋', '好き', 'प्यार', 'इश्क', 'காதல்'],
  'sad': ['涙', '悲し', 'दर्द'],
  'happy': ['幸せ', '笑顔', 'खुशी'],
  'drive': ['走', '道'],
  'party': ['踊', 'नाच'],
};

final _word = RegExp(r"[a-z']+");
final _lrcStamp = RegExp(r'\[\d+:\d+(?:\.\d+)?\]');

/// What a song's metadata says about how it feels.
class SongTraits {
  SongTraits(this.valence, this.energy, this.confidence, this.themes, this.instrumental, {this.hasSentiment = false});
  double valence, energy;

  /// Its words actually said something positive or negative. Genre and artist only
  /// suggest a feeling, and a quiet song isn't a sad one just for being quiet.
  final bool hasSentiment;

  /// From 0, knowing nothing, to 1.
  double confidence;
  final Map<String, double> themes;
  final bool instrumental;
}

int _count(String text, String needle) {
  var n = 0, at = 0;
  while ((at = text.indexOf(needle, at)) != -1) {
    n++;
    at += needle.length;
  }
  return n;
}

/// Reads a song's traits from its lyrics, title, genre and length. Plain text work,
/// so it takes microseconds and needs no audio.
SongTraits analyzeSong(Song s) {
  var valence = 0.0, energy = 0.0, weight = 0.0;
  void vote(double v, double e, double w) {
    valence += v * w;
    energy += e * w;
    weight += w;
  }

  final genre = s.genre?.toLowerCase();
  if (genre != null) {
    for (final e in _genres.entries) {
      if (genre.contains(e.key)) {
        vote(e.value.$1, e.value.$2, 1);
        break;
      }
    }
  }
  if (s.instrumental) vote(0, -0.3, 0.5);

  var hasSentiment = false;
  final themes = <String, double>{};
  final title = s.title.toLowerCase();
  final titleWords = {for (final m in _word.allMatches(title)) m.group(0)!};
  // A word in the title says more than one anywhere in the lyrics.
  for (final t in _themes.entries) {
    if (titleWords.any(t.value.contains)) themes[t.key] = 1;
  }
  for (final t in _themeScript.entries) {
    if (t.value.any(title.contains)) themes[t.key] = 1;
  }

  final raw = s.lyrics;
  if (raw != null && raw.isNotEmpty) {
    final text = raw.replaceAll(_lrcStamp, ' ').toLowerCase();
    final words = [for (final m in _word.allMatches(text)) m.group(0)!];
    var pos = 0, neg = 0;
    final hits = <String, int>{};
    for (final w in words) {
      if (_positive.contains(w)) pos++;
      if (_negative.contains(w)) neg++;
      for (final t in _themes.entries) {
        if (t.value.contains(w)) hits[t.key] = (hits[t.key] ?? 0) + 1;
      }
    }
    for (final w in _positiveScript) {
      pos += _count(text, w);
    }
    for (final w in _negativeScript) {
      neg += _count(text, w);
    }
    for (final t in _themeScript.entries) {
      for (final w in t.value) {
        hits[t.key] = (hits[t.key] ?? 0) + _count(text, w);
      }
    }
    // Scripts without spaces count characters, so a word is about two of them.
    final nonLatin = text.replaceAll(RegExp(r'[a-z\s\p{P}\d]', unicode: true), '').length;
    final tokens = words.length + nonLatin / 2;
    if (tokens > 0) {
      if (pos + neg > 0) {
        // Leans to neutral when there's little evidence, however one-sided.
        final lean = (pos - neg) / (pos + neg + 3);
        hasSentiment = pos + neg >= 3;
        vote(lean.clamp(-1.0, 1.0), 0, 1.5);
      }
      // Words per second: fast, wordy songs tend to feel more intense.
      if (s.durationSec > 0) {
        final rate = tokens / s.durationSec;
        vote(0, ((rate - 1.2) / 1.2).clamp(-1.0, 1.0), 0.8);
      }
      for (final h in hits.entries) {
        final share = h.value / sqrt(tokens);
        themes[h.key] = min(1, (themes[h.key] ?? 0) + share);
      }
    }
  }

  return SongTraits(
    weight == 0 ? 0 : valence / weight,
    weight == 0 ? 0 : energy / weight,
    min(1, weight / 2.5),
    themes,
    s.instrumental,
    hasSentiment: hasSentiment,
  );
}

/// Fills gaps from a song's album and artist: songs by one artist tend to feel
/// alike, so a song with little known about it leans on those that have more.
void _spreadTraits(List<Song> songs, Map<String, SongTraits> traits) {
  for (final keyOf in <String Function(Song)>[(s) => firstArtist(s.artist), (s) => s.album]) {
    final sums = <String, List<double>>{};
    for (final s in songs) {
      final k = keyOf(s);
      if (k.isEmpty) continue;
      final t = traits[s.uniqueId]!;
      final sum = sums[k] ??= [0, 0, 0];
      sum[0] += t.valence * t.confidence;
      sum[1] += t.energy * t.confidence;
      sum[2] += t.confidence;
    }
    for (final s in songs) {
      final sum = sums[keyOf(s)];
      if (sum == null || sum[2] == 0) continue;
      final t = traits[s.uniqueId]!;
      const pull = 0.5;
      final total = t.confidence + pull;
      t.valence = (t.valence * t.confidence + sum[0] / sum[2] * pull) / total;
      t.energy = (t.energy * t.confidence + sum[1] / sum[2] * pull) / total;
      t.confidence = min(1, t.confidence + pull * min(1, sum[2]) * 0.5);
    }
  }
}

/// How well a song suits a mood, before personal taste. Above about 0.5 is a fit.
double moodFit(SongTraits t, Mood m) {
  final dv = t.valence - m.valence, de = t.energy - m.energy;
  const spread = 0.5;
  final near = exp(-(dv * dv + de * de) / (2 * spread * spread));
  var fit = near * (0.3 + 0.7 * t.confidence);
  // Moods that are about a feeling need words that show it.
  if (m.valence.abs() >= 0.5 && !t.hasSentiment && t.themes[m.theme] == null) fit *= 0.4;
  // Singing about it is strong evidence, but only if the song also feels close:
  // "when the party's over" is not a party song.
  if (m.theme != null) fit += 1.5 * (t.themes[m.theme] ?? 0) * max(0.15, near);
  if (m.wantsInstrumental) fit += t.instrumental ? 0.5 : -0.2;
  return fit;
}

/// Stable across devices and runs, unlike [String.hashCode], so one library gives
/// the same mixes on every device on the same day.
int stableHash(String text) {
  var h = 0x811c9dc5;
  for (final c in text.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

class MoodVerdict {
  const MoodVerdict(this.uniqueId, this.artist, this.mood, this.vote);
  final String uniqueId, artist, mood;

  /// 1 for "fits this mood", -1 for "doesn't".
  final int vote;
}

/// A list of songs someone made: a playlist, a Telegram topic, or their favorites.
class TasteList {
  const TasteList(this.name, this.songIds);
  final String name;
  final Set<String> songIds;
}

/// A picture of someone's taste, from their lists alone. Songs in a list score
/// highest, then other songs by the same artists, then by the same genres.
class TasteModel {
  TasteModel._(this._members, this._artists, this._genres);

  factory TasteModel.build(List<TasteList> lists, List<Song> songs) {
    final members = {for (final l in lists) ...l.songIds};
    final artists = <String, int>{};
    final genres = <String, int>{};
    for (final s in songs) {
      if (!members.contains(s.uniqueId)) continue;
      final a = firstArtist(s.artist);
      artists[a] = (artists[a] ?? 0) + 1;
      final g = s.genre;
      if (g != null) genres[g] = (genres[g] ?? 0) + 1;
    }
    return TasteModel._(members, artists, genres);
  }

  final Set<String> _members;
  final Map<String, int> _artists, _genres;

  bool get isEmpty => _members.isEmpty;
  bool contains(Song s) => _members.contains(s.uniqueId);

  /// 1 with nothing to go on. Otherwise from about 0.4, a stranger, upwards.
  double scoreOf(Song s) {
    if (_members.isEmpty) return 1;
    var score = 0.4;
    if (_members.contains(s.uniqueId)) score += 1;
    score += 0.8 * min(1, (_artists[firstArtist(s.artist)] ?? 0) / 3);
    final g = s.genre;
    if (g != null && _genres.isNotEmpty) {
      score += 0.4 * (_genres[g] ?? 0) / _genres.values.reduce(max);
    }
    return score;
  }
}

class DailyMix {
  const DailyMix(this.mood, this.title, this.songs);
  final Mood mood;
  final String title;
  final List<Song> songs;
}

const _mixLength = 30, _minMix = 10, _maxPerArtist = 2, _maxPerArtistInOwnList = 5, _fitFloor = 0.3;

/// A song already in one mix is this much less likely in the next, so each mix
/// sounds like itself instead of the same calm songs under different names.
const _usedPenalty = 0.2;

/// How much someone seems to like a song from what they do with it: how often they
/// finish it rather than skip it. Starts neutral, and few plays don't move it much.
/// Only used when learning from plays is turned on.
double tasteOf(Song s) {
  final finished = (s.plays + 1) / (s.plays + s.skips + 2);
  return 0.5 + finished;
}

/// Songs heard recently rest for a few days, so mixes stay fresh.
double freshnessOf(Song s, DateTime now) {
  final played = s.lastPlayedAt;
  if (played == null) return 1;
  final days = now.difference(DateTime.fromMillisecondsSinceEpoch(played)).inHours / 24;
  return days <= 0 ? 0.15 : min(1, 0.15 + 0.85 * days / 7);
}

/// Today's mixes, most fitting first.
///
/// For each mood: score every song by fit, taste and freshness, draw a weighted
/// random sample (so good fits are likely but not certain, and each day differs),
/// keep artists varied, then order it so each song flows into the next. About
/// O(n log n) per mood over plain numbers, needing no audio or network.
List<DailyMix> buildDailyMixes({
  required List<Song> songs,
  required DateTime now,
  List<MoodVerdict> votes = const [],
  WeatherKind? weather,
  List<TasteList> lists = const [],
  TasteSettings options = const TasteSettings(),
}) {
  final traits = {for (final s in songs) s.uniqueId: analyzeSong(s)};
  final taste = TasteModel.build(lists, songs);
  // Someone's own "Sad Songs" says more about what they find sad than any lyric.
  final namedFor = <String, Set<String>>{};
  for (final l in lists) {
    for (final m in moodsForListName(l.name)) {
      (namedFor[m] ??= {}).addAll(l.songIds);
    }
  }
  _spreadTraits(songs, traits);

  final songVotes = <String, int>{};
  final artistVotes = <String, int>{};
  for (final v in votes) {
    songVotes['${v.mood}:${v.uniqueId}'] = v.vote;
    final key = '${v.mood}:${firstArtist(v.artist)}';
    artistVotes[key] = (artistVotes[key] ?? 0) + v.vote;
  }

  final day = '${now.year}-${now.month}-${now.day}';
  final mixes = <DailyMix>[];
  final used = <String>{};
  for (final mood in moods) {
    final random = Random(stableHash('$day:${mood.id}'));
    final drawn = <(double, Song)>[];
    final named = namedFor[mood.id] ?? const <String>{};
    for (final s in songs) {
      if (options.onlyFromLists && !taste.isEmpty && !taste.contains(s)) continue;
      final vote = songVotes['${mood.id}:${s.uniqueId}'] ?? 0;
      if (vote < 0) continue;
      var fit = moodFit(traits[s.uniqueId]!, mood);
      if (vote > 0) fit += 1;
      if (named.contains(s.uniqueId)) fit += 1.5;
      // A verdict on one song says a little about the artist's others.
      fit += 0.1 * (artistVotes['${mood.id}:${firstArtist(s.artist)}'] ?? 0).clamp(-3, 3);
      if (fit < _fitFloor) continue;
      // A high power makes a clearly better fit much likelier, not just slightly.
      final weight = pow(fit, 4) *
          taste.scoreOf(s) *
          (options.learnFromPlays ? tasteOf(s) : 1) *
          (options.restRecent ? freshnessOf(s, now) : 1) *
          (used.contains(s.uniqueId) ? _usedPenalty : 1);
      // Efraimidis-Spirakis weighted sampling: the largest keys are the sample.
      drawn.add((pow(random.nextDouble(), 1 / weight).toDouble(), s));
    }
    drawn.sort((a, b) => b.$1.compareTo(a.$1));

    final perArtist = <String, int>{};
    final titles = <String>{};
    final picked = <Song>[];
    for (final (_, s) in drawn) {
      final artist = firstArtist(s.artist);
      // Someone's own list for this mood can lean on its artists more: that's their choice.
      final cap = named.contains(s.uniqueId) ? _maxPerArtistInOwnList : _maxPerArtist;
      if ((perArtist[artist] ?? 0) >= cap) continue;
      // Two files of one song shouldn't both be in a mix.
      if (!titles.add('${comparableText(searchTitle(s.title))}|$artist')) continue;
      perArtist[artist] = (perArtist[artist] ?? 0) + 1;
      picked.add(s);
      if (picked.length == _mixLength) break;
    }
    // Too few real fits makes a bad mix, so it's better to offer none.
    if (picked.length < _minMix) continue;
    used.addAll(picked.map((s) => s.uniqueId));
    mixes.add(DailyMix(mood, _titleFor(mood, weather), _sequence(picked, traits)));
  }
  final rank = {for (final (i, id) in contextOrder(now, weather).indexed) id: i};
  mixes.sort((a, b) => (rank[a.mood.id] ?? 99).compareTo(rank[b.mood.id] ?? 99));
  return mixes;
}

String _titleFor(Mood m, WeatherKind? weather) {
  if (m.id == 'rain' && (weather == WeatherKind.rain || weather == WeatherKind.storm)) return 'Rainy day mix';
  return '${m.name} mix';
}

/// Moods suited to right now first, from the weather and the time of day.
List<String> contextOrder(DateTime now, WeatherKind? weather) {
  final hour = now.hour;
  final byWeather = switch (weather) {
    WeatherKind.rain || WeatherKind.storm => ['rain', 'chill', 'sad'],
    WeatherKind.clear => hour >= 7 && hour < 19 ? ['happy', 'drive'] : <String>[],
    WeatherKind.cloudy => ['chill'],
    WeatherKind.snow => ['chill', 'love'],
    null => <String>[],
  };
  final byHour = hour >= 22 || hour < 5
      ? ['night', 'chill', 'sad']
      : hour < 10
          ? ['happy', 'focus', 'drive']
          : hour < 17
              ? ['focus', 'happy', 'workout']
              : ['drive', 'party', 'love'];
  return {...byWeather, ...byHour, for (final m in moods) m.id}.toList();
}

/// Orders songs so each is close in feel to the last, instead of lurching between
/// moods. Starts from the calmest, so a mix builds as it goes.
List<Song> _sequence(List<Song> songs, Map<String, SongTraits> traits) {
  final left = [...songs];
  left.sort((a, b) => traits[a.uniqueId]!.energy.compareTo(traits[b.uniqueId]!.energy));
  final ordered = [left.removeAt(0)];
  while (left.isNotEmpty) {
    final last = traits[ordered.last.uniqueId]!;
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < left.length; i++) {
      final t = traits[left[i].uniqueId]!;
      final d = pow(t.valence - last.valence, 2) + pow(t.energy - last.energy, 2);
      if (d < bestDistance) {
        bestDistance = d.toDouble();
        best = i;
      }
    }
    ordered.add(left.removeAt(best));
  }
  return ordered;
}
