import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../playback/audio_outputs.dart';
import '../playback/player.dart';
import 'connection.dart';

/// Opens the list of places the music can play. Lit while another device is the output.
class DeviceButton extends StatelessWidget {
  const DeviceButton({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: app.player.target,
        builder: (context, target, _) => IconButton(
          tooltip: target == null ? 'Choose where to play' : 'Playing on ${_nameOf(target)}',
          isSelected: target != null,
          icon: const Icon(Icons.devices_rounded),
          selectedIcon: const Icon(Icons.speaker_group_rounded),
          onPressed: () => showDevices(context),
        ),
      );
}

String _nameOf(String id) =>
    app.link.devices.value.where((d) => d.id == id).firstOrNull?.name ?? 'another device';

/// The name of the device playing, when it isn't this one.
class PlayingOnLabel extends StatelessWidget {
  const PlayingOnLabel({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: app.player.target,
        builder: (context, target, _) => target == null
            ? const SizedBox.shrink()
            : Text(
                'Playing on ${_nameOf(target)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
      );
}

Future<void> showDevices(BuildContext context) {
  final player = app.player;
  // Following a device that's already playing doesn't move or interrupt it.
  final playing = defaultOutput(player.target.value, player.player.playing, player.remoteStates.value);
  if (playing != player.target.value) player.selectOutput(playing);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: 520,
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (sheet) => const SafeArea(child: _DeviceSheet()),
  );
}

IconData _iconFor(OutputKind? kind) => switch (kind) {
      OutputKind.bluetooth => Icons.headphones_rounded,
      OutputKind.wired => Icons.headset_rounded,
      OutputKind.usb => Icons.usb_rounded,
      OutputKind.speaker => Icons.speaker_rounded,
      OutputKind.other => Icons.volume_up_rounded,
      null => _thisDeviceIcon,
    };

IconData get _thisDeviceIcon => Platform.isAndroid ? Icons.smartphone_rounded : Icons.computer_rounded;

String get _thisDeviceName => Platform.isAndroid ? 'This phone' : 'This PC';

class _RemoteVolume extends StatelessWidget {
  const _RemoteVolume();

  @override
  Widget build(BuildContext context) => StreamBuilder<double>(
        stream: app.player.out.volumeStream,
        initialData: app.player.out.volume,
        builder: (context, snap) {
          final v = (snap.data ?? 1).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: v == 0 ? 'Unmute' : 'Mute',
                  icon: Icon(v == 0 ? Icons.volume_off_rounded : v < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                  onPressed: () => app.player.out.setVolume(v == 0 ? 1 : 0),
                ),
                Expanded(child: Slider(value: v, onChanged: app.player.out.setVolume)),
              ],
            ),
          );
        },
      );
}

class _DeviceSheet extends StatelessWidget {
  const _DeviceSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: Listenable.merge([
        app.link.devices,
        app.player.target,
        app.player.groupOn,
        app.player.remoteStates,
        app.player.current,
        app.sound.current,
        app.sound.available,
      ]),
      builder: (context, _) {
        final devices = app.link.devices.value;
        final target = app.player.target.value;
        final sound = app.sound.current.value;
        final choices = app.sound.available.value;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text('Play on', style: theme.textTheme.titleLarge),
            ),
            _CurrentCard(target: target, sound: sound),
            // The volume of the other device, since this phone's buttons only set its own.
            if (target != null) const _RemoteVolume(),
            if (target != null)
              _Row(
                icon: _thisDeviceIcon,
                title: _thisDeviceName,
                subtitle: sound?.name,
                onTap: () {
                  app.player.selectOutput(null);
                  Navigator.pop(context);
                },
              ),
            for (final d in devices)
              if (d.id != target)
                _Row(
                  icon: Icons.speaker_group_rounded,
                  title: d.name,
                  subtitle: _describe(app.player.remoteStates.value[d.id]),
                  onTap: () {
                    app.player.selectOutput(d.id);
                    Navigator.pop(context);
                  },
                ),
            if (target == null && devices.isNotEmpty)
              SwitchListTile(
                secondary: const Icon(Icons.surround_sound_rounded),
                title: const Text('Play on all devices'),
                subtitle: const Text('This device leads; every connected device plays the same song in step'),
                value: app.player.groupOn.value,
                onChanged: app.player.setGroup,
              ),
            if (target == null && choices.length > 1) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: Text('Sound output', style: theme.textTheme.titleSmall),
              ),
              for (final c in choices)
                _Row(
                  icon: _iconFor(c.kind),
                  title: c.name,
                  selected: c.id == sound?.id,
                  onTap: () => app.sound.select(c),
                ),
            ],
            if (devices.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: Text(
                  "No other devices found. Open Paper Play on another device on this Wi-Fi, with the same bot.",
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _BigButton(
                      icon: Icons.settings_ethernet_rounded,
                      label: 'Connection',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (_) => const ConnectionScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Platform.isAndroid
                        ? _BigButton(
                            icon: Icons.bluetooth_rounded,
                            label: 'Bluetooth',
                            active: sound?.kind == OutputKind.bluetooth,
                            onTap: app.sound.openBluetoothSettings,
                          )
                        : _BigButton(
                            icon: Icons.tune_rounded,
                            label: 'Sound settings',
                            onTap: () => launchUrl(Uri.parse('ms-settings:sound')),
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String? _describe(RemoteState? s) {
    final title = s?.title;
    if (title == null) return s?.outputName;
    return '${s!.playing ? 'Playing' : 'Paused'}: $title';
  }
}

/// Where the music is coming out right now, and what's playing there.
class _CurrentCard extends StatelessWidget {
  const _CurrentCard({required this.target, required this.sound});
  final String? target;
  final SoundOutput? sound;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final song = app.player.current.value;
    final remote = target == null ? null : app.player.remoteStates.value[target];
    final String title;
    final String? route;
    final IconData icon;
    if (target != null) {
      title = _nameOf(target!);
      route = remote?.outputName;
      icon = Icons.speaker_group_rounded;
    } else if (sound != null && sound!.kind != OutputKind.speaker) {
      title = sound!.name;
      route = _thisDeviceName;
      icon = _iconFor(sound!.kind);
    } else {
      title = _thisDeviceName;
      route = sound?.name == _thisDeviceName ? null : sound?.name;
      icon = _thisDeviceIcon;
    }
    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge),
                if (route != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    route,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                if (song != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.graphic_eq_rounded, size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${song.title} – ${song.artist}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 40, color: scheme.primary),
        ],
      ),
    );
    if (!Platform.isAndroid || target != null) return card;
    // Android chooses the route itself, so this opens its own switcher.
    return Semantics(
      button: true,
      label: 'Change sound output',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          app.sound.openSystemSwitcher();
        },
        child: card,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, this.subtitle, this.selected = false, required this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: Icon(icon),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: selected ? const Icon(Icons.check_rounded) : null,
        selected: selected,
        onTap: onTap,
      );
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(label, style: theme.textTheme.labelMedium?.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
