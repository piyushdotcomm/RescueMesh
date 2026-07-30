const String meshStrategyP2P = 'com.rescuemesh.mesh';

class MeshDevice {
  const MeshDevice({
    required this.id,
    required this.name,
    required this.status,
    required this.location,
    required this.role,
    this.lastSeen,
    this.goneSilentAt,
    this.skills = const [],
    this.resources = const [],
  });

  final String id;
  final String name;
  final MeshStatus status;
  final MeshLocation? location;
  final MeshRole role;
  final DateTime? lastSeen;

  /// Ghost Protocol: when this device stopped responding
  final DateTime? goneSilentAt;

  /// Known skills (CPR, first aid, etc.)
  final List<String> skills;

  /// Known resources (water, medicine, etc.)
  final List<String> resources;

  MeshDevice copyWith({
    String? id,
    String? name,
    MeshStatus? status,
    MeshLocation? location,
    MeshRole? role,
    DateTime? lastSeen,
    DateTime? goneSilentAt,
    List<String>? skills,
    List<String>? resources,
  }) {
    return MeshDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      location: location ?? this.location,
      role: role ?? this.role,
      lastSeen: lastSeen ?? this.lastSeen,
      goneSilentAt: goneSilentAt ?? this.goneSilentAt,
      skills: skills ?? this.skills,
      resources: resources ?? this.resources,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.name,
        'location': location?.toJson(),
        'role': role.name,
        'lastSeen': lastSeen?.toIso8601String(),
      };

  factory MeshDevice.fromJson(Map<String, dynamic> json) => MeshDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        status: MeshStatus.values.byName(json['status'] as String),
        location: json['location'] != null
            ? MeshLocation.fromJson(json['location'] as Map<String, dynamic>)
            : null,
        role: MeshRole.values.byName(json['role'] as String),
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'] as String)
            : null,
      );
}

enum MeshStatus { safe, needsHelp, critical, unknown }

extension MeshStatusExtension on MeshStatus {
  String get label {
    switch (this) {
      case MeshStatus.safe:
        return 'Safe';
      case MeshStatus.needsHelp:
        return 'Needs Help';
      case MeshStatus.critical:
        return 'Critical';
      case MeshStatus.unknown:
        return 'Unknown';
    }
  }
}

class MeshLocation {
  const MeshLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory MeshLocation.fromJson(Map<String, dynamic> json) => MeshLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}

enum MeshRole { survivor, firstResponder, volunteer }

extension MeshRoleExtension on MeshRole {
  String get label {
    switch (this) {
      case MeshRole.survivor:
        return 'Survivor';
      case MeshRole.firstResponder:
        return 'First Responder';
      case MeshRole.volunteer:
        return 'Volunteer';
    }
  }
}

class MeshMessage {
  const MeshMessage({
    required this.id,
    required this.type,
    required this.payload,
    required this.fromDeviceId,
    required this.timestamp,
    this.recipientDeviceId,
  });

  final String id;
  final MeshMessageType type;
  final String payload;
  final String fromDeviceId;
  final DateTime timestamp;
  final String? recipientDeviceId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'fromDeviceId': fromDeviceId,
        'timestamp': timestamp.toIso8601String(),
        'recipientDeviceId': recipientDeviceId,
      };

  factory MeshMessage.fromJson(Map<String, dynamic> json) => MeshMessage(
        id: json['id'] as String,
        type: MeshMessageType.values.byName(json['type'] as String),
        payload: json['payload'] as String,
        fromDeviceId: json['fromDeviceId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        recipientDeviceId: json['recipientDeviceId'] as String?,
      );
}

enum MeshMessageType {
  sos,
  statusUpdate,
  resourceShare,
  chat,
  discovery,
  ping,
  ghost,
  hazard,
}
