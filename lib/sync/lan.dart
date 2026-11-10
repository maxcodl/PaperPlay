import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

const lanDiscoveryPort = 47871;

/// Fixed, so an address saved on another device keeps working.
const lanPort = 47872;

const _protocol = 3;
const _pairWindow = Duration(minutes: 2);
const _maxBadProofs = 5;
const _announceEvery = Duration(seconds: 5);
const _pingEvery = Duration(seconds: 15);
const _peerTimeout = Duration(seconds: 40);
const _handshakeTimeout = Duration(seconds: 8);
const _scanTimeout = Duration(milliseconds: 400);
const _scanAtOnce = 32;
const _maxHello = 1024;
const _maxFrame = 64 * 1024 * 1024;
const _compressOver = 1024;

/// Why a connection attempt failed.
enum ConnectFailure { unreachable, refused }

/// Another of this owner's devices, connected and proven to hold the same bot token.
class Peer {
  Peer._(this.id, this.name, this.host, this.port, this._conn);
  final String id, name;

  /// Where it can be reached. [port] is what it listens on, not this connection's.
  final String host;
  final int port;
  final _Connection _conn;

  /// A PC: it takes the heavy background work when connected.
  bool get desktop => _conn.peerDesktop;
}

/// A device that proved it holds the same bot token but isn't trusted yet. Entering the PIN
/// another device shows ([LanHub.openPairing]) trusts it, or it shows ours.
class PendingPeer {
  PendingPeer._(this.id, this.name, this.host, this.port, this._conn, this._transcript);
  final String id, name, host;
  final int port;
  final _Connection _conn;
  final List<int> _transcript;
  Completer<bool>? _result;
  var _busy = false;
}

/// A PIN this device shows so another can pair with it.
class PairingWindow {
  const PairingWindow(this.pin, this.expires);
  final String pin;
  final DateTime expires;
}

/// Keeps an encrypted connection to each of this owner's other devices, found by
/// broadcast, by saved address, or by a scan. No server is involved.
///
/// The bot token is the shared secret and never goes on the wire. It proves both
/// ends are the same owner, while a new key exchange per connection means a
/// recording can't be decrypted later, even by someone who gets the token.
class LanHub {
  LanHub({
    required String secret,
    required this.deviceId,
    required this.deviceName,
    this.discoveryPort = lanDiscoveryPort,
    this.listenPort = lanPort,
  }) : _secret = utf8.encode(secret);

  final List<int> _secret;
  final String deviceId, deviceName;
  final int discoveryPort, listenPort;

  final peers = ValueNotifier<List<Peer>>(const []);

  /// Devices that reached this one with the right token but aren't trusted.
  final pending = ValueNotifier<List<PendingPeer>>(const []);

  /// Trusted devices (id to name). Only enforced when [requirePairing] is on.
  final trusted = ValueNotifier<Map<String, String>>(const {});

  /// When on, only trusted devices are linked; others wait in [pending] for a PIN.
  var requirePairing = false;

  /// Open while this device shows a PIN.
  final window = ValueNotifier<PairingWindow?>(null);
  Timer? _windowTimer;
  var _badProofs = 0;
  void Function(Peer)? onConnected;
  void Function(Peer)? onDisconnected;
  void Function(Peer, Map<String, dynamic>)? onMessage;

  ServerSocket? _server;
  RawDatagramSocket? _udp;
  Timer? _announcer;
  String _group = '';
  var _running = false;
  var _discovery = false;
  final _connecting = <String>{};

  int? get port => _server?.port;

  /// Starts accepting connections.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    final mac = await Hmac.sha256().calculateMac(
      utf8.encode('teleplayer-lan-group-v1'),
      secretKey: SecretKey(_secret),
    );
    // Lets strangers' devices ignore each other without revealing anything.
    _group = base64Url.encode(mac.bytes.sublist(0, 8));
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, listenPort);
    } on SocketException {
      // Taken, perhaps by another copy of the app. Saved addresses won't reach
      // this device, but it can still connect out and be found by broadcast.
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    }
    _server!.listen(
      (s) => unawaited(_handshake(s, s.remoteAddress.address, initiator: false)),
      onError: (_) {},
    );
  }

  /// Turns finding devices by broadcast on or off.
  void setDiscovery(bool on) {
    if (on == _discovery) return;
    _discovery = on;
    _announcer?.cancel();
    _announcer = null;
    if (on) {
      _announcer = Timer.periodic(_announceEvery, (_) => unawaited(_announce()));
      unawaited(_announce());
    } else {
      _udp?.close();
      _udp = null;
    }
  }

  Future<void> stop() async {
    _running = false;
    closePairing();
    setDiscovery(false);
    await _server?.close();
    _server = null;
    for (final p in [...peers.value]) {
      p._conn.close();
    }
    peers.value = const [];
    for (final p in [...pending.value]) {
      p._conn.close();
    }
    pending.value = const [];
  }

  void send(Peer peer, Map<String, dynamic> message) => peer._conn.send(message);

  void broadcast(Map<String, dynamic> message) {
    for (final p in peers.value) {
      p._conn.send(message);
    }
  }

  /// Reopens the listening socket if something closed it.
  Future<void> _ensureListening() async {
    if (_udp != null) return;
    try {
      final udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort, reuseAddress: true);
      _udp = udp;
      void drop() {
        if (identical(_udp, udp)) _udp = null;
      }

      udp.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          final d = udp.receive();
          if (d != null) _onAnnounce(d);
        },
        onError: (_) {
          drop();
          udp.close();
        },
        onDone: drop,
      );
    } on SocketException catch (e) {
      debugPrint('LAN discovery unavailable: ${e.message}');
    }
  }

  Future<void> _announce() async {
    await _ensureListening();
    final port = _server?.port;
    if (port == null || !_discovery) return;
    final data = utf8.encode(jsonEncode({'v': _protocol, 'g': _group, 'id': deviceId, 'port': port}));
    final List<InternetAddress> own;
    try {
      own = await localAddresses();
    } on SocketException {
      return; // Between networks; the next round tries again.
    }
    // The limited broadcast leaves through one adapter only, so each adapter's
    // own broadcast address is tried too.
    final targets = {
      InternetAddress('255.255.255.255'),
      for (final a in own)
        // chisle: assumes a /24, which covers home networks; Dart hides the mask.
        InternetAddress.fromRawAddress(Uint8List.fromList([a.rawAddress[0], a.rawAddress[1], a.rawAddress[2], 255])),
    };
    for (final t in targets) {
      await _sendOnce(data, t);
    }
  }

  /// Sends from a socket of its own. A failed send closes the socket it used,
  /// and some adapters always fail, such as mobile data on a phone. Sharing one
  /// socket would let them silently end discovery for good.
  Future<void> _sendOnce(List<int> data, InternetAddress to) async {
    RawDatagramSocket? s;
    try {
      s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      s.broadcastEnabled = true;
      s.listen((_) {}, onError: (_) {});
      s.send(data, to, discoveryPort);
    } on SocketException {
      // This adapter can't send it.
    } finally {
      s?.close();
    }
  }

  void _onAnnounce(Datagram d) {
    try {
      final m = jsonDecode(utf8.decode(d.data)) as Map<String, dynamic>;
      final id = m['id'] as String;
      if (m['v'] != _protocol || m['g'] != _group || id == deviceId) return;
      if (peers.value.any((p) => p.id == id) || !_connecting.add(id)) return;
      unawaited(connect(d.address.address, m['port'] as int).whenComplete(() => _connecting.remove(id)));
    } catch (_) {
      // Not one of ours.
    }
  }

  /// Connects to an address. Returns null on success, or why it failed.
  Future<ConnectFailure?> connect(
    String host,
    int port, {
    Duration timeout = _handshakeTimeout,
  }) async {
    final Socket socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
    } on SocketException {
      return ConnectFailure.unreachable;
    }
    return await _handshake(socket, host, initiator: true) ? null : ConnectFailure.refused;
  }

  /// Tries the fixed port on every address of this device's networks, for when
  /// broadcast is filtered and the other device's address has changed. Only
  /// Paper Play answers the handshake. Returns how many devices it connected.
  Future<int> scanNetwork() async {
    final own = await localAddresses();
    final mine = {for (final a in own) a.address};
    final hosts = <String>[
      for (final a in own)
        for (var i = 1; i < 255; i++)
          if (!mine.contains('${a.rawAddress[0]}.${a.rawAddress[1]}.${a.rawAddress[2]}.$i'))
            '${a.rawAddress[0]}.${a.rawAddress[1]}.${a.rawAddress[2]}.$i',
    ];
    final before = peers.value.length;
    var next = 0;
    Future<void> worker() async {
      while (next < hosts.length) {
        final host = hosts[next++];
        await connect(host, listenPort, timeout: _scanTimeout);
      }
    }

    await Future.wait(List.generate(_scanAtOnce, (_) => worker()));
    return peers.value.length - before;
  }

  /// Returns whether the other end proved it holds the same token.
  Future<bool> _handshake(Socket socket, String host, {required bool initiator}) async {
    final conn = _Connection(socket);
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
      final myNonce = SecretKeyData.random(length: 16).bytes;
      final x25519 = X25519();
      final myKeys = await x25519.newKeyPair();
      final myPublic = (await myKeys.extractPublicKey()).bytes;
      // Only what a stranger may see: the name and port travel encrypted below.
      conn.sendPlain(jsonEncode({
        'v': _protocol,
        'id': deviceId,
        'nonce': base64Encode(myNonce),
        'pub': base64Encode(myPublic),
      }));
      final hello = jsonDecode(await conn.readPlain().timeout(_handshakeTimeout)) as Map<String, dynamic>;
      if (hello['v'] != _protocol) throw const FormatException('Other version');
      final peerId = hello['id'] as String;
      if (peerId == deviceId) throw const FormatException('Connected to itself');
      final peerNonce = base64Decode(hello['nonce'] as String);
      final peerPublic = base64Decode(hello['pub'] as String);

      final shared = await x25519.sharedSecretKey(
        keyPair: myKeys,
        remotePublicKey: SimplePublicKey(peerPublic, type: KeyPairType.x25519),
      );
      final ikm = [..._secret, ...await shared.extractBytes()];
      // Order-independent, so both ends derive the same keys.
      final salt = _ordered(myNonce, peerNonce);
      final transcript = _ordered(myPublic, peerPublic);
      Future<SecretKey> keyFor(String sender) => Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
            secretKey: SecretKey(ikm),
            nonce: salt,
            // Binding the public keys stops anyone swapping them in transit, and
            // a key per sender stops a device's messages being reflected to it.
            info: [...utf8.encode('teleplayer-lan-v2:$sender:'), ...transcript],
          );

      conn.setKeys(await keyFor(deviceId), await keyFor(peerId));
      conn.send({
        't': 'auth',
        'name': deviceName,
        'port': _server?.port ?? 0,
        'admit': _admits(peerId),
        'desktop': Platform.isWindows || Platform.isLinux || Platform.isMacOS,
      });
      final auth = await conn.nextMessage().timeout(_handshakeTimeout);
      if (auth['t'] != 'auth') throw const FormatException('Bad handshake');
      conn.peerDesktop = auth['desktop'] == true;

      conn.initiatorId = initiator ? deviceId : peerId;
      final name = auth['name'] as String;
      final peerPort = auth['port'] as int;
      // Both ends must agree, or one would think it is linked while the other ignores it.
      if (!_admits(peerId) || auth['admit'] == false) {
        return _park(PendingPeer._(peerId, name, host, peerPort, conn, transcript));
      }
      return _admit(conn, peerId, name, host, peerPort);
    } catch (e) {
      // Wrong token, another program on this port, or a dropped connection.
      debugPrint('LAN handshake failed: ${e.runtimeType}');
      conn.close();
      return false;
    }
  }

  bool _admits(String id) => !requirePairing || trusted.value.containsKey(id);

  /// Links a connection whose other end is admitted.
  bool _admit(_Connection conn, String peerId, String name, String host, int port) {
    final existing = peers.value.where((p) => p.id == peerId).firstOrNull;
    if (existing != null) {
      // Both ends connected at once. Both keep the same one of the two.
      if (conn.initiatorId.compareTo(existing._conn.initiatorId) >= 0) {
        conn.close();
        return true;
      }
      peers.value = peers.value.where((p) => p != existing).toList();
      existing._conn.close();
    }
    final peer = Peer._(peerId, name, host, port, conn);
    peers.value = [...peers.value, peer];
    conn.listen(
      (m) {
        if (m['t'] != 'ping') onMessage?.call(peer, m);
      },
      onDone: () {
        if (!peers.value.contains(peer)) return;
        peers.value = peers.value.where((p) => p != peer).toList();
        onDisconnected?.call(peer);
      },
    );
    onConnected?.call(peer);
    return true;
  }

  /// Holds a connection until a PIN trusts it.
  bool _park(PendingPeer p) {
    final existing = pending.value.where((x) => x.id == p.id).firstOrNull;
    if (existing != null) {
      if (p._conn.initiatorId.compareTo(existing._conn.initiatorId) >= 0) {
        p._conn.close();
        return true;
      }
      pending.value = pending.value.where((x) => x != existing).toList();
      existing._conn.close();
    }
    pending.value = [...pending.value, p];
    p._conn.listen(
      (m) => unawaited(_onPending(p, m)),
      onDone: () => pending.value = pending.value.where((x) => x != p).toList(),
    );
    return true;
  }

  void _promote(PendingPeer p) {
    pending.value = pending.value.where((x) => x != p).toList();
    _admit(p._conn, p.id, p.name, p.host, p.port);
  }

  void _trust(String id, String name) => trusted.value = {...trusted.value, id: name};

  /// Proves knowing the PIN and seeing this very connection's keys, so a relay can't reuse it.
  Future<String> _proof(String pin, List<int> transcript, String sender) async {
    final mac = await Hmac.sha256().calculateMac(
      utf8.encode('teleplayer-pair-v1:${base64Encode(transcript)}:$sender'),
      secretKey: SecretKey(utf8.encode(pin)),
    );
    return base64Encode(mac.bytes);
  }

  Future<void> _onPending(PendingPeer p, Map<String, dynamic> m) async {
    switch (m['t']) {
      case 'pair':
        final w = window.value;
        if (w == null || p._busy) return p._conn.send({'t': 'denied'});
        p._busy = true;
        try {
          final expected = Mac(base64Decode(await _proof(w.pin, p._transcript, p.id)));
          final given = Mac(base64Decode(m['proof'] as String? ?? ''));
          if (window.value == null) return p._conn.send({'t': 'denied'});
          if (expected != given) {
            p._conn.send({'t': 'denied'});
            if (++_badProofs >= _maxBadProofs) closePairing();
            return;
          }
          closePairing();
          _trust(p.id, p.name);
          p._conn.send({'t': 'paired'});
          _promote(p);
        } finally {
          p._busy = false;
        }
      case 'paired':
        final r = p._result;
        if (r == null || r.isCompleted) return;
        _trust(p.id, p.name);
        _promote(p);
        r.complete(true);
      case 'denied':
        final r = p._result;
        if (r != null && !r.isCompleted) r.complete(false);
    }
  }

  /// Shows a PIN for two minutes. Another device enters it to pair with this one.
  PairingWindow openPairing() {
    final n = Random.secure().nextInt(1000000);
    final w = PairingWindow(n.toString().padLeft(6, '0'), DateTime.now().add(_pairWindow));
    _badProofs = 0;
    window.value = w;
    _windowTimer?.cancel();
    _windowTimer = Timer(_pairWindow, closePairing);
    return w;
  }

  void closePairing() {
    _windowTimer?.cancel();
    window.value = null;
  }

  /// Pairs with a waiting device using the PIN it shows. Returns whether it was accepted.
  Future<bool> pairWith(PendingPeer p, String pin) async {
    if (!pending.value.contains(p) || p._result != null) return false;
    final result = p._result = Completer<bool>();
    p._conn.send({'t': 'pair', 'proof': await _proof(pin.trim(), p._transcript, deviceId)});
    final ok = await result.future.timeout(_handshakeTimeout, onTimeout: () => false);
    p._result = null;
    return ok;
  }

  /// Trusts everyone connected now, so turning pairing on doesn't unlink them.
  void trustConnected() {
    for (final p in peers.value) {
      _trust(p.id, p.name);
    }
  }

  /// Stops trusting a device and drops its connection.
  void revoke(String id) {
    trusted.value = {...trusted.value}..remove(id);
    for (final p in peers.value.where((p) => p.id == id).toList()) {
      p._conn.close();
    }
  }

  static List<int> _ordered(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i] < b[i] ? [...a, ...b] : [...b, ...a];
    }
    return [...a, ...b];
  }
}

/// This device's IPv4 addresses on its networks.
Future<List<InternetAddress>> localAddresses() async => [
      for (final nic in await NetworkInterface.list(type: InternetAddressType.IPv4)) ...nic.addresses,
    ];

/// Framed, encrypted messages over one socket. Each frame is a 4-byte length and
/// a nonce, ciphertext and tag. Handshake frames are plain and size-limited.
class _Connection {
  _Connection(this._socket) {
    _socket.listen(_onData, onError: (_) => close(), onDone: close, cancelOnError: true);
  }

  final Socket _socket;

  /// Whether the other end is a PC (Windows, Linux or macOS), as it said in its handshake.
  var peerDesktop = false;
  final _aes = AesGcm.with256bits();
  var _buf = Uint8List(0);
  SecretKey? _sendKey, _recvKey;
  String initiatorId = '';

  Completer<String>? _plainWaiter;
  final _plainFrames = <String>[];
  // Held until a handler is set, so nothing sent right after the handshake is lost.
  final _pending = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? _messageWaiter;
  void Function(Map<String, dynamic>)? _handler;
  void Function()? _onDone;
  var _queue = Future<void>.value();
  var _sendQueue = Future<void>.value();
  Timer? _pinger, _watchdog;
  var _closed = false;
  var _helloRead = false;

  void setKeys(SecretKey send, SecretKey recv) {
    _sendKey = send;
    _recvKey = recv;
    _pump();
  }

  Future<Map<String, dynamic>> nextMessage() {
    if (_pending.isNotEmpty) return Future.value(_pending.removeAt(0));
    if (_closed) return Future.error(const SocketException('Closed'));
    return (_messageWaiter = Completer<Map<String, dynamic>>()).future;
  }

  void listen(void Function(Map<String, dynamic>) handler, {required void Function() onDone}) {
    _handler = handler;
    _onDone = onDone;
    _pending.forEach(handler);
    _pending.clear();
    if (_closed) return onDone();
    _pinger?.cancel();
    _pinger = Timer.periodic(_pingEvery, (_) => send({'t': 'ping'}));
    _feedWatchdog();
  }

  void _feedWatchdog() {
    if (_handler == null) return;
    _watchdog?.cancel();
    _watchdog = Timer(_peerTimeout, close);
  }

  void sendPlain(String text) {
    final data = utf8.encode(text);
    _socket.add(_lengthPrefix(data.length));
    _socket.add(data);
  }

  Future<String> readPlain() {
    if (_plainFrames.isNotEmpty) return Future.value(_plainFrames.removeAt(0));
    if (_closed) return Future.error(const SocketException('Closed'));
    return (_plainWaiter = Completer<String>()).future;
  }

  /// Queues [message]; order is kept even though encrypting is asynchronous.
  void send(Map<String, dynamic> message) {
    if (_closed) return;
    _sendQueue = _sendQueue.then((_) async {
      if (_closed) return;
      final json = utf8.encode(jsonEncode(message));
      final compress = json.length > _compressOver;
      final body = compress ? gzip.encode(json) : json;
      final box = await _aes.encrypt(
        [compress ? 1 : 0, ...body],
        secretKey: _sendKey!,
      );
      final frame = box.concatenation();
      _socket.add(_lengthPrefix(frame.length));
      _socket.add(frame);
    }).catchError((Object _) {
      close();
    });
  }

  static Uint8List _lengthPrefix(int n) =>
      (ByteData(4)..setUint32(0, n)).buffer.asUint8List();

  void _onData(Uint8List chunk) {
    _feedWatchdog();
    _buf = (BytesBuilder(copy: false)
          ..add(_buf)
          ..add(chunk))
        .takeBytes();
    _pump();
  }

  void _pump() {
    while (_buf.length >= 4 && !_closed) {
      final n = ByteData.sublistView(_buf).getUint32(0);
      final limit = _recvKey == null ? _maxHello : _maxFrame;
      if (n > limit) return close();
      if (_buf.length < 4 + n) return;
      // The peer's auth frame can arrive before our keys are ready: hold it.
      if (_recvKey == null && _helloRead) return;
      final frame = Uint8List.sublistView(_buf, 4, 4 + n);
      _buf = Uint8List.sublistView(_buf, 4 + n);
      if (_recvKey == null) {
        _helloRead = true;
        final text = utf8.decode(frame, allowMalformed: true);
        final waiter = _plainWaiter;
        if (waiter != null) {
          _plainWaiter = null;
          waiter.complete(text);
        } else {
          _plainFrames.add(text);
        }
      } else {
        final copy = Uint8List.fromList(frame);
        _queue = _queue.then((_) => _decrypt(copy));
      }
    }
  }

  Future<void> _decrypt(Uint8List frame) async {
    if (_closed) return;
    try {
      final box = SecretBox.fromConcatenation(frame, nonceLength: 12, macLength: 16);
      final plain = await _aes.decrypt(box, secretKey: _recvKey!);
      final body = plain.sublist(1);
      final json = plain.first == 1 ? gzip.decode(body) : body;
      final message = jsonDecode(utf8.decode(json)) as Map<String, dynamic>;
      final waiter = _messageWaiter;
      if (waiter != null) {
        _messageWaiter = null;
        waiter.complete(message);
      } else if (_handler != null) {
        _handler!(message);
      } else {
        _pending.add(message);
      }
    } catch (_) {
      // Wrong key or tampered with.
      close();
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _pinger?.cancel();
    _watchdog?.cancel();
    _plainWaiter?.completeError(const SocketException('Closed'));
    _plainWaiter = null;
    _messageWaiter?.completeError(const SocketException('Closed'));
    _messageWaiter = null;
    _socket.destroy();
    _onDone?.call();
  }
}
