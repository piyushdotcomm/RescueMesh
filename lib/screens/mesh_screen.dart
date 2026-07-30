import 'dart:async';

import 'package:flutter/material.dart';
import '../models/mesh_device.dart';
import '../services/mesh_service.dart';
import '../theme/rescue_theme.dart';
import '../widgets/glass.dart';

class MeshScreen extends StatefulWidget {
  const MeshScreen({
    required this.meshService,
    super.key,
  });

  final MeshService meshService;

  @override
  State<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends State<MeshScreen> {
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.meshService.addListener(_onMeshChanged);
  }

  @override
  void dispose() {
    widget.meshService.removeListener(_onMeshChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onMeshChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = RescueMesh(context);
    final mesh = widget.meshService;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // ── Header ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  'RescueMesh',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 36,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Row(
                children: [
                  // Status dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: mesh.meshActive ? c.success : c.textDim,
                      shape: BoxShape.circle,
                      boxShadow: mesh.meshActive
                          ? [
                              BoxShadow(
                                color: c.success.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    mesh.meshActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: mesh.meshActive ? c.success : c.textDim,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            mesh.meshActive
                ? '${mesh.devices.length + 1} devices connected'
                : 'Tap to activate emergency mesh',
            style: TextStyle(color: c.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // ── Activation / Status banner ─────────────────────────
          Glass(
            radius: 18,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  mesh.meshActive ? Icons.wifi : Icons.wifi_off_rounded,
                  size: 24,
                  color:
                      mesh.meshActive ? c.success : c.textDim,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    mesh.meshActive
                        ? 'P2P mesh is active. Devices within 100m can '
                            'connect and share emergency information.'
                        : 'Create an offline emergency network. Phones connect '
                            'directly via WiFi — no cell towers, no internet.',
                    style: TextStyle(color: c.text, fontSize: 14, height: 1.4),
                  ),
                ),
                if (!mesh.meshActive)
                  _PillButton(
                    c: c,
                    label: 'Activate',
                    onTap: () => mesh.activateMesh(),
                  )
                else
                  _PillButton(
                    c: c,
                    label: 'Stop',
                    secondary: true,
                    onTap: () => mesh.deactivateMesh(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Stats row ──────────────────────────────────────────
          if (mesh.meshActive) ...[
            _StatsRow(mesh: mesh, c: c),
            const SizedBox(height: 20),
          ],

          // ── Action buttons ────────────────────────────────────
          if (mesh.meshActive) ...[
            _buildActionBar(mesh, c),
            const SizedBox(height: 24),
          ],

          // ── Ghost Protocol section ────────────────────────────
          if (mesh.meshActive && mesh.ghosts.isNotEmpty) ...[
            const SectionHeader(label: 'Ghost Protocol'),
            const SizedBox(height: 4),
            Text('Devices that went silent — their last state persists in the mesh',
                style: TextStyle(color: c.textDim, fontSize: 12)),
            const SizedBox(height: 8),
            Glass(
              radius: 18,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final ghost in mesh.ghosts)
                    _buildGhostTile(c, ghost),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── My status ──────────────────────────────────────────
          if (mesh.meshActive) ...[
            const SectionHeader(label: 'My status'),
            const SizedBox(height: 8),
            Glass(
              radius: 18,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _buildRow(
                    c,
                    icon: Icons.person_outline,
                    label: 'Name',
                    value: mesh.deviceName,
                    chevron: true,
                    onTap: () => _showEditNameDialog(context, c),
                  ),
                  _divider(c),
                  _buildRow(
                    c,
                    icon: Icons.shield_outlined,
                    label: 'Role',
                    value: mesh.myRole.label,
                    chevron: true,
                    onTap: () => _showRolePicker(context, c),
                  ),
                  _divider(c),
                  _buildRow(
                    c,
                    icon: Icons.favorite_border,
                    label: 'Status',
                    value: mesh.myStatus.label,
                    chevron: true,
                    onTap: () => _showStatusPicker(context, c),
                  ),
                  _divider(c),
                  _buildRow(
                    c,
                    icon: Icons.person_pin,
                    label: 'Device ID',
                    value: mesh.deviceId.length > 12
                        ? '${mesh.deviceId.substring(0, 12)}...'
                        : mesh.deviceId,
                  ),
                ],
              ),
            ),
          ],

          if (mesh.meshActive) const SizedBox(height: 24),

          // ── Connected devices ──────────────────────────────────
          if (mesh.meshActive) ...[
            const SectionHeader(label: 'Connected devices'),
            const SizedBox(height: 8),
            Glass(
              radius: 18,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  // Self
                  _buildDeviceTile(
                    c,
                    name: 'You (${mesh.deviceName})',
                    status: mesh.myStatus,
                    role: mesh.myRole,
                    isMe: true,
                  ),
                  _divider(c),
                  // Peers
                  for (final device in mesh.devices)
                    _buildDeviceTile(
                      c,
                      name: device.name,
                      status: device.status,
                      role: device.role,
                      onTap: () => _showDeviceDetail(context, c, device),
                    ),
                ],
              ),
            ),
          ],

          if (mesh.meshActive) const SizedBox(height: 24),

          // ── Recent activity feed ───────────────────────────────
          if (mesh.meshActive && mesh.messages.isNotEmpty) ...[
            const SectionHeader(label: 'Activity feed'),
            const SizedBox(height: 8),
            Glass(
              radius: 18,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  for (final msg in mesh.messages.take(10))
                    _buildMessageTile(c, msg),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _sendSOS() {
    final mesh = widget.meshService;
    final c = RescueMesh(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Glass(
            radius: 24,
            strong: true,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.textDim,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Send SOS Beacon',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This will alert all nearby devices in the mesh',
                  style: TextStyle(color: c.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Describe your emergency...',
                    hintStyle: TextStyle(color: c.textDim),
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: c.accent, width: 1.5),
                    ),
                  ),
                  style: TextStyle(color: c.text),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final text = _messageController.text.trim();
                      if (text.isEmpty) return;
                      mesh.sendSOS(message: text);
                      _messageController.clear();
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'BROADCAST SOS',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Quick messages
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _quickSosChip(c, 'Need medical help',
                        'Trapped, need immediate medical assistance'),
                    _quickSosChip(
                        c, 'Need rescue', 'Stuck under debris, need extraction'),
                    _quickSosChip(c, 'Need water/food',
                        'Running low on supplies, need water and food'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickSosChip(RescueMeshColors c, String label, String message) {
    return GestureDetector(
      onTap: () {
        widget.meshService.sendSOS(message: '$message. Location: VIT Chennai campus.');
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.accentSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.accent.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(color: c.accent, fontSize: 12),
        ),
      ),
    );
  }

  // ── Device tile ───────────────────────────────────────────────

  Widget _buildDeviceTile(
    RescueMeshColors c, {
    required String name,
    required MeshStatus status,
    required MeshRole role,
    VoidCallback? onTap,
    bool isMe = false,
  }) {
    final statusColor = _statusColor(status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(You)',
                          style: TextStyle(color: c.textDim, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${status.label} · ${role.label}',
                    style: TextStyle(color: c.textDim, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (!isMe)
              _MiniBadge(c: c, status: status),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 20, color: c.textDim),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(MeshStatus s) {
    switch (s) {
      case MeshStatus.safe:
        return const Color(0xFF4CAF50);
      case MeshStatus.needsHelp:
        return const Color(0xFFFFC107);
      case MeshStatus.critical:
        return const Color(0xFFE53935);
      case MeshStatus.unknown:
        return const Color(0xFF9E9E9E);
    }
  }

  // ── Message tile ──────────────────────────────────────────────

  Widget _buildMessageTile(RescueMeshColors c, MeshMessage msg) {
    final icon = _messageIcon(msg.type);
    final color = _messageColor(msg.type);
    final deviceName = msg.fromDeviceId == widget.meshService.deviceId
        ? 'You'
        : (widget.meshService.devices
                .where((d) => d.id == msg.fromDeviceId)
                .firstOrNull
                ?.name ??
            'Unknown');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      deviceName,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _timeAgo(msg.timestamp),
                      style: TextStyle(color: c.textDim, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  msg.payload,
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _messageIcon(MeshMessageType type) {
    switch (type) {
      case MeshMessageType.sos:
        return Icons.warning_rounded;
      case MeshMessageType.ghost:
        return Icons.person_off;
      case MeshMessageType.hazard:
        return Icons.crisis_alert;
      case MeshMessageType.statusUpdate:
        return Icons.info_outline;
      case MeshMessageType.resourceShare:
        return Icons.inventory_2_outlined;
      case MeshMessageType.chat:
        return Icons.chat_bubble_outline;
      case MeshMessageType.discovery:
        return Icons.wifi_find;
      case MeshMessageType.ping:
        return Icons.wifi;
    }
  }

  Color _messageColor(MeshMessageType type) {
    switch (type) {
      case MeshMessageType.sos:
        return const Color(0xFFE53935);
      case MeshMessageType.ghost:
        return const Color(0xFF6A1B9A);
      case MeshMessageType.hazard:
        return const Color(0xFFFF6D00);
      case MeshMessageType.statusUpdate:
        return const Color(0xFF2196F3);
      case MeshMessageType.resourceShare:
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Dialogs ──────────────────────────────────────────────────

  void _showEditNameDialog(BuildContext context, RescueMeshColors c) {
    final controller =
        TextEditingController(text: widget.meshService.deviceName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surfaceStrong,
        title: Text('Device name',
            style: TextStyle(color: c.text)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: c.text),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: TextStyle(color: c.textDim),
            filled: true,
            fillColor: c.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: c.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              widget.meshService.setDeviceName(controller.text.trim());
              Navigator.of(ctx).pop();
            },
            child: Text('Save',
                style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    );
  }

  void _showRolePicker(BuildContext context, RescueMeshColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Glass(
            radius: 24,
            strong: true,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: c.textDim,
                      borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Select role',
                        style: TextStyle(
                            color: c.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                for (final role in MeshRole.values)
                  _pickerTile(
                    c,
                    label: role.label,
                    selected: role == widget.meshService.myRole,
                    onTap: () {
                      widget.meshService.setRole(role);
                      Navigator.of(ctx).pop();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStatusPicker(BuildContext context, RescueMeshColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Glass(
            radius: 24,
            strong: true,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: c.textDim,
                      borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Update status',
                        style: TextStyle(
                            color: c.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                for (final s in MeshStatus.values)
                  _pickerTile(
                    c,
                    label: s.label,
                    selected: s == widget.meshService.myStatus,
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _statusColor(s),
                        shape: BoxShape.circle,
                      ),
                    ),
                    onTap: () {
                      widget.meshService.updateMyStatus(s);
                      Navigator.of(ctx).pop();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pickerTile(
    RescueMeshColors c, {
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    Widget? leading,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? c.accent : c.text,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 18, color: c.accent),
          ],
        ),
      ),
    );
  }

  void _showDeviceDetail(
      BuildContext context, RescueMeshColors c, MeshDevice device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Glass(
            radius: 24,
            strong: true,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: c.textDim,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _statusColor(device.status),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _statusColor(device.status)
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      device.name,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _detailRow(c, 'Status', device.status.label),
                _detailRow(c, 'Role', device.role.label),
                _detailRow(c, 'ID', device.id),
                if (device.location != null)
                  _detailRow(c, 'Location',
                      '${device.location!.latitude.toStringAsFixed(4)}, ${device.location!.longitude.toStringAsFixed(4)}'),
                _detailRow(
                  c,
                  'Last seen',
                  device.lastSeen != null
                      ? _timeAgo(device.lastSeen!)
                      : 'Unknown',
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(RescueMeshColors c, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(color: c.textDim, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: c.text, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Utility widgets ──────────────────────────────────────────

  Widget _buildRow(
    RescueMeshColors c, {
    required IconData icon,
    required String label,
    String? value,
    VoidCallback? onTap,
    bool chevron = false,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textDim),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(color: c.text, fontSize: 15)),
          ),
          if (value != null)
            Text(value, style: TextStyle(color: c.textMuted, fontSize: 13)),
          if (chevron) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: c.textDim),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }

  Widget _divider(RescueMeshColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: c.border),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.c,
    required this.label,
    required this.onTap,
    this.secondary = false,
  });

  final RescueMeshColors c;
  final String label;
  final VoidCallback onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: secondary
              ? c.surfaceElev
              : c.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: secondary ? c.borderStrong : c.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: secondary ? c.text : c.accent,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.c, required this.status});
  final RescueMeshColors c;
  final MeshStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == MeshStatus.safe) return const SizedBox.shrink();
    final color = status == MeshStatus.critical
        ? const Color(0xFFE53935)
        : const Color(0xFFFFC107);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.mesh, required this.c});
  final MeshService mesh;
  final RescueMeshColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _statCard(c, 'Safe', '${mesh.safe}', c.success)),
        const SizedBox(width: 8),
        Expanded(
            child: _statCard(
                c, 'Need Help', '${mesh.help}', const Color(0xFFFFC107))),
        const SizedBox(width: 8),
        Expanded(
            child: _statCard(
                c, 'Critical', '${mesh.crit}', const Color(0xFFE53935))),
      ],
    );
  }

  Widget _statCard(RescueMeshColors c, String label, String value, Color color) {
    return Glass(
      radius: 12,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: c.textDim, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = RescueMesh(context);
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: c.textDim,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── GHOST TILE ─────────────────────────────────────────────────

extension _GhostTile on _MeshScreenState {
  Widget _buildGhostTile(RescueMeshColors c, MeshDevice ghost) {
    final silentFor = DateTime.now().difference(ghost.goneSilentAt!);
    final mins = silentFor.inMinutes > 0
        ? '${silentFor.inMinutes}m ago'
        : '${silentFor.inSeconds}s ago';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.person_off, color: Color(0xFFE53935), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(ghost.name, style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE53935).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                    child: const Text('UNRESPONSIVE', style: TextStyle(color: Color(0xFFE53935), fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('$mins · Was ${ghost.role.label} · Last status: ${ghost.status.label}',
                    style: TextStyle(color: c.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: c.textDim, size: 20),
        ],
      ),
    );
  }

  // ─── ACTION BAR ────────────────────────────────────────────────

  Widget _buildActionBar(MeshService mesh, RescueMeshColors c) {
    return Column(
      children: [
        // SOS Button
        GestureDetector(
          onTap: () => _sendSOS(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: c.accent, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: c.accentGlow, blurRadius: 20, offset: const Offset(0, 4))],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text('SEND SOS BEACON', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Silent Guardian + Flashlight row
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showHazardMenu(mesh, c),
                child: Glass(
                  radius: 14,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      Icon(mesh.guardianActive ? Icons.hearing : Icons.hearing_disabled,
                          color: mesh.guardianActive ? c.success : c.textMuted, size: 24),
                      const SizedBox(height: 6),
                      Text(mesh.guardianActive ? 'Listening' : 'Silent Guardian',
                          style: TextStyle(color: mesh.guardianActive ? c.success : c.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => mesh.toggleFlashlight(),
                child: Glass(
                  radius: 14,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      Icon(
                        mesh.flashlightActive ? Icons.flashlight_on : Icons.flashlight_off,
                        color: mesh.flashlightActive ? const Color(0xFFFFC107) : c.textMuted,
                        size: 24,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mesh.flashlightActive ? 'SOS Morse' : 'Signal Light',
                        style: TextStyle(
                          color: mesh.flashlightActive ? const Color(0xFFFFC107) : c.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showHazardMenu(MeshService mesh, RescueMeshColors c) {
    mesh.toggleGuardian();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Glass(
            radius: 24, strong: true,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: c.textDim, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(alignment: Alignment.centerLeft,
                      child: Text('Simulate Hazard', style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w600))),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Demo: simulate environmental hazards via Gemma 4 audio classification',
                      style: TextStyle(color: c.textDim, fontSize: 12)),
                ),
                const SizedBox(height: 12),
                for (final h in [
                  (HazardType.structuralCollapse, Icons.domain_disabled, 'Structural Collapse'),
                  (HazardType.explosion, Icons.local_fire_department, 'Explosion'),
                  (HazardType.scream, Icons.record_voice_over, 'Distress Calls'),
                  (HazardType.gas, Icons.water_damage, 'Gas Leak'),
                  (HazardType.flood, Icons.water, 'Flash Flood'),
                  (HazardType.crash, Icons.car_crash, 'Vehicle Crash'),
                ])
                  InkWell(
                    onTap: () { mesh.simulateHazard(h.$1); Navigator.of(ctx).pop(); },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      child: Row(children: [
                        Icon(h.$2, color: c.accent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(h.$3, style: TextStyle(color: c.text, fontSize: 15))),
                        Icon(Icons.play_arrow, color: c.textDim, size: 18),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
