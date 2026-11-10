import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../sync/device_link.dart';
import '../sync/lan.dart';
import 'widgets.dart';

/// How this device connects to the owner's others: who's connected, addresses
/// to try, and what protects the connection.
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  List<String> _ownAddresses = const [];
  var _scanning = false;

  @override
  void initState() {
    super.initState();
    localAddresses().then((list) {
      if (mounted) setState(() => _ownAddresses = [for (final a in list) a.address]);
    }, onError: (_) {});
  }

  void _say(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    final result = await showDialog<SavedAddress>(context: context, builder: (_) => const _AddAddressDialog());
    if (result != null) await app.link.addAddress(result);
  }

  Future<void> _enterPin(PendingPeer p) async {
    final pin = await showDialog<String>(context: context, builder: (_) => _PinDialog(name: p.name));
    if (pin == null) return;
    final ok = await app.link.pairWith(p, pin);
    _say(ok ? 'Paired with ${p.name}.' : 'Wrong PIN, or the PIN expired.');
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final found = await app.link.scanNetwork();
      _say(found == 0 ? 'No new devices found on this network.' : 'Connected to $found new device${found == 1 ? '' : 's'}.');
    } on SocketException catch (e) {
      _say('Couldn\'t scan: ${e.message}');
    }
    if (mounted) setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final port = app.link.port ?? lanPort;
    return Scaffold(
      appBar: AppBar(title: const Text('Connection')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              app.link.devices,
              app.link.addresses,
              app.link.states,
              app.link.discovery,
              app.link.requirePairing,
              app.link.trusted,
              app.link.pending,
              app.link.pairingWindow,
            ]),
            builder: (context, _) => ListView(
              padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 16),
              children: [
                SectionCard(
                  title: 'Connected devices',
                  children: [
                    if (app.link.devices.value.isEmpty)
                      const ListTile(
                        leading: Icon(Icons.link_off_rounded),
                        title: Row(children: [Flexible(child: Text('None right now')), SizedBox(width: 4), InfoText("Paper Play has to be open on the other device, with the same bot.")]),
                      ),
                    for (final d in app.link.devices.value)
                      ListTile(
                        leading: const Icon(Icons.lock_rounded),
                        title: Text(d.name),
                        subtitle: Text('${d.host} · Encrypted'),
                      ),
                  ],
                ),
                SectionCard(
                  title: 'Pairing',
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.verified_user_outlined),
                      title: Row(children: [
                        const Flexible(child: Text('Only paired devices may link')),
                        const SizedBox(width: 4),
                        const InfoText("Without this, any device with your bot token links. With it, a new device also needs a PIN shown here. Turn it on on every device."),
                      ]),
                      value: app.link.requirePairing.value,
                      onChanged: app.link.setRequirePairing,
                    ),
                    for (final p in app.link.pending.value)
                      ListTile(
                        leading: const Icon(Icons.devices_other_rounded),
                        title: Text(p.name),
                        subtitle: Text('${p.host} · Waiting for a PIN'),
                        trailing: FilledButton.tonal(
                          onPressed: () => _enterPin(p),
                          child: const Text('Enter PIN'),
                        ),
                      ),
                    if (app.link.pairingWindow.value case final w?)
                      ListTile(
                        leading: const Icon(Icons.pin_rounded),
                        title: SelectableText(w.pin, style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 6)),
                        subtitle: const Text('Enter this on the other device. Expires in 2 minutes.'),
                        trailing: IconButton(
                          tooltip: 'Hide PIN',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: app.link.closePairing,
                        ),
                      )
                    else
                      ListTile(
                        leading: const Icon(Icons.pin_outlined),
                        title: const Text('Show a PIN'),
                        subtitle: const Text('For a waiting device to enter.'),
                        onTap: app.link.openPairing,
                      ),
                    for (final e in app.link.trusted.value.entries)
                      ListTile(
                        leading: const Icon(Icons.check_circle_outline_rounded),
                        title: Text(e.value),
                        subtitle: const Text('Paired'),
                        trailing: IconButton(
                          tooltip: 'Unpair',
                          icon: const Icon(Icons.link_off_rounded),
                          onPressed: () => app.link.revoke(e.key),
                        ),
                      ),
                  ],
                ),
                SectionCard(
                  title: 'Saved addresses',
                  children: [
                    if (app.link.addresses.value.isEmpty)
                      const ListTile(
                        title: Row(children: [Flexible(child: Text('No addresses yet')), SizedBox(width: 4), InfoText("Devices get saved here once they connect, and Paper Play keeps trying them.")]),
                      ),
                    for (final a in app.link.addresses.value) _AddressTile(address: a),
                    ListTile(
                      leading: const Icon(Icons.add_rounded),
                      title: const Text('Add address'),
                      onTap: _add,
                    ),
                  ],
                ),
                SectionCard(
                  title: 'Finding devices',
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.wifi_tethering_rounded),
                      title: Row(children: [Flexible(child: Text('Find devices automatically')), const SizedBox(width: 4), InfoText("Lets other devices find this one. Some routers block it.")]),
                      value: app.link.discovery.value,
                      onChanged: app.link.setDiscovery,
                    ),
                    ListTile(
                      leading: const Icon(Icons.radar_rounded),
                      title: const Text('Scan this network'),
                      subtitle: const Text(
                        'Tries every address once, for when a device moved and isn\'t announcing. '
                        'Network monitoring on shared networks may notice this.',
                      ),
                      trailing: _scanning
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : null,
                      onTap: _scanning ? null : _scan,
                    ),
                  ],
                ),
                SectionCard(
                  title: 'This device',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(app.link.deviceName.isEmpty ? 'Not started yet' : app.link.deviceName),
                      subtitle: const Text("Type one of these on your other device."),
                    ),
                    for (final ip in _ownAddresses)
                      ListTile(
                        leading: const Icon(Icons.router_outlined),
                        title: SelectableText('$ip:$port'),
                        trailing: IconButton(
                          tooltip: 'Copy address',
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: '$ip:$port'));
                            _say('Address copied.');
                          },
                        ),
                      ),
                  ],
                ),
                SectionCard(
                  title: 'Encryption',
                  children: [
                    const ListTile(
                      leading: Icon(Icons.verified_user_rounded),
                      title: Text('Always on'),
                      subtitle: Text(
                        'Every connection is encrypted and can\'t be turned off. Only devices with '
                        'your bot token can connect, and the token itself is never sent.',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.key_rounded),
                      title: const Text('X25519 key exchange, AES-256-GCM'),
                      subtitle: Text(
                        'New keys for each connection, so a recording can\'t be decrypted later. '
                        'Comparable to HTTPS, but it doesn\'t depend on a web certificate, which a '
                        'home address can\'t get.',
                        style: muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.address});
  final SavedAddress address;

  @override
  Widget build(BuildContext context) {
    final state = app.link.states.value[address.key];
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, String status, Color color) = switch (state) {
      AddressState.connected => (Icons.check_circle_rounded, 'Connected', scheme.primary),
      AddressState.trying => (Icons.sync_rounded, 'Trying…', scheme.onSurfaceVariant),
      AddressState.refused => (Icons.gpp_bad_rounded, 'Refused: another bot or not Paper Play', scheme.error),
      AddressState.unreachable => (Icons.cloud_off_rounded, 'Not reachable right now', scheme.onSurfaceVariant),
      null => (Icons.schedule_rounded, 'Not tried yet', scheme.onSurfaceVariant),
    };
    return ListTile(
      leading: Icon(icon, color: color, semanticLabel: status),
      title: Text(address.label ?? address.host, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${address.key} · $status', maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state != AddressState.connected)
            IconButton(
              tooltip: 'Connect',
              icon: const Icon(Icons.power_rounded),
              onPressed: state == AddressState.trying ? null : () => app.link.connectTo(address),
            ),
          IconButton(
            tooltip: 'Remove address',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => app.link.removeAddress(address),
          ),
        ],
      ),
    );
  }
}

class _PinDialog extends StatelessWidget {
  const _PinDialog({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return AlertDialog(
      title: Text('Pair with $name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(labelText: 'PIN shown on that device'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Pair')),
      ],
    );
  }
}

class _AddAddressDialog extends StatefulWidget {
  const _AddAddressDialog();

  @override
  State<_AddAddressDialog> createState() => _AddAddressDialogState();
}

class _AddAddressDialogState extends State<_AddAddressDialog> {
  final _address = TextEditingController();
  final _label = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = parseAddress(_address.text, label: _label.text);
    if (parsed == null) {
      setState(() => _error = 'Enter an address like 192.168.1.5');
      return;
    }
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _address,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'IP address or hostname',
                hintText: '192.168.1.5',
                helperText: 'Port $lanPort unless you add :port',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Name (optional)', hintText: 'Home PC'),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Add and connect')),
        ],
      );
}
