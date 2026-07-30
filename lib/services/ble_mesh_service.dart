import 'dart:async';

import 'package:flutter/services.dart';

/// Bluetooth Low Energy mesh transport for RescueMesh.
///
/// Uses BLE advertising to broadcast presence and messages.
/// Every phone advertises + scans simultaneously.
/// No pairing, no WiFi, no router, no hotspot — just Bluetooth.
class BleMeshService {
  BleMeshService() {
    _eventChannel.receiveBroadcastStream().listen(_onEvent);
  }

  static const _methodChannel = MethodChannel('com.rescuemesh/ble_mesh');
  static const _eventChannel = EventChannel('com.rescuemesh/ble_mesh_events');

  final _controller = StreamController<BleMeshEvent>.broadcast();
  Stream<BleMeshEvent> get events => _controller.stream;

  bool _active = false;
  bool _advertising = false;
  final Set<String> _seenAddresses = {};
  int _deviceCount = 0;

  bool get isActive => _active;
  bool get isAdvertising => _advertising;
  int get deviceCount => _deviceCount;

  Future<bool> isSupported() async {
    try {
      return await _methodChannel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    try {
      return await _methodChannel.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestEnable() async {
    await _methodChannel.invokeMethod('requestEnable');
  }

  Future<void> startMesh({
    String deviceName = 'RescueMesh',
    String status = 'safe',
    String role = 'survivor',
  }) async {
    try {
      await _methodChannel.invokeMethod('startMesh', {
        'deviceName': deviceName,
        'status': status,
        'role': role,
      });
    } catch (_) {}
  }

  Future<void> stopMesh() async {
    try {
      await _methodChannel.invokeMethod('stopMesh');
      _active = false;
      _advertising = false;
      _seenAddresses.clear();
      _deviceCount = 0;
    } catch (_) {}
  }

  Future<void> broadcastMessage({
    required String type,
    required String payload,
  }) async {
    try {
      await _methodChannel.invokeMethod('broadcastMessage', {
        'type': type,
        'payload': payload,
      });
    } catch (_) {}
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['event'] as String? ?? '';

    switch (type) {
      case 'meshStarted':
        _active = true;
        _advertising = true;
        _controller.add(const BleMeshEvent(type: BleEventType.meshStarted));
        break;
      case 'meshStopped':
        _active = false;
        _advertising = false;
        _seenAddresses.clear();
        _deviceCount = 0;
        _controller.add(const BleMeshEvent(type: BleEventType.meshStopped));
        break;
      case 'deviceDiscovered':
        final address = event['address'] as String? ?? '';
        if (!_seenAddresses.contains(address)) {
          _seenAddresses.add(address);
          _deviceCount = _seenAddresses.length;
        }
        _controller.add(BleMeshEvent(
          type: BleEventType.deviceDiscovered,
          deviceName: event['name'] as String? ?? 'Unknown',
          address: address,
          deviceStatus: event['status'] as String? ?? 'safe',
          deviceRole: event['role'] as String? ?? 'survivor',
          rssi: event['rssi'] as int? ?? 0,
        ));
        break;
      case 'messageReceived':
        _controller.add(BleMeshEvent(
          type: BleEventType.messageReceived,
          fromDevice: event['from'] as String? ?? 'Unknown',
          messageType: event['type'] as String? ?? 'sos',
          payload: event['payload'] as String? ?? '',
          rssi: event['rssi'] as int? ?? 0,
        ));
        break;
      case 'advertisingStarted':
        _advertising = true;
        break;
      case 'error':
        _controller.add(BleMeshEvent(
          type: BleEventType.error,
          payload: event['error'] as String? ?? '',
        ));
        break;
    }
  }

  void dispose() {
    stopMesh();
    _controller.close();
  }
}

class BleMeshEvent {
  const BleMeshEvent({
    required this.type,
    this.deviceName,
    this.address,
    this.deviceStatus,
    this.deviceRole,
    this.fromDevice,
    this.messageType,
    this.payload,
    this.rssi,
  });

  final BleEventType type;
  final String? deviceName;
  final String? address;
  final String? deviceStatus;
  final String? deviceRole;
  final String? fromDevice;
  final String? messageType;
  final String? payload;
  final int? rssi;
}

enum BleEventType {
  meshStarted,
  meshStopped,
  deviceDiscovered,
  messageReceived,
  error,
}
