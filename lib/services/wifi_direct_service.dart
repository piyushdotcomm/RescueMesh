import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

/// WiFi Direct transport layer for RescueMesh.
///
/// Uses Android's native WifiP2pManager via platform channels.
/// Phones connect directly with no router, no WiFi network, no internet.
class WifiDirectService {
  WifiDirectService() {
    _eventChannel.receiveBroadcastStream().listen(_onEvent);
  }

  static const _methodChannel = MethodChannel('com.rescuemesh/wifi_direct');
  static const _eventChannel = EventChannel('com.rescuemesh/wifi_direct_events');

  final _controller = StreamController<WifiDirectEvent>.broadcast();
  Stream<WifiDirectEvent> get events => _controller.stream;

  bool _discovering = false;
  String _connectedAddress = '';
  String _groupOwnerAddress = '';
  bool _connected = false;

  bool get isDiscovering => _discovering;
  bool get isConnected => _connected;
  String get connectedAddress => _connectedAddress;

  Future<bool> startDiscovery() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startDiscovery');
      _discovering = result ?? false;
      return _discovering;
    } catch (e) {
      _discovering = false;
      return false;
    }
  }

  Future<void> stopDiscovery() async {
    try {
      await _methodChannel.invokeMethod('stopDiscovery');
      _discovering = false;
    } catch (_) {}
  }

  Future<void> connectToPeer(String address) async {
    try {
      await _methodChannel.invokeMethod('connect', address);
    } catch (_) {}
  }

  Future<void> disconnect() async {
    try {
      await _methodChannel.invokeMethod('disconnect');
      _connected = false;
      _connectedAddress = '';
    } catch (_) {}
  }

  Future<void> sendMessage(String message) async {
    try {
      await _methodChannel.invokeMethod('send', message);
    } catch (_) {}
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;

    final type = event['event'] as String? ?? '';
    switch (type) {
      case 'peersChanged':
        final devices = (event['devices'] as List?)?.cast<Map>() ?? [];
        _controller.add(WifiDirectEvent(
          type: WifiDirectEventType.peersFound,
          peers: devices
              .map((d) => WifiDirectPeer(
                    name: d['name'] as String? ?? 'Unknown',
                    address: d['address'] as String? ?? '',
                    status: d['status'] as String? ?? 'unknown',
                  ))
              .toList(),
        ));
        break;
      case 'connected':
        _connected = true;
        _groupOwnerAddress = event['groupOwnerAddress'] as String? ?? '';
        _controller.add(WifiDirectEvent(
          type: WifiDirectEventType.connected,
          groupOwnerAddress: _groupOwnerAddress,
        ));
        break;
      case 'disconnected':
        _connected = false;
        _connectedAddress = '';
        _controller.add(const WifiDirectEvent(type: WifiDirectEventType.disconnected));
        break;
      case 'messageReceived':
        _controller.add(WifiDirectEvent(
          type: WifiDirectEventType.message,
          message: event['message'] as String? ?? '',
        ));
        break;
      case 'discoveryFailed':
        _controller.add(WifiDirectEvent(
          type: WifiDirectEventType.error,
          error: event['error'] as String? ?? 'Discovery failed',
        ));
        break;
      case 'connectionFailed':
        _controller.add(WifiDirectEvent(
          type: WifiDirectEventType.error,
          error: 'Connection failed',
        ));
        break;
    }
  }

  void dispose() {
    _controller.close();
    stopDiscovery();
    disconnect();
  }
}

class WifiDirectEvent {
  const WifiDirectEvent({
    required this.type,
    this.peers,
    this.message,
    this.error,
    this.groupOwnerAddress,
  });

  final WifiDirectEventType type;
  final List<WifiDirectPeer>? peers;
  final String? message;
  final String? error;
  final String? groupOwnerAddress;
}

enum WifiDirectEventType {
  peersFound,
  connected,
  disconnected,
  message,
  error,
}

class WifiDirectPeer {
  const WifiDirectPeer({
    required this.name,
    required this.address,
    required this.status,
  });

  final String name;
  final String address;
  final String status;
}
