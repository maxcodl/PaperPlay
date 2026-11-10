import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../library/audio_info.dart';
import '../library/db.dart';
import '../library/upload.dart' show Uploader;
import '../library/spotify_account.dart';
import '../library/weather.dart';
import 'background_tiles.dart';
import 'channels_screen.dart';
import 'connection.dart';
import 'duplicates_screen.dart';
import 'glass/glass_settings.dart';
import 'sort_general_screen.dart';
import 'mix_settings.dart';
import 'library_status.dart';
import 'profile_page.dart';
import 'extra_bots_screen.dart';
import 'log_screen.dart';
import '../pace.dart';
import 'ui_prefs.dart';
import 'user_login_screen.dart';
import 'equalizer_screen.dart';
import 'widgets.dart';

Future<void> _chooseCity(BuildContext context) async {
  final name = await askText(context, 'Your city', label: 'City');
  if (name == null || name.trim().isEmpty || !context.mounted) return;
  final List<WeatherPlace> places;
  try {
    places = await app.weather.searchPlaces(name.trim());
  } on Exception {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't reach the weather service. Check your connection.")),
      );
    }
    return;
  }
  if (!context.mounted) return;
  if (places.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No place called "${name.trim()}" found.')));
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final p in places)
            ListTile(
              leading: const Icon(Icons.place_rounded),
              title: Text(p.name),
              onTap: () {
                app.weather.setPlace(p);
                Navigator.pop(sheet);
              },
            ),
        ],
      ),
    ),
  );
}

/// ListenBrainz token and on/off.
class _ListenBrainzControls extends StatelessWidget {
  const _ListenBrainzControls();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([app.listenbrainz.enabled, app.listenbrainz.hasToken]),
        builder: (context, _) => Column(
          children: [
            ListTile(
              leading: const Icon(Icons.key_rounded),
              title: const Text('ListenBrainz token'),
              subtitle: Text(app.listenbrainz.hasToken.value ? 'Set. Tap to change' : 'Not set (listenbrainz.org/settings)'),
              onTap: () async {
                final t = await askText(context, 'ListenBrainz user token', label: 'Token', hint: 'Paste it here', paste: true);
                if (t != null) await app.listenbrainz.setToken(t);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.music_note_rounded),
              title: const Text('Send listens to ListenBrainz'),
              subtitle: const Text('After half a song or 4 minutes. Offline listens wait.'),
              value: app.listenbrainz.enabled.value,
              onChanged: app.listenbrainz.hasToken.value ? app.listenbrainz.setEnabled : null,
            ),
          ],
        ),
      );
}

/// Volume levelling by ReplayGain tags.
class _LoudnessControls extends StatefulWidget {
  const _LoudnessControls();

  @override
  State<_LoudnessControls> createState() => _LoudnessControlsState();
}

class _LoudnessControlsState extends State<_LoudnessControls> {
  @override
  Widget build(BuildContext context) {
    final on = app.player.normMode == 'track';
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.volume_up_rounded),
          title: const Text('Level volume between songs'),
          subtitle: const Text('Uses ReplayGain tags in the file and only turns loud songs down. Songs without tags are unchanged.'),
          value: on,
          onChanged: (v) async {
            await app.player.setNormalization(mode: v ? 'track' : 'off');
            setState(() {});
          },
        ),
        if (on)
          ListTile(
            title: Text('Preamp: ${app.player.normPreamp.toStringAsFixed(0)} dB'),
            subtitle: Slider(
              min: -12,
              max: 6,
              divisions: 18,
              value: app.player.normPreamp,
              onChanged: (v) => setState(() => app.player.normPreamp = v),
              onChangeEnd: (v) => app.player.setNormalization(preamp: v),
            ),
          ),
      ],
    );
  }
}

/// Signs in to Spotify, for importing a whole playlist instead of the first 100.
class _SpotifyControls extends StatefulWidget {
  const _SpotifyControls();

  @override
  State<_SpotifyControls> createState() => _SpotifyControlsState();
}

class _SpotifyControlsState extends State<_SpotifyControls> {
  var _busy = false;

  Future<void> _setId() async {
    final id = await askText(
      context,
      'Spotify Client ID',
      label: 'Client ID',
      hint: 'Paste it here',
      initial: app.spotify.clientId.value,
      paste: true,
    );
    if (id != null && id.trim().isNotEmpty) await app.spotify.setClientId(id);
  }

  Future<void> _connect() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await app.spotify.connect((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));
      messenger.showSnackBar(const SnackBar(content: Text('Connected to Spotify.')));
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([app.spotify.clientId, app.spotify.connected]),
        builder: (context, _) {
          final id = app.spotify.clientId.value;
          final connected = app.spotify.connected.value;
          return Column(
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Row(children: [Flexible(child: Text('Import whole playlists')), SizedBox(width: 4), InfoText("Without this, imports stop at around 100 tracks. Works for playlists you own or collaborate on. Add this Redirect URI in your Spotify developer dashboard: $spotifyRedirectUri")]),
              ),
              ListTile(
                leading: const Icon(Icons.key_rounded),
                title: const Text('Client ID'),
                subtitle: Text(id == null || id.isEmpty ? 'Not set' : id, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: _setId,
              ),
              ListTile(
                leading: Icon(connected ? Icons.check_circle_rounded : Icons.login_rounded),
                title: Text(connected ? 'Connected' : 'Connect to Spotify'),
                subtitle: connected ? const Text('Tap to disconnect') : null,
                trailing: _busy
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                onTap: _busy ? null : (connected ? app.spotify.disconnect : _connect),
              ),
            ],
          );
        },
      );
}

/// Light or dark, AMOLED and accent colour. Saved on this device only.
class _ThemeControls extends StatelessWidget {
  const _ThemeControls();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([app.ui.themeMode, app.ui.amoled, app.ui.accent, app.ui.coverGradient]),
      builder: (context, _) {
        final mode = app.ui.themeMode.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => app.ui.setThemeMode(s.first),
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.contrast_rounded),
              title: const Text('AMOLED black'),
              subtitle: Text(
                mode == ThemeMode.light ? 'Only applies in dark mode' : 'Pure black background in dark mode',
              ),
              value: app.ui.amoled.value,
              onChanged: mode == ThemeMode.light ? null : app.ui.setAmoled,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.gradient_rounded),
              title: const Text('Cover gradient background'),
              subtitle: const Text("Fades the colours of the playing song's cover into the background"),
              value: app.ui.coverGradient.value,
              onChanged: app.ui.setCoverGradient,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Accent colour', style: theme.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Wrap(
                children: [
                  for (final a in accentOptions)
                    _AccentSwatch(
                      option: a,
                      selected: a.id == app.ui.accent.value,
                      onTap: () => app.ui.setAccent(a.id),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({required this.option, required this.selected, required this.onTap});
  final AccentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final seed = option.seed;
    return Semantics(
      button: true,
      selected: selected,
      label: option.name,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: seed ?? scheme.primaryContainer,
                    border: Border.all(
                      color: selected ? scheme.onSurface : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    selected
                        ? Icons.check_rounded
                        : option.id == accentCover
                            ? Icons.album_rounded
                            : seed == null
                                ? Icons.auto_awesome_rounded
                                : null,
                    color: seed == null ? scheme.onPrimaryContainer : Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  option.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _gb = 1024 * 1024 * 1024;
const _limits = [_gb ~/ 2, _gb, 2 * _gb, 5 * _gb, 10 * _gb, 20 * _gb, 50 * _gb];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int? _limit;

  final _version = app.td.version();

  @override
  void initState() {
    super.initState();
    app.db.cacheLimit().then((v) {
      if (mounted) setState(() => _limit = v);
    });
  }

  Future<void> _logout() async {
    final ok = await confirm(
      context,
      'Log out?',
      "This wipes your bot token, library, playlists, favorites, tag edits and offline songs from this device. Your music in Telegram stays. Playlists and favorites can't be recovered.",
      'Log out',
    );
    if (!ok) return;
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    await app.logOut();
  }

  var _backupBusy = false;

  void _say(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveBackup() async {
    final password = await askPassword(
      context,
      title: 'Include your keys, bots and Spotify?',
      body: 'Your Telegram keys, bot tokens (all of them), Spotify sign-in and your own account session are encrypted with this '
          'password, because anyone who has them can control your bot. It can\'t be recovered, so '
          'remember it. If you forget it, your library still restores and you enter them by hand.',
      action: 'Save',
      skipLabel: 'Save without them',
      minLength: 8,
    );
    if (password == null) return;
    setState(() => _backupBusy = true);
    try {
      final zip = await app.saveBackup(password: password.isEmpty ? null : password);
      final day = DateTime.now().toIso8601String().split('T').first;
      final saved = await FilePicker.saveFile(
        fileName: 'paperplay-backup-$day.zip',
        bytes: await zip.readAsBytes(),
      );
      await zip.delete();
      _say(saved == null ? 'Backup not saved.' : 'Backup saved.');
    } catch (e) {
      _say('Couldn\'t save the backup: $e');
    }
    if (mounted) setState(() => _backupBusy = false);
  }

  Future<void> _restoreBackup() async {
    var layout = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Restore a backup?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This replaces your library, playlists and favorites with the backup. Offline songs are '
                'cleared and download again when played. Bots and Spotify come back if the backup has '
                'them and you know its password.',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: layout,
                onChanged: (v) => setDialog(() => layout = v ?? true),
                title: const Text('Also restore the app layout'),
                subtitle: const Text('Theme, navigation bar, sort orders, sound and speeds'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Restore')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final picked = await FilePicker.pickFiles(type: FileType.any);
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null) return;
    setState(() => _backupBusy = true);
    try {
      final result = await app.restoreFromBackup(path, applyLayout: layout);
      _say('Restored ${result.songs} songs${result.layoutApplied ? ' and the app layout' : ''}.');
      if (mounted) await applyBackupCredentials(context, result.sealedCredentials, result.sealedUserSession);
    } on FormatException catch (e) {
      _say('Backup not restored. Your library wasn\'t changed. ${e.message}');
    } catch (e) {
      _say('Couldn\'t restore the backup: $e');
    }
    if (mounted) setState(() => _backupBusy = false);
  }

  Future<void> _fullRescan() async {
    final ok = await confirm(
      context,
      'Run a full rescan?',
      "Re-reads every message in your music chats. Takes a few minutes and sends Telegram a lot of requests. Songs whose posts are gone get removed. You rarely need it, new songs show up on their own.",
      'Rescan',
    );
    if (ok) await app.scanner.fullRescan();
  }

  Future<void> _clearCache() async {
    final ok = await confirm(
      context,
      'Clear the cache?',
      "Clears offline songs; they download again when played. Pinned songs and the current one stay.",
      'Clear',
    );
    if (ok) await app.cache.clear();
  }

  var _query = '';

  /// Sub-pages rebuild from this, since they sit outside this State's own build.
  final _rebuild = ValueNotifier(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _rebuild.value++;
  }

  @override
  void dispose() {
    _rebuild.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final c in _categories(context))
        if (q.isEmpty || c.matches(q)) c,
    ];
    return Scaffold(
      appBar: AppBar(toolbarHeight: 72, title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SearchBar(
            hintText: 'Search settings',
            leading: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.search_rounded)),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          if (q.isEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              clipBehavior: Clip.antiAlias,
              child: ListenableBuilder(
                listenable: Listenable.merge([app.ui.profileName, app.ui.profilePhoto]),
                builder: (context, _) {
                  final photo = app.ui.profilePhoto.value;
                  final name = app.ui.profileName.value;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundImage: photo == null ? null : FileImage(File(photo)),
                      child: photo == null ? Text(name.characters.first.toUpperCase()) : null,
                    ),
                    title: Text(name, style: theme.textTheme.titleLarge),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Profile')),
                          body: ValueListenableBuilder(
                            valueListenable: app.liveSongs,
                            builder: (context, songs, _) => ProfilePage(songs: songs.values.toList()),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          for (final c in shown)
            Card(
              margin: const EdgeInsets.only(bottom: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                leading: Icon(c.icon),
                title: Text(c.title, style: theme.textTheme.titleMedium),
                subtitle: Text(c.subtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(c.title)),
                      body: ListenableBuilder(
                        listenable: _rebuild,
                        builder: (context, _) => ListView(
                          padding: const EdgeInsets.only(top: 4, bottom: 24),
                          children: _categories(this.context).firstWhere((x) => x.title == c.title).children,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (shown.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No settings match'))),
        ],
      ),
    );
  }

  /// Every settings group. Each opens as its own page.
  Widget _rateSlider(BuildContext context, Work w) => ValueListenableBuilder(
        valueListenable: rates[w]!,
        builder: (context, perMinute, _) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text('${w.label}: $perMinute a minute', style: Theme.of(context).textTheme.bodyMedium)),
                const SizedBox(width: 4),
                const InfoText(
                  "How many happen per minute. Faster gets done sooner, but Telegram may slow the bot "
                  "down for a while if it's pushed too hard. Song info never goes past one MusicBrainz "
                  "request a second.",
                ),
              ]),
              Slider(
                min: minRate.toDouble(),
                max: maxRate.toDouble(),
                divisions: maxRate - minRate,
                value: perMinute.toDouble(),
                label: '$perMinute',
                onChanged: (v) => rates[w]!.value = v.round(),
                onChangeEnd: (v) => setRate(app.db, w, v.round()),
              ),
            ],
          ),
        ),
      );

  List<_Category> _categories(BuildContext context) {
    final limit = _limit ?? AppDb.defaultCacheLimit;
    final limitIndex = _limits.indexWhere((l) => l >= limit).clamp(0, _limits.length - 1);
    return [
          const _Category(
            title: 'Appearance',
            subtitle: 'Theme, colors, display',
            keywords: 'theme dark amoled accent color',
            icon: Icons.palette_rounded,
            children: [_ThemeControls()],
          ),
          // The floating bar and its glass are phone-only; the PC has a sidebar instead.
          if (Platform.isAndroid || Platform.isIOS) ...const [
          _Category(
            title: 'Navigation bar',
            subtitle: 'Floating bar and its style',
            keywords: 'nav bar floating radius',
            icon: Icons.view_agenda_rounded,
            children: [NavBarSettings()],
          ),
          _Category(
            title: 'Glass',
            subtitle: 'Liquid glass look',
            keywords: 'glass blur refraction',
            icon: Icons.blur_on_rounded,
            children: [GlassSettings()],
          ),
          ],
          _Category(
            title: 'Telegram',
            subtitle: 'Channels, your account, bot activity, log out',
            keywords: 'bot channels account log tdlib logout speed reading copy',
            icon: Icons.send_rounded,
            children: [
              _rateSlider(context, Work.reading),
              _rateSlider(context, Work.accountCopy),
              ListTile(
                leading: const Icon(Icons.forum_rounded),
                title: const Text('Channels'),
                subtitle: const Text('See what\'s added, add more, and choose the main chat'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ChannelsScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.smart_toy_rounded),
                title: const Text('Extra bots'),
                subtitle: const Text('More bots share the uploading'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ExtraBotsScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: const Text('Your account (optional)'),
                subtitle: const Text("Deletes old posts the bot isn't allowed to"),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const UserLoginScreen()),
                ),
              ),
              ListenableBuilder(
                listenable: app.td.activity,
                builder: (context, _) {
                  final a = app.td.activity;
                  return ListTile(
                    leading: const Icon(Icons.monitor_heart_rounded),
                    title: const Text('Bot activity since the app opened'),
                    subtitle: Text(
                      '${a.reads} message reads, ${a.downloads} download requests, '
                      '${a.uploads} uploads, ${a.rateLimits} rate limits. Tap for the full log',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const LogScreen()),
                    ),
                  );
                },
              ),
              FutureBuilder<String>(
                future: _version,
                builder: (context, snap) => ListTile(
                  leading: const Icon(Icons.info_rounded),
                  title: const Text('TDLib version'),
                  subtitle: Text(snap.data ?? ''),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Log out'),
                onTap: _logout,
              ),
            ],
          ),
          _Category(
            title: 'Library',
            subtitle: 'Speeds, sorting, duplicates, rescan, song info',
            keywords: 'speed rate rescan duplicates sort general covers info',
            icon: Icons.library_music_rounded,
            children: [
              _rateSlider(context, Work.filing),
              ListTile(
                leading: const Icon(Icons.drive_file_move_rounded),
                title: const Text('Sort General'),
                subtitle: const Text("Suggests topics for songs in General. Nothing moves till you confirm"),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const SortGeneralScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.content_copy_rounded),
                title: const Text('Find duplicates'),
                subtitle: const Text("Repeated songs in your main chat, and deleting them"),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const DuplicatesScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.sync_rounded),
                title: const Text('Full rescan'),
                subtitle: const Text('Also removes songs deleted while the app was closed'),
                onTap: _fullRescan,
              ),
              _rateSlider(context, Work.lookups),
              _rateSlider(context, Work.covers),
              const LibraryStatusTiles(),
            ],
          ),
          _Category(
            title: 'Mixes',
            subtitle: 'Taste learning and weather mixes',
            keywords: 'mix taste learning weather city',
            icon: Icons.auto_awesome_rounded,
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome_rounded),
                title: const Text('Mixes and learning'),
                subtitle: const Text('What your taste is learned from, and clearing it'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const MixSettingsScreen()),
                ),
              ),
              ValueListenableBuilder(
                valueListenable: app.weather.place,
                builder: (context, place, _) => ListTile(
                  leading: const Icon(Icons.cloud_rounded),
                  title: const Text('Weather'),
                  subtitle: Text(
                    place == null
                        ? "Off. Add your city for weather mixes, like a rainy day mix. Only your city goes to Open-Meteo."
                        : '${place.name}. Weather by Open-Meteo.',
                  ),
                  trailing: place == null
                      ? const Icon(Icons.chevron_right_rounded)
                      : IconButton(
                          tooltip: 'Turn off weather',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => app.weather.setPlace(null),
                        ),
                  onTap: () => _chooseCity(context),
                ),
              ),
            ],
          ),
          _Category(
            title: 'Uploads',
            subtitle: 'Upload pace and skipping known songs',
            keywords: 'upload slow skip speed parallel',
            icon: Icons.upload_rounded,
            children: [
              _rateSlider(context, Work.uploads),
              ValueListenableBuilder(
                valueListenable: app.uploader.parallel,
                builder: (context, n, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Uploads at once: $n', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(width: 4),
                        const InfoText("Songs sent at the same time. Telegram lets a bot post about 20 messages a minute in one group, so keep this and the upload speed modest. If Telegram asks to wait, all of them wait."),
                      ]),
                      Slider(
                        value: n.toDouble(),
                        min: 1,
                        max: Uploader.maxParallel.toDouble(),
                        divisions: Uploader.maxParallel - 1,
                        label: '$n',
                        onChanged: (v) => app.uploader.setParallel(v.round()),
                      ),
                    ],
                  ),
                ),
              ),
              ValueListenableBuilder(
                valueListenable: app.uploader.slower,
                builder: (context, slower, _) => SwitchListTile(
                  secondary: const Icon(Icons.hourglass_bottom_rounded),
                  title: Row(children: [Flexible(child: Text('Upload more slowly')), const SizedBox(width: 4), InfoText("30-60 seconds between songs instead of 8-20. For really big uploads.")]),
                  value: slower,
                  onChanged: app.uploader.setSlower,
                ),
              ),
              ValueListenableBuilder(
                valueListenable: app.uploader.skipKnown,
                builder: (context, skip, _) => SwitchListTile(
                  secondary: const Icon(Icons.rule_rounded),
                  title: const Text('Skip songs already in my library'),
                  subtitle: const Text('Matches the file name and size, including files this app already sent.'),
                  value: skip,
                  onChanged: app.uploader.setSkipKnown,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.history_toggle_off_rounded),
                title: const Text('Forget sent files'),
                subtitle: const Text('Lets files this app uploaded before be uploaded again'),
                onTap: () async {
                  await app.uploader.forgetSent();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forgotten')));
                  }
                },
              ),
            ],
          ),
          _Category(
            title: 'Spotify import',
            subtitle: 'Import playlists from Spotify',
            keywords: 'spotify playlist import',
            icon: Icons.playlist_add_rounded,
            children: [
              _SpotifyControls(),
            ],
          ),
          _Category(
            title: 'Listening',
            subtitle: 'ListenBrainz, volume levelling, equalizer',
            keywords: 'listenbrainz scrobble listens loudness replaygain equalizer eq',
            icon: Icons.graphic_eq_rounded,
            children: [
              _ListenBrainzControls(),
              _LoudnessControls(),
              ListTile(
                leading: const Icon(Icons.equalizer_rounded),
                title: const Text('Equalizer'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EqualizerScreen())),
              ),
            ],
          ),
          _Category(
            title: 'Devices and background',
            subtitle: 'Connect devices, keep running',
            keywords: 'device connection sync background battery',
            icon: Icons.devices_rounded,
            children: [
              ValueListenableBuilder(
                valueListenable: app.link.devices,
                builder: (context, devices, _) => ListTile(
                  leading: const Icon(Icons.settings_ethernet_rounded),
                  title: const Text('Connection'),
                  subtitle: Text(
                    devices.isEmpty
                        ? 'No devices connected. Addresses and encryption.'
                        : 'Connected to ${devices.map((d) => d.name).join(', ')}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const ConnectionScreen()),
                  ),
                ),
              ),
              const BackgroundTiles(),
            ],
          ),
          _Category(
            title: 'Storage and backup',
            subtitle: 'Cache size, backup and restore',
            keywords: 'cache storage backup restore clear',
            icon: Icons.storage_rounded,
            children: [
              StreamBuilder<List<Song>>(
                stream: app.db.watchSongs(),
                builder: (context, snap) {
                  var pinned = 0, cached = 0;
                  for (final s in snap.data ?? const <Song>[]) {
                    s.pinned ? pinned += s.cachedBytes : cached += s.cachedBytes;
                  }
                  return ListTile(
                    leading: const Icon(Icons.storage_rounded),
                    title: Text('Cache: ${formatBytes(cached)} of ${formatBytes(limit)}'),
                    subtitle: Text(
                      'Pinned: ${formatBytes(pinned)}, not counted in the limit, stays until unpinned',
                    ),
                  );
                },
              ),
              Slider(
                max: _limits.length - 1.0,
                divisions: _limits.length - 1,
                value: limitIndex.toDouble(),
                label: formatBytes(_limits[limitIndex]),
                onChanged: (v) => setState(() => _limit = _limits[v.round()]),
                onChangeEnd: (v) async {
                  await app.db.setCacheLimit(_limits[v.round()]);
                  await app.cache.enforce();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_rounded),
                title: const Text('Clear cache'),
                subtitle: const Text('Keeps pinned songs and the current song'),
                onTap: _clearCache,
              ),
              ListTile(
                enabled: !_backupBusy,
                leading: const Icon(Icons.save_alt_rounded),
                title: Row(children: [Flexible(child: Text('Save backup')), const SizedBox(width: 4), InfoText("Song info, covers, playlists, favorites and the app layout. If you want, also your keys, all bot tokens and the Spotify sign-in, encrypted. Music isn't included.")]),
                onTap: _saveBackup,
              ),
              ListTile(
                enabled: !_backupBusy,
                leading: const Icon(Icons.restore_rounded),
                title: const Text('Restore backup'),
                subtitle: const Text('Replaces your current library'),
                onTap: _restoreBackup,
              ),
              if (_backupBusy) const _BackupProgressBar(),
            ],
          ),
    ];
  }
}

/// How far a backup or restore has got: what it is doing, a bar, and the percentage.
class _BackupProgressBar extends StatelessWidget {
  const _BackupProgressBar();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: app.backupProgress,
        builder: (context, progress, _) {
          final fraction = progress?.fraction;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(progress?.stage ?? 'Working', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (fraction != null) Text('${(fraction * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(minHeight: 8, value: fraction),
                ),
              ],
            ),
          );
        },
      );
}

/// One group of settings: a card on the Settings page, and a page of its own.
class _Category {
  const _Category({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.keywords = '',
  });
  final String title, subtitle, keywords;
  final IconData icon;
  final List<Widget> children;

  bool matches(String q) => '$title $subtitle $keywords'.toLowerCase().contains(q);
}
