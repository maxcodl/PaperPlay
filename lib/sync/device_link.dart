import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../library/db.dart';
import '../log.dart';
import '../playback/player.dart';
import 'lan.dart';
import 'library_sync.dart';

/// An address to try for another device.
class SavedAddress {
  const SavedAddress({required this.host, this.port = lanPort, this.label, this.deviceId});

  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
        host: j['host'] as String,
        port: j['port'] as int? ?? lanPort,
        label: j['label'] as String?,
        deviceId: j['deviceId'] as String?,
      );

  final String host;
  final int port;

  /// A name for it: the owner's, or the device's once it has connected.
  final String? label;

  /// The device last reached here, to avoid connecting to it twice.
  final String? deviceId;

  String get key => '$host:$port';

  Map<String, dynamic> toJson() => {'host': host, 'port': port, 'label': label, 'deviceId': deviceId};
}

/// Reads `192.168.1.5` or `192.168.1.5:47872`. Null if it isn't an address.
SavedAddress? parseAddress(String text, {String? label}) {
  final t = text.trim();
  final colon = t.lastIndexOf(':');
  final host = colon == -1 ? t : t.substring(0, colon);
  final port = colon == -1 ? lanPort : int.tryParse(t.substring(colon + 1));
  if (port == null || port < 1 || port > 65535) return null;
  if (!RegExp(r'^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$').hasMatch(host)) return null;
  return SavedAddress(host: host, port: port, label: label?.trim().isEmpty ?? true ? null : label!.trim());
}

/// Puts [incoming] first and removes anything it replaces, including any older
/// address of the same device: a restarted router gives a device a new address,
/// and the old one is never worth showing as a second device.
List<SavedAddress> rememberAddress(List<SavedAddress> saved, SavedAddress incoming) => [
      incoming,
      for (final s in saved)
        if (s.key != incoming.key && (incoming.deviceId == null || s.deviceId != incoming.deviceId)) s,
    ];

/// One address per device, keeping the first (newest). Addresses saved by older
/// versions can repeat a device.
List<SavedAddress> onePerDevice(List<SavedAddress> saved) {
  final seen = <String>{};
  return [
    for (final s in saved)
      if (s.deviceId == null || seen.add(s.deviceId!)) s,
  ];
}

/// How the last try at a saved address went.
enum AddressState { connected, trying, unreachable, refused }

/// Connects this device's library and player to the owner's other devices.
/// Everything but the song cache stays the same on all of them.
class DeviceLink with WidgetsBindingObserver {
  DeviceLink(
    this._db,
    this._player, {
    required this.onNewChats,
    required this.afterMerge,
    required this.saveCover,
    required this.onTasteChanged,
    this.onStatus,
  });

  /// What's happening, for the same line a scan reports on.
  final void Function(String?)? onStatus;

  /// Another device's running tasks arrived, or it left (an empty list).
  void Function(String peerId, String peerName, List<Map<String, dynamic>> runs)? onRemoteTasks;

  /// Which of these posts (chat, message) still exist in Telegram. Songs the other device
  /// lists are only taken if their post does, so deleted ones don't come back.
  Future<Set<(int, int)>> Function(List<(int, int)> posts)? postsExist;

  /// Another device asked this one to stop a kind of task.
  void Function(String kind)? onStopTask;

  /// This device's running tasks, sent to a device as it connects.
  List<Map<String, dynamic>> Function()? liveTasks;

  /// The extra bots' tokens here, and what to do with a device's. Sent to devices of the
  /// same owner over the encrypted link, so a bot added on one is added on all.
  Future<List<String>> Function()? botTokens;
  Future<void> Function(List<String> tokens)? onRemoteBots;

  /// The profile name and photo here, and what to do with another device's.
  Future<Map<String, dynamic>> Function()? profile;
  Future<void> Function(Map<String, dynamic> profile)? onRemoteProfile;

  Future<void> sendProfile() async {
    final data = await profile?.call();
    if (data != null) _hub?.broadcast({'t': 'profile', ...data});
  }

  Future<void> sendBots() async => _hub?.broadcast({'t': 'bots', 'tokens': await botTokens?.call() ?? const <String>[]});

  /// Whether this device has its own account logged in, told to the others, and what to do
  /// when another device asks to sign in through this one (a login link to approve).
  bool Function()? accountIn;
  void Function(Peer peer, String link)? onQrRequest;

  /// Which devices say they have an account logged in, by device id.
  final accounts = ValueNotifier<Map<String, bool>>(const {});

  /// Called on another device's request to log out everywhere.
  void Function()? onLogoutAll;

  void sendLogoutAll() => _hub?.broadcast({'t': 'accountLogout'});

  void sendAccount() => _hub?.broadcast({'t': 'account', 'in': accountIn?.call() ?? false});

  /// Asks [peerId] to approve this device's login link.
  void sendQr(String peerId, String link) {
    final peer = devices.value.where((p) => p.id == peerId).firstOrNull;
    if (peer != null) _hub?.send(peer, {'t': 'qr', 'link': link});
  }

  /// How far each device's clock is ahead of this one's, in milliseconds.
  final _offsets = <String, int>{};
  final _pings = <int, Completer<int>>{};
  var _pingId = 0;
  Timer? _clockTimer;

  /// Compares clocks with [peer]: a few quick round trips, keeping the fastest, since its
  /// midpoint is the most exact. Good to a few milliseconds on a home network.
  Future<void> _syncClock(Peer peer) async {
    var bestRtt = 1 << 30, bestOffset = 0;
    for (var i = 0; i < 8; i++) {
      final id = _pingId++;
      final answer = _pings[id] = Completer<int>();
      final t0 = DateTime.now().millisecondsSinceEpoch;
      _hub?.send(peer, {'t': 'ping', 'id': id});
      try {
        final t1 = await answer.future.timeout(const Duration(seconds: 2));
        final t2 = DateTime.now().millisecondsSinceEpoch;
        if (t2 - t0 < bestRtt) {
          bestRtt = t2 - t0;
          bestOffset = t1 - (t0 + (t2 - t0) ~/ 2);
        }
      } on TimeoutException {
        // A lost ping; the others still count.
      } finally {
        _pings.remove(id);
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    if (bestRtt < 1 << 30) {
      _offsets[peer.id] = bestOffset;
      logEvent('devices', 'Clock of ${peer.name}: ${bestOffset >= 0 ? 'ahead' : 'behind'} by ${bestOffset.abs()} ms (round trip $bestRtt ms)');
    }
  }

  /// Tells every connected device what is running here.
  void sendTasks(List<Map<String, dynamic>> runs) => _hub?.broadcast({'t': 'tasks', 'runs': runs});

  /// Asks the device with [peerId] to stop a kind of task.
  void stopRemoteTask(String peerId, String kind) {
    final peer = _hub?.peers.value.where((p) => p.id == peerId).firstOrNull;
    if (peer != null) _hub?.send(peer, {'t': 'taskStop', 'kind': kind});
  }

  final _firstMerge = Completer<void>();

  /// Finishes when a device's library has been merged, or after [timeout] if none
  /// answers, so a new device can take the library rather than read every channel.
  Future<void> firstMerge(Duration timeout) =>
      _firstMerge.future.timeout(timeout, onTimeout: () {});

  final AppDb _db;
  final PlayerController _player;
  final void Function(List<LibraryChat>) onNewChats;
  final Future<void> Function() afterMerge;

  /// Stores a cover chosen on another device.
  final Future<void> Function(Song song, List<int> bytes, int at) saveCover;

  /// Another device may have changed what mixes learn from.
  final Future<void> Function() onTasteChanged;

  String? _deviceId;
  Timer? _listenTimer;

  static const _deviceIdKey = 'device_id';
  static const _addressesKey = 'lan_addresses';
  static const _discoveryKey = 'lan_discovery';
  static const _requireKey = 'lan_require_pairing';
  static const _trustedKey = 'lan_trusted';
  static const _retryEvery = Duration(seconds: 15);
  static const _retryTimeout = Duration(seconds: 3);

  /// Far above any real cover; stops a bad file filling a message.
  static const _maxCoverBytes = 15 * 1024 * 1024;

  /// How far back each change announcement looks, in case one was missed.
  static const _overlap = Duration(seconds: 30);

  LanHub? _hub;
  String? _token;
  StreamSubscription<void>? _changes;
  Timer? _pushTimer, _retryTimer;
  var _lastPush = 0, _lastRowId = 0;
  var _merges = Future<void>.value();
  var _observing = false;

  /// Connected devices.
  final devices = ValueNotifier<List<Peer>>(const []);

  /// Addresses to try, newest first.
  final addresses = ValueNotifier<List<SavedAddress>>(const []);

  /// The last result for each address, by [SavedAddress.key].
  final states = ValueNotifier<Map<String, AddressState>>(const {});

  /// Whether this device announces itself and listens for others.
  final discovery = ValueNotifier<bool>(true);

  /// Whether only paired devices may link. Off by default: the bot token alone is enough.
  final requirePairing = ValueNotifier<bool>(false);

  /// Paired devices, id to name.
  final trusted = ValueNotifier<Map<String, String>>(const {});

  /// Devices with the right token waiting for a PIN.
  final pending = ValueNotifier<List<PendingPeer>>(const []);

  /// The PIN this device is showing, if any.
  final pairingWindow = ValueNotifier<PairingWindow?>(null);

  PairingWindow? openPairing() => _hub?.openPairing();
  void closePairing() => _hub?.closePairing();
  Future<bool> pairWith(PendingPeer p, String pin) async => await _hub?.pairWith(p, pin) ?? false;
  void revoke(String id) => _hub?.revoke(id);

  Future<void> setRequirePairing(bool on) async {
    if (on) _hub?.trustConnected();
    requirePairing.value = on;
    _hub?.requirePairing = on;
    await _db.setPref(_requireKey, '$on');
  }

  /// This device's name, as other devices see it.
  String deviceName = '';

  /// The port this device listens on.
  int? get port => _hub?.port;

  /// Starts linking devices that use [token]. Safe to call again.
  Future<void> start(String token) async {
    if (_token == token && _hub != null) return;
    await stop();
    _token = token;
    var id = await _db.pref(_deviceIdKey);
    if (id == null) {
      id = newUuid();
      await _db.setPref(_deviceIdKey, id);
    }
    deviceName = await _localName();
    await _setAddresses(onePerDevice(_decode(await _db.pref(_addressesKey))));
    discovery.value = await _db.pref(_discoveryKey) != 'false';
    final hub = LanHub(secret: token, deviceId: id, deviceName: deviceName)
      ..onConnected = _onConnected
      ..onDisconnected = _onDisconnected
      ..onMessage = _onMessage;
    requirePairing.value = await _db.pref(_requireKey) == 'true';
    hub.requirePairing = requirePairing.value;
    hub.trusted.value = _decodeTrusted(await _db.pref(_trustedKey));
    trusted.value = hub.trusted.value;
    hub.trusted.addListener(() {
      trusted.value = hub.trusted.value;
      unawaited(_db.setPref(_trustedKey, jsonEncode(hub.trusted.value)));
    });
    hub.pending.addListener(() => pending.value = hub.pending.value);
    hub.window.addListener(() => pairingWindow.value = hub.window.value);
    hub.peers.addListener(() {
      devices.value = hub.peers.value;
      _refreshStates();
    });
    _hub = hub;
    _player.sendToDevice = (deviceId, message) {
      final peer = hub.peers.value.where((p) => p.id == deviceId).firstOrNull;
      if (peer != null) hub.send(peer, message);
    };
    _player.onLocalState = (state) => hub.broadcast({'t': 'state', ...state});
    _player.sendToAll = hub.broadcast;
    _player.clockOffsetOf = (peerId) => _offsets[peerId] ?? 0;
    // Clocks drift apart slowly, so they're compared again every so often while playing together.
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_player.groupOn.value) return;
      for (final p in hub.peers.value) {
        unawaited(_syncClock(p));
      }
    });
    _player.groupOn.addListener(() {
      if (!_player.groupOn.value) return;
      for (final p in hub.peers.value) {
        unawaited(_syncClock(p));
      }
    });
    _deviceId = id;
    _player.onListenChanged = () {
      _listenTimer?.cancel();
      _listenTimer = Timer(const Duration(seconds: 20), () async {
        hub.broadcast({'t': 'listen', 'rows': await _db.listenRows(origin: id)});
      });
    };
    _changes = _db.syncableChanges.listen((_) {
      _pushTimer?.cancel();
      _pushTimer = Timer(const Duration(seconds: 2), () => unawaited(_pushChanges()));
    });
    try {
      await hub.start();
    } on SocketException catch (e) {
      debugPrint('Device link unavailable: ${e.message}');
      return;
    }
    hub.setDiscovery(discovery.value);
    _retryTimer = Timer.periodic(_retryEvery, (_) => unawaited(_trySaved()));
    unawaited(_trySaved());
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
  }

  Future<void> stop() async {
    _pushTimer?.cancel();
    _retryTimer?.cancel();
    await _changes?.cancel();
    _changes = null;
    _clockTimer?.cancel();
    _player.sendToAll = null;
    _player.sendToDevice = null;
    _player.onLocalState = null;
    await _hub?.stop();
    _hub = null;
    _token = null;
    devices.value = const [];
    pending.value = const [];
    pairingWindow.value = null;
  }

  /// A phone suspends apps in the background, so this tries at once on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_trySaved());
  }

  static Map<String, String> _decodeTrusted(String? json) {
    if (json == null) return const {};
    try {
      return {
        for (final e in (jsonDecode(json) as Map<String, dynamic>).entries) e.key: e.value as String,
      };
    } on Object {
      return const {};
    }
  }

  static List<SavedAddress> _decode(String? json) {
    if (json == null) return const [];
    try {
      return [
        for (final a in jsonDecode(json) as List) SavedAddress.fromJson(a as Map<String, dynamic>),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _setAddresses(List<SavedAddress> list) async {
    addresses.value = list;
    await _db.setPref(_addressesKey, jsonEncode(list.map((a) => a.toJson()).toList()));
  }

  /// Saves an address and tries it straight away.
  Future<void> addAddress(SavedAddress address) async {
    await _setAddresses(rememberAddress(addresses.value, address));
    await connectTo(address);
  }

  Future<void> removeAddress(SavedAddress address) async {
    await _setAddresses([
      for (final a in addresses.value)
        if (a.key != address.key) a,
    ]);
    states.value = {...states.value}..remove(address.key);
  }

  Future<void> setDiscovery(bool on) async {
    discovery.value = on;
    await _db.setPref(_discoveryKey, '$on');
    _hub?.setDiscovery(on);
  }

  /// Looks for devices at every address on this network. Returns how many it found.
  Future<int> scanNetwork() async => await _hub?.scanNetwork() ?? 0;

  Future<void> connectTo(SavedAddress a) async {
    final hub = _hub;
    if (hub == null) return;
    _setState(a, AddressState.trying);
    final failure = await hub.connect(a.host, a.port, timeout: _retryTimeout);
    if (failure == null) {
      _setState(a, AddressState.connected);
    } else {
      _setState(a, failure == ConnectFailure.refused ? AddressState.refused : AddressState.unreachable);
    }
  }

  void _setState(SavedAddress a, AddressState s) {
    states.value = {...states.value, a.key: s};
  }

  bool _isConnected(SavedAddress a) {
    final peers = _hub?.peers.value ?? const <Peer>[];
    return peers.any((p) => p.id == a.deviceId || (p.host == a.host && p.port == a.port));
  }

  /// Keeps what's shown true when a connection is lost or found another way.
  void _refreshStates() {
    final next = {...states.value};
    for (final a in addresses.value) {
      if (_isConnected(a)) {
        next[a.key] = AddressState.connected;
      } else if (next[a.key] == AddressState.connected) {
        next[a.key] = AddressState.unreachable;
      }
    }
    states.value = next;
  }

  Future<void> _trySaved() async {
    final own = {for (final a in await localAddresses().catchError((_) => <InternetAddress>[])) a.address};
    await Future.wait([
      for (final a in addresses.value)
        if (!_isConnected(a) && !own.contains(a.host)) connectTo(a),
    ]);
    await _findMovedDevices();
  }

  /// A known device that stopped answering has probably been given a new address,
  /// so this looks for it. Connecting updates its saved address.
  Future<void> _findMovedDevices() async {
    final missing = addresses.value.any((a) => a.deviceId != null && !_isConnected(a));
    final hub = _hub;
    final now = DateTime.now();
    if (!missing || hub == null || now.difference(_lastScan) < _scanEvery) return;
    _lastScan = now;
    logEvent('devices', 'Looking for a saved device that moved');
    await hub.scanNetwork();
  }

  static const _scanEvery = Duration(minutes: 10);
  var _lastScan = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<String> _localName() async {
    if (Platform.isAndroid) {
      try {
        final r = await Process.run('getprop', ['ro.product.model']);
        final model = (r.stdout as String).trim();
        if (model.isNotEmpty) return model;
      } on ProcessException {
        // Falls through to the generic name.
      }
      return 'Android phone';
    }
    return Platform.localHostname;
  }

  Future<void> _onConnected(Peer peer) async {
    final hub = _hub;
    if (hub == null) return;
    logEvent('devices', 'Connected to ${peer.name} at ${peer.host}');
    // Remembered so it can be found again if broadcast stops working.
    if (peer.port > 0) {
      await _setAddresses(
        rememberAddress(
          addresses.value,
          SavedAddress(host: peer.host, port: peer.port, label: peer.name, deviceId: peer.id),
        ),
      );
      _refreshStates();
    }
    unawaited(_syncClock(peer));
    hub.send(peer, {'t': 'state', ..._player.localState(withQueue: true)});
    hub.send(peer, {'t': 'sync', 'data': await librarySnapshot(_db)});
    hub.send(peer, {'t': 'listen', 'rows': await _db.listenRows()});
    hub.send(peer, {'t': 'tasks', 'runs': liveTasks?.call() ?? const []});
    hub.send(peer, {'t': 'bots', 'tokens': await botTokens?.call() ?? const <String>[]});
    hub.send(peer, {'t': 'account', 'in': accountIn?.call() ?? false});
    final mine = await profile?.call();
    if (mine != null) hub.send(peer, {'t': 'profile', ...mine});
  }

  void _onDisconnected(Peer peer) {
    accounts.value = {...accounts.value}..remove(peer.id);
    logEvent('devices', 'Lost connection to ${peer.name}');
    onRemoteTasks?.call(peer.id, peer.name, const []);
    unawaited(_player.onDeviceLeft(peer.id));
  }

  void _onMessage(Peer peer, Map<String, dynamic> m) {
    switch (m['t']) {
      case 'state':
        unawaited(_player.onDeviceState(peer.id, m));
      case 'cmd':
        // Which device sent it, for working out the time on its clock.
        unawaited(_player.onDeviceCommand({...m, 'from': peer.id}));
      case 'ping':
        _hub?.send(peer, {'t': 'pong', 'id': m['id'], 't1': DateTime.now().millisecondsSinceEpoch});
      case 'pong':
        _pings[m['id'] as int]?.complete(m['t1'] as int);
      case 'sync':
        // One at a time, in the order they arrived.
        _merges = _merges.then((_) => _merge(peer, m['data'] as Map<String, dynamic>));
      case 'listen':
        final self = _deviceId;
        if (self != null) unawaited(_db.mergeListen((m['rows'] as List).cast<Map<String, dynamic>>(), self: self));
      case 'tasks':
        onRemoteTasks?.call(peer.id, peer.name, [for (final r in m['runs'] as List) r as Map<String, dynamic>]);
      case 'profile':
        unawaited(onRemoteProfile?.call(m) ?? Future<void>.value());
      case 'bots':
        unawaited(onRemoteBots?.call([for (final t in m['tokens'] as List) t as String]) ?? Future<void>.value());
      case 'account':
        accounts.value = {...accounts.value, peer.id: m['in'] == true};
      case 'accountLogout':
        onLogoutAll?.call();
      case 'qr':
        // Only approved by a person, on this device, never automatically.
        if (accountIn?.call() == true && m['link'] is String) onQrRequest?.call(peer, m['link'] as String);
      case 'taskStop':
        onStopTask?.call(m['kind'] as String);
      case 'coverGet':
        unawaited(_sendCover(peer, m));
      case 'cover':
        _merges = _merges.then((_) => _receiveCover(m));
    }
  }

  Future<void> _merge(Peer peer, Map<String, dynamic> data) async {
    final songs = (data['songs'] as List).length;
    final firstTime = !_firstMerge.isCompleted;
    if (firstTime) onStatus?.call('Getting library from ${peer.name}: $songs songs');
    try {
      final result = await mergeSnapshot(_db, data, existing: postsExist);
      logEvent('sync', '${peer.name}: merged $songs songs, ${result.coversWanted.length} covers to fetch');
      if (result.newChats.isNotEmpty) onNewChats(result.newChats);
      if (result.changed) {
        await onTasteChanged();
        await afterMerge();
      }
      unawaited(_fetchCovers(peer, result.coversWanted));
    } catch (e) {
      logEvent('sync', 'Library merge failed: ${e.runtimeType}', level: LogLevel.error);
    } finally {
      if (firstTime) {
        onStatus?.call(null);
        if (!_firstMerge.isCompleted) _firstMerge.complete();
      }
    }
  }

  /// One at a time and paced: a new device can want the whole library's covers.
  Future<void> _fetchCovers(Peer peer, List<Song> songs) async {
    for (final s in songs) {
      _hub?.send(peer, {'t': 'coverGet', 'uid': s.uniqueId, 'chatId': s.chatId, 'messageId': s.messageId});
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<Song?> _songFor(Map<String, dynamic> m) async {
    final uid = m['uid'] as String?;
    return (uid == null ? null : await _db.songByUniqueId(uid)) ?? await _db.song(m['chatId'] as int, m['messageId'] as int);
  }

  Future<void> _sendCover(Peer peer, Map<String, dynamic> m) async {
    try {
      final song = await _songFor(m);
      final path = song?.coverPath;
      if (song == null || path == null) return;
      final file = File(path);
      if (await file.length() > _maxCoverBytes) return;
      _hub?.send(peer, {
        't': 'cover',
        'uid': song.uniqueId,
        'chatId': song.chatId,
        'messageId': song.messageId,
        'at': song.coverAt,
        'image': base64Encode(await file.readAsBytes()),
      });
    } on FileSystemException {
      // Its file is gone; the other device asks again at the next exchange.
    }
  }

  Future<void> _receiveCover(Map<String, dynamic> m) async {
    try {
      final song = await _songFor(m);
      final at = m['at'] as int;
      if (song == null) return;
      // A chosen cover, newest wins. An automatic one only fills a gap, and stays
      // automatic: it's saved with the sender's 0.
      final wanted = at > song.coverAt || (at == 0 && song.coverAt == 0 && song.coverPath == null);
      if (!wanted) return;
      final bytes = base64Decode(m['image'] as String);
      if (bytes.length > _maxCoverBytes) return;
      await saveCover(song, bytes, at);
    } catch (e) {
      debugPrint('Cover not saved: ${e.runtimeType}');
    }
  }

  Future<void> _pushChanges() async {
    final hub = _hub;
    if (hub == null || hub.peers.value.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // New songs carry no timestamp, so they're found by row number: only those are added to
    // what changed, instead of the whole library (and its lyrics) every time one appears.
    final top = (await _db.customSelect('SELECT COALESCE(MAX(rowid), 0) AS m FROM songs').getSingle()).read<int>('m');
    final since = _lastPush == 0 ? 0 : _lastPush - _overlap.inMilliseconds;
    final after = _lastRowId;
    _lastRowId = top;
    _lastPush = now;
    hub.broadcast({'t': 'sync', 'data': await librarySnapshot(_db, since: since, afterRowId: after)});
  }
}
