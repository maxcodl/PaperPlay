// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $SongsTable extends Songs with TableInfo<$SongsTable, Song> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<int> chatId = GeneratedColumn<int>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<int> messageId = GeneratedColumn<int>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uniqueIdMeta = const VerificationMeta(
    'uniqueId',
  );
  @override
  late final GeneratedColumn<String> uniqueId = GeneratedColumn<String>(
    'unique_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<int> date = GeneratedColumn<int>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseIdMeta = const VerificationMeta(
    'releaseId',
  );
  @override
  late final GeneratedColumn<String> releaseId = GeneratedColumn<String>(
    'release_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataSourceMeta = const VerificationMeta(
    'metadataSource',
  );
  @override
  late final GeneratedColumn<String> metadataSource = GeneratedColumn<String>(
    'metadata_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
    'favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _coverHiResMeta = const VerificationMeta(
    'coverHiRes',
  );
  @override
  late final GeneratedColumn<bool> coverHiRes = GeneratedColumn<bool>(
    'cover_hi_res',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cover_hi_res" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userEditedMeta = const VerificationMeta(
    'userEdited',
  );
  @override
  late final GeneratedColumn<bool> userEdited = GeneratedColumn<bool>(
    'user_edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("user_edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _enrichStateMeta = const VerificationMeta(
    'enrichState',
  );
  @override
  late final GeneratedColumn<int> enrichState = GeneratedColumn<int>(
    'enrich_state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(EnrichState.pending),
  );
  static const VerificationMeta _lyricsMeta = const VerificationMeta('lyrics');
  @override
  late final GeneratedColumn<String> lyrics = GeneratedColumn<String>(
    'lyrics',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedBytesMeta = const VerificationMeta(
    'cachedBytes',
  );
  @override
  late final GeneratedColumn<int> cachedBytes = GeneratedColumn<int>(
    'cached_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<int> lastPlayedAt = GeneratedColumn<int>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tagsAtMeta = const VerificationMeta('tagsAt');
  @override
  late final GeneratedColumn<int> tagsAt = GeneratedColumn<int>(
    'tags_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _favoriteAtMeta = const VerificationMeta(
    'favoriteAt',
  );
  @override
  late final GeneratedColumn<int> favoriteAt = GeneratedColumn<int>(
    'favorite_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _coverAtMeta = const VerificationMeta(
    'coverAt',
  );
  @override
  late final GeneratedColumn<int> coverAt = GeneratedColumn<int>(
    'cover_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _instrumentalMeta = const VerificationMeta(
    'instrumental',
  );
  @override
  late final GeneratedColumn<bool> instrumental = GeneratedColumn<bool>(
    'instrumental',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("instrumental" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _moodScannedAtMeta = const VerificationMeta(
    'moodScannedAt',
  );
  @override
  late final GeneratedColumn<int> moodScannedAt = GeneratedColumn<int>(
    'mood_scanned_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _playsMeta = const VerificationMeta('plays');
  @override
  late final GeneratedColumn<int> plays = GeneratedColumn<int>(
    'plays',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _skipsMeta = const VerificationMeta('skips');
  @override
  late final GeneratedColumn<int> skips = GeneratedColumn<int>(
    'skips',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<int> topicId = GeneratedColumn<int>(
    'topic_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bitDepthMeta = const VerificationMeta(
    'bitDepth',
  );
  @override
  late final GeneratedColumn<int> bitDepth = GeneratedColumn<int>(
    'bit_depth',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codecMeta = const VerificationMeta('codec');
  @override
  late final GeneratedColumn<String> codec = GeneratedColumn<String>(
    'codec',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    chatId,
    messageId,
    uniqueId,
    remoteId,
    title,
    artist,
    album,
    durationSec,
    size,
    mime,
    fileName,
    date,
    coverPath,
    releaseId,
    coverUrl,
    genre,
    year,
    metadataSource,
    favorite,
    coverHiRes,
    userEdited,
    enrichState,
    lyrics,
    cachedBytes,
    lastPlayedAt,
    pinned,
    tagsAt,
    favoriteAt,
    coverAt,
    instrumental,
    moodScannedAt,
    plays,
    skips,
    topicId,
    sampleRate,
    bitDepth,
    codec,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Song> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('unique_id')) {
      context.handle(
        _uniqueIdMeta,
        uniqueId.isAcceptableOrUnknown(data['unique_id']!, _uniqueIdMeta),
      );
    } else if (isInserting) {
      context.missing(_uniqueIdMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('release_id')) {
      context.handle(
        _releaseIdMeta,
        releaseId.isAcceptableOrUnknown(data['release_id']!, _releaseIdMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('metadata_source')) {
      context.handle(
        _metadataSourceMeta,
        metadataSource.isAcceptableOrUnknown(
          data['metadata_source']!,
          _metadataSourceMeta,
        ),
      );
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
    }
    if (data.containsKey('cover_hi_res')) {
      context.handle(
        _coverHiResMeta,
        coverHiRes.isAcceptableOrUnknown(
          data['cover_hi_res']!,
          _coverHiResMeta,
        ),
      );
    }
    if (data.containsKey('user_edited')) {
      context.handle(
        _userEditedMeta,
        userEdited.isAcceptableOrUnknown(data['user_edited']!, _userEditedMeta),
      );
    }
    if (data.containsKey('enrich_state')) {
      context.handle(
        _enrichStateMeta,
        enrichState.isAcceptableOrUnknown(
          data['enrich_state']!,
          _enrichStateMeta,
        ),
      );
    }
    if (data.containsKey('lyrics')) {
      context.handle(
        _lyricsMeta,
        lyrics.isAcceptableOrUnknown(data['lyrics']!, _lyricsMeta),
      );
    }
    if (data.containsKey('cached_bytes')) {
      context.handle(
        _cachedBytesMeta,
        cachedBytes.isAcceptableOrUnknown(
          data['cached_bytes']!,
          _cachedBytesMeta,
        ),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('tags_at')) {
      context.handle(
        _tagsAtMeta,
        tagsAt.isAcceptableOrUnknown(data['tags_at']!, _tagsAtMeta),
      );
    }
    if (data.containsKey('favorite_at')) {
      context.handle(
        _favoriteAtMeta,
        favoriteAt.isAcceptableOrUnknown(data['favorite_at']!, _favoriteAtMeta),
      );
    }
    if (data.containsKey('cover_at')) {
      context.handle(
        _coverAtMeta,
        coverAt.isAcceptableOrUnknown(data['cover_at']!, _coverAtMeta),
      );
    }
    if (data.containsKey('instrumental')) {
      context.handle(
        _instrumentalMeta,
        instrumental.isAcceptableOrUnknown(
          data['instrumental']!,
          _instrumentalMeta,
        ),
      );
    }
    if (data.containsKey('mood_scanned_at')) {
      context.handle(
        _moodScannedAtMeta,
        moodScannedAt.isAcceptableOrUnknown(
          data['mood_scanned_at']!,
          _moodScannedAtMeta,
        ),
      );
    }
    if (data.containsKey('plays')) {
      context.handle(
        _playsMeta,
        plays.isAcceptableOrUnknown(data['plays']!, _playsMeta),
      );
    }
    if (data.containsKey('skips')) {
      context.handle(
        _skipsMeta,
        skips.isAcceptableOrUnknown(data['skips']!, _skipsMeta),
      );
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    }
    if (data.containsKey('bit_depth')) {
      context.handle(
        _bitDepthMeta,
        bitDepth.isAcceptableOrUnknown(data['bit_depth']!, _bitDepthMeta),
      );
    }
    if (data.containsKey('codec')) {
      context.handle(
        _codecMeta,
        codec.isAcceptableOrUnknown(data['codec']!, _codecMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chatId, messageId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {uniqueId},
  ];
  @override
  Song map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Song(
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chat_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      )!,
      uniqueId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unique_id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      )!,
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date'],
      )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      releaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}release_id'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      metadataSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_source'],
      ),
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorite'],
      )!,
      coverHiRes: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cover_hi_res'],
      )!,
      userEdited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}user_edited'],
      )!,
      enrichState: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enrich_state'],
      )!,
      lyrics: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lyrics'],
      ),
      cachedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_bytes'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_played_at'],
      ),
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      tagsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tags_at'],
      )!,
      favoriteAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}favorite_at'],
      )!,
      coverAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cover_at'],
      )!,
      instrumental: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}instrumental'],
      )!,
      moodScannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mood_scanned_at'],
      )!,
      plays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plays'],
      )!,
      skips: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skips'],
      )!,
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}topic_id'],
      ),
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      ),
      bitDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bit_depth'],
      ),
      codec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}codec'],
      ),
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }
}

class Song extends DataClass implements Insertable<Song> {
  final int chatId;
  final int messageId;

  /// Same file posted twice keeps one row, first seen wins.
  final String uniqueId;
  final String remoteId;
  final String title;
  final String artist;
  final String album;
  final int durationSec;
  final int size;
  final String mime;
  final String fileName;
  final int date;
  final String? coverPath;

  /// MusicBrainz release, for fetching the cover when a song is first shown.
  final String? releaseId;

  /// Cover found on Deezer or iTunes, fetched when the song is first shown.
  final String? coverUrl;
  final String? genre;
  final int? year;

  /// Which service the tags came from.
  final String? metadataSource;
  final bool favorite;

  /// [coverPath] is full size, not a small thumbnail from the Telegram file.
  final bool coverHiRes;
  final bool userEdited;
  final int enrichState;
  final String? lyrics;
  final int cachedBytes;
  final int? lastPlayedAt;
  final bool pinned;

  /// When tags last changed here; newest wins between devices. 0 means never.
  final int tagsAt;

  /// When [favorite] last changed, kept apart so a tag match can't undo it.
  final int favoriteAt;

  /// When someone chose this cover. Above 0, automatic covers leave it alone,
  /// and other devices fetch its image, since cover files aren't otherwise shared.
  final int coverAt;

  /// The lyrics service says this song has no words.
  final bool instrumental;

  /// When its lyrics and genre were looked up for mood mixes. 0 means not yet.
  final int moodScannedAt;

  /// Times finished and skipped, which teach the mixes what's liked.
  final int plays;
  final int skips;

  /// The forum topic it was posted in, if the chat has topics.
  final int? topicId;

  /// Read from the file's header once some of it is on a device. Null until then:
  /// never estimated. [codec] is set only where the file name can't tell, like
  /// ALAC inside an .m4a.
  final int? sampleRate;
  final int? bitDepth;
  final String? codec;
  const Song({
    required this.chatId,
    required this.messageId,
    required this.uniqueId,
    required this.remoteId,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSec,
    required this.size,
    required this.mime,
    required this.fileName,
    required this.date,
    this.coverPath,
    this.releaseId,
    this.coverUrl,
    this.genre,
    this.year,
    this.metadataSource,
    required this.favorite,
    required this.coverHiRes,
    required this.userEdited,
    required this.enrichState,
    this.lyrics,
    required this.cachedBytes,
    this.lastPlayedAt,
    required this.pinned,
    required this.tagsAt,
    required this.favoriteAt,
    required this.coverAt,
    required this.instrumental,
    required this.moodScannedAt,
    required this.plays,
    required this.skips,
    this.topicId,
    this.sampleRate,
    this.bitDepth,
    this.codec,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chat_id'] = Variable<int>(chatId);
    map['message_id'] = Variable<int>(messageId);
    map['unique_id'] = Variable<String>(uniqueId);
    map['remote_id'] = Variable<String>(remoteId);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['album'] = Variable<String>(album);
    map['duration_sec'] = Variable<int>(durationSec);
    map['size'] = Variable<int>(size);
    map['mime'] = Variable<String>(mime);
    map['file_name'] = Variable<String>(fileName);
    map['date'] = Variable<int>(date);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || releaseId != null) {
      map['release_id'] = Variable<String>(releaseId);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || metadataSource != null) {
      map['metadata_source'] = Variable<String>(metadataSource);
    }
    map['favorite'] = Variable<bool>(favorite);
    map['cover_hi_res'] = Variable<bool>(coverHiRes);
    map['user_edited'] = Variable<bool>(userEdited);
    map['enrich_state'] = Variable<int>(enrichState);
    if (!nullToAbsent || lyrics != null) {
      map['lyrics'] = Variable<String>(lyrics);
    }
    map['cached_bytes'] = Variable<int>(cachedBytes);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<int>(lastPlayedAt);
    }
    map['pinned'] = Variable<bool>(pinned);
    map['tags_at'] = Variable<int>(tagsAt);
    map['favorite_at'] = Variable<int>(favoriteAt);
    map['cover_at'] = Variable<int>(coverAt);
    map['instrumental'] = Variable<bool>(instrumental);
    map['mood_scanned_at'] = Variable<int>(moodScannedAt);
    map['plays'] = Variable<int>(plays);
    map['skips'] = Variable<int>(skips);
    if (!nullToAbsent || topicId != null) {
      map['topic_id'] = Variable<int>(topicId);
    }
    if (!nullToAbsent || sampleRate != null) {
      map['sample_rate'] = Variable<int>(sampleRate);
    }
    if (!nullToAbsent || bitDepth != null) {
      map['bit_depth'] = Variable<int>(bitDepth);
    }
    if (!nullToAbsent || codec != null) {
      map['codec'] = Variable<String>(codec);
    }
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      chatId: Value(chatId),
      messageId: Value(messageId),
      uniqueId: Value(uniqueId),
      remoteId: Value(remoteId),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      durationSec: Value(durationSec),
      size: Value(size),
      mime: Value(mime),
      fileName: Value(fileName),
      date: Value(date),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      releaseId: releaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseId),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      metadataSource: metadataSource == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataSource),
      favorite: Value(favorite),
      coverHiRes: Value(coverHiRes),
      userEdited: Value(userEdited),
      enrichState: Value(enrichState),
      lyrics: lyrics == null && nullToAbsent
          ? const Value.absent()
          : Value(lyrics),
      cachedBytes: Value(cachedBytes),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
      pinned: Value(pinned),
      tagsAt: Value(tagsAt),
      favoriteAt: Value(favoriteAt),
      coverAt: Value(coverAt),
      instrumental: Value(instrumental),
      moodScannedAt: Value(moodScannedAt),
      plays: Value(plays),
      skips: Value(skips),
      topicId: topicId == null && nullToAbsent
          ? const Value.absent()
          : Value(topicId),
      sampleRate: sampleRate == null && nullToAbsent
          ? const Value.absent()
          : Value(sampleRate),
      bitDepth: bitDepth == null && nullToAbsent
          ? const Value.absent()
          : Value(bitDepth),
      codec: codec == null && nullToAbsent
          ? const Value.absent()
          : Value(codec),
    );
  }

  factory Song.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Song(
      chatId: serializer.fromJson<int>(json['chatId']),
      messageId: serializer.fromJson<int>(json['messageId']),
      uniqueId: serializer.fromJson<String>(json['uniqueId']),
      remoteId: serializer.fromJson<String>(json['remoteId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String>(json['album']),
      durationSec: serializer.fromJson<int>(json['durationSec']),
      size: serializer.fromJson<int>(json['size']),
      mime: serializer.fromJson<String>(json['mime']),
      fileName: serializer.fromJson<String>(json['fileName']),
      date: serializer.fromJson<int>(json['date']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      releaseId: serializer.fromJson<String?>(json['releaseId']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      genre: serializer.fromJson<String?>(json['genre']),
      year: serializer.fromJson<int?>(json['year']),
      metadataSource: serializer.fromJson<String?>(json['metadataSource']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      coverHiRes: serializer.fromJson<bool>(json['coverHiRes']),
      userEdited: serializer.fromJson<bool>(json['userEdited']),
      enrichState: serializer.fromJson<int>(json['enrichState']),
      lyrics: serializer.fromJson<String?>(json['lyrics']),
      cachedBytes: serializer.fromJson<int>(json['cachedBytes']),
      lastPlayedAt: serializer.fromJson<int?>(json['lastPlayedAt']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      tagsAt: serializer.fromJson<int>(json['tagsAt']),
      favoriteAt: serializer.fromJson<int>(json['favoriteAt']),
      coverAt: serializer.fromJson<int>(json['coverAt']),
      instrumental: serializer.fromJson<bool>(json['instrumental']),
      moodScannedAt: serializer.fromJson<int>(json['moodScannedAt']),
      plays: serializer.fromJson<int>(json['plays']),
      skips: serializer.fromJson<int>(json['skips']),
      topicId: serializer.fromJson<int?>(json['topicId']),
      sampleRate: serializer.fromJson<int?>(json['sampleRate']),
      bitDepth: serializer.fromJson<int?>(json['bitDepth']),
      codec: serializer.fromJson<String?>(json['codec']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chatId': serializer.toJson<int>(chatId),
      'messageId': serializer.toJson<int>(messageId),
      'uniqueId': serializer.toJson<String>(uniqueId),
      'remoteId': serializer.toJson<String>(remoteId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String>(album),
      'durationSec': serializer.toJson<int>(durationSec),
      'size': serializer.toJson<int>(size),
      'mime': serializer.toJson<String>(mime),
      'fileName': serializer.toJson<String>(fileName),
      'date': serializer.toJson<int>(date),
      'coverPath': serializer.toJson<String?>(coverPath),
      'releaseId': serializer.toJson<String?>(releaseId),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'genre': serializer.toJson<String?>(genre),
      'year': serializer.toJson<int?>(year),
      'metadataSource': serializer.toJson<String?>(metadataSource),
      'favorite': serializer.toJson<bool>(favorite),
      'coverHiRes': serializer.toJson<bool>(coverHiRes),
      'userEdited': serializer.toJson<bool>(userEdited),
      'enrichState': serializer.toJson<int>(enrichState),
      'lyrics': serializer.toJson<String?>(lyrics),
      'cachedBytes': serializer.toJson<int>(cachedBytes),
      'lastPlayedAt': serializer.toJson<int?>(lastPlayedAt),
      'pinned': serializer.toJson<bool>(pinned),
      'tagsAt': serializer.toJson<int>(tagsAt),
      'favoriteAt': serializer.toJson<int>(favoriteAt),
      'coverAt': serializer.toJson<int>(coverAt),
      'instrumental': serializer.toJson<bool>(instrumental),
      'moodScannedAt': serializer.toJson<int>(moodScannedAt),
      'plays': serializer.toJson<int>(plays),
      'skips': serializer.toJson<int>(skips),
      'topicId': serializer.toJson<int?>(topicId),
      'sampleRate': serializer.toJson<int?>(sampleRate),
      'bitDepth': serializer.toJson<int?>(bitDepth),
      'codec': serializer.toJson<String?>(codec),
    };
  }

  Song copyWith({
    int? chatId,
    int? messageId,
    String? uniqueId,
    String? remoteId,
    String? title,
    String? artist,
    String? album,
    int? durationSec,
    int? size,
    String? mime,
    String? fileName,
    int? date,
    Value<String?> coverPath = const Value.absent(),
    Value<String?> releaseId = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> metadataSource = const Value.absent(),
    bool? favorite,
    bool? coverHiRes,
    bool? userEdited,
    int? enrichState,
    Value<String?> lyrics = const Value.absent(),
    int? cachedBytes,
    Value<int?> lastPlayedAt = const Value.absent(),
    bool? pinned,
    int? tagsAt,
    int? favoriteAt,
    int? coverAt,
    bool? instrumental,
    int? moodScannedAt,
    int? plays,
    int? skips,
    Value<int?> topicId = const Value.absent(),
    Value<int?> sampleRate = const Value.absent(),
    Value<int?> bitDepth = const Value.absent(),
    Value<String?> codec = const Value.absent(),
  }) => Song(
    chatId: chatId ?? this.chatId,
    messageId: messageId ?? this.messageId,
    uniqueId: uniqueId ?? this.uniqueId,
    remoteId: remoteId ?? this.remoteId,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    durationSec: durationSec ?? this.durationSec,
    size: size ?? this.size,
    mime: mime ?? this.mime,
    fileName: fileName ?? this.fileName,
    date: date ?? this.date,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    releaseId: releaseId.present ? releaseId.value : this.releaseId,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    genre: genre.present ? genre.value : this.genre,
    year: year.present ? year.value : this.year,
    metadataSource: metadataSource.present
        ? metadataSource.value
        : this.metadataSource,
    favorite: favorite ?? this.favorite,
    coverHiRes: coverHiRes ?? this.coverHiRes,
    userEdited: userEdited ?? this.userEdited,
    enrichState: enrichState ?? this.enrichState,
    lyrics: lyrics.present ? lyrics.value : this.lyrics,
    cachedBytes: cachedBytes ?? this.cachedBytes,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
    pinned: pinned ?? this.pinned,
    tagsAt: tagsAt ?? this.tagsAt,
    favoriteAt: favoriteAt ?? this.favoriteAt,
    coverAt: coverAt ?? this.coverAt,
    instrumental: instrumental ?? this.instrumental,
    moodScannedAt: moodScannedAt ?? this.moodScannedAt,
    plays: plays ?? this.plays,
    skips: skips ?? this.skips,
    topicId: topicId.present ? topicId.value : this.topicId,
    sampleRate: sampleRate.present ? sampleRate.value : this.sampleRate,
    bitDepth: bitDepth.present ? bitDepth.value : this.bitDepth,
    codec: codec.present ? codec.value : this.codec,
  );
  Song copyWithCompanion(SongsCompanion data) {
    return Song(
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      uniqueId: data.uniqueId.present ? data.uniqueId.value : this.uniqueId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      size: data.size.present ? data.size.value : this.size,
      mime: data.mime.present ? data.mime.value : this.mime,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      date: data.date.present ? data.date.value : this.date,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      releaseId: data.releaseId.present ? data.releaseId.value : this.releaseId,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      genre: data.genre.present ? data.genre.value : this.genre,
      year: data.year.present ? data.year.value : this.year,
      metadataSource: data.metadataSource.present
          ? data.metadataSource.value
          : this.metadataSource,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      coverHiRes: data.coverHiRes.present
          ? data.coverHiRes.value
          : this.coverHiRes,
      userEdited: data.userEdited.present
          ? data.userEdited.value
          : this.userEdited,
      enrichState: data.enrichState.present
          ? data.enrichState.value
          : this.enrichState,
      lyrics: data.lyrics.present ? data.lyrics.value : this.lyrics,
      cachedBytes: data.cachedBytes.present
          ? data.cachedBytes.value
          : this.cachedBytes,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      tagsAt: data.tagsAt.present ? data.tagsAt.value : this.tagsAt,
      favoriteAt: data.favoriteAt.present
          ? data.favoriteAt.value
          : this.favoriteAt,
      coverAt: data.coverAt.present ? data.coverAt.value : this.coverAt,
      instrumental: data.instrumental.present
          ? data.instrumental.value
          : this.instrumental,
      moodScannedAt: data.moodScannedAt.present
          ? data.moodScannedAt.value
          : this.moodScannedAt,
      plays: data.plays.present ? data.plays.value : this.plays,
      skips: data.skips.present ? data.skips.value : this.skips,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      sampleRate: data.sampleRate.present
          ? data.sampleRate.value
          : this.sampleRate,
      bitDepth: data.bitDepth.present ? data.bitDepth.value : this.bitDepth,
      codec: data.codec.present ? data.codec.value : this.codec,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Song(')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('uniqueId: $uniqueId, ')
          ..write('remoteId: $remoteId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('durationSec: $durationSec, ')
          ..write('size: $size, ')
          ..write('mime: $mime, ')
          ..write('fileName: $fileName, ')
          ..write('date: $date, ')
          ..write('coverPath: $coverPath, ')
          ..write('releaseId: $releaseId, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('metadataSource: $metadataSource, ')
          ..write('favorite: $favorite, ')
          ..write('coverHiRes: $coverHiRes, ')
          ..write('userEdited: $userEdited, ')
          ..write('enrichState: $enrichState, ')
          ..write('lyrics: $lyrics, ')
          ..write('cachedBytes: $cachedBytes, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('pinned: $pinned, ')
          ..write('tagsAt: $tagsAt, ')
          ..write('favoriteAt: $favoriteAt, ')
          ..write('coverAt: $coverAt, ')
          ..write('instrumental: $instrumental, ')
          ..write('moodScannedAt: $moodScannedAt, ')
          ..write('plays: $plays, ')
          ..write('skips: $skips, ')
          ..write('topicId: $topicId, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('bitDepth: $bitDepth, ')
          ..write('codec: $codec')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    chatId,
    messageId,
    uniqueId,
    remoteId,
    title,
    artist,
    album,
    durationSec,
    size,
    mime,
    fileName,
    date,
    coverPath,
    releaseId,
    coverUrl,
    genre,
    year,
    metadataSource,
    favorite,
    coverHiRes,
    userEdited,
    enrichState,
    lyrics,
    cachedBytes,
    lastPlayedAt,
    pinned,
    tagsAt,
    favoriteAt,
    coverAt,
    instrumental,
    moodScannedAt,
    plays,
    skips,
    topicId,
    sampleRate,
    bitDepth,
    codec,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Song &&
          other.chatId == this.chatId &&
          other.messageId == this.messageId &&
          other.uniqueId == this.uniqueId &&
          other.remoteId == this.remoteId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.durationSec == this.durationSec &&
          other.size == this.size &&
          other.mime == this.mime &&
          other.fileName == this.fileName &&
          other.date == this.date &&
          other.coverPath == this.coverPath &&
          other.releaseId == this.releaseId &&
          other.coverUrl == this.coverUrl &&
          other.genre == this.genre &&
          other.year == this.year &&
          other.metadataSource == this.metadataSource &&
          other.favorite == this.favorite &&
          other.coverHiRes == this.coverHiRes &&
          other.userEdited == this.userEdited &&
          other.enrichState == this.enrichState &&
          other.lyrics == this.lyrics &&
          other.cachedBytes == this.cachedBytes &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.pinned == this.pinned &&
          other.tagsAt == this.tagsAt &&
          other.favoriteAt == this.favoriteAt &&
          other.coverAt == this.coverAt &&
          other.instrumental == this.instrumental &&
          other.moodScannedAt == this.moodScannedAt &&
          other.plays == this.plays &&
          other.skips == this.skips &&
          other.topicId == this.topicId &&
          other.sampleRate == this.sampleRate &&
          other.bitDepth == this.bitDepth &&
          other.codec == this.codec);
}

class SongsCompanion extends UpdateCompanion<Song> {
  final Value<int> chatId;
  final Value<int> messageId;
  final Value<String> uniqueId;
  final Value<String> remoteId;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> album;
  final Value<int> durationSec;
  final Value<int> size;
  final Value<String> mime;
  final Value<String> fileName;
  final Value<int> date;
  final Value<String?> coverPath;
  final Value<String?> releaseId;
  final Value<String?> coverUrl;
  final Value<String?> genre;
  final Value<int?> year;
  final Value<String?> metadataSource;
  final Value<bool> favorite;
  final Value<bool> coverHiRes;
  final Value<bool> userEdited;
  final Value<int> enrichState;
  final Value<String?> lyrics;
  final Value<int> cachedBytes;
  final Value<int?> lastPlayedAt;
  final Value<bool> pinned;
  final Value<int> tagsAt;
  final Value<int> favoriteAt;
  final Value<int> coverAt;
  final Value<bool> instrumental;
  final Value<int> moodScannedAt;
  final Value<int> plays;
  final Value<int> skips;
  final Value<int?> topicId;
  final Value<int?> sampleRate;
  final Value<int?> bitDepth;
  final Value<String?> codec;
  final Value<int> rowid;
  const SongsCompanion({
    this.chatId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.uniqueId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.size = const Value.absent(),
    this.mime = const Value.absent(),
    this.fileName = const Value.absent(),
    this.date = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.releaseId = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.metadataSource = const Value.absent(),
    this.favorite = const Value.absent(),
    this.coverHiRes = const Value.absent(),
    this.userEdited = const Value.absent(),
    this.enrichState = const Value.absent(),
    this.lyrics = const Value.absent(),
    this.cachedBytes = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.pinned = const Value.absent(),
    this.tagsAt = const Value.absent(),
    this.favoriteAt = const Value.absent(),
    this.coverAt = const Value.absent(),
    this.instrumental = const Value.absent(),
    this.moodScannedAt = const Value.absent(),
    this.plays = const Value.absent(),
    this.skips = const Value.absent(),
    this.topicId = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.bitDepth = const Value.absent(),
    this.codec = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SongsCompanion.insert({
    required int chatId,
    required int messageId,
    required String uniqueId,
    required String remoteId,
    required String title,
    required String artist,
    this.album = const Value.absent(),
    this.durationSec = const Value.absent(),
    required int size,
    required String mime,
    required String fileName,
    required int date,
    this.coverPath = const Value.absent(),
    this.releaseId = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.metadataSource = const Value.absent(),
    this.favorite = const Value.absent(),
    this.coverHiRes = const Value.absent(),
    this.userEdited = const Value.absent(),
    this.enrichState = const Value.absent(),
    this.lyrics = const Value.absent(),
    this.cachedBytes = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.pinned = const Value.absent(),
    this.tagsAt = const Value.absent(),
    this.favoriteAt = const Value.absent(),
    this.coverAt = const Value.absent(),
    this.instrumental = const Value.absent(),
    this.moodScannedAt = const Value.absent(),
    this.plays = const Value.absent(),
    this.skips = const Value.absent(),
    this.topicId = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.bitDepth = const Value.absent(),
    this.codec = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : chatId = Value(chatId),
       messageId = Value(messageId),
       uniqueId = Value(uniqueId),
       remoteId = Value(remoteId),
       title = Value(title),
       artist = Value(artist),
       size = Value(size),
       mime = Value(mime),
       fileName = Value(fileName),
       date = Value(date);
  static Insertable<Song> custom({
    Expression<int>? chatId,
    Expression<int>? messageId,
    Expression<String>? uniqueId,
    Expression<String>? remoteId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<int>? durationSec,
    Expression<int>? size,
    Expression<String>? mime,
    Expression<String>? fileName,
    Expression<int>? date,
    Expression<String>? coverPath,
    Expression<String>? releaseId,
    Expression<String>? coverUrl,
    Expression<String>? genre,
    Expression<int>? year,
    Expression<String>? metadataSource,
    Expression<bool>? favorite,
    Expression<bool>? coverHiRes,
    Expression<bool>? userEdited,
    Expression<int>? enrichState,
    Expression<String>? lyrics,
    Expression<int>? cachedBytes,
    Expression<int>? lastPlayedAt,
    Expression<bool>? pinned,
    Expression<int>? tagsAt,
    Expression<int>? favoriteAt,
    Expression<int>? coverAt,
    Expression<bool>? instrumental,
    Expression<int>? moodScannedAt,
    Expression<int>? plays,
    Expression<int>? skips,
    Expression<int>? topicId,
    Expression<int>? sampleRate,
    Expression<int>? bitDepth,
    Expression<String>? codec,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chatId != null) 'chat_id': chatId,
      if (messageId != null) 'message_id': messageId,
      if (uniqueId != null) 'unique_id': uniqueId,
      if (remoteId != null) 'remote_id': remoteId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (durationSec != null) 'duration_sec': durationSec,
      if (size != null) 'size': size,
      if (mime != null) 'mime': mime,
      if (fileName != null) 'file_name': fileName,
      if (date != null) 'date': date,
      if (coverPath != null) 'cover_path': coverPath,
      if (releaseId != null) 'release_id': releaseId,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (genre != null) 'genre': genre,
      if (year != null) 'year': year,
      if (metadataSource != null) 'metadata_source': metadataSource,
      if (favorite != null) 'favorite': favorite,
      if (coverHiRes != null) 'cover_hi_res': coverHiRes,
      if (userEdited != null) 'user_edited': userEdited,
      if (enrichState != null) 'enrich_state': enrichState,
      if (lyrics != null) 'lyrics': lyrics,
      if (cachedBytes != null) 'cached_bytes': cachedBytes,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (pinned != null) 'pinned': pinned,
      if (tagsAt != null) 'tags_at': tagsAt,
      if (favoriteAt != null) 'favorite_at': favoriteAt,
      if (coverAt != null) 'cover_at': coverAt,
      if (instrumental != null) 'instrumental': instrumental,
      if (moodScannedAt != null) 'mood_scanned_at': moodScannedAt,
      if (plays != null) 'plays': plays,
      if (skips != null) 'skips': skips,
      if (topicId != null) 'topic_id': topicId,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (bitDepth != null) 'bit_depth': bitDepth,
      if (codec != null) 'codec': codec,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SongsCompanion copyWith({
    Value<int>? chatId,
    Value<int>? messageId,
    Value<String>? uniqueId,
    Value<String>? remoteId,
    Value<String>? title,
    Value<String>? artist,
    Value<String>? album,
    Value<int>? durationSec,
    Value<int>? size,
    Value<String>? mime,
    Value<String>? fileName,
    Value<int>? date,
    Value<String?>? coverPath,
    Value<String?>? releaseId,
    Value<String?>? coverUrl,
    Value<String?>? genre,
    Value<int?>? year,
    Value<String?>? metadataSource,
    Value<bool>? favorite,
    Value<bool>? coverHiRes,
    Value<bool>? userEdited,
    Value<int>? enrichState,
    Value<String?>? lyrics,
    Value<int>? cachedBytes,
    Value<int?>? lastPlayedAt,
    Value<bool>? pinned,
    Value<int>? tagsAt,
    Value<int>? favoriteAt,
    Value<int>? coverAt,
    Value<bool>? instrumental,
    Value<int>? moodScannedAt,
    Value<int>? plays,
    Value<int>? skips,
    Value<int?>? topicId,
    Value<int?>? sampleRate,
    Value<int?>? bitDepth,
    Value<String?>? codec,
    Value<int>? rowid,
  }) {
    return SongsCompanion(
      chatId: chatId ?? this.chatId,
      messageId: messageId ?? this.messageId,
      uniqueId: uniqueId ?? this.uniqueId,
      remoteId: remoteId ?? this.remoteId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationSec: durationSec ?? this.durationSec,
      size: size ?? this.size,
      mime: mime ?? this.mime,
      fileName: fileName ?? this.fileName,
      date: date ?? this.date,
      coverPath: coverPath ?? this.coverPath,
      releaseId: releaseId ?? this.releaseId,
      coverUrl: coverUrl ?? this.coverUrl,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      metadataSource: metadataSource ?? this.metadataSource,
      favorite: favorite ?? this.favorite,
      coverHiRes: coverHiRes ?? this.coverHiRes,
      userEdited: userEdited ?? this.userEdited,
      enrichState: enrichState ?? this.enrichState,
      lyrics: lyrics ?? this.lyrics,
      cachedBytes: cachedBytes ?? this.cachedBytes,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      pinned: pinned ?? this.pinned,
      tagsAt: tagsAt ?? this.tagsAt,
      favoriteAt: favoriteAt ?? this.favoriteAt,
      coverAt: coverAt ?? this.coverAt,
      instrumental: instrumental ?? this.instrumental,
      moodScannedAt: moodScannedAt ?? this.moodScannedAt,
      plays: plays ?? this.plays,
      skips: skips ?? this.skips,
      topicId: topicId ?? this.topicId,
      sampleRate: sampleRate ?? this.sampleRate,
      bitDepth: bitDepth ?? this.bitDepth,
      codec: codec ?? this.codec,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chatId.present) {
      map['chat_id'] = Variable<int>(chatId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<int>(messageId.value);
    }
    if (uniqueId.present) {
      map['unique_id'] = Variable<String>(uniqueId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(date.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (releaseId.present) {
      map['release_id'] = Variable<String>(releaseId.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (metadataSource.present) {
      map['metadata_source'] = Variable<String>(metadataSource.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (coverHiRes.present) {
      map['cover_hi_res'] = Variable<bool>(coverHiRes.value);
    }
    if (userEdited.present) {
      map['user_edited'] = Variable<bool>(userEdited.value);
    }
    if (enrichState.present) {
      map['enrich_state'] = Variable<int>(enrichState.value);
    }
    if (lyrics.present) {
      map['lyrics'] = Variable<String>(lyrics.value);
    }
    if (cachedBytes.present) {
      map['cached_bytes'] = Variable<int>(cachedBytes.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<int>(lastPlayedAt.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (tagsAt.present) {
      map['tags_at'] = Variable<int>(tagsAt.value);
    }
    if (favoriteAt.present) {
      map['favorite_at'] = Variable<int>(favoriteAt.value);
    }
    if (coverAt.present) {
      map['cover_at'] = Variable<int>(coverAt.value);
    }
    if (instrumental.present) {
      map['instrumental'] = Variable<bool>(instrumental.value);
    }
    if (moodScannedAt.present) {
      map['mood_scanned_at'] = Variable<int>(moodScannedAt.value);
    }
    if (plays.present) {
      map['plays'] = Variable<int>(plays.value);
    }
    if (skips.present) {
      map['skips'] = Variable<int>(skips.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<int>(topicId.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (bitDepth.present) {
      map['bit_depth'] = Variable<int>(bitDepth.value);
    }
    if (codec.present) {
      map['codec'] = Variable<String>(codec.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('uniqueId: $uniqueId, ')
          ..write('remoteId: $remoteId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('durationSec: $durationSec, ')
          ..write('size: $size, ')
          ..write('mime: $mime, ')
          ..write('fileName: $fileName, ')
          ..write('date: $date, ')
          ..write('coverPath: $coverPath, ')
          ..write('releaseId: $releaseId, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('metadataSource: $metadataSource, ')
          ..write('favorite: $favorite, ')
          ..write('coverHiRes: $coverHiRes, ')
          ..write('userEdited: $userEdited, ')
          ..write('enrichState: $enrichState, ')
          ..write('lyrics: $lyrics, ')
          ..write('cachedBytes: $cachedBytes, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('pinned: $pinned, ')
          ..write('tagsAt: $tagsAt, ')
          ..write('favoriteAt: $favoriteAt, ')
          ..write('coverAt: $coverAt, ')
          ..write('instrumental: $instrumental, ')
          ..write('moodScannedAt: $moodScannedAt, ')
          ..write('plays: $plays, ')
          ..write('skips: $skips, ')
          ..write('topicId: $topicId, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('bitDepth: $bitDepth, ')
          ..write('codec: $codec, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryChatsTable extends LibraryChats
    with TableInfo<$LibraryChatsTable, LibraryChat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryChatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastScannedMessageIdMeta =
      const VerificationMeta('lastScannedMessageId');
  @override
  late final GeneratedColumn<int> lastScannedMessageId = GeneratedColumn<int>(
    'last_scanned_message_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _useBotMeta = const VerificationMeta('useBot');
  @override
  late final GeneratedColumn<bool> useBot = GeneratedColumn<bool>(
    'use_bot',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_bot" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _walkDoneMeta = const VerificationMeta(
    'walkDone',
  );
  @override
  late final GeneratedColumn<bool> walkDone = GeneratedColumn<bool>(
    'walk_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("walk_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    lastScannedMessageId,
    useBot,
    walkDone,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_chats';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryChat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('last_scanned_message_id')) {
      context.handle(
        _lastScannedMessageIdMeta,
        lastScannedMessageId.isAcceptableOrUnknown(
          data['last_scanned_message_id']!,
          _lastScannedMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('use_bot')) {
      context.handle(
        _useBotMeta,
        useBot.isAcceptableOrUnknown(data['use_bot']!, _useBotMeta),
      );
    }
    if (data.containsKey('walk_done')) {
      context.handle(
        _walkDoneMeta,
        walkDone.isAcceptableOrUnknown(data['walk_done']!, _walkDoneMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LibraryChat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryChat(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      lastScannedMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_scanned_message_id'],
      ),
      useBot: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_bot'],
      )!,
      walkDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}walk_done'],
      )!,
    );
  }

  @override
  $LibraryChatsTable createAlias(String alias) {
    return $LibraryChatsTable(attachedDatabase, alias);
  }
}

class LibraryChat extends DataClass implements Insertable<LibraryChat> {
  final int id;
  final String title;
  final int? lastScannedMessageId;

  /// Left over from when a user login could also read chats. No longer used.
  final bool useBot;

  /// The bot has read this chat through to its end at least once.
  final bool walkDone;
  const LibraryChat({
    required this.id,
    required this.title,
    this.lastScannedMessageId,
    required this.useBot,
    required this.walkDone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || lastScannedMessageId != null) {
      map['last_scanned_message_id'] = Variable<int>(lastScannedMessageId);
    }
    map['use_bot'] = Variable<bool>(useBot);
    map['walk_done'] = Variable<bool>(walkDone);
    return map;
  }

  LibraryChatsCompanion toCompanion(bool nullToAbsent) {
    return LibraryChatsCompanion(
      id: Value(id),
      title: Value(title),
      lastScannedMessageId: lastScannedMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScannedMessageId),
      useBot: Value(useBot),
      walkDone: Value(walkDone),
    );
  }

  factory LibraryChat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryChat(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      lastScannedMessageId: serializer.fromJson<int?>(
        json['lastScannedMessageId'],
      ),
      useBot: serializer.fromJson<bool>(json['useBot']),
      walkDone: serializer.fromJson<bool>(json['walkDone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'lastScannedMessageId': serializer.toJson<int?>(lastScannedMessageId),
      'useBot': serializer.toJson<bool>(useBot),
      'walkDone': serializer.toJson<bool>(walkDone),
    };
  }

  LibraryChat copyWith({
    int? id,
    String? title,
    Value<int?> lastScannedMessageId = const Value.absent(),
    bool? useBot,
    bool? walkDone,
  }) => LibraryChat(
    id: id ?? this.id,
    title: title ?? this.title,
    lastScannedMessageId: lastScannedMessageId.present
        ? lastScannedMessageId.value
        : this.lastScannedMessageId,
    useBot: useBot ?? this.useBot,
    walkDone: walkDone ?? this.walkDone,
  );
  LibraryChat copyWithCompanion(LibraryChatsCompanion data) {
    return LibraryChat(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      lastScannedMessageId: data.lastScannedMessageId.present
          ? data.lastScannedMessageId.value
          : this.lastScannedMessageId,
      useBot: data.useBot.present ? data.useBot.value : this.useBot,
      walkDone: data.walkDone.present ? data.walkDone.value : this.walkDone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibraryChat(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('lastScannedMessageId: $lastScannedMessageId, ')
          ..write('useBot: $useBot, ')
          ..write('walkDone: $walkDone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, lastScannedMessageId, useBot, walkDone);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibraryChat &&
          other.id == this.id &&
          other.title == this.title &&
          other.lastScannedMessageId == this.lastScannedMessageId &&
          other.useBot == this.useBot &&
          other.walkDone == this.walkDone);
}

class LibraryChatsCompanion extends UpdateCompanion<LibraryChat> {
  final Value<int> id;
  final Value<String> title;
  final Value<int?> lastScannedMessageId;
  final Value<bool> useBot;
  final Value<bool> walkDone;
  const LibraryChatsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.lastScannedMessageId = const Value.absent(),
    this.useBot = const Value.absent(),
    this.walkDone = const Value.absent(),
  });
  LibraryChatsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.lastScannedMessageId = const Value.absent(),
    this.useBot = const Value.absent(),
    this.walkDone = const Value.absent(),
  }) : title = Value(title);
  static Insertable<LibraryChat> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<int>? lastScannedMessageId,
    Expression<bool>? useBot,
    Expression<bool>? walkDone,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (lastScannedMessageId != null)
        'last_scanned_message_id': lastScannedMessageId,
      if (useBot != null) 'use_bot': useBot,
      if (walkDone != null) 'walk_done': walkDone,
    });
  }

  LibraryChatsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<int?>? lastScannedMessageId,
    Value<bool>? useBot,
    Value<bool>? walkDone,
  }) {
    return LibraryChatsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      lastScannedMessageId: lastScannedMessageId ?? this.lastScannedMessageId,
      useBot: useBot ?? this.useBot,
      walkDone: walkDone ?? this.walkDone,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (lastScannedMessageId.present) {
      map['last_scanned_message_id'] = Variable<int>(
        lastScannedMessageId.value,
      );
    }
    if (useBot.present) {
      map['use_bot'] = Variable<bool>(useBot.value);
    }
    if (walkDone.present) {
      map['walk_done'] = Variable<bool>(walkDone.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibraryChatsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('lastScannedMessageId: $lastScannedMessageId, ')
          ..write('useBot: $useBot, ')
          ..write('walkDone: $walkDone')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<int> modifiedAt = GeneratedColumn<int>(
    'modified_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    uuid,
    modifiedAt,
    deletedAt,
    sourceUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Playlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      ),
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final int id;
  final String name;

  /// Same on every device; [id] is local to this one.
  final String uuid;
  final int modifiedAt;

  /// Kept after deleting, so another device can't bring the playlist back.
  final int? deletedAt;

  /// Where it was imported from, for refreshing it.
  final String? sourceUrl;
  const Playlist({
    required this.id,
    required this.name,
    required this.uuid,
    required this.modifiedAt,
    this.deletedAt,
    this.sourceUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['uuid'] = Variable<String>(uuid);
    map['modified_at'] = Variable<int>(modifiedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      uuid: Value(uuid),
      modifiedAt: Value(modifiedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
    );
  }

  factory Playlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      uuid: serializer.fromJson<String>(json['uuid']),
      modifiedAt: serializer.fromJson<int>(json['modifiedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'uuid': serializer.toJson<String>(uuid),
      'modifiedAt': serializer.toJson<int>(modifiedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
    };
  }

  Playlist copyWith({
    int? id,
    String? name,
    String? uuid,
    int? modifiedAt,
    Value<int?> deletedAt = const Value.absent(),
    Value<String?> sourceUrl = const Value.absent(),
  }) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    uuid: uuid ?? this.uuid,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
  );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('uuid: $uuid, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('sourceUrl: $sourceUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, uuid, modifiedAt, deletedAt, sourceUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.uuid == this.uuid &&
          other.modifiedAt == this.modifiedAt &&
          other.deletedAt == this.deletedAt &&
          other.sourceUrl == this.sourceUrl);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> uuid;
  final Value<int> modifiedAt;
  final Value<int?> deletedAt;
  final Value<String?> sourceUrl;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.uuid = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.sourceUrl = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.uuid = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.sourceUrl = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Playlist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? uuid,
    Expression<int>? modifiedAt,
    Expression<int>? deletedAt,
    Expression<String>? sourceUrl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (uuid != null) 'uuid': uuid,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (sourceUrl != null) 'source_url': sourceUrl,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? uuid,
    Value<int>? modifiedAt,
    Value<int?>? deletedAt,
    Value<String?>? sourceUrl,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      uuid: uuid ?? this.uuid,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<int>(modifiedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('uuid: $uuid, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('sourceUrl: $sourceUrl')
          ..write(')'))
        .toString();
  }
}

class $PlaylistSongsTable extends PlaylistSongs
    with TableInfo<$PlaylistSongsTable, PlaylistSong> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistSongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<int> chatId = GeneratedColumn<int>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<int> messageId = GeneratedColumn<int>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceAddedAtMeta = const VerificationMeta(
    'sourceAddedAt',
  );
  @override
  late final GeneratedColumn<int> sourceAddedAt = GeneratedColumn<int>(
    'source_added_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _removedAtMeta = const VerificationMeta(
    'removedAt',
  );
  @override
  late final GeneratedColumn<int> removedAt = GeneratedColumn<int>(
    'removed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playlistId,
    chatId,
    messageId,
    addedAt,
    sourceAddedAt,
    removedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistSong> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('source_added_at')) {
      context.handle(
        _sourceAddedAtMeta,
        sourceAddedAt.isAcceptableOrUnknown(
          data['source_added_at']!,
          _sourceAddedAtMeta,
        ),
      );
    }
    if (data.containsKey('removed_at')) {
      context.handle(
        _removedAtMeta,
        removedAt.isAcceptableOrUnknown(data['removed_at']!, _removedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, chatId, messageId};
  @override
  PlaylistSong map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistSong(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chat_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      sourceAddedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_added_at'],
      ),
      removedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}removed_at'],
      ),
    );
  }

  @override
  $PlaylistSongsTable createAlias(String alias) {
    return $PlaylistSongsTable(attachedDatabase, alias);
  }
}

class PlaylistSong extends DataClass implements Insertable<PlaylistSong> {
  final int playlistId;
  final int chatId;
  final int messageId;
  final int addedAt;

  /// When the source service says it was added there (Spotify's `added_at`), if known.
  final int? sourceAddedAt;

  /// Kept after removing, so another device can't add the song back.
  final int? removedAt;
  const PlaylistSong({
    required this.playlistId,
    required this.chatId,
    required this.messageId,
    required this.addedAt,
    this.sourceAddedAt,
    this.removedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    map['chat_id'] = Variable<int>(chatId);
    map['message_id'] = Variable<int>(messageId);
    map['added_at'] = Variable<int>(addedAt);
    if (!nullToAbsent || sourceAddedAt != null) {
      map['source_added_at'] = Variable<int>(sourceAddedAt);
    }
    if (!nullToAbsent || removedAt != null) {
      map['removed_at'] = Variable<int>(removedAt);
    }
    return map;
  }

  PlaylistSongsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistSongsCompanion(
      playlistId: Value(playlistId),
      chatId: Value(chatId),
      messageId: Value(messageId),
      addedAt: Value(addedAt),
      sourceAddedAt: sourceAddedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceAddedAt),
      removedAt: removedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(removedAt),
    );
  }

  factory PlaylistSong.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistSong(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      chatId: serializer.fromJson<int>(json['chatId']),
      messageId: serializer.fromJson<int>(json['messageId']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      sourceAddedAt: serializer.fromJson<int?>(json['sourceAddedAt']),
      removedAt: serializer.fromJson<int?>(json['removedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'chatId': serializer.toJson<int>(chatId),
      'messageId': serializer.toJson<int>(messageId),
      'addedAt': serializer.toJson<int>(addedAt),
      'sourceAddedAt': serializer.toJson<int?>(sourceAddedAt),
      'removedAt': serializer.toJson<int?>(removedAt),
    };
  }

  PlaylistSong copyWith({
    int? playlistId,
    int? chatId,
    int? messageId,
    int? addedAt,
    Value<int?> sourceAddedAt = const Value.absent(),
    Value<int?> removedAt = const Value.absent(),
  }) => PlaylistSong(
    playlistId: playlistId ?? this.playlistId,
    chatId: chatId ?? this.chatId,
    messageId: messageId ?? this.messageId,
    addedAt: addedAt ?? this.addedAt,
    sourceAddedAt: sourceAddedAt.present
        ? sourceAddedAt.value
        : this.sourceAddedAt,
    removedAt: removedAt.present ? removedAt.value : this.removedAt,
  );
  PlaylistSong copyWithCompanion(PlaylistSongsCompanion data) {
    return PlaylistSong(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      sourceAddedAt: data.sourceAddedAt.present
          ? data.sourceAddedAt.value
          : this.sourceAddedAt,
      removedAt: data.removedAt.present ? data.removedAt.value : this.removedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistSong(')
          ..write('playlistId: $playlistId, ')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('addedAt: $addedAt, ')
          ..write('sourceAddedAt: $sourceAddedAt, ')
          ..write('removedAt: $removedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    playlistId,
    chatId,
    messageId,
    addedAt,
    sourceAddedAt,
    removedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistSong &&
          other.playlistId == this.playlistId &&
          other.chatId == this.chatId &&
          other.messageId == this.messageId &&
          other.addedAt == this.addedAt &&
          other.sourceAddedAt == this.sourceAddedAt &&
          other.removedAt == this.removedAt);
}

class PlaylistSongsCompanion extends UpdateCompanion<PlaylistSong> {
  final Value<int> playlistId;
  final Value<int> chatId;
  final Value<int> messageId;
  final Value<int> addedAt;
  final Value<int?> sourceAddedAt;
  final Value<int?> removedAt;
  final Value<int> rowid;
  const PlaylistSongsCompanion({
    this.playlistId = const Value.absent(),
    this.chatId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.sourceAddedAt = const Value.absent(),
    this.removedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistSongsCompanion.insert({
    required int playlistId,
    required int chatId,
    required int messageId,
    required int addedAt,
    this.sourceAddedAt = const Value.absent(),
    this.removedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       chatId = Value(chatId),
       messageId = Value(messageId),
       addedAt = Value(addedAt);
  static Insertable<PlaylistSong> custom({
    Expression<int>? playlistId,
    Expression<int>? chatId,
    Expression<int>? messageId,
    Expression<int>? addedAt,
    Expression<int>? sourceAddedAt,
    Expression<int>? removedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (chatId != null) 'chat_id': chatId,
      if (messageId != null) 'message_id': messageId,
      if (addedAt != null) 'added_at': addedAt,
      if (sourceAddedAt != null) 'source_added_at': sourceAddedAt,
      if (removedAt != null) 'removed_at': removedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistSongsCompanion copyWith({
    Value<int>? playlistId,
    Value<int>? chatId,
    Value<int>? messageId,
    Value<int>? addedAt,
    Value<int?>? sourceAddedAt,
    Value<int?>? removedAt,
    Value<int>? rowid,
  }) {
    return PlaylistSongsCompanion(
      playlistId: playlistId ?? this.playlistId,
      chatId: chatId ?? this.chatId,
      messageId: messageId ?? this.messageId,
      addedAt: addedAt ?? this.addedAt,
      sourceAddedAt: sourceAddedAt ?? this.sourceAddedAt,
      removedAt: removedAt ?? this.removedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<int>(chatId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<int>(messageId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (sourceAddedAt.present) {
      map['source_added_at'] = Variable<int>(sourceAddedAt.value);
    }
    if (removedAt.present) {
      map['removed_at'] = Variable<int>(removedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistSongsCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('addedAt: $addedAt, ')
          ..write('sourceAddedAt: $sourceAddedAt, ')
          ..write('removedAt: $removedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrefsTable extends Prefs with TableInfo<$PrefsTable, Pref> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prefs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pref> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Pref map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pref(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $PrefsTable createAlias(String alias) {
    return $PrefsTable(attachedDatabase, alias);
  }
}

class Pref extends DataClass implements Insertable<Pref> {
  final String key;
  final String value;
  const Pref({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  PrefsCompanion toCompanion(bool nullToAbsent) {
    return PrefsCompanion(key: Value(key), value: Value(value));
  }

  factory Pref.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pref(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Pref copyWith({String? key, String? value}) =>
      Pref(key: key ?? this.key, value: value ?? this.value);
  Pref copyWithCompanion(PrefsCompanion data) {
    return Pref(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pref(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pref && other.key == this.key && other.value == this.value);
}

class PrefsCompanion extends UpdateCompanion<Pref> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const PrefsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrefsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Pref> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrefsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return PrefsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrefsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MissingTracksTable extends MissingTracks
    with TableInfo<$MissingTracksTable, MissingTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MissingTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _trackKeyMeta = const VerificationMeta(
    'trackKey',
  );
  @override
  late final GeneratedColumn<String> trackKey = GeneratedColumn<String>(
    'track_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sourceAddedAtMeta = const VerificationMeta(
    'sourceAddedAt',
  );
  @override
  late final GeneratedColumn<int> sourceAddedAt = GeneratedColumn<int>(
    'source_added_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playlistId,
    trackKey,
    title,
    artist,
    durationSec,
    position,
    sourceAddedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'missing_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<MissingTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('track_key')) {
      context.handle(
        _trackKeyMeta,
        trackKey.isAcceptableOrUnknown(data['track_key']!, _trackKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_trackKeyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('source_added_at')) {
      context.handle(
        _sourceAddedAtMeta,
        sourceAddedAt.isAcceptableOrUnknown(
          data['source_added_at']!,
          _sourceAddedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, trackKey};
  @override
  MissingTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MissingTrack(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      trackKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_key'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      sourceAddedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_added_at'],
      ),
    );
  }

  @override
  $MissingTracksTable createAlias(String alias) {
    return $MissingTracksTable(attachedDatabase, alias);
  }
}

class MissingTrack extends DataClass implements Insertable<MissingTrack> {
  final int playlistId;

  /// The source's id for the track, such as a Spotify URI.
  final String trackKey;
  final String title;
  final String artist;
  final int durationSec;
  final int position;
  final int? sourceAddedAt;
  const MissingTrack({
    required this.playlistId,
    required this.trackKey,
    required this.title,
    required this.artist,
    required this.durationSec,
    required this.position,
    this.sourceAddedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    map['track_key'] = Variable<String>(trackKey);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['duration_sec'] = Variable<int>(durationSec);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || sourceAddedAt != null) {
      map['source_added_at'] = Variable<int>(sourceAddedAt);
    }
    return map;
  }

  MissingTracksCompanion toCompanion(bool nullToAbsent) {
    return MissingTracksCompanion(
      playlistId: Value(playlistId),
      trackKey: Value(trackKey),
      title: Value(title),
      artist: Value(artist),
      durationSec: Value(durationSec),
      position: Value(position),
      sourceAddedAt: sourceAddedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceAddedAt),
    );
  }

  factory MissingTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MissingTrack(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      trackKey: serializer.fromJson<String>(json['trackKey']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      durationSec: serializer.fromJson<int>(json['durationSec']),
      position: serializer.fromJson<int>(json['position']),
      sourceAddedAt: serializer.fromJson<int?>(json['sourceAddedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'trackKey': serializer.toJson<String>(trackKey),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'durationSec': serializer.toJson<int>(durationSec),
      'position': serializer.toJson<int>(position),
      'sourceAddedAt': serializer.toJson<int?>(sourceAddedAt),
    };
  }

  MissingTrack copyWith({
    int? playlistId,
    String? trackKey,
    String? title,
    String? artist,
    int? durationSec,
    int? position,
    Value<int?> sourceAddedAt = const Value.absent(),
  }) => MissingTrack(
    playlistId: playlistId ?? this.playlistId,
    trackKey: trackKey ?? this.trackKey,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    durationSec: durationSec ?? this.durationSec,
    position: position ?? this.position,
    sourceAddedAt: sourceAddedAt.present
        ? sourceAddedAt.value
        : this.sourceAddedAt,
  );
  MissingTrack copyWithCompanion(MissingTracksCompanion data) {
    return MissingTrack(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      trackKey: data.trackKey.present ? data.trackKey.value : this.trackKey,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      position: data.position.present ? data.position.value : this.position,
      sourceAddedAt: data.sourceAddedAt.present
          ? data.sourceAddedAt.value
          : this.sourceAddedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MissingTrack(')
          ..write('playlistId: $playlistId, ')
          ..write('trackKey: $trackKey, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('durationSec: $durationSec, ')
          ..write('position: $position, ')
          ..write('sourceAddedAt: $sourceAddedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    playlistId,
    trackKey,
    title,
    artist,
    durationSec,
    position,
    sourceAddedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MissingTrack &&
          other.playlistId == this.playlistId &&
          other.trackKey == this.trackKey &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.durationSec == this.durationSec &&
          other.position == this.position &&
          other.sourceAddedAt == this.sourceAddedAt);
}

class MissingTracksCompanion extends UpdateCompanion<MissingTrack> {
  final Value<int> playlistId;
  final Value<String> trackKey;
  final Value<String> title;
  final Value<String> artist;
  final Value<int> durationSec;
  final Value<int> position;
  final Value<int?> sourceAddedAt;
  final Value<int> rowid;
  const MissingTracksCompanion({
    this.playlistId = const Value.absent(),
    this.trackKey = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.position = const Value.absent(),
    this.sourceAddedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MissingTracksCompanion.insert({
    required int playlistId,
    required String trackKey,
    required String title,
    required String artist,
    this.durationSec = const Value.absent(),
    this.position = const Value.absent(),
    this.sourceAddedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       trackKey = Value(trackKey),
       title = Value(title),
       artist = Value(artist);
  static Insertable<MissingTrack> custom({
    Expression<int>? playlistId,
    Expression<String>? trackKey,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<int>? durationSec,
    Expression<int>? position,
    Expression<int>? sourceAddedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (trackKey != null) 'track_key': trackKey,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (durationSec != null) 'duration_sec': durationSec,
      if (position != null) 'position': position,
      if (sourceAddedAt != null) 'source_added_at': sourceAddedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MissingTracksCompanion copyWith({
    Value<int>? playlistId,
    Value<String>? trackKey,
    Value<String>? title,
    Value<String>? artist,
    Value<int>? durationSec,
    Value<int>? position,
    Value<int?>? sourceAddedAt,
    Value<int>? rowid,
  }) {
    return MissingTracksCompanion(
      playlistId: playlistId ?? this.playlistId,
      trackKey: trackKey ?? this.trackKey,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      durationSec: durationSec ?? this.durationSec,
      position: position ?? this.position,
      sourceAddedAt: sourceAddedAt ?? this.sourceAddedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (trackKey.present) {
      map['track_key'] = Variable<String>(trackKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (sourceAddedAt.present) {
      map['source_added_at'] = Variable<int>(sourceAddedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MissingTracksCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('trackKey: $trackKey, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('durationSec: $durationSec, ')
          ..write('position: $position, ')
          ..write('sourceAddedAt: $sourceAddedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MoodVotesTable extends MoodVotes
    with TableInfo<$MoodVotesTable, MoodVote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoodVotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<int> chatId = GeneratedColumn<int>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<int> messageId = GeneratedColumn<int>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  @override
  late final GeneratedColumn<String> mood = GeneratedColumn<String>(
    'mood',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voteMeta = const VerificationMeta('vote');
  @override
  late final GeneratedColumn<int> vote = GeneratedColumn<int>(
    'vote',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [chatId, messageId, mood, vote, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mood_votes';
  @override
  VerificationContext validateIntegrity(
    Insertable<MoodVote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    } else if (isInserting) {
      context.missing(_moodMeta);
    }
    if (data.containsKey('vote')) {
      context.handle(
        _voteMeta,
        vote.isAcceptableOrUnknown(data['vote']!, _voteMeta),
      );
    } else if (isInserting) {
      context.missing(_voteMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chatId, messageId, mood};
  @override
  MoodVote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MoodVote(
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chat_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mood'],
      )!,
      vote: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vote'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $MoodVotesTable createAlias(String alias) {
    return $MoodVotesTable(attachedDatabase, alias);
  }
}

class MoodVote extends DataClass implements Insertable<MoodVote> {
  final int chatId;
  final int messageId;
  final String mood;

  /// 1 fits, -1 doesn't, 0 means the verdict was undone.
  final int vote;
  final int at;
  const MoodVote({
    required this.chatId,
    required this.messageId,
    required this.mood,
    required this.vote,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chat_id'] = Variable<int>(chatId);
    map['message_id'] = Variable<int>(messageId);
    map['mood'] = Variable<String>(mood);
    map['vote'] = Variable<int>(vote);
    map['at'] = Variable<int>(at);
    return map;
  }

  MoodVotesCompanion toCompanion(bool nullToAbsent) {
    return MoodVotesCompanion(
      chatId: Value(chatId),
      messageId: Value(messageId),
      mood: Value(mood),
      vote: Value(vote),
      at: Value(at),
    );
  }

  factory MoodVote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MoodVote(
      chatId: serializer.fromJson<int>(json['chatId']),
      messageId: serializer.fromJson<int>(json['messageId']),
      mood: serializer.fromJson<String>(json['mood']),
      vote: serializer.fromJson<int>(json['vote']),
      at: serializer.fromJson<int>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chatId': serializer.toJson<int>(chatId),
      'messageId': serializer.toJson<int>(messageId),
      'mood': serializer.toJson<String>(mood),
      'vote': serializer.toJson<int>(vote),
      'at': serializer.toJson<int>(at),
    };
  }

  MoodVote copyWith({
    int? chatId,
    int? messageId,
    String? mood,
    int? vote,
    int? at,
  }) => MoodVote(
    chatId: chatId ?? this.chatId,
    messageId: messageId ?? this.messageId,
    mood: mood ?? this.mood,
    vote: vote ?? this.vote,
    at: at ?? this.at,
  );
  MoodVote copyWithCompanion(MoodVotesCompanion data) {
    return MoodVote(
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      mood: data.mood.present ? data.mood.value : this.mood,
      vote: data.vote.present ? data.vote.value : this.vote,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MoodVote(')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('mood: $mood, ')
          ..write('vote: $vote, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chatId, messageId, mood, vote, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MoodVote &&
          other.chatId == this.chatId &&
          other.messageId == this.messageId &&
          other.mood == this.mood &&
          other.vote == this.vote &&
          other.at == this.at);
}

class MoodVotesCompanion extends UpdateCompanion<MoodVote> {
  final Value<int> chatId;
  final Value<int> messageId;
  final Value<String> mood;
  final Value<int> vote;
  final Value<int> at;
  final Value<int> rowid;
  const MoodVotesCompanion({
    this.chatId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.mood = const Value.absent(),
    this.vote = const Value.absent(),
    this.at = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MoodVotesCompanion.insert({
    required int chatId,
    required int messageId,
    required String mood,
    required int vote,
    required int at,
    this.rowid = const Value.absent(),
  }) : chatId = Value(chatId),
       messageId = Value(messageId),
       mood = Value(mood),
       vote = Value(vote),
       at = Value(at);
  static Insertable<MoodVote> custom({
    Expression<int>? chatId,
    Expression<int>? messageId,
    Expression<String>? mood,
    Expression<int>? vote,
    Expression<int>? at,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chatId != null) 'chat_id': chatId,
      if (messageId != null) 'message_id': messageId,
      if (mood != null) 'mood': mood,
      if (vote != null) 'vote': vote,
      if (at != null) 'at': at,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MoodVotesCompanion copyWith({
    Value<int>? chatId,
    Value<int>? messageId,
    Value<String>? mood,
    Value<int>? vote,
    Value<int>? at,
    Value<int>? rowid,
  }) {
    return MoodVotesCompanion(
      chatId: chatId ?? this.chatId,
      messageId: messageId ?? this.messageId,
      mood: mood ?? this.mood,
      vote: vote ?? this.vote,
      at: at ?? this.at,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chatId.present) {
      map['chat_id'] = Variable<int>(chatId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<int>(messageId.value);
    }
    if (mood.present) {
      map['mood'] = Variable<String>(mood.value);
    }
    if (vote.present) {
      map['vote'] = Variable<int>(vote.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoodVotesCompanion(')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('mood: $mood, ')
          ..write('vote: $vote, ')
          ..write('at: $at, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ForumTopicsTable extends ForumTopics
    with TableInfo<$ForumTopicsTable, ForumTopic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ForumTopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<int> chatId = GeneratedColumn<int>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<int> topicId = GeneratedColumn<int>(
    'topic_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [chatId, topicId, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'forum_topics';
  @override
  VerificationContext validateIntegrity(
    Insertable<ForumTopic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chatId, topicId};
  @override
  ForumTopic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ForumTopic(
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chat_id'],
      )!,
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}topic_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $ForumTopicsTable createAlias(String alias) {
    return $ForumTopicsTable(attachedDatabase, alias);
  }
}

class ForumTopic extends DataClass implements Insertable<ForumTopic> {
  final int chatId;
  final int topicId;
  final String name;
  const ForumTopic({
    required this.chatId,
    required this.topicId,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chat_id'] = Variable<int>(chatId);
    map['topic_id'] = Variable<int>(topicId);
    map['name'] = Variable<String>(name);
    return map;
  }

  ForumTopicsCompanion toCompanion(bool nullToAbsent) {
    return ForumTopicsCompanion(
      chatId: Value(chatId),
      topicId: Value(topicId),
      name: Value(name),
    );
  }

  factory ForumTopic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ForumTopic(
      chatId: serializer.fromJson<int>(json['chatId']),
      topicId: serializer.fromJson<int>(json['topicId']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chatId': serializer.toJson<int>(chatId),
      'topicId': serializer.toJson<int>(topicId),
      'name': serializer.toJson<String>(name),
    };
  }

  ForumTopic copyWith({int? chatId, int? topicId, String? name}) => ForumTopic(
    chatId: chatId ?? this.chatId,
    topicId: topicId ?? this.topicId,
    name: name ?? this.name,
  );
  ForumTopic copyWithCompanion(ForumTopicsCompanion data) {
    return ForumTopic(
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ForumTopic(')
          ..write('chatId: $chatId, ')
          ..write('topicId: $topicId, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chatId, topicId, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ForumTopic &&
          other.chatId == this.chatId &&
          other.topicId == this.topicId &&
          other.name == this.name);
}

class ForumTopicsCompanion extends UpdateCompanion<ForumTopic> {
  final Value<int> chatId;
  final Value<int> topicId;
  final Value<String> name;
  final Value<int> rowid;
  const ForumTopicsCompanion({
    this.chatId = const Value.absent(),
    this.topicId = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ForumTopicsCompanion.insert({
    required int chatId,
    required int topicId,
    required String name,
    this.rowid = const Value.absent(),
  }) : chatId = Value(chatId),
       topicId = Value(topicId),
       name = Value(name);
  static Insertable<ForumTopic> custom({
    Expression<int>? chatId,
    Expression<int>? topicId,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chatId != null) 'chat_id': chatId,
      if (topicId != null) 'topic_id': topicId,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ForumTopicsCompanion copyWith({
    Value<int>? chatId,
    Value<int>? topicId,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return ForumTopicsCompanion(
      chatId: chatId ?? this.chatId,
      topicId: topicId ?? this.topicId,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chatId.present) {
      map['chat_id'] = Variable<int>(chatId.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<int>(topicId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ForumTopicsCompanion(')
          ..write('chatId: $chatId, ')
          ..write('topicId: $topicId, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PostCopiesTable extends PostCopies
    with TableInfo<$PostCopiesTable, PostCopy> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PostCopiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<int> chatId = GeneratedColumn<int>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<int> messageId = GeneratedColumn<int>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uniqueIdMeta = const VerificationMeta(
    'uniqueId',
  );
  @override
  late final GeneratedColumn<String> uniqueId = GeneratedColumn<String>(
    'unique_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<int> topicId = GeneratedColumn<int>(
    'topic_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<int> date = GeneratedColumn<int>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    chatId,
    messageId,
    uniqueId,
    fileName,
    size,
    topicId,
    date,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'post_copies';
  @override
  VerificationContext validateIntegrity(
    Insertable<PostCopy> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('unique_id')) {
      context.handle(
        _uniqueIdMeta,
        uniqueId.isAcceptableOrUnknown(data['unique_id']!, _uniqueIdMeta),
      );
    } else if (isInserting) {
      context.missing(_uniqueIdMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chatId, messageId};
  @override
  PostCopy map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PostCopy(
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chat_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_id'],
      )!,
      uniqueId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unique_id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}topic_id'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date'],
      )!,
    );
  }

  @override
  $PostCopiesTable createAlias(String alias) {
    return $PostCopiesTable(attachedDatabase, alias);
  }
}

class PostCopy extends DataClass implements Insertable<PostCopy> {
  final int chatId;
  final int messageId;
  final String uniqueId;
  final String fileName;
  final int size;
  final int? topicId;
  final int date;
  const PostCopy({
    required this.chatId,
    required this.messageId,
    required this.uniqueId,
    required this.fileName,
    required this.size,
    this.topicId,
    required this.date,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chat_id'] = Variable<int>(chatId);
    map['message_id'] = Variable<int>(messageId);
    map['unique_id'] = Variable<String>(uniqueId);
    map['file_name'] = Variable<String>(fileName);
    map['size'] = Variable<int>(size);
    if (!nullToAbsent || topicId != null) {
      map['topic_id'] = Variable<int>(topicId);
    }
    map['date'] = Variable<int>(date);
    return map;
  }

  PostCopiesCompanion toCompanion(bool nullToAbsent) {
    return PostCopiesCompanion(
      chatId: Value(chatId),
      messageId: Value(messageId),
      uniqueId: Value(uniqueId),
      fileName: Value(fileName),
      size: Value(size),
      topicId: topicId == null && nullToAbsent
          ? const Value.absent()
          : Value(topicId),
      date: Value(date),
    );
  }

  factory PostCopy.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PostCopy(
      chatId: serializer.fromJson<int>(json['chatId']),
      messageId: serializer.fromJson<int>(json['messageId']),
      uniqueId: serializer.fromJson<String>(json['uniqueId']),
      fileName: serializer.fromJson<String>(json['fileName']),
      size: serializer.fromJson<int>(json['size']),
      topicId: serializer.fromJson<int?>(json['topicId']),
      date: serializer.fromJson<int>(json['date']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chatId': serializer.toJson<int>(chatId),
      'messageId': serializer.toJson<int>(messageId),
      'uniqueId': serializer.toJson<String>(uniqueId),
      'fileName': serializer.toJson<String>(fileName),
      'size': serializer.toJson<int>(size),
      'topicId': serializer.toJson<int?>(topicId),
      'date': serializer.toJson<int>(date),
    };
  }

  PostCopy copyWith({
    int? chatId,
    int? messageId,
    String? uniqueId,
    String? fileName,
    int? size,
    Value<int?> topicId = const Value.absent(),
    int? date,
  }) => PostCopy(
    chatId: chatId ?? this.chatId,
    messageId: messageId ?? this.messageId,
    uniqueId: uniqueId ?? this.uniqueId,
    fileName: fileName ?? this.fileName,
    size: size ?? this.size,
    topicId: topicId.present ? topicId.value : this.topicId,
    date: date ?? this.date,
  );
  PostCopy copyWithCompanion(PostCopiesCompanion data) {
    return PostCopy(
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      uniqueId: data.uniqueId.present ? data.uniqueId.value : this.uniqueId,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      size: data.size.present ? data.size.value : this.size,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      date: data.date.present ? data.date.value : this.date,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PostCopy(')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('uniqueId: $uniqueId, ')
          ..write('fileName: $fileName, ')
          ..write('size: $size, ')
          ..write('topicId: $topicId, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(chatId, messageId, uniqueId, fileName, size, topicId, date);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PostCopy &&
          other.chatId == this.chatId &&
          other.messageId == this.messageId &&
          other.uniqueId == this.uniqueId &&
          other.fileName == this.fileName &&
          other.size == this.size &&
          other.topicId == this.topicId &&
          other.date == this.date);
}

class PostCopiesCompanion extends UpdateCompanion<PostCopy> {
  final Value<int> chatId;
  final Value<int> messageId;
  final Value<String> uniqueId;
  final Value<String> fileName;
  final Value<int> size;
  final Value<int?> topicId;
  final Value<int> date;
  final Value<int> rowid;
  const PostCopiesCompanion({
    this.chatId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.uniqueId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.size = const Value.absent(),
    this.topicId = const Value.absent(),
    this.date = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PostCopiesCompanion.insert({
    required int chatId,
    required int messageId,
    required String uniqueId,
    required String fileName,
    required int size,
    this.topicId = const Value.absent(),
    required int date,
    this.rowid = const Value.absent(),
  }) : chatId = Value(chatId),
       messageId = Value(messageId),
       uniqueId = Value(uniqueId),
       fileName = Value(fileName),
       size = Value(size),
       date = Value(date);
  static Insertable<PostCopy> custom({
    Expression<int>? chatId,
    Expression<int>? messageId,
    Expression<String>? uniqueId,
    Expression<String>? fileName,
    Expression<int>? size,
    Expression<int>? topicId,
    Expression<int>? date,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chatId != null) 'chat_id': chatId,
      if (messageId != null) 'message_id': messageId,
      if (uniqueId != null) 'unique_id': uniqueId,
      if (fileName != null) 'file_name': fileName,
      if (size != null) 'size': size,
      if (topicId != null) 'topic_id': topicId,
      if (date != null) 'date': date,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PostCopiesCompanion copyWith({
    Value<int>? chatId,
    Value<int>? messageId,
    Value<String>? uniqueId,
    Value<String>? fileName,
    Value<int>? size,
    Value<int?>? topicId,
    Value<int>? date,
    Value<int>? rowid,
  }) {
    return PostCopiesCompanion(
      chatId: chatId ?? this.chatId,
      messageId: messageId ?? this.messageId,
      uniqueId: uniqueId ?? this.uniqueId,
      fileName: fileName ?? this.fileName,
      size: size ?? this.size,
      topicId: topicId ?? this.topicId,
      date: date ?? this.date,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chatId.present) {
      map['chat_id'] = Variable<int>(chatId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<int>(messageId.value);
    }
    if (uniqueId.present) {
      map['unique_id'] = Variable<String>(uniqueId.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<int>(topicId.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(date.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PostCopiesCompanion(')
          ..write('chatId: $chatId, ')
          ..write('messageId: $messageId, ')
          ..write('uniqueId: $uniqueId, ')
          ..write('fileName: $fileName, ')
          ..write('size: $size, ')
          ..write('topicId: $topicId, ')
          ..write('date: $date, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ListenStatsTable extends ListenStats
    with TableInfo<$ListenStatsTable, ListenStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListenStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackKeyMeta = const VerificationMeta(
    'trackKey',
  );
  @override
  late final GeneratedColumn<String> trackKey = GeneratedColumn<String>(
    'track_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _msMeta = const VerificationMeta('ms');
  @override
  late final GeneratedColumn<int> ms = GeneratedColumn<int>(
    'ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _playsMeta = const VerificationMeta('plays');
  @override
  late final GeneratedColumn<int> plays = GeneratedColumn<int>(
    'plays',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [origin, day, trackKey, ms, plays];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'listen_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<ListenStat> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('track_key')) {
      context.handle(
        _trackKeyMeta,
        trackKey.isAcceptableOrUnknown(data['track_key']!, _trackKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_trackKeyMeta);
    }
    if (data.containsKey('ms')) {
      context.handle(_msMeta, ms.isAcceptableOrUnknown(data['ms']!, _msMeta));
    }
    if (data.containsKey('plays')) {
      context.handle(
        _playsMeta,
        plays.isAcceptableOrUnknown(data['plays']!, _playsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {origin, day, trackKey};
  @override
  ListenStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListenStat(
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      trackKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_key'],
      )!,
      ms: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ms'],
      )!,
      plays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plays'],
      )!,
    );
  }

  @override
  $ListenStatsTable createAlias(String alias) {
    return $ListenStatsTable(attachedDatabase, alias);
  }
}

class ListenStat extends DataClass implements Insertable<ListenStat> {
  final String origin;
  final String day;
  final String trackKey;
  final int ms;
  final int plays;
  const ListenStat({
    required this.origin,
    required this.day,
    required this.trackKey,
    required this.ms,
    required this.plays,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['origin'] = Variable<String>(origin);
    map['day'] = Variable<String>(day);
    map['track_key'] = Variable<String>(trackKey);
    map['ms'] = Variable<int>(ms);
    map['plays'] = Variable<int>(plays);
    return map;
  }

  ListenStatsCompanion toCompanion(bool nullToAbsent) {
    return ListenStatsCompanion(
      origin: Value(origin),
      day: Value(day),
      trackKey: Value(trackKey),
      ms: Value(ms),
      plays: Value(plays),
    );
  }

  factory ListenStat.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListenStat(
      origin: serializer.fromJson<String>(json['origin']),
      day: serializer.fromJson<String>(json['day']),
      trackKey: serializer.fromJson<String>(json['trackKey']),
      ms: serializer.fromJson<int>(json['ms']),
      plays: serializer.fromJson<int>(json['plays']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'origin': serializer.toJson<String>(origin),
      'day': serializer.toJson<String>(day),
      'trackKey': serializer.toJson<String>(trackKey),
      'ms': serializer.toJson<int>(ms),
      'plays': serializer.toJson<int>(plays),
    };
  }

  ListenStat copyWith({
    String? origin,
    String? day,
    String? trackKey,
    int? ms,
    int? plays,
  }) => ListenStat(
    origin: origin ?? this.origin,
    day: day ?? this.day,
    trackKey: trackKey ?? this.trackKey,
    ms: ms ?? this.ms,
    plays: plays ?? this.plays,
  );
  ListenStat copyWithCompanion(ListenStatsCompanion data) {
    return ListenStat(
      origin: data.origin.present ? data.origin.value : this.origin,
      day: data.day.present ? data.day.value : this.day,
      trackKey: data.trackKey.present ? data.trackKey.value : this.trackKey,
      ms: data.ms.present ? data.ms.value : this.ms,
      plays: data.plays.present ? data.plays.value : this.plays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListenStat(')
          ..write('origin: $origin, ')
          ..write('day: $day, ')
          ..write('trackKey: $trackKey, ')
          ..write('ms: $ms, ')
          ..write('plays: $plays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(origin, day, trackKey, ms, plays);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListenStat &&
          other.origin == this.origin &&
          other.day == this.day &&
          other.trackKey == this.trackKey &&
          other.ms == this.ms &&
          other.plays == this.plays);
}

class ListenStatsCompanion extends UpdateCompanion<ListenStat> {
  final Value<String> origin;
  final Value<String> day;
  final Value<String> trackKey;
  final Value<int> ms;
  final Value<int> plays;
  final Value<int> rowid;
  const ListenStatsCompanion({
    this.origin = const Value.absent(),
    this.day = const Value.absent(),
    this.trackKey = const Value.absent(),
    this.ms = const Value.absent(),
    this.plays = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListenStatsCompanion.insert({
    required String origin,
    required String day,
    required String trackKey,
    this.ms = const Value.absent(),
    this.plays = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : origin = Value(origin),
       day = Value(day),
       trackKey = Value(trackKey);
  static Insertable<ListenStat> custom({
    Expression<String>? origin,
    Expression<String>? day,
    Expression<String>? trackKey,
    Expression<int>? ms,
    Expression<int>? plays,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (origin != null) 'origin': origin,
      if (day != null) 'day': day,
      if (trackKey != null) 'track_key': trackKey,
      if (ms != null) 'ms': ms,
      if (plays != null) 'plays': plays,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListenStatsCompanion copyWith({
    Value<String>? origin,
    Value<String>? day,
    Value<String>? trackKey,
    Value<int>? ms,
    Value<int>? plays,
    Value<int>? rowid,
  }) {
    return ListenStatsCompanion(
      origin: origin ?? this.origin,
      day: day ?? this.day,
      trackKey: trackKey ?? this.trackKey,
      ms: ms ?? this.ms,
      plays: plays ?? this.plays,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (trackKey.present) {
      map['track_key'] = Variable<String>(trackKey.value);
    }
    if (ms.present) {
      map['ms'] = Variable<int>(ms.value);
    }
    if (plays.present) {
      map['plays'] = Variable<int>(plays.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListenStatsCompanion(')
          ..write('origin: $origin, ')
          ..write('day: $day, ')
          ..write('trackKey: $trackKey, ')
          ..write('ms: $ms, ')
          ..write('plays: $plays, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $SongsTable songs = $SongsTable(this);
  late final $LibraryChatsTable libraryChats = $LibraryChatsTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistSongsTable playlistSongs = $PlaylistSongsTable(this);
  late final $PrefsTable prefs = $PrefsTable(this);
  late final $MissingTracksTable missingTracks = $MissingTracksTable(this);
  late final $MoodVotesTable moodVotes = $MoodVotesTable(this);
  late final $ForumTopicsTable forumTopics = $ForumTopicsTable(this);
  late final $PostCopiesTable postCopies = $PostCopiesTable(this);
  late final $ListenStatsTable listenStats = $ListenStatsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    songs,
    libraryChats,
    playlists,
    playlistSongs,
    prefs,
    missingTracks,
    moodVotes,
    forumTopics,
    postCopies,
    listenStats,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_songs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('missing_tracks', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SongsTableCreateCompanionBuilder =
    SongsCompanion Function({
      required int chatId,
      required int messageId,
      required String uniqueId,
      required String remoteId,
      required String title,
      required String artist,
      Value<String> album,
      Value<int> durationSec,
      required int size,
      required String mime,
      required String fileName,
      required int date,
      Value<String?> coverPath,
      Value<String?> releaseId,
      Value<String?> coverUrl,
      Value<String?> genre,
      Value<int?> year,
      Value<String?> metadataSource,
      Value<bool> favorite,
      Value<bool> coverHiRes,
      Value<bool> userEdited,
      Value<int> enrichState,
      Value<String?> lyrics,
      Value<int> cachedBytes,
      Value<int?> lastPlayedAt,
      Value<bool> pinned,
      Value<int> tagsAt,
      Value<int> favoriteAt,
      Value<int> coverAt,
      Value<bool> instrumental,
      Value<int> moodScannedAt,
      Value<int> plays,
      Value<int> skips,
      Value<int?> topicId,
      Value<int?> sampleRate,
      Value<int?> bitDepth,
      Value<String?> codec,
      Value<int> rowid,
    });
typedef $$SongsTableUpdateCompanionBuilder =
    SongsCompanion Function({
      Value<int> chatId,
      Value<int> messageId,
      Value<String> uniqueId,
      Value<String> remoteId,
      Value<String> title,
      Value<String> artist,
      Value<String> album,
      Value<int> durationSec,
      Value<int> size,
      Value<String> mime,
      Value<String> fileName,
      Value<int> date,
      Value<String?> coverPath,
      Value<String?> releaseId,
      Value<String?> coverUrl,
      Value<String?> genre,
      Value<int?> year,
      Value<String?> metadataSource,
      Value<bool> favorite,
      Value<bool> coverHiRes,
      Value<bool> userEdited,
      Value<int> enrichState,
      Value<String?> lyrics,
      Value<int> cachedBytes,
      Value<int?> lastPlayedAt,
      Value<bool> pinned,
      Value<int> tagsAt,
      Value<int> favoriteAt,
      Value<int> coverAt,
      Value<bool> instrumental,
      Value<int> moodScannedAt,
      Value<int> plays,
      Value<int> skips,
      Value<int?> topicId,
      Value<int?> sampleRate,
      Value<int?> bitDepth,
      Value<String?> codec,
      Value<int> rowid,
    });

class $$SongsTableFilterComposer extends Composer<_$AppDb, $SongsTable> {
  $$SongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uniqueId => $composableBuilder(
    column: $table.uniqueId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get releaseId => $composableBuilder(
    column: $table.releaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataSource => $composableBuilder(
    column: $table.metadataSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get coverHiRes => $composableBuilder(
    column: $table.coverHiRes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get userEdited => $composableBuilder(
    column: $table.userEdited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enrichState => $composableBuilder(
    column: $table.enrichState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lyrics => $composableBuilder(
    column: $table.lyrics,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedBytes => $composableBuilder(
    column: $table.cachedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tagsAt => $composableBuilder(
    column: $table.tagsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get favoriteAt => $composableBuilder(
    column: $table.favoriteAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coverAt => $composableBuilder(
    column: $table.coverAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get instrumental => $composableBuilder(
    column: $table.instrumental,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get moodScannedAt => $composableBuilder(
    column: $table.moodScannedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plays => $composableBuilder(
    column: $table.plays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skips => $composableBuilder(
    column: $table.skips,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitDepth => $composableBuilder(
    column: $table.bitDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get codec => $composableBuilder(
    column: $table.codec,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SongsTableOrderingComposer extends Composer<_$AppDb, $SongsTable> {
  $$SongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uniqueId => $composableBuilder(
    column: $table.uniqueId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get releaseId => $composableBuilder(
    column: $table.releaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataSource => $composableBuilder(
    column: $table.metadataSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get coverHiRes => $composableBuilder(
    column: $table.coverHiRes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get userEdited => $composableBuilder(
    column: $table.userEdited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enrichState => $composableBuilder(
    column: $table.enrichState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lyrics => $composableBuilder(
    column: $table.lyrics,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedBytes => $composableBuilder(
    column: $table.cachedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tagsAt => $composableBuilder(
    column: $table.tagsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get favoriteAt => $composableBuilder(
    column: $table.favoriteAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coverAt => $composableBuilder(
    column: $table.coverAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get instrumental => $composableBuilder(
    column: $table.instrumental,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get moodScannedAt => $composableBuilder(
    column: $table.moodScannedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plays => $composableBuilder(
    column: $table.plays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skips => $composableBuilder(
    column: $table.skips,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitDepth => $composableBuilder(
    column: $table.bitDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codec => $composableBuilder(
    column: $table.codec,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SongsTableAnnotationComposer extends Composer<_$AppDb, $SongsTable> {
  $$SongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<int> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get uniqueId =>
      $composableBuilder(column: $table.uniqueId, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get releaseId =>
      $composableBuilder(column: $table.releaseId, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get metadataSource => $composableBuilder(
    column: $table.metadataSource,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumn<bool> get coverHiRes => $composableBuilder(
    column: $table.coverHiRes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get userEdited => $composableBuilder(
    column: $table.userEdited,
    builder: (column) => column,
  );

  GeneratedColumn<int> get enrichState => $composableBuilder(
    column: $table.enrichState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lyrics =>
      $composableBuilder(column: $table.lyrics, builder: (column) => column);

  GeneratedColumn<int> get cachedBytes => $composableBuilder(
    column: $table.cachedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<int> get tagsAt =>
      $composableBuilder(column: $table.tagsAt, builder: (column) => column);

  GeneratedColumn<int> get favoriteAt => $composableBuilder(
    column: $table.favoriteAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get coverAt =>
      $composableBuilder(column: $table.coverAt, builder: (column) => column);

  GeneratedColumn<bool> get instrumental => $composableBuilder(
    column: $table.instrumental,
    builder: (column) => column,
  );

  GeneratedColumn<int> get moodScannedAt => $composableBuilder(
    column: $table.moodScannedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plays =>
      $composableBuilder(column: $table.plays, builder: (column) => column);

  GeneratedColumn<int> get skips =>
      $composableBuilder(column: $table.skips, builder: (column) => column);

  GeneratedColumn<int> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bitDepth =>
      $composableBuilder(column: $table.bitDepth, builder: (column) => column);

  GeneratedColumn<String> get codec =>
      $composableBuilder(column: $table.codec, builder: (column) => column);
}

class $$SongsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SongsTable,
          Song,
          $$SongsTableFilterComposer,
          $$SongsTableOrderingComposer,
          $$SongsTableAnnotationComposer,
          $$SongsTableCreateCompanionBuilder,
          $$SongsTableUpdateCompanionBuilder,
          (Song, BaseReferences<_$AppDb, $SongsTable, Song>),
          Song,
          PrefetchHooks Function()
        > {
  $$SongsTableTableManager(_$AppDb db, $SongsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> chatId = const Value.absent(),
                Value<int> messageId = const Value.absent(),
                Value<String> uniqueId = const Value.absent(),
                Value<String> remoteId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String> album = const Value.absent(),
                Value<int> durationSec = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> date = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> releaseId = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> metadataSource = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<bool> coverHiRes = const Value.absent(),
                Value<bool> userEdited = const Value.absent(),
                Value<int> enrichState = const Value.absent(),
                Value<String?> lyrics = const Value.absent(),
                Value<int> cachedBytes = const Value.absent(),
                Value<int?> lastPlayedAt = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> tagsAt = const Value.absent(),
                Value<int> favoriteAt = const Value.absent(),
                Value<int> coverAt = const Value.absent(),
                Value<bool> instrumental = const Value.absent(),
                Value<int> moodScannedAt = const Value.absent(),
                Value<int> plays = const Value.absent(),
                Value<int> skips = const Value.absent(),
                Value<int?> topicId = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<int?> bitDepth = const Value.absent(),
                Value<String?> codec = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SongsCompanion(
                chatId: chatId,
                messageId: messageId,
                uniqueId: uniqueId,
                remoteId: remoteId,
                title: title,
                artist: artist,
                album: album,
                durationSec: durationSec,
                size: size,
                mime: mime,
                fileName: fileName,
                date: date,
                coverPath: coverPath,
                releaseId: releaseId,
                coverUrl: coverUrl,
                genre: genre,
                year: year,
                metadataSource: metadataSource,
                favorite: favorite,
                coverHiRes: coverHiRes,
                userEdited: userEdited,
                enrichState: enrichState,
                lyrics: lyrics,
                cachedBytes: cachedBytes,
                lastPlayedAt: lastPlayedAt,
                pinned: pinned,
                tagsAt: tagsAt,
                favoriteAt: favoriteAt,
                coverAt: coverAt,
                instrumental: instrumental,
                moodScannedAt: moodScannedAt,
                plays: plays,
                skips: skips,
                topicId: topicId,
                sampleRate: sampleRate,
                bitDepth: bitDepth,
                codec: codec,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int chatId,
                required int messageId,
                required String uniqueId,
                required String remoteId,
                required String title,
                required String artist,
                Value<String> album = const Value.absent(),
                Value<int> durationSec = const Value.absent(),
                required int size,
                required String mime,
                required String fileName,
                required int date,
                Value<String?> coverPath = const Value.absent(),
                Value<String?> releaseId = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> metadataSource = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<bool> coverHiRes = const Value.absent(),
                Value<bool> userEdited = const Value.absent(),
                Value<int> enrichState = const Value.absent(),
                Value<String?> lyrics = const Value.absent(),
                Value<int> cachedBytes = const Value.absent(),
                Value<int?> lastPlayedAt = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int> tagsAt = const Value.absent(),
                Value<int> favoriteAt = const Value.absent(),
                Value<int> coverAt = const Value.absent(),
                Value<bool> instrumental = const Value.absent(),
                Value<int> moodScannedAt = const Value.absent(),
                Value<int> plays = const Value.absent(),
                Value<int> skips = const Value.absent(),
                Value<int?> topicId = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<int?> bitDepth = const Value.absent(),
                Value<String?> codec = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SongsCompanion.insert(
                chatId: chatId,
                messageId: messageId,
                uniqueId: uniqueId,
                remoteId: remoteId,
                title: title,
                artist: artist,
                album: album,
                durationSec: durationSec,
                size: size,
                mime: mime,
                fileName: fileName,
                date: date,
                coverPath: coverPath,
                releaseId: releaseId,
                coverUrl: coverUrl,
                genre: genre,
                year: year,
                metadataSource: metadataSource,
                favorite: favorite,
                coverHiRes: coverHiRes,
                userEdited: userEdited,
                enrichState: enrichState,
                lyrics: lyrics,
                cachedBytes: cachedBytes,
                lastPlayedAt: lastPlayedAt,
                pinned: pinned,
                tagsAt: tagsAt,
                favoriteAt: favoriteAt,
                coverAt: coverAt,
                instrumental: instrumental,
                moodScannedAt: moodScannedAt,
                plays: plays,
                skips: skips,
                topicId: topicId,
                sampleRate: sampleRate,
                bitDepth: bitDepth,
                codec: codec,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SongsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SongsTable,
      Song,
      $$SongsTableFilterComposer,
      $$SongsTableOrderingComposer,
      $$SongsTableAnnotationComposer,
      $$SongsTableCreateCompanionBuilder,
      $$SongsTableUpdateCompanionBuilder,
      (Song, BaseReferences<_$AppDb, $SongsTable, Song>),
      Song,
      PrefetchHooks Function()
    >;
typedef $$LibraryChatsTableCreateCompanionBuilder =
    LibraryChatsCompanion Function({
      Value<int> id,
      required String title,
      Value<int?> lastScannedMessageId,
      Value<bool> useBot,
      Value<bool> walkDone,
    });
typedef $$LibraryChatsTableUpdateCompanionBuilder =
    LibraryChatsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<int?> lastScannedMessageId,
      Value<bool> useBot,
      Value<bool> walkDone,
    });

class $$LibraryChatsTableFilterComposer
    extends Composer<_$AppDb, $LibraryChatsTable> {
  $$LibraryChatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastScannedMessageId => $composableBuilder(
    column: $table.lastScannedMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useBot => $composableBuilder(
    column: $table.useBot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get walkDone => $composableBuilder(
    column: $table.walkDone,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibraryChatsTableOrderingComposer
    extends Composer<_$AppDb, $LibraryChatsTable> {
  $$LibraryChatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastScannedMessageId => $composableBuilder(
    column: $table.lastScannedMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useBot => $composableBuilder(
    column: $table.useBot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get walkDone => $composableBuilder(
    column: $table.walkDone,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibraryChatsTableAnnotationComposer
    extends Composer<_$AppDb, $LibraryChatsTable> {
  $$LibraryChatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get lastScannedMessageId => $composableBuilder(
    column: $table.lastScannedMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get useBot =>
      $composableBuilder(column: $table.useBot, builder: (column) => column);

  GeneratedColumn<bool> get walkDone =>
      $composableBuilder(column: $table.walkDone, builder: (column) => column);
}

class $$LibraryChatsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LibraryChatsTable,
          LibraryChat,
          $$LibraryChatsTableFilterComposer,
          $$LibraryChatsTableOrderingComposer,
          $$LibraryChatsTableAnnotationComposer,
          $$LibraryChatsTableCreateCompanionBuilder,
          $$LibraryChatsTableUpdateCompanionBuilder,
          (
            LibraryChat,
            BaseReferences<_$AppDb, $LibraryChatsTable, LibraryChat>,
          ),
          LibraryChat,
          PrefetchHooks Function()
        > {
  $$LibraryChatsTableTableManager(_$AppDb db, $LibraryChatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryChatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryChatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryChatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> lastScannedMessageId = const Value.absent(),
                Value<bool> useBot = const Value.absent(),
                Value<bool> walkDone = const Value.absent(),
              }) => LibraryChatsCompanion(
                id: id,
                title: title,
                lastScannedMessageId: lastScannedMessageId,
                useBot: useBot,
                walkDone: walkDone,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<int?> lastScannedMessageId = const Value.absent(),
                Value<bool> useBot = const Value.absent(),
                Value<bool> walkDone = const Value.absent(),
              }) => LibraryChatsCompanion.insert(
                id: id,
                title: title,
                lastScannedMessageId: lastScannedMessageId,
                useBot: useBot,
                walkDone: walkDone,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryChatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LibraryChatsTable,
      LibraryChat,
      $$LibraryChatsTableFilterComposer,
      $$LibraryChatsTableOrderingComposer,
      $$LibraryChatsTableAnnotationComposer,
      $$LibraryChatsTableCreateCompanionBuilder,
      $$LibraryChatsTableUpdateCompanionBuilder,
      (LibraryChat, BaseReferences<_$AppDb, $LibraryChatsTable, LibraryChat>),
      LibraryChat,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableCreateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> uuid,
      Value<int> modifiedAt,
      Value<int?> deletedAt,
      Value<String?> sourceUrl,
    });
typedef $$PlaylistsTableUpdateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> uuid,
      Value<int> modifiedAt,
      Value<int?> deletedAt,
      Value<String?> sourceUrl,
    });

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDb, $PlaylistsTable, Playlist> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistSongsTable, List<PlaylistSong>>
  _playlistSongsRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.playlistSongs,
    aliasName: 'playlists__id__playlist_songs__playlist_id',
  );

  $$PlaylistSongsTableProcessedTableManager get playlistSongsRefs {
    final manager = $$PlaylistSongsTableTableManager(
      $_db,
      $_db.playlistSongs,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistSongsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MissingTracksTable, List<MissingTrack>>
  _missingTracksRefsTable(_$AppDb db) => MultiTypedResultKey.fromTable(
    db.missingTracks,
    aliasName: 'playlists__id__missing_tracks__playlist_id',
  );

  $$MissingTracksTableProcessedTableManager get missingTracksRefs {
    final manager = $$MissingTracksTableTableManager(
      $_db,
      $_db.missingTracks,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_missingTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDb, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistSongsRefs(
    Expression<bool> Function($$PlaylistSongsTableFilterComposer f) f,
  ) {
    final $$PlaylistSongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistSongs,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistSongsTableFilterComposer(
            $db: $db,
            $table: $db.playlistSongs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> missingTracksRefs(
    Expression<bool> Function($$MissingTracksTableFilterComposer f) f,
  ) {
    final $$MissingTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.missingTracks,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissingTracksTableFilterComposer(
            $db: $db,
            $table: $db.missingTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDb, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDb, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  Expression<T> playlistSongsRefs<T extends Object>(
    Expression<T> Function($$PlaylistSongsTableAnnotationComposer a) f,
  ) {
    final $$PlaylistSongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistSongs,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistSongsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistSongs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> missingTracksRefs<T extends Object>(
    Expression<T> Function($$MissingTracksTableAnnotationComposer a) f,
  ) {
    final $$MissingTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.missingTracks,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissingTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.missingTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PlaylistsTable,
          Playlist,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (Playlist, $$PlaylistsTableReferences),
          Playlist,
          PrefetchHooks Function({
            bool playlistSongsRefs,
            bool missingTracksRefs,
          })
        > {
  $$PlaylistsTableTableManager(_$AppDb db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> modifiedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                uuid: uuid,
                modifiedAt: modifiedAt,
                deletedAt: deletedAt,
                sourceUrl: sourceUrl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> uuid = const Value.absent(),
                Value<int> modifiedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String?> sourceUrl = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                uuid: uuid,
                modifiedAt: modifiedAt,
                deletedAt: deletedAt,
                sourceUrl: sourceUrl,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({playlistSongsRefs = false, missingTracksRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playlistSongsRefs) db.playlistSongs,
                    if (missingTracksRefs) db.missingTracks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playlistSongsRefs)
                        await $_getPrefetchedData<
                          Playlist,
                          $PlaylistsTable,
                          PlaylistSong
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._playlistSongsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistSongsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (missingTracksRefs)
                        await $_getPrefetchedData<
                          Playlist,
                          $PlaylistsTable,
                          MissingTrack
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._missingTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).missingTracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PlaylistsTable,
      Playlist,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (Playlist, $$PlaylistsTableReferences),
      Playlist,
      PrefetchHooks Function({bool playlistSongsRefs, bool missingTracksRefs})
    >;
typedef $$PlaylistSongsTableCreateCompanionBuilder =
    PlaylistSongsCompanion Function({
      required int playlistId,
      required int chatId,
      required int messageId,
      required int addedAt,
      Value<int?> sourceAddedAt,
      Value<int?> removedAt,
      Value<int> rowid,
    });
typedef $$PlaylistSongsTableUpdateCompanionBuilder =
    PlaylistSongsCompanion Function({
      Value<int> playlistId,
      Value<int> chatId,
      Value<int> messageId,
      Value<int> addedAt,
      Value<int?> sourceAddedAt,
      Value<int?> removedAt,
      Value<int> rowid,
    });

final class $$PlaylistSongsTableReferences
    extends BaseReferences<_$AppDb, $PlaylistSongsTable, PlaylistSong> {
  $$PlaylistSongsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDb db) =>
      db.playlists.createAlias('playlist_songs__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistSongsTableFilterComposer
    extends Composer<_$AppDb, $PlaylistSongsTable> {
  $$PlaylistSongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceAddedAt => $composableBuilder(
    column: $table.sourceAddedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get removedAt => $composableBuilder(
    column: $table.removedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistSongsTableOrderingComposer
    extends Composer<_$AppDb, $PlaylistSongsTable> {
  $$PlaylistSongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceAddedAt => $composableBuilder(
    column: $table.sourceAddedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get removedAt => $composableBuilder(
    column: $table.removedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistSongsTableAnnotationComposer
    extends Composer<_$AppDb, $PlaylistSongsTable> {
  $$PlaylistSongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<int> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get sourceAddedAt => $composableBuilder(
    column: $table.sourceAddedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get removedAt =>
      $composableBuilder(column: $table.removedAt, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistSongsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PlaylistSongsTable,
          PlaylistSong,
          $$PlaylistSongsTableFilterComposer,
          $$PlaylistSongsTableOrderingComposer,
          $$PlaylistSongsTableAnnotationComposer,
          $$PlaylistSongsTableCreateCompanionBuilder,
          $$PlaylistSongsTableUpdateCompanionBuilder,
          (PlaylistSong, $$PlaylistSongsTableReferences),
          PlaylistSong,
          PrefetchHooks Function({bool playlistId})
        > {
  $$PlaylistSongsTableTableManager(_$AppDb db, $PlaylistSongsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistSongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistSongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistSongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> playlistId = const Value.absent(),
                Value<int> chatId = const Value.absent(),
                Value<int> messageId = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int?> sourceAddedAt = const Value.absent(),
                Value<int?> removedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistSongsCompanion(
                playlistId: playlistId,
                chatId: chatId,
                messageId: messageId,
                addedAt: addedAt,
                sourceAddedAt: sourceAddedAt,
                removedAt: removedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int playlistId,
                required int chatId,
                required int messageId,
                required int addedAt,
                Value<int?> sourceAddedAt = const Value.absent(),
                Value<int?> removedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistSongsCompanion.insert(
                playlistId: playlistId,
                chatId: chatId,
                messageId: messageId,
                addedAt: addedAt,
                sourceAddedAt: sourceAddedAt,
                removedAt: removedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaylistSongsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.playlistId,
                                referencedTable: $$PlaylistSongsTableReferences
                                    ._playlistIdTable(db),
                                referencedColumn: $$PlaylistSongsTableReferences
                                    ._playlistIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistSongsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PlaylistSongsTable,
      PlaylistSong,
      $$PlaylistSongsTableFilterComposer,
      $$PlaylistSongsTableOrderingComposer,
      $$PlaylistSongsTableAnnotationComposer,
      $$PlaylistSongsTableCreateCompanionBuilder,
      $$PlaylistSongsTableUpdateCompanionBuilder,
      (PlaylistSong, $$PlaylistSongsTableReferences),
      PlaylistSong,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$PrefsTableCreateCompanionBuilder =
    PrefsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$PrefsTableUpdateCompanionBuilder =
    PrefsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$PrefsTableFilterComposer extends Composer<_$AppDb, $PrefsTable> {
  $$PrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrefsTableOrderingComposer extends Composer<_$AppDb, $PrefsTable> {
  $$PrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrefsTableAnnotationComposer extends Composer<_$AppDb, $PrefsTable> {
  $$PrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$PrefsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PrefsTable,
          Pref,
          $$PrefsTableFilterComposer,
          $$PrefsTableOrderingComposer,
          $$PrefsTableAnnotationComposer,
          $$PrefsTableCreateCompanionBuilder,
          $$PrefsTableUpdateCompanionBuilder,
          (Pref, BaseReferences<_$AppDb, $PrefsTable, Pref>),
          Pref,
          PrefetchHooks Function()
        > {
  $$PrefsTableTableManager(_$AppDb db, $PrefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrefsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => PrefsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PrefsTable,
      Pref,
      $$PrefsTableFilterComposer,
      $$PrefsTableOrderingComposer,
      $$PrefsTableAnnotationComposer,
      $$PrefsTableCreateCompanionBuilder,
      $$PrefsTableUpdateCompanionBuilder,
      (Pref, BaseReferences<_$AppDb, $PrefsTable, Pref>),
      Pref,
      PrefetchHooks Function()
    >;
typedef $$MissingTracksTableCreateCompanionBuilder =
    MissingTracksCompanion Function({
      required int playlistId,
      required String trackKey,
      required String title,
      required String artist,
      Value<int> durationSec,
      Value<int> position,
      Value<int?> sourceAddedAt,
      Value<int> rowid,
    });
typedef $$MissingTracksTableUpdateCompanionBuilder =
    MissingTracksCompanion Function({
      Value<int> playlistId,
      Value<String> trackKey,
      Value<String> title,
      Value<String> artist,
      Value<int> durationSec,
      Value<int> position,
      Value<int?> sourceAddedAt,
      Value<int> rowid,
    });

final class $$MissingTracksTableReferences
    extends BaseReferences<_$AppDb, $MissingTracksTable, MissingTrack> {
  $$MissingTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDb db) =>
      db.playlists.createAlias('missing_tracks__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MissingTracksTableFilterComposer
    extends Composer<_$AppDb, $MissingTracksTable> {
  $$MissingTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackKey => $composableBuilder(
    column: $table.trackKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceAddedAt => $composableBuilder(
    column: $table.sourceAddedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MissingTracksTableOrderingComposer
    extends Composer<_$AppDb, $MissingTracksTable> {
  $$MissingTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackKey => $composableBuilder(
    column: $table.trackKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceAddedAt => $composableBuilder(
    column: $table.sourceAddedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MissingTracksTableAnnotationComposer
    extends Composer<_$AppDb, $MissingTracksTable> {
  $$MissingTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackKey =>
      $composableBuilder(column: $table.trackKey, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get sourceAddedAt => $composableBuilder(
    column: $table.sourceAddedAt,
    builder: (column) => column,
  );

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MissingTracksTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $MissingTracksTable,
          MissingTrack,
          $$MissingTracksTableFilterComposer,
          $$MissingTracksTableOrderingComposer,
          $$MissingTracksTableAnnotationComposer,
          $$MissingTracksTableCreateCompanionBuilder,
          $$MissingTracksTableUpdateCompanionBuilder,
          (MissingTrack, $$MissingTracksTableReferences),
          MissingTrack,
          PrefetchHooks Function({bool playlistId})
        > {
  $$MissingTracksTableTableManager(_$AppDb db, $MissingTracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MissingTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MissingTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MissingTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> playlistId = const Value.absent(),
                Value<String> trackKey = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<int> durationSec = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> sourceAddedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MissingTracksCompanion(
                playlistId: playlistId,
                trackKey: trackKey,
                title: title,
                artist: artist,
                durationSec: durationSec,
                position: position,
                sourceAddedAt: sourceAddedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int playlistId,
                required String trackKey,
                required String title,
                required String artist,
                Value<int> durationSec = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> sourceAddedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MissingTracksCompanion.insert(
                playlistId: playlistId,
                trackKey: trackKey,
                title: title,
                artist: artist,
                durationSec: durationSec,
                position: position,
                sourceAddedAt: sourceAddedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MissingTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.playlistId,
                                referencedTable: $$MissingTracksTableReferences
                                    ._playlistIdTable(db),
                                referencedColumn: $$MissingTracksTableReferences
                                    ._playlistIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MissingTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $MissingTracksTable,
      MissingTrack,
      $$MissingTracksTableFilterComposer,
      $$MissingTracksTableOrderingComposer,
      $$MissingTracksTableAnnotationComposer,
      $$MissingTracksTableCreateCompanionBuilder,
      $$MissingTracksTableUpdateCompanionBuilder,
      (MissingTrack, $$MissingTracksTableReferences),
      MissingTrack,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$MoodVotesTableCreateCompanionBuilder =
    MoodVotesCompanion Function({
      required int chatId,
      required int messageId,
      required String mood,
      required int vote,
      required int at,
      Value<int> rowid,
    });
typedef $$MoodVotesTableUpdateCompanionBuilder =
    MoodVotesCompanion Function({
      Value<int> chatId,
      Value<int> messageId,
      Value<String> mood,
      Value<int> vote,
      Value<int> at,
      Value<int> rowid,
    });

class $$MoodVotesTableFilterComposer
    extends Composer<_$AppDb, $MoodVotesTable> {
  $$MoodVotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get vote => $composableBuilder(
    column: $table.vote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MoodVotesTableOrderingComposer
    extends Composer<_$AppDb, $MoodVotesTable> {
  $$MoodVotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get vote => $composableBuilder(
    column: $table.vote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MoodVotesTableAnnotationComposer
    extends Composer<_$AppDb, $MoodVotesTable> {
  $$MoodVotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<int> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<int> get vote =>
      $composableBuilder(column: $table.vote, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$MoodVotesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $MoodVotesTable,
          MoodVote,
          $$MoodVotesTableFilterComposer,
          $$MoodVotesTableOrderingComposer,
          $$MoodVotesTableAnnotationComposer,
          $$MoodVotesTableCreateCompanionBuilder,
          $$MoodVotesTableUpdateCompanionBuilder,
          (MoodVote, BaseReferences<_$AppDb, $MoodVotesTable, MoodVote>),
          MoodVote,
          PrefetchHooks Function()
        > {
  $$MoodVotesTableTableManager(_$AppDb db, $MoodVotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoodVotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoodVotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoodVotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> chatId = const Value.absent(),
                Value<int> messageId = const Value.absent(),
                Value<String> mood = const Value.absent(),
                Value<int> vote = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MoodVotesCompanion(
                chatId: chatId,
                messageId: messageId,
                mood: mood,
                vote: vote,
                at: at,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int chatId,
                required int messageId,
                required String mood,
                required int vote,
                required int at,
                Value<int> rowid = const Value.absent(),
              }) => MoodVotesCompanion.insert(
                chatId: chatId,
                messageId: messageId,
                mood: mood,
                vote: vote,
                at: at,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MoodVotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $MoodVotesTable,
      MoodVote,
      $$MoodVotesTableFilterComposer,
      $$MoodVotesTableOrderingComposer,
      $$MoodVotesTableAnnotationComposer,
      $$MoodVotesTableCreateCompanionBuilder,
      $$MoodVotesTableUpdateCompanionBuilder,
      (MoodVote, BaseReferences<_$AppDb, $MoodVotesTable, MoodVote>),
      MoodVote,
      PrefetchHooks Function()
    >;
typedef $$ForumTopicsTableCreateCompanionBuilder =
    ForumTopicsCompanion Function({
      required int chatId,
      required int topicId,
      required String name,
      Value<int> rowid,
    });
typedef $$ForumTopicsTableUpdateCompanionBuilder =
    ForumTopicsCompanion Function({
      Value<int> chatId,
      Value<int> topicId,
      Value<String> name,
      Value<int> rowid,
    });

class $$ForumTopicsTableFilterComposer
    extends Composer<_$AppDb, $ForumTopicsTable> {
  $$ForumTopicsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ForumTopicsTableOrderingComposer
    extends Composer<_$AppDb, $ForumTopicsTable> {
  $$ForumTopicsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ForumTopicsTableAnnotationComposer
    extends Composer<_$AppDb, $ForumTopicsTable> {
  $$ForumTopicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<int> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$ForumTopicsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ForumTopicsTable,
          ForumTopic,
          $$ForumTopicsTableFilterComposer,
          $$ForumTopicsTableOrderingComposer,
          $$ForumTopicsTableAnnotationComposer,
          $$ForumTopicsTableCreateCompanionBuilder,
          $$ForumTopicsTableUpdateCompanionBuilder,
          (ForumTopic, BaseReferences<_$AppDb, $ForumTopicsTable, ForumTopic>),
          ForumTopic,
          PrefetchHooks Function()
        > {
  $$ForumTopicsTableTableManager(_$AppDb db, $ForumTopicsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ForumTopicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ForumTopicsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ForumTopicsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> chatId = const Value.absent(),
                Value<int> topicId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ForumTopicsCompanion(
                chatId: chatId,
                topicId: topicId,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int chatId,
                required int topicId,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => ForumTopicsCompanion.insert(
                chatId: chatId,
                topicId: topicId,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ForumTopicsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ForumTopicsTable,
      ForumTopic,
      $$ForumTopicsTableFilterComposer,
      $$ForumTopicsTableOrderingComposer,
      $$ForumTopicsTableAnnotationComposer,
      $$ForumTopicsTableCreateCompanionBuilder,
      $$ForumTopicsTableUpdateCompanionBuilder,
      (ForumTopic, BaseReferences<_$AppDb, $ForumTopicsTable, ForumTopic>),
      ForumTopic,
      PrefetchHooks Function()
    >;
typedef $$PostCopiesTableCreateCompanionBuilder =
    PostCopiesCompanion Function({
      required int chatId,
      required int messageId,
      required String uniqueId,
      required String fileName,
      required int size,
      Value<int?> topicId,
      required int date,
      Value<int> rowid,
    });
typedef $$PostCopiesTableUpdateCompanionBuilder =
    PostCopiesCompanion Function({
      Value<int> chatId,
      Value<int> messageId,
      Value<String> uniqueId,
      Value<String> fileName,
      Value<int> size,
      Value<int?> topicId,
      Value<int> date,
      Value<int> rowid,
    });

class $$PostCopiesTableFilterComposer
    extends Composer<_$AppDb, $PostCopiesTable> {
  $$PostCopiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uniqueId => $composableBuilder(
    column: $table.uniqueId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PostCopiesTableOrderingComposer
    extends Composer<_$AppDb, $PostCopiesTable> {
  $$PostCopiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get chatId => $composableBuilder(
    column: $table.chatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uniqueId => $composableBuilder(
    column: $table.uniqueId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PostCopiesTableAnnotationComposer
    extends Composer<_$AppDb, $PostCopiesTable> {
  $$PostCopiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get chatId =>
      $composableBuilder(column: $table.chatId, builder: (column) => column);

  GeneratedColumn<int> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get uniqueId =>
      $composableBuilder(column: $table.uniqueId, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  GeneratedColumn<int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);
}

class $$PostCopiesTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PostCopiesTable,
          PostCopy,
          $$PostCopiesTableFilterComposer,
          $$PostCopiesTableOrderingComposer,
          $$PostCopiesTableAnnotationComposer,
          $$PostCopiesTableCreateCompanionBuilder,
          $$PostCopiesTableUpdateCompanionBuilder,
          (PostCopy, BaseReferences<_$AppDb, $PostCopiesTable, PostCopy>),
          PostCopy,
          PrefetchHooks Function()
        > {
  $$PostCopiesTableTableManager(_$AppDb db, $PostCopiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PostCopiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PostCopiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PostCopiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> chatId = const Value.absent(),
                Value<int> messageId = const Value.absent(),
                Value<String> uniqueId = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int?> topicId = const Value.absent(),
                Value<int> date = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PostCopiesCompanion(
                chatId: chatId,
                messageId: messageId,
                uniqueId: uniqueId,
                fileName: fileName,
                size: size,
                topicId: topicId,
                date: date,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int chatId,
                required int messageId,
                required String uniqueId,
                required String fileName,
                required int size,
                Value<int?> topicId = const Value.absent(),
                required int date,
                Value<int> rowid = const Value.absent(),
              }) => PostCopiesCompanion.insert(
                chatId: chatId,
                messageId: messageId,
                uniqueId: uniqueId,
                fileName: fileName,
                size: size,
                topicId: topicId,
                date: date,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PostCopiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PostCopiesTable,
      PostCopy,
      $$PostCopiesTableFilterComposer,
      $$PostCopiesTableOrderingComposer,
      $$PostCopiesTableAnnotationComposer,
      $$PostCopiesTableCreateCompanionBuilder,
      $$PostCopiesTableUpdateCompanionBuilder,
      (PostCopy, BaseReferences<_$AppDb, $PostCopiesTable, PostCopy>),
      PostCopy,
      PrefetchHooks Function()
    >;
typedef $$ListenStatsTableCreateCompanionBuilder =
    ListenStatsCompanion Function({
      required String origin,
      required String day,
      required String trackKey,
      Value<int> ms,
      Value<int> plays,
      Value<int> rowid,
    });
typedef $$ListenStatsTableUpdateCompanionBuilder =
    ListenStatsCompanion Function({
      Value<String> origin,
      Value<String> day,
      Value<String> trackKey,
      Value<int> ms,
      Value<int> plays,
      Value<int> rowid,
    });

class $$ListenStatsTableFilterComposer
    extends Composer<_$AppDb, $ListenStatsTable> {
  $$ListenStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackKey => $composableBuilder(
    column: $table.trackKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ms => $composableBuilder(
    column: $table.ms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plays => $composableBuilder(
    column: $table.plays,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ListenStatsTableOrderingComposer
    extends Composer<_$AppDb, $ListenStatsTable> {
  $$ListenStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackKey => $composableBuilder(
    column: $table.trackKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ms => $composableBuilder(
    column: $table.ms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plays => $composableBuilder(
    column: $table.plays,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ListenStatsTableAnnotationComposer
    extends Composer<_$AppDb, $ListenStatsTable> {
  $$ListenStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get trackKey =>
      $composableBuilder(column: $table.trackKey, builder: (column) => column);

  GeneratedColumn<int> get ms =>
      $composableBuilder(column: $table.ms, builder: (column) => column);

  GeneratedColumn<int> get plays =>
      $composableBuilder(column: $table.plays, builder: (column) => column);
}

class $$ListenStatsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ListenStatsTable,
          ListenStat,
          $$ListenStatsTableFilterComposer,
          $$ListenStatsTableOrderingComposer,
          $$ListenStatsTableAnnotationComposer,
          $$ListenStatsTableCreateCompanionBuilder,
          $$ListenStatsTableUpdateCompanionBuilder,
          (ListenStat, BaseReferences<_$AppDb, $ListenStatsTable, ListenStat>),
          ListenStat,
          PrefetchHooks Function()
        > {
  $$ListenStatsTableTableManager(_$AppDb db, $ListenStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListenStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListenStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListenStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> origin = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<String> trackKey = const Value.absent(),
                Value<int> ms = const Value.absent(),
                Value<int> plays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListenStatsCompanion(
                origin: origin,
                day: day,
                trackKey: trackKey,
                ms: ms,
                plays: plays,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String origin,
                required String day,
                required String trackKey,
                Value<int> ms = const Value.absent(),
                Value<int> plays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListenStatsCompanion.insert(
                origin: origin,
                day: day,
                trackKey: trackKey,
                ms: ms,
                plays: plays,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ListenStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ListenStatsTable,
      ListenStat,
      $$ListenStatsTableFilterComposer,
      $$ListenStatsTableOrderingComposer,
      $$ListenStatsTableAnnotationComposer,
      $$ListenStatsTableCreateCompanionBuilder,
      $$ListenStatsTableUpdateCompanionBuilder,
      (ListenStat, BaseReferences<_$AppDb, $ListenStatsTable, ListenStat>),
      ListenStat,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db, _db.songs);
  $$LibraryChatsTableTableManager get libraryChats =>
      $$LibraryChatsTableTableManager(_db, _db.libraryChats);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistSongsTableTableManager get playlistSongs =>
      $$PlaylistSongsTableTableManager(_db, _db.playlistSongs);
  $$PrefsTableTableManager get prefs =>
      $$PrefsTableTableManager(_db, _db.prefs);
  $$MissingTracksTableTableManager get missingTracks =>
      $$MissingTracksTableTableManager(_db, _db.missingTracks);
  $$MoodVotesTableTableManager get moodVotes =>
      $$MoodVotesTableTableManager(_db, _db.moodVotes);
  $$ForumTopicsTableTableManager get forumTopics =>
      $$ForumTopicsTableTableManager(_db, _db.forumTopics);
  $$PostCopiesTableTableManager get postCopies =>
      $$PostCopiesTableTableManager(_db, _db.postCopies);
  $$ListenStatsTableTableManager get listenStats =>
      $$ListenStatsTableTableManager(_db, _db.listenStats);
}
