import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../library/audio_info.dart';
import '../library/backup.dart';
import '../library/db.dart';
import '../metadata/enricher.dart';
import 'mixes.dart';
import 'quality_badge.dart';
import 'theme.dart';

/// Clips to an expressive scalloped "cookie" shape.
class CookieClipper extends CustomClipper<Path> {
  const CookieClipper();

  @override
  Path getClip(Size size) {
    final unit = MaterialShapes.cookie9Sided.toPath();
    return unit.transform((Matrix4.identity()..scaleByDouble(size.width, size.height, 1, 1)).storage);
  }

  @override
  bool shouldReclip(CookieClipper old) => false;
}

class Cover extends StatelessWidget {
  const Cover(this.song, {super.key, this.size = 56, this.radius});
  final Song? song;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        // Whoever passed this song may be holding an old copy of it.
        valueListenable: app.liveSongs,
        builder: (context, live, _) => _build(context, song == null ? null : live[song!.uniqueId] ?? song),
      );

  Widget _build(BuildContext context, Song? song) {
    final path = song?.coverPath;
    // Lists build only visible rows, so this asks for on-screen covers only.
    if (song != null) app.enricher.requestCover(song);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? size / 4.5),
      child: SizedBox.square(
        dimension: size,
        child: path != null
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                // Decoding at display size keeps long lists smooth.
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Icon(Icons.music_note_rounded, size: size / 2, color: scheme.onSurfaceVariant),
    );
  }
}

String formatDuration(Duration d) {
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  final minutes = d.inHours > 0 ? (d.inMinutes % 60).toString().padLeft(2, '0') : '${d.inMinutes}';
  return d.inHours > 0 ? '${d.inHours}:$minutes:$seconds' : '$minutes:$seconds';
}

/// Fades and rises once, staggered by [index], when a list first appears.
class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 280 + index * 35),
        curve: Curves.easeOutCubic,
        child: child,
        builder: (context, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: child),
        ),
      );
}

/// Height of a [SongTile] including its gap, fixed so long lists scroll fast.
const songTileExtent = 68.0;

/// Song row. [songs] is the list played when the row is tapped.
class SongTile extends StatelessWidget {
  const SongTile({super.key, required this.songs, required this.index, this.playlistId});
  final List<Song> songs;
  final int index;
  final int? playlistId;

  Song get song => songs[index];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ValueListenableBuilder(
      valueListenable: selection,
      builder: (context, picked, _) => Material(
      color: picked.contains(song.uniqueId) ? scheme.secondaryContainer : Colors.transparent,
      child: InkWell(
      onTap: () => picked.isEmpty ? app.player.play(songs, index) : toggleSelected(song),
      onLongPress: () => toggleSelected(song),
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            picked.contains(song.uniqueId)
                ? SizedBox.square(dimension: 52, child: Icon(Icons.check_circle_rounded, color: scheme.primary, size: 32))
                : Cover(song, size: 52, radius: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder(
                    valueListenable: app.player.current,
                    builder: (context, current, _) => Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: current?.uniqueId == song.uniqueId ? scheme.primary : null,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (song.pinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin_rounded, size: 13, color: scheme.primary, semanticLabel: 'Pinned'),
                        )
                      else if (song.cachedBytes >= song.size)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.offline_pin_rounded,
                            size: 13,
                            color: scheme.primary,
                            semanticLabel: 'Available offline',
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: QualityLabel(
                          song,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isLossless(songFormat(song)) ? scheme.primary : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          songDetails(song),
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (song.favorite)
              Icon(Icons.favorite_rounded, size: 16, color: scheme.primary, semanticLabel: 'Favorite'),
            SongMenu(song: song, playlistId: playlistId),
          ],
        ),
      ),
    ),
    ),
    );
  }
}

/// Songs picked in multi-select, by file. Long-press a song to start.
final selection = ValueNotifier<Set<String>>(const {});

void toggleSelected(Song s) {
  final next = {...selection.value};
  if (!next.remove(s.uniqueId)) next.add(s.uniqueId);
  selection.value = next;
}

/// Shown above a song list while songs are picked: what to do with all of them.
class SelectionBar extends StatelessWidget {
  const SelectionBar({super.key, required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: selection,
        builder: (context, picked, _) {
          if (picked.isEmpty) return const SizedBox.shrink();
          final chosen = [for (final s in songs) if (picked.contains(s.uniqueId)) s];
          final scheme = Theme.of(context).colorScheme;
          final all = picked.length >= songs.length;
          // Runs [each] on every picked song, then leaves picking.
          Future<void> forAll(Future<void> Function(Song) each, [Iterable<Song>? only]) async {
            for (final s in only ?? chosen) {
              await each(s);
            }
            selection.value = const {};
          }

          // Below the status bar on pages whose header runs under it.
          return SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Material(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(28),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Done',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => selection.value = const {},
                    ),
                    Expanded(child: Text('${picked.length} selected', style: Theme.of(context).textTheme.titleMedium)),
                    TextButton(
                      onPressed: () => selection.value = all ? const {} : {for (final s in songs) s.uniqueId},
                      child: Text(all ? 'None' : 'All'),
                    ),
                    IconButton(
                      tooltip: 'Add to playlist',
                      icon: const Icon(Icons.playlist_add_rounded),
                      onPressed: () async {
                        await _addToPlaylist(context, chosen);
                        selection.value = const {};
                      },
                    ),
                    PopupMenuButton<VoidCallback>(
                      tooltip: 'More',
                      onSelected: (a) => a(),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: () => forAll(app.player.playNext, chosen.reversed),
                          child: const ListTile(leading: Icon(Icons.queue_play_next_rounded), title: Text('Play next')),
                        ),
                        PopupMenuItem(
                          value: () => forAll(app.player.toggleFavorite, chosen.where((s) => !s.favorite)),
                          child: const ListTile(leading: Icon(Icons.favorite_rounded), title: Text('Add to favorites')),
                        ),
                        PopupMenuItem(
                          value: () => forAll(app.player.toggleFavorite, chosen.where((s) => s.favorite)),
                          child: const ListTile(leading: Icon(Icons.heart_broken_rounded), title: Text('Remove from favorites')),
                        ),
                        PopupMenuItem(
                          value: () => forAll((s) => app.cache.setPinned(s, true)),
                          child: const ListTile(leading: Icon(Icons.push_pin_rounded), title: Text('Pin for offline')),
                        ),
                        PopupMenuItem(
                          value: () => _deleteSongs(context, chosen),
                          child: const ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Delete from Telegram')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class SongMenu extends StatelessWidget {
  const SongMenu({super.key, required this.song, this.playlistId, this.icon});
  final Song song;
  final int? playlistId;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => PopupMenuButton<VoidCallback>(
        tooltip: 'Song options',
        icon: Icon(icon ?? Icons.more_vert_rounded),
        onSelected: (action) => action(),
        itemBuilder: (context) => [
          PopupMenuItem(value: () => app.player.playNext(song), child: const Text('Play next')),
          PopupMenuItem(
            value: () => app.player.toggleFavorite(song),
            child: Text(song.favorite ? 'Remove from favorites' : 'Add to favorites'),
          ),
          PopupMenuItem(value: () => showSongInfo(context, song), child: const Text('Song info')),
          PopupMenuItem(value: () => openInTelegram(song), child: const Text('Open in Telegram')),
          PopupMenuItem(
            value: () => app.cache.setPinned(song, !song.pinned),
            child: Text(song.pinned ? 'Unpin' : 'Pin for offline'),
          ),
          PopupMenuItem(
            value: () => _addToPlaylist(context, [song]),
            child: const Text('Add to playlist'),
          ),
          if (playlistId != null)
            PopupMenuItem(
              value: () => app.db.removeFromPlaylist(playlistId!, song),
              child: const Text('Remove from playlist'),
            ),
          PopupMenuItem(value: () => _editTags(context, song), child: const Text('Edit tags')),
          PopupMenuItem(value: () => _findMetadata(context, song), child: const Text('Find metadata')),
          PopupMenuItem(value: () => _changeCover(context, song), child: const Text('Change cover')),
          if (MixScope.maybeOf(context) case final scope?)
            PopupMenuItem(value: () => scope.onReject(song), child: const Text("Doesn't fit this mix")),
          PopupMenuItem(value: () => _deleteSong(context, song), child: const Text('Delete from Telegram')),
        ],
      );
}

/// Rounded group with a coloured heading, as used in Settings and song info.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A [SectionCard]-styled group that opens and closes when its heading is tapped.
/// Closed sections don't build their contents. Stays as left until the app closes.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.startOpen = false,
  });
  final String title;
  final List<Widget> children;

  /// A cookie-shaped badge before the title.
  final IconData? icon;

  /// Open the first time it's shown. After that it stays as it was left.
  final bool startOpen;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  static final _open = <String>{};
  static final _seen = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.startOpen && _seen.add(widget.title)) _open.add(widget.title);
  }

  bool get _isOpen => _open.contains(widget.title);

  void _toggle() => setState(() => _isOpen ? _open.remove(widget.title) : _open.add(widget.title));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = _isOpen;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              expanded: open,
              child: InkWell(
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      if (widget.icon != null) ...[
                        ClipPath(
                          clipper: const CookieClipper(),
                          child: Container(
                            width: 44,
                            height: 44,
                            color: theme.colorScheme.primaryContainer,
                            child: Icon(widget.icon, color: theme.colorScheme.onPrimaryContainer, size: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Text(
                          widget.title,
                          style: widget.icon == null
                              ? theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)
                              : theme.textTheme.titleLarge,
                        ),
                      ),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child: const Icon(Icons.expand_more_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: open
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.children,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before something that's costly or can't be undone. True means go ahead.
Future<bool> confirm(BuildContext context, String title, String body, String action) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(action)),
      ],
    ),
  );
  return answer == true;
}

/// Asks for a password. Null means cancelled, and an empty string means the
/// [skipLabel] button was chosen. A [minLength] is enforced before OK works.
Future<String?> askPassword(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  required String skipLabel,
  int minLength = 1,
  String? error,
}) {
  final input = TextEditingController();
  var hidden = true;
  return showDialog<String>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body),
              const SizedBox(height: 16),
              TextField(
                controller: input,
                autofocus: true,
                obscureText: hidden,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: error,
                  helperText: minLength > 1 ? 'At least $minLength characters' : null,
                  suffixIcon: IconButton(
                    tooltip: hidden ? 'Show password' : 'Hide password',
                    icon: Icon(hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => hidden = !hidden),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, ''), child: Text(skipLabel)),
          FilledButton(
            onPressed: input.text.length < minLength ? null : () => Navigator.pop(dialog, input.text),
            child: Text(action),
          ),
        ],
      ),
    ),
  );
}

/// After a restore, opens the backup's keys and token if it has them. Keeps
/// asking until the password is right or the user skips. True when applied.
Future<bool> applyBackupCredentials(BuildContext context, String? sealed, [String? sealedUserSession]) async {
  if (sealed == null) return false;
  String? error;
  while (true) {
    if (!context.mounted) return false;
    final password = await askPassword(
      context,
      title: 'Restore keys and bot token?',
      body: 'Enter the password you chose when saving this backup. If you skip, your library is '
          'still restored and you can enter them by hand.',
      action: 'Restore',
      skipLabel: 'Skip',
      error: error,
    );
    if (password == null || password.isEmpty) return false;
    try {
      await app.applyCredentials(await openCredentials(sealed, password));
      // The account's own session, with the same password.
      if (sealedUserSession != null) {
        final ok = await app.userSession.importSession(await openBytes(sealedUserSession, password));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? 'Your account is logged in again.' : 'Your account session had ended. Log in again under Your account.'),
          ));
        }
      }
      return true;
    } on WrongPassword {
      error = 'Wrong password';
    }
  }
}

/// Everything known about a song, in a clean bottom sheet.
Future<void> showSongInfo(BuildContext context, Song song) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SizedBox(
        height: MediaQuery.sizeOf(sheet).height * 0.8,
        child: _SongInfo(song: song),
      ),
    );

class _SongInfo extends StatefulWidget {
  const _SongInfo({required this.song});
  final Song song;

  @override
  State<_SongInfo> createState() => _SongInfoState();
}

class _SongInfoState extends State<_SongInfo> {
  late final _chat = app.db.chatTitle(widget.song.chatId);
  late final _sampleRate = app.cache.sampleRate(widget.song);

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final s = widget.song;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final format = songFormat(s);
    final kbps = averageKbps(s.size, s.durationSec);
    final tier = songTier(s);
    final posted = DateTime.fromMillisecondsSinceEpoch(s.date * 1000);
    final saved = s.size > 0 ? (s.cachedBytes * 100 / s.size).clamp(0, 100).round() : 0;

    Widget row(String label, String? value) => value == null || value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(width: 24),
                Expanded(
                  child: SelectableText(
                    value,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Cover(s, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge),
                    Text(
                      s.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Audio quality',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  QualityGlyph(tier, size: 24, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tier.label, style: theme.textTheme.headlineSmall)),
                ],
              ),
            ),
            FutureBuilder<int?>(
              future: _sampleRate,
              builder: (context, snap) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  [
                    format,
                    if (s.bitDepth != null) '${s.bitDepth}-bit',
                    if ((s.sampleRate ?? snap.data) case final rate?) formatKhz(rate),
                    if (kbps != null) '$kbps kbps average',
                  ].join(' · '),
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
        SectionCard(
          title: 'Details',
          children: [
            row('Album', s.album),
            row('Year', s.year?.toString()),
            row('Genre', s.genre),
            row('Length', s.durationSec > 0 ? formatDuration(Duration(seconds: s.durationSec)) : null),
          ],
        ),
        SectionCard(
          title: 'File',
          children: [
            row('Size', formatBytes(s.size)),
            row('Saved on this device', '$saved%'),
            row('Name', s.fileName),
            FutureBuilder<String?>(future: _chat, builder: (context, snap) => row('Channel', snap.data)),
            row('Posted', '${posted.year}-${_two(posted.month)}-${_two(posted.day)}'),
            row('Song info from', s.userEdited ? 'You' : s.metadataSource ?? 'The Telegram file'),
          ],
        ),
      ],
    );
  }
}

Future<String?> askText(
  BuildContext context,
  String title, {
  String label = 'Name',
  String? hint,
  String? initial,
  bool paste = false,
}) {
  final input = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: input,
        autofocus: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          // The label stays up, so the hint under it can always be seen.
          floatingLabelBehavior: hint == null ? null : FloatingLabelBehavior.always,
          // The dialog is this colour by default, which hides the field.
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          suffixIcon: !paste
              ? null
              : IconButton(
                  tooltip: 'Paste',
                  icon: const Icon(Icons.content_paste_rounded),
                  onPressed: () async {
                    final clip = await Clipboard.getData(Clipboard.kTextPlain);
                    if (clip?.text != null) input.text = clip!.text!;
                  },
                ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, input.text.trim()), child: const Text('OK')),
      ],
    ),
  );
}

Future<void> _addToPlaylist(BuildContext context, List<Song> songs) async {
  final lists = await app.db.livePlaylists();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: const Icon(Icons.add_rounded),
          title: const Text('New playlist'),
          onTap: () async {
            final name = await askText(sheet, 'New playlist');
            if (name != null && name.isNotEmpty) {
              final id = await app.db.createPlaylist(name);
              for (final song in songs) {
                await app.db.addToPlaylist(id, song);
              }
            }
            if (sheet.mounted) Navigator.pop(sheet);
          },
        ),
        for (final l in lists)
          ListTile(
            leading: const Icon(Icons.queue_music_rounded),
            title: Text(l.name),
            onTap: () async {
              Navigator.pop(sheet);
              for (final song in songs) {
                await app.db.addToPlaylist(l.id, song);
              }
            },
          ),
      ],
    ),
  );
}

Future<void> _editTags(BuildContext context, Song song) async {
  final title = TextEditingController(text: song.title);
  final artist = TextEditingController(text: song.artist);
  final album = TextEditingController(text: song.album);
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit tags'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 8),
          TextField(controller: artist, decoration: const InputDecoration(labelText: 'Artist')),
          const SizedBox(height: 8),
          TextField(controller: album, decoration: const InputDecoration(labelText: 'Album')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    ),
  );
  if (saved != true) return;
  // Local only: the file and message in Telegram are not changed.
  await app.db.updateSong(
    song,
    SongsCompanion(
      title: Value(title.text.trim()),
      artist: Value(artist.text.trim()),
      album: Value(album.text.trim()),
      userEdited: const Value(true),
    ),
  );
}

Future<void> _findMetadata(BuildContext context, Song song) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => FractionallySizedBox(heightFactor: 0.8, child: _MetadataSearch(song: song)),
    );

/// Search by any words, so a badly named file can still find its song.
class _MetadataSearch extends StatefulWidget {
  const _MetadataSearch({required this.song});
  final Song song;

  @override
  State<_MetadataSearch> createState() => _MetadataSearchState();
}

class _MetadataSearchState extends State<_MetadataSearch> {
  late final _term = TextEditingController(
    text: '${cleanTitle(widget.song.title, widget.song.artist)} '
            '${widget.song.artist == 'Unknown artist' ? '' : firstArtist(widget.song.artist)}'
        .trim(),
  );
  late Future<List<MetadataOption>> _results = _search();

  Future<List<MetadataOption>> _search() =>
      app.enricher.searchOnline(_term.text, durationSec: widget.song.durationSec);

  @override
  void dispose() {
    _term.dispose();
    super.dispose();
  }

  Future<void> _apply(MetadataOption m) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final hasCover = await app.enricher.applyOption(widget.song, m);
    if (!hasCover) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tags updated, but this result has no cover. Use Change cover.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _term,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search by song name, artist or album',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () => setState(() => _results = _search()),
                ),
              ),
              onSubmitted: (_) => setState(() => _results = _search()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MetadataOption>>(
              future: _results,
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final options = snap.data!;
                if (options.isEmpty) {
                  return const Center(child: Text('No matches. Try fewer or different words.'));
                }
                return ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, i) {
                    final m = options[i];
                    return ListTile(
                      leading: m.coverUrl == null
                          ? const SizedBox.square(dimension: 48, child: Icon(Icons.album_rounded))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                m.coverUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                cacheWidth: 144,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.square(dimension: 48, child: Icon(Icons.album_rounded)),
                              ),
                            ),
                      title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          m.artist,
                          m.album,
                          if (m.lengthSec != null) formatDuration(Duration(seconds: m.lengthSec!)),
                          m.source,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _apply(m),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
}

Future<void> _deleteSongs(BuildContext context, List<Song> songs) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await confirm(
    context,
    'Delete ${songs.length} songs?',
    "They're deleted from your main chat for everyone, repeats included, and leave your library and playlists. Copies in other channels stay there. Can't be undone.",
    'Delete',
  );
  if (!ok) return;
  selection.value = const {};
  final done = await app.deleteSongs(songs);
  messenger.showSnackBar(SnackBar(content: Text(done == songs.length ? 'Deleted $done.' : 'Deleted $done of ${songs.length}.')));
}

Future<void> _deleteSong(BuildContext context, Song song) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!await app.canDeleteIn(song.chatId)) {
    messenger.showSnackBar(
      const SnackBar(content: Text('The bot can\'t delete here. Make it an admin with the "Delete messages" right.')),
    );
    return;
  }
  if (!context.mounted) return;
  final ok = await confirm(
    context,
    'Delete "${song.title}"?',
    "This deletes it from your main chat for everyone, repeats of the same file included, and removes it from your library and playlists. Copies in other channels stay there. Can't be undone.",
    'Delete',
  );
  if (!ok) return;
  try {
    final posts = await app.deleteSong(song);
    messenger.showSnackBar(SnackBar(content: Text(posts == 1 ? 'Deleted.' : 'Deleted $posts posts.')));
  } on Exception catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Couldn\'t delete it: $e')));
  }
}

/// The most a picked image may be, so it stays quick to sync between devices.
const _maxPickedCover = 10 * 1024 * 1024;

Future<void> _changeCover(BuildContext context, Song song) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => FractionallySizedBox(heightFactor: 0.75, child: _CoverPicker(song: song)),
    );

class _CoverPicker extends StatefulWidget {
  const _CoverPicker({required this.song});
  final Song song;

  @override
  State<_CoverPicker> createState() => _CoverPickerState();
}

class _CoverPickerState extends State<_CoverPicker> {
  late final _term = TextEditingController(text: '${widget.song.title} ${firstArtist(widget.song.artist)}');
  late Future<List<CoverOption>> _options = app.enricher.coverOptions(_term.text);
  var _saving = false;

  /// Everything on this song's album. Empty until read, or if it has no album.
  var _album = const <Song>[];
  var _wholeAlbum = true;

  @override
  void initState() {
    super.initState();
    app.db
        .albumOf(widget.song, (a, b) => firstArtist(a.artist) == firstArtist(b.artist))
        .then((list) {
      if (mounted) setState(() => _album = list);
    });
  }

  List<Song> get _targets => _wholeAlbum && _album.length > 1 ? _album : [widget.song];

  @override
  void dispose() {
    _term.dispose();
    super.dispose();
  }

  void _finish(String? problem) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (problem == null) {
      final count = _targets.length;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(count == 1 ? 'Cover changed.' : 'Cover changed on $count songs.')),
      );
    } else {
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null) return;
    setState(() => _saving = true);
    final String? problem;
    try {
      final file = File(path);
      if (await file.length() > _maxPickedCover) {
        problem = 'That image is over 10 MB. Choose a smaller one.';
      } else {
        final bytes = await file.readAsBytes();
        // Decoding proves it's an image before it replaces anything.
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 16);
        codec.dispose();
        await app.enricher.setCoverBytes(_targets, bytes);
        problem = null;
      }
    } on FileSystemException {
      return _finish('Couldn\'t read that file.');
    } on Exception {
      return _finish('That file isn\'t an image Paper Play can show.');
    }
    _finish(problem);
  }

  Future<void> _useOption(CoverOption option) async {
    setState(() => _saving = true);
    final ok = await app.enricher.setCoverFromUrl(_targets, option.url);
    _finish(ok ? null : 'Couldn\'t download that cover. Check your connection.');
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _term,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Search for a cover',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onSubmitted: (v) => setState(() => _options = app.enricher.coverOptions(v)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.image_rounded),
            title: const Text('Choose an image from this device'),
            enabled: !_saving,
            onTap: _pickFile,
          ),
          if (_album.length > 1)
            SwitchListTile(
              secondary: const Icon(Icons.album_rounded),
              title: Text('Apply to the whole album (${_album.length} songs)'),
              subtitle: Text(widget.song.album, maxLines: 1, overflow: TextOverflow.ellipsis),
              value: _wholeAlbum,
              onChanged: _saving ? null : (v) => setState(() => _wholeAlbum = v),
            ),
          if (_saving) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<CoverOption>>(
              future: _options,
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final options = snap.data!;
                if (options.isEmpty) return const Center(child: Text('No covers found. Try other words.'));
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, i) => Tooltip(
                    message: options[i].label,
                    child: Semantics(
                      button: true,
                      label: 'Use cover: ${options[i].label}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _saving ? null : () => _useOption(options[i]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            options[i].url,
                            fit: BoxFit.cover,
                            cacheWidth: 300,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: Colors.black26,
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
}

/// Press feedback with a small overshoot, as Material 3 Expressive buttons have.
class SpringPress extends StatefulWidget {
  const SpringPress({super.key, required this.child});
  final Widget child;

  @override
  State<SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<SpringPress> {
  var _down = false;

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down ? 0.9 : 1,
          duration: const Duration(milliseconds: 260),
          curve: expressiveSpring,
          child: widget.child,
        ),
      );
}

/// An explanation kept out of the way: a small "i" that shows [text] when tapped.
class InfoText extends StatelessWidget {
  const InfoText(this.text, {super.key, this.textAlign, this.style});
  final String text;
  // Accepted so it can stand in for a Text; the explanation itself shows in a dialog.
  final TextAlign? textAlign;
  final TextStyle? style;

  static double _size(BuildContext context) =>
      ((DefaultTextStyle.of(context).style.fontSize ?? 16) * 0.8).clamp(16, 26).toDouble();

  @override
  Widget build(BuildContext context) => Align(
        // Only as wide as the icon, so it also fits as a trailing widget.
        widthFactor: 1,
        heightFactor: 1,
        alignment: textAlign == TextAlign.center ? Alignment.center : Alignment.centerLeft,
        child: IconButton(
          tooltip: 'More info',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          // Sized to the text beside it, so it sits level with a big title or a small label.
          constraints: BoxConstraints.tightFor(width: _size(context) + 8, height: _size(context) + 8),
          icon: Icon(Icons.info_outline_rounded, size: _size(context), color: Theme.of(context).colorScheme.onSurfaceVariant),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              content: SelectableText(text),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          ),
        ),
      );
}

/// Opens the song's post in Telegram. Private chat links (t.me/c/...) open for anyone
/// who's a member. TDLib ids are the server's shifted up by 20 bits.
Future<void> openInTelegram(Song s) async {
  final chat = -s.chatId - 1000000000000;
  final post = s.messageId >> 20;
  final topic = s.topicId == null ? '' : '${s.topicId! >> 20}/';
  await launchUrl(Uri.parse('https://t.me/c/$chat/$topic$post'), mode: LaunchMode.externalApplication);
}

/// A tile title with its explanation behind a small "i" right after it.
class TitleWithInfo extends StatelessWidget {
  const TitleWithInfo(this.title, this.info, {super.key});
  final String title, info;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Flexible(child: Text(title)),
          const SizedBox(width: 4),
          InfoText(info),
        ],
      );
}

/// The app's messenger and navigator, for toasts and pages opened from background work.
final appMessenger = GlobalKey<ScaffoldMessengerState>();
final appNavigator = GlobalKey<NavigatorState>();
