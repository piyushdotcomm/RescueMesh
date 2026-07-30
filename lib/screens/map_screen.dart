import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/mesh_device.dart';
import '../services/mesh_service.dart';
import '../theme/rescue_theme.dart';
import '../widgets/glass.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.meshService,
    super.key,
  });

  final MeshService meshService;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  LatLng _center = const LatLng(12.9716, 80.1550);
  bool _tracking = false;
  StreamSubscription<Position>? _posSub;

  @override
  void initState() {
    super.initState();
    _requestLocation();
    widget.meshService.addListener(_onMesh);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    widget.meshService.removeListener(_onMesh);
    _mapController.dispose();
    super.dispose();
  }

  void _onMesh() {
    if (mounted) setState(() {});
  }

  Future<void> _requestLocation() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    final service = await Geolocator.isLocationServiceEnabled();
    if (!service) return;

    // Get last known position immediately for initial center
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        final loc = LatLng(lastPos.latitude, lastPos.longitude);
        _mapController.move(loc, 17);
        setState(() { _center = loc; _tracking = true; });
        widget.meshService.updateLocation(lastPos.latitude, lastPos.longitude);
      }
    } catch (_) {}

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      final loc = LatLng(pos.latitude, pos.longitude);
      _mapController.move(loc, 17);
      widget.meshService.updateLocation(pos.latitude, pos.longitude);
      setState(() { _center = loc; _tracking = true; });
    });
  }

  Color _statusColor(MeshStatus s) {
    switch (s) {
      case MeshStatus.safe: return Colors.green;
      case MeshStatus.needsHelp: return Colors.orange;
      case MeshStatus.critical: return Colors.red;
      case MeshStatus.unknown: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RescueMesh(context);
    final mesh = widget.meshService;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(12.9716, 80.1550),
              initialZoom: 17,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rescuemesh.rescuemesh',
              ),
              MarkerLayer(markers: _buildMarkers(mesh, c)),
            ],
          ),
          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _topBar(c, mesh),
          ),
          // Legend
          Positioned(
            bottom: 80,
            right: 16,
            child: _legend(c),
          ),
          // Loading overlay
          if (!_tracking)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: c.surfaceStrong,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                        color: Color(0xFFCC3F1E), strokeWidth: 3),
                    SizedBox(height: 16),
                    Text('Acquiring GPS...',
                        style: TextStyle(color: Colors.white70)),
                    SizedBox(height: 6),
                    Text('Go outside or near a window',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(MeshService mesh, RescueMeshColors c) {
    final markers = <Marker>[];

    // Self
    if (_tracking) {
      markers.add(Marker(
        point: _center,
        width: 40,
        height: 40,
        child: _marker(c.accent, 'You', 'self'),
      ));
    }

    // Peers with GPS
    var peerCount = 0;
    for (final d in mesh.devices) {
      if (d.location != null) {
        peerCount++;
        markers.add(Marker(
          point: LatLng(d.location!.latitude, d.location!.longitude),
          width: 40,
          height: 40,
          child: _marker(_statusColor(d.status), d.name, d.id),
        ));
      }
    }

    // Debug: If 0 peers with GPS but mesh has devices, show info
    if (_tracking && peerCount == 0 && mesh.devices.isNotEmpty) {
      markers.add(Marker(
        point: _center,
        width: 300,
        height: 40,
        child: Container(
          padding: const EdgeInsets.all(8),
          color: Colors.black87,
          child: Text(
            '${mesh.devices.length} device(s) connected — waiting for GPS...',
            style: const TextStyle(color: Colors.orange, fontSize: 11),
          ),
        ),
      ));
    }

    return markers;
  }

  Widget _marker(Color color, String label, String key) {
    return Column(
      key: ValueKey(key),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
          ),
          child: Center(
            child: Text(
              label.isNotEmpty ? label[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label.length > 6 ? '${label.substring(0, 6)}..' : label,
            style: const TextStyle(
                color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _topBar(RescueMeshColors c, MeshService mesh) {
    final devCount = mesh.devices.where((d) => d.location != null).length;
    final totalDevices = mesh.devices.length;
    return Glass(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(_tracking ? Icons.my_location : Icons.location_searching,
              color: _tracking ? c.success : c.textDim, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _tracking 
                  ? 'Self: ✓  |  Peers: $devCount/$totalDevices with GPS'
                  : 'GPS...',
              style:
                  TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(RescueMeshColors c) {
    return Glass(
      radius: 12,
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendRow(Colors.green, 'Safe'),
          const SizedBox(height: 4),
          _legendRow(Colors.orange, 'Needs Help'),
          const SizedBox(height: 4),
          _legendRow(Colors.red, 'Critical'),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}
