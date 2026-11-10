import 'dart:convert';

/// The forum's built-in General topic. Everything unsorted lands there, so it says
/// little about taste and isn't learned from unless someone turns it on.
const generalTopicId = 1048576;

/// What mixes may learn from and do. Shared between devices, newest wins.
class TasteSettings {
  const TasteSettings({
    this.at = 0,
    this.resetAt = 0,
    this.sources = const {},
    this.topicNames = const {},
    this.showMixes = true,
    this.learnFromPlays = false,
    this.onlyFromLists = false,
    this.restRecent = true,
    this.lookups = true,
  });

  factory TasteSettings.fromJson(Map<String, dynamic> j) => TasteSettings(
        at: j['at'] as int? ?? 0,
        resetAt: j['resetAt'] as int? ?? 0,
        sources: (j['sources'] as Map<String, dynamic>? ?? const {}).cast<String, bool>(),
        topicNames: (j['topicNames'] as Map<String, dynamic>? ?? const {}).cast<String, String>(),
        showMixes: j['showMixes'] as bool? ?? true,
        learnFromPlays: j['learnFromPlays'] as bool? ?? false,
        onlyFromLists: j['onlyFromLists'] as bool? ?? false,
        restRecent: j['restRecent'] as bool? ?? true,
        lookups: j['lookups'] as bool? ?? true,
      );

  static TasteSettings parse(String? text) {
    if (text == null || text.isEmpty) return const TasteSettings();
    try {
      return TasteSettings.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } on FormatException {
      return const TasteSettings();
    }
  }

  /// When these were last changed.
  final int at;

  /// When learned data was last cleared. Older counts from another device are ignored.
  final int resetAt;

  /// Which lists to learn from, where someone chose. See [learnsFrom] for the default.
  final Map<String, bool> sources;

  /// Names given to topics here, since a bot can't always see a topic's current name.
  final Map<String, String> topicNames;
  final bool showMixes, learnFromPlays, onlyFromLists, restRecent, lookups;

  static const favoritesKey = 'favorites';
  static String playlistKey(String uuid) => 'playlist:$uuid';
  static String topicKey(int chatId, int topicId) => 'topic:$chatId:$topicId';

  bool learnsFrom(String key) => sources[key] ?? !key.endsWith(':$generalTopicId');

  TasteSettings copyWith({
    int? at,
    int? resetAt,
    Map<String, bool>? sources,
    Map<String, String>? topicNames,
    bool? showMixes,
    bool? learnFromPlays,
    bool? onlyFromLists,
    bool? restRecent,
    bool? lookups,
  }) =>
      TasteSettings(
        at: at ?? this.at,
        resetAt: resetAt ?? this.resetAt,
        sources: sources ?? this.sources,
        topicNames: topicNames ?? this.topicNames,
        showMixes: showMixes ?? this.showMixes,
        learnFromPlays: learnFromPlays ?? this.learnFromPlays,
        onlyFromLists: onlyFromLists ?? this.onlyFromLists,
        restRecent: restRecent ?? this.restRecent,
        lookups: lookups ?? this.lookups,
      );

  Map<String, dynamic> toJson() => {
        'at': at,
        'resetAt': resetAt,
        'sources': sources,
        'topicNames': topicNames,
        'showMixes': showMixes,
        'learnFromPlays': learnFromPlays,
        'onlyFromLists': onlyFromLists,
        'restRecent': restRecent,
        'lookups': lookups,
      };

  String encode() => jsonEncode(toJson());
}

const _listMoods = <String, List<String>>{
  'sad': ['sad'],
  'cry': ['sad'],
  'heartbreak': ['sad'],
  'calm': ['chill'],
  'chill': ['chill'],
  'relax': ['chill'],
  'sleep': ['chill'],
  'lofi': ['chill', 'focus'],
  'lo-fi': ['chill', 'focus'],
  'study': ['focus'],
  'focus': ['focus'],
  'phonk': ['workout', 'drive'],
  'gym': ['workout'],
  'workout': ['workout'],
  'hype': ['workout', 'party'],
  'drive': ['drive'],
  'driving': ['drive'],
  'road': ['drive'],
  'party': ['party'],
  'dance': ['party'],
  'love': ['love'],
  'romantic': ['love'],
  'rain': ['rain'],
  'monsoon': ['rain'],
  'night': ['night'],
  'midnight': ['night'],
  'happy': ['happy'],
  'feeling good': ['happy'],
  'good vibes': ['happy'],
};

/// Moods a list's own name says it's for: someone's "Sad Songs" is better evidence
/// of what they find sad than any lyric. "Work" is left out, since it's as often a
/// leftover name as a mood.
Set<String> moodsForListName(String name) {
  final n = name.toLowerCase();
  return {
    for (final e in _listMoods.entries)
      if (n.contains(e.key)) ...e.value,
  };
}
