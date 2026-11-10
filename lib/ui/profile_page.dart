import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../activity.dart';
import '../app.dart';
import '../library/album_art.dart';
import '../library/audio_info.dart';
import '../library/db.dart';
import '../library/profile_stats.dart';
import 'channels_screen.dart';
import 'connection.dart';
import 'duplicates_screen.dart';
import 'home.dart' show openCollection, pushPage;
import 'missing_info_screen.dart';
import 'stats_screen.dart';
import 'tasks_screen.dart';
import 'widgets.dart';

/// Who's listening, how big the library is, and where things are set up.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.songs, this.openLibrary});
  final List<Song> songs;

  /// Opens a tab of the library: 0 songs, 3 playlists.
  final ValueChanged<int>? openLibrary;

  Future<void> _pickPhoto(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFiles(type: FileType.image);
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null) return;
    final small = await shrinkCoverInBackground(await File(path).readAsBytes(), side: 512, limit: 300 * 1024);
    if (small == null) {
      messenger.showSnackBar(const SnackBar(content: Text('That image can\'t be used.')));
      return;
    }
    final dir = await getApplicationSupportDirectory();
    // A new name each time, since images are cached by path.
    final out = File(p.join(dir.path, 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await out.writeAsBytes(small.bytes);
    await _forgetPhoto();
    await app.ui.setProfilePhoto(out.path);
  }

  static Future<void> _forgetPhoto() async {
    final old = app.ui.profilePhoto.value;
    if (old == null) return;
    try {
      await File(old).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: app.ui.profileName.value);
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await app.ui.setProfileName(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      // Room for the floating bar and mini player, so the last section isn't hidden.
      padding: EdgeInsets.only(top: 8, bottom: MediaQuery.paddingOf(context).bottom + 160),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ListenableBuilder(
                listenable: Listenable.merge([app.ui.profileName, app.ui.profilePhoto]),
                builder: (context, _) {
                  final name = app.ui.profileName.value;
                  final photo = app.ui.profilePhoto.value;
                  return Column(
                    children: [
                      SizedBox.square(
                        dimension: 140,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: ClipPath(
                                  clipper: const CookieClipper(),
                                  child: photo != null
                                      ? Image.file(File(photo), fit: BoxFit.cover, gaplessPlayback: true)
                                      : ColoredBox(
                                          color: theme.colorScheme.primaryContainer,
                                          child: Center(
                                            child: Text(
                                              name.characters.first.toUpperCase(),
                                              style: theme.textTheme.displayMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: IconButton.filled(
                                tooltip: 'Change photo',
                                icon: const Icon(Icons.photo_camera_rounded),
                                onPressed: () => _pickPhoto(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _rename(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Text(name, style: theme.textTheme.headlineMedium),
                        ),
                      ),
                      if (photo != null)
                        TextButton(
                          onPressed: () async {
                            await _forgetPhoto();
                            await app.ui.setProfilePhoto(null);
                          },
                          child: const Text('Remove photo'),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: StreamBuilder<List<Playlist>>(
            stream: app.db.watchPlaylists(),
            builder: (context, lists) {
              final counts = profileCounts(songs, lists.data?.length ?? 0);
              return Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      shape: () => MaterialShapes.cookie6Sided.toPath(),
                      icon: Icons.music_note_rounded,
                      value: thousands(counts.songs),
                      label: 'Songs',
                      onTap: () => openLibrary?.call(0),
                      container: theme.colorScheme.primaryContainer,
                      onContainer: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(
                      shape: () => MaterialShapes.flower.toPath(),
                      icon: Icons.favorite_rounded,
                      value: thousands(counts.favorites),
                      label: 'Favorites',
                      onTap: () => openCollection(context, 'Favorites', [for (final s in songs) if (s.favorite) s]),
                      container: theme.colorScheme.tertiaryContainer,
                      onContainer: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(
                      shape: () => MaterialShapes.clover4Leaf.toPath(),
                      icon: Icons.queue_music_rounded,
                      value: thousands(counts.playlists),
                      label: 'Playlists',
                      onTap: () => openLibrary?.call(3),
                      container: theme.colorScheme.secondaryContainer,
                      onContainer: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        CollapsibleSection(
          title: 'Library',
          icon: Icons.library_music_rounded,
          startOpen: true,
          children: [
            StreamBuilder<List<LibraryChat>>(
              stream: app.db.watchChats(),
              builder: (context, chats) => ListenableBuilder(
                listenable: app.mainChat,
                builder: (context, _) {
                  final all = chats.data ?? const <LibraryChat>[];
                  final main = all.where((c) => c.id == app.mainChat.value).firstOrNull;
                  return ListTile(
                    leading: const Icon(Icons.forum_rounded),
                    title: Text('${all.length} channel${all.length == 1 ? '' : 's'}'),
                    subtitle: Text(main == null ? 'No main chat chosen' : 'Main chat: ${main.title}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => pushPage(context, const ChannelsScreen()),
                  );
                },
              ),
            ),
            ListenableBuilder(
              listenable: Listenable.merge([app.tasks.live, app.tasks.remote]),
              builder: (context, _) => ListTile(
                leading: const Icon(Icons.task_alt_rounded),
                title: const Text('Tasks'),
                subtitle: Text(() {
                  final n = app.tasks.live.value.length + app.tasks.remote.value.values.fold(0, (a, l) => a + l.length);
                  return n == 0 ? 'Nothing running' : '$n running';
                }()),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => pushPage(context, const TasksScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded),
              title: const Text('Listening'),
              subtitle: const Text('Time listened, top songs and artists'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => pushPage(context, const StatsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.library_add_check_rounded),
              title: const Text('Duplicates'),
              subtitle: const Text('Find songs posted more than once and remove the extras'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => pushPage(context, const DuplicatesScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('Song info left'),
              subtitle: const Text('See which songs still lack info or a cover'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => pushPage(context, const MissingInfoScreen()),
            ),
          ],
        ),
        CollapsibleSection(
          title: 'Devices',
          icon: Icons.devices_rounded,
          startOpen: true,
          children: [
            ListenableBuilder(
              listenable: app.link.devices,
              builder: (context, _) {
                final devices = app.link.devices.value;
                return ListTile(
                  leading: const Icon(Icons.lan_rounded),
                  title: Text(devices.isEmpty ? 'No other device connected' : 'Connected to ${devices.map((d) => d.name).join(', ')}'),
                  subtitle: const Text('Sync and play on your other devices'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => pushPage(context, const ConnectionScreen()),
                );
              },
            ),
          ],
        ),
        CollapsibleSection(
          title: 'Storage',
          icon: Icons.storage_rounded,
          startOpen: true,
          children: [
            FutureBuilder<int>(
              future: app.db.cacheLimit(),
              builder: (context, limit) {
                final used = songs.fold<int>(0, (sum, s) => sum + s.cachedBytes);
                return ListTile(
                  leading: const Icon(Icons.download_done_rounded),
                  title: Text('${formatBytes(used)} saved on this device'),
                  subtitle: Text(limit.hasData ? 'Limit ${formatBytes(limit.data!)}' : ''),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_rounded),
              title: const Text('Clear cache'),
              subtitle: const Text('Keeps pinned songs and the current song'),
              onTap: () async {
                final ok = await confirm(
                  context,
                  'Clear the cache?',
                  "Clears offline songs; they download again when played. Pinned songs and the current one stay.",
                  'Clear',
                );
                if (ok) await app.cache.clear();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.shape,
    required this.icon,
    required this.value,
    required this.label,
    required this.container,
    required this.onContainer,
    this.onTap,
  });

  final VoidCallback? onTap;

  final Path Function() shape;
  final IconData icon;
  final String value, label;
  final Color container, onContainer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            ClipPath(
              clipper: _ShapeClipper(shape),
              child: Container(
                width: 52,
                height: 52,
                color: container,
                child: Icon(icon, color: onContainer),
              ),
            ),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      )
    );
  }
}

class _ShapeClipper extends CustomClipper<Path> {
  const _ShapeClipper(this.unit);
  final Path Function() unit;

  @override
  Path getClip(Size size) => unit().transform((Matrix4.identity()..scaleByDouble(size.width, size.height, 1, 1)).storage);

  @override
  bool shouldReclip(_ShapeClipper old) => false;
}
