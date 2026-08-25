import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mesh_device.dart';

enum HazardType { explosion, structuralCollapse, scream, gunshot, flood, crash, gas }

class MeshService extends ChangeNotifier {
  MeshService() { _loadIdentity(); }

  static const _port = 6000;
  static const _interval = Duration(seconds: 2);

  RawDatagramSocket? _socket;
  Timer? _discoveryTimer;
  Timer? _cleanupTimer;
  Timer? _digestTimer;
  Timer? _ghostTimer;

  // Track each peer's last known IP for direct unicast
  final Map<String, String> _peerIps = {};

  String _deviceId = '';
  String _deviceName = 'RescueMesh User';
  MeshStatus _myStatus = MeshStatus.safe;
  MeshRole _myRole = MeshRole.survivor;
  bool _meshActive = false;
  MeshLocation? _myLocation;

  String get deviceId => _deviceId;
  String get deviceName => _deviceName;
  MeshStatus get myStatus => _myStatus;
  MeshRole get myRole => _myRole;
  bool get meshActive => _meshActive;

  final List<MeshDevice> _devices = [];
  List<MeshDevice> get devices => List.unmodifiable(_devices);

  // Ghost Protocol — devices that went silent but we still track
  final List<MeshDevice> _ghosts = [];
  List<MeshDevice> get ghosts => List.unmodifiable(_ghosts);

  final List<MeshMessage> _messages = [];
  List<MeshMessage> get messages => List.unmodifiable(_messages);

  final _msg = StreamController<MeshMessage>.broadcast();
  Stream<MeshMessage> get onMessage => _msg.stream;

  // Spectral Relay
  final Map<String, MeshMessage> _relayStore = {};
  final Set<String> _seen = {};
  int _relayCount = 0;
  int get relayCount => _relayCount;

  // Silent Guardian
  bool _guardianActive = false;
  bool get guardianActive => _guardianActive;

  final List<HazardEvent> _hazards = [];
  List<HazardEvent> get hazards => List.unmodifiable(_hazards);

  // SOS Flashlight
  bool _flashlightActive = false;
  bool get flashlightActive => _flashlightActive;
  Timer? _flashlightTimer;

  // ─── IDENTITY ─────────────────────────────────────────────────

  Future<void> _loadIdentity() async {
    try {
      final p = await SharedPreferences.getInstance();
      _deviceName = p.getString('mesh_device_name') ?? 'RescueMesh User';
      final r = p.getString('mesh_device_role') ?? MeshRole.survivor.name;
      _myRole = MeshRole.values.byName(r);
      // Reuse the identity across launches. A fresh random ID per launch
      // made this device look brand-new to peers after every restart,
      // orphaning its Ghost Protocol records and relay-store entries, and
      // the 1-in-10000 random space risked two devices colliding on the
      // same ID (which breaks presence dedup for both). Timestamp entropy
      // keeps first-run collisions practically impossible.
      final saved = p.getString('mesh_device_id');
      if (saved != null && saved.isNotEmpty) {
        _deviceId = saved;
      } else {
        _deviceId =
            'N${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_${Random().nextInt(9999)}';
        await p.setString('mesh_device_id', _deviceId);
      }
    } catch (_) {}
  }

  Future<void> setDeviceName(String n) async {
    _deviceName = n.trim().isEmpty ? 'RescueMesh User' : n.trim();
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('mesh_device_name', _deviceName);
    _broadcast();
  }

  Future<void> setRole(MeshRole r) async {
    _myRole = r;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('mesh_device_role', r.name);
    _broadcast();
  }

  // ─── ACTIVATION ───────────────────────────────────────────────

  Future<String> activateMesh() async {
    if (_meshActive) return 'Already active';
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
      _socket!.broadcastEnabled = true;
      _socket!.readEventsEnabled = true;
      _socket!.listen(_onData);
      _meshActive = true;
      _discoveryTimer = Timer.periodic(_interval, (_) => _broadcast());
      _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkHealth());
      _digestTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sendDigest());
      _ghostTimer = Timer.periodic(const Duration(seconds: 10), (_) => _purgeOldGhosts());
      _broadcast();
      notifyListeners();
      return 'Mesh active';
    } catch (e) {
      _meshActive = false; notifyListeners();
      return 'Error: $e';
    }
  }

  Future<void> deactivateMesh() async {
    _meshActive = false;
    _discoveryTimer?.cancel();
    _cleanupTimer?.cancel();
    _digestTimer?.cancel();
    _ghostTimer?.cancel();
    _socket?.close();
    _socket = null;
    _devices.clear();
    _ghosts.clear();
    _relayStore.clear();
    _seen.clear();
    _relayCount = 0;
    notifyListeners();
  }

  // ─── BROADCAST ─────────────────────────────────────────────────

  void _broadcast() {
    if (!_meshActive || _socket == null) return;
    final data = _encode({
      'type': 'p',
      'id': _deviceId,
      'name': _deviceName,
      'status': _myStatus.name,
      'role': _myRole.name,
      if (_myLocation != null) ...{
        'lat': _myLocation!.latitude,
        'lng': _myLocation!.longitude,
      },
    });
    _send(data);
  }

  void _send(List<int> p, {bool unicastPeers = false}) {
    // Always broadcast to common subnets
    for (final a in [_bcast(), '255.255.255.255', '192.168.43.255', '192.168.137.255']) {
      try { _socket!.send(p, InternetAddress(a), _port); } catch (_) {}
    }
    // Also unicast to each known peer directly if requested
    if (unicastPeers) {
      for (final ip in _peerIps.values) {
        try { _socket!.send(p, InternetAddress(ip), _port); } catch (_) {}
      }
    }
  }

  String _bcast() {
    final ip = _socket?.address.address ?? '';
    final parts = ip.split('.');
    if (parts.length == 4) return '${parts[0]}.${parts[1]}.${parts[2]}.255';
    return '255.255.255.255';
  }

  List<int> _encode(Map<String, dynamic> d) => utf8.encode(jsonEncode(d));

  // ─── GHOST PROTOCOL ───────────────────────────────────────────

  /// Devices track heartbeats. If a peer misses pings for 8+ seconds, 
  /// it becomes a ghost — persists in the mesh with last-known state.
  final Map<String, DateTime> _heartbeats = {};

  void _checkHealth() {
    final now = DateTime.now();

    // Check for devices that went silent
    for (var i = _devices.length - 1; i >= 0; i--) {
      final d = _devices[i];
      final lastBeat = _heartbeats[d.id] ?? d.lastSeen;
      if (lastBeat == null) continue;

      final silent = now.difference(lastBeat).inSeconds;
      if (silent > 8 && d.goneSilentAt == null) {
        // Ghost Protocol activated
        final ghost = d.copyWith(
          goneSilentAt: now,
          status: MeshStatus.critical,
        );
        _devices[i] = ghost;
        _ghosts.add(ghost);

        _addSys('⚠️ GHOST: ${d.name} went silent');
        _addSys('Last known: ${d.role.label}, ${d.status.label}');

        // Broadcast ghost alert to mesh
        _send(_encode({
          'type': 'ghost',
          'id': d.id,
          'name': d.name,
          'role': d.role.name,
          'goneSilentAt': now.toIso8601String(),
        }));

        notifyListeners();
      } else if (silent > 30) {
        // Remove entirely after 30s
        _devices.removeAt(i);
        _heartbeats.remove(d.id);
        notifyListeners();
      }
    }
  }

  void _onGhost(Map<String, dynamic> j) {
    final id = j['id'] as String? ?? '';
    final name = j['name'] as String? ?? 'Unknown';
    final role = MeshRole.values.byName((j['role'] as String?) ?? 'survivor');
    final goneAt = DateTime.tryParse(j['goneSilentAt'] as String? ?? '') ?? DateTime.now();

    // Check if we already have this ghost
    if (_ghosts.any((g) => g.id == id)) return;

    final ghost = MeshDevice(
      id: id, name: name,
      status: MeshStatus.critical,
      location: null, role: role,
      goneSilentAt: goneAt,
    );
    _ghosts.add(ghost);
    _addSys('⚠️ GHOST ALERT: $name ($role.label) stopped responding');
    _addSys('Last known in mesh — check their area');
    notifyListeners();
  }

  void _purgeOldGhosts() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    _ghosts.removeWhere((g) => g.goneSilentAt!.isBefore(cutoff));
  }

  // ─── SPECTRAL RELAY ───────────────────────────────────────────

  void _sendDigest() {
    if (!_meshActive || _socket == null || _relayStore.isEmpty) return;
    final ids = _relayStore.keys.take(100).toList();
    _send(_encode({'type': 'digest', 'id': _deviceId, 'messageIds': ids}));
  }

  void _handleDigest(Map<String, dynamic> json) {
    final ids = (json['messageIds'] as List?)?.cast<String>() ?? [];
    final missing = ids.where((id) => !_seen.contains(id)).toList();
    if (missing.isNotEmpty) {
      _send(_encode({'type': 'request', 'id': _deviceId, 'messageIds': missing}));
    }
  }

  void _handleRequest(Map<String, dynamic> json, InternetAddress from) {
    final ids = (json['messageIds'] as List?)?.cast<String>() ?? [];
    for (final id in ids) {
      final m = _relayStore[id];
      if (m != null) {
        _sendTo(from, _encode({
          'type': 'relay', 'id': _deviceId, 'originId': m.fromDeviceId,
          'messageId': m.id, 'msgType': m.type.name, 'payload': m.payload,
          'timestamp': m.timestamp.toIso8601String(), 'ttl': 10, 'hops': 0,
        }));
      }
    }
  }

  void _handleRelay(Map<String, dynamic> json, InternetAddress from) {
    final msgId = json['messageId'] as String? ?? '';
    if (_seen.contains(msgId)) return;
    final ttl = (json['ttl'] as int?) ?? 10;
    if (ttl <= 0) return;

    final msg = MeshMessage(
      id: msgId,
      type: MeshMessageType.values.byName((json['msgType'] as String?) ?? 'statusUpdate'),
      payload: json['payload'] as String? ?? '',
      fromDeviceId: json['originId'] as String? ?? 'unknown',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );

    _seen.add(msgId); _relayStore[msgId] = msg; _relayCount = _relayStore.length;
    _addMessage(msg);

    final next = _encode({
      'type': 'relay', 'id': _deviceId, 'originId': msg.fromDeviceId,
      'messageId': msgId, 'msgType': msg.type.name, 'payload': msg.payload,
      'timestamp': msg.timestamp.toIso8601String(), 'ttl': ttl - 1, 'hops': (json['hops'] as int?)! + 1,
    });
    for (final a in [_bcast(), '255.255.255.255']) {
      final addr = InternetAddress(a);
      if (addr.address != from.address) {
        try { _socket?.send(next, addr, _port); } catch (_) {}
      }
    }
  }

  void _sendTo(InternetAddress to, List<int> p) {
    try { _socket?.send(p, to, _port); } catch (_) {}
  }

  // ─── RECEIVE ──────────────────────────────────────────────────

  void _onData(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final d = _socket?.receive();
    if (d == null || d.address.address == _socket?.address.address) return;
    try {
      final j = jsonDecode(utf8.decode(d.data)) as Map<String, dynamic>;
      final fromId = j['id'] as String? ?? '';
      if (fromId.isNotEmpty) _peerIps[fromId] = d.address.address;
      switch (j['type'] as String?) {
        case 'p': return _onPresence(j);
        case 'sos': return _onSOS(j);
        case 'status': return _onStatus(j);
        case 'digest': return _handleDigest(j);
        case 'request': return _handleRequest(j, d.address);
        case 'relay': return _handleRelay(j, d.address);
        case 'ghost': return _onGhost(j);
        case 'hazard': return _onHazard(j);
        case 'loc': return _onLocation(j);
      }
    } catch (_) {}
  }

  void _onPresence(Map<String, dynamic> j) {
    final id = j['id'] as String? ?? '';
    if (id == _deviceId) return;
    _heartbeats[id] = DateTime.now();
    final name = j['name'] as String? ?? 'Unknown';
    final s = MeshStatus.values.byName((j['status'] as String?) ?? 'safe');
    final r = MeshRole.values.byName((j['role'] as String?) ?? 'survivor');
    final idx = _devices.indexWhere((d) => d.id == id);
    // Parse GPS from presence if available
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    final loc = (lat != null && lng != null)
        ? MeshLocation(latitude: lat, longitude: lng)
        : (idx >= 0 ? _devices[idx].location : null);
    final dev = MeshDevice(id: id, name: name, status: s, location: loc, role: r, lastSeen: DateTime.now());
    if (idx >= 0) {
      // If device was ghosted but came back, un-ghost
      if (_devices[idx].goneSilentAt != null) {
        _ghosts.removeWhere((g) => g.id == id);
        _addSys('$name is back online');
      }
      _devices[idx] = dev;
    } else {
      _devices.add(dev);
      _addSys('$name connected ($_relayCount relay messages)');
    }
    notifyListeners();
  }

  void _onSOS(Map<String, dynamic> j) {
    final id = j['id'] as String? ?? '';
    final payload = j['payload'] as String? ?? 'EMERGENCY!';
    final name = _devices.where((d) => d.id == id).firstOrNull?.name ?? 'Device $id';
    final msg = MeshMessage(
      id: 'sos_${DateTime.now().millisecondsSinceEpoch}',
      type: MeshMessageType.sos,
      payload: '$name: $payload', fromDeviceId: id, timestamp: DateTime.now(),
    );
    _relayStore[msg.id] = msg; _seen.add(msg.id); _relayCount = _relayStore.length;
    _addMessage(msg);
    _send(_encode({
      'type': 'relay', 'id': _deviceId, 'originId': id,
      'messageId': msg.id, 'msgType': 'sos', 'payload': msg.payload,
      'timestamp': msg.timestamp.toIso8601String(), 'ttl': 10, 'hops': 1,
    }), unicastPeers: true);
  }

  void _onStatus(Map<String, dynamic> j) {
    final id = j['id'] as String? ?? '';
    final s = MeshStatus.values.byName((j['status'] as String?) ?? 'safe');
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx >= 0) {
      _devices[idx] = _devices[idx].copyWith(status: s, lastSeen: DateTime.now());
      _heartbeats[id] = DateTime.now();
      notifyListeners();
    }
  }

  // ─── SILENT GUARDIAN ──────────────────────────────────────────

  void toggleGuardian() {
    _guardianActive = !_guardianActive;
    notifyListeners();
  }

  /// Simulate detecting a hazard (demo mode — in production, uses Gemma 4 audio classification)
  void simulateHazard(HazardType type) {
    if (!_meshActive) return;

    final labels = {
      HazardType.explosion: 'Explosion detected',
      HazardType.structuralCollapse: 'Structural collapse detected',
      HazardType.scream: 'Distress calls detected',
      HazardType.gunshot: 'Gunfire detected',
      HazardType.flood: 'Rapid water rise detected',
      HazardType.crash: 'Vehicle crash detected',
      HazardType.gas: 'Gas leak detected',
    };

    final event = HazardEvent(
      type: type,
      label: labels[type] ?? 'Hazard detected',
      detectedAt: DateTime.now(),
      deviceId: _deviceId,
    );
    _hazards.add(event);

    final alert = '⚠️ ${event.label} by $_deviceName';
    _addSys(alert);

    // Broadcast hazard to mesh
    _send(_encode({
      'type': 'hazard', 'id': _deviceId,
      'hazardType': type.name, 'label': event.label,
      'timestamp': event.detectedAt.toIso8601String(),
    }));

    notifyListeners();
  }

  void _onHazard(Map<String, dynamic> j) {
    final type = HazardType.values.byName((j['hazardType'] as String?) ?? 'explosion');
    final label = j['label'] as String? ?? 'Hazard';
    final fromId = j['id'] as String? ?? '';
    final name = _devices.where((d) => d.id == fromId).firstOrNull?.name ?? 'Device';

    final event = HazardEvent(
      type: type, label: label,
      detectedAt: DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(),
      deviceId: fromId,
    );
    _hazards.add(event);

    _addSys('⚠️ HAZARD from $name: $label');
    notifyListeners();
  }

  // ─── SOS FLASHLIGHT ───────────────────────────────────────────

  bool _sosFlashOn = false;
  bool get sosFlashOn => _sosFlashOn;

  static const _flashChannel = MethodChannel('com.rescuemesh/flashlight');

  Future<void> _setFlash(bool on) async {
    try {
      await _flashChannel.invokeMethod('setFlashlight', on);
    } catch (_) {}
  }

  void toggleFlashlight() {
    _flashlightActive = !_flashlightActive;
    if (_flashlightActive) {
      _startSOSFlash();
    } else {
      _sosFlashOn = false;
      _flashlightTimer?.cancel();
      _flashlightTimer = null;
      _setFlash(false);
    }
    notifyListeners();
  }

  void _startSOSFlash() {
    // Morse SOS ... --- ... as alternating ON/OFF durations in ms.
    // Even indices = ON (dot 200ms, dash 500ms), odd indices = OFF gap
    // (intra-letter 400ms, letter 800ms, word 1200ms before repeating).
    const pattern = [
      200, 400, 200, 400, 200, // S: · · ·
      800,                     // letter gap
      500, 400, 500, 400, 500, // O: — — —
      800,                     // letter gap
      200, 400, 200, 400, 200, // S: · · ·
      1200,                    // word gap, then repeat
    ];

    // Chain one-shot timers instead of a 1ms periodic tick: each phase runs
    // for its actual pattern duration. A 1ms periodic timer ignores the
    // durations entirely and strobes at ~500Hz — invisible as Morse code,
    // while hammering the flashlight method channel ~1000x/sec.
    var idx = 0;

    void runPhase() {
      if (!_flashlightActive) {
        _setFlash(false);
        return;
      }
      final on = idx.isEven;
      _sosFlashOn = on;
      notifyListeners();
      _setFlash(on);
      final durationMs = pattern[idx];
      idx = (idx + 1) % pattern.length;
      _flashlightTimer?.cancel();
      _flashlightTimer = Timer(Duration(milliseconds: durationMs), runPhase);
    }

    runPhase();
  }

  // ─── PUBLIC ACTIONS ───────────────────────────────────────────

  Future<void> sendSOS({required String message}) async {
    if (!_meshActive || _socket == null) return;
    final msg = MeshMessage(
      id: 'sos_${DateTime.now().millisecondsSinceEpoch}',
      type: MeshMessageType.sos,
      payload: '$deviceName: $message', fromDeviceId: _deviceId, timestamp: DateTime.now(),
    );
    _relayStore[msg.id] = msg; _seen.add(msg.id); _relayCount = _relayStore.length;
    _addMessage(msg);
    _send(_encode({'type': 'sos', 'id': _deviceId, 'payload': message}), unicastPeers: true);
  }

  Future<void> updateMyStatus(MeshStatus s) async {
    _myStatus = s; notifyListeners(); _broadcast();
  }

  /// Broadcast GPS location to mesh peers
  void updateLocation(double lat, double lng) {
    _myLocation = MeshLocation(latitude: lat, longitude: lng);
    if (!_meshActive || _socket == null) return;
    _send(_encode({
      'type': 'loc',
      'id': _deviceId,
      'lat': lat,
      'lng': lng,
    }));
  }

  void _onLocation(Map<String, dynamic> j) {
    final id = j['id'] as String? ?? '';
    final lat = (j['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (j['lng'] as num?)?.toDouble() ?? 0.0;
    final idx = _devices.indexWhere((d) => d.id == id);
    if (idx >= 0) {
      _devices[idx] = _devices[idx].copyWith(
        location: MeshLocation(latitude: lat, longitude: lng),
        lastSeen: DateTime.now(),
      );
      notifyListeners();
    }
  }

  int get safe => _devices.where((d) => d.status == MeshStatus.safe && d.goneSilentAt == null).length;
  int get help => _devices.where((d) => d.status == MeshStatus.needsHelp).length;
  int get crit => _devices.where((d) => d.status == MeshStatus.critical).length;
  int get ghostCount => _ghosts.length;

  void _addMessage(MeshMessage m) { _messages.insert(0, m); _msg.add(m); notifyListeners(); }
  void _addSys(String t) {
    _addMessage(MeshMessage(
      id: 'sys_${DateTime.now().millisecondsSinceEpoch}',
      type: MeshMessageType.statusUpdate,
      payload: t, fromDeviceId: 'system', timestamp: DateTime.now(),
    ));
  }

  /// Called from MeshScreen when BLE receives an SOS
  void handleBleSOS(String from, String message) {
    _addSys('🚨 BLE SOS from $from: $message');
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel(); _cleanupTimer?.cancel(); _digestTimer?.cancel();
    _ghostTimer?.cancel(); _flashlightTimer?.cancel();
    _socket?.close(); _msg.close();
    super.dispose();
  }
}

class HazardEvent {
  const HazardEvent({
    required this.type, required this.label,
    required this.detectedAt, required this.deviceId,
  });
  final HazardType type;
  final String label;
  final DateTime detectedAt;
  final String deviceId;
}
