/// Soft record lifecycle for admin ground registry.
enum AdminGroundRecordStatus {
  active,
  deleted,
  archived;

  String get label => switch (this) {
        AdminGroundRecordStatus.active => 'Active',
        AdminGroundRecordStatus.deleted => 'Deleted',
        AdminGroundRecordStatus.archived => 'Archived',
      };

  String get wireValue => name;

  bool get isSoftDeleted => this == AdminGroundRecordStatus.deleted;

  static AdminGroundRecordStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return AdminGroundRecordStatus.active;
    for (final s in AdminGroundRecordStatus.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return AdminGroundRecordStatus.active;
  }
}

/// Operational status for grounds.
enum ManagedGroundStatus {
  active,
  pendingVerification,
  verified,
  suspended,
  archived,
  deleted;

  String get label => switch (this) {
        ManagedGroundStatus.active => 'Active',
        ManagedGroundStatus.pendingVerification => 'Pending Verification',
        ManagedGroundStatus.verified => 'Verified',
        ManagedGroundStatus.suspended => 'Suspended',
        ManagedGroundStatus.archived => 'Archived',
        ManagedGroundStatus.deleted => 'Deleted',
      };

  String get wireValue => name;

  static ManagedGroundStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedGroundStatus.active;
    for (final s in ManagedGroundStatus.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return ManagedGroundStatus.active;
  }

  static ManagedGroundStatus derive({
    required AdminGroundRecordStatus recordStatus,
    required String? adminStatus,
    required bool adminVerified,
  }) {
    if (recordStatus == AdminGroundRecordStatus.deleted) {
      return ManagedGroundStatus.deleted;
    }
    if (recordStatus == AdminGroundRecordStatus.archived) {
      return ManagedGroundStatus.archived;
    }
    final parsed = parse(adminStatus);
    if (parsed == ManagedGroundStatus.suspended) {
      return ManagedGroundStatus.suspended;
    }
    if (parsed == ManagedGroundStatus.pendingVerification) {
      return ManagedGroundStatus.pendingVerification;
    }
    if (adminVerified || parsed == ManagedGroundStatus.verified) {
      return ManagedGroundStatus.verified;
    }
    return ManagedGroundStatus.active;
  }
}

enum ManagedGroundType {
  outdoor,
  indoor,
  turf,
  matting,
  concrete,
  synthetic;

  String get label => switch (this) {
        ManagedGroundType.outdoor => 'Outdoor',
        ManagedGroundType.indoor => 'Indoor',
        ManagedGroundType.turf => 'Turf',
        ManagedGroundType.matting => 'Matting',
        ManagedGroundType.concrete => 'Concrete',
        ManagedGroundType.synthetic => 'Synthetic',
      };

  String get wireValue => name;

  static ManagedGroundType? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in ManagedGroundType.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return null;
  }
}

enum ManagedGroundPitchType {
  grass,
  turf,
  cement,
  matting,
  synthetic,
  rough,
  astroturf;

  String get label => switch (this) {
        ManagedGroundPitchType.grass => 'Grass',
        ManagedGroundPitchType.turf => 'Turf',
        ManagedGroundPitchType.cement => 'Cement',
        ManagedGroundPitchType.matting => 'Matting',
        ManagedGroundPitchType.synthetic => 'Synthetic',
        ManagedGroundPitchType.rough => 'Rough',
        ManagedGroundPitchType.astroturf => 'Astroturf',
      };

  String get wireValue => name;

  static ManagedGroundPitchType? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in ManagedGroundPitchType.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return null;
  }
}

enum ManagedGroundBallType {
  leather,
  tennis,
  indoor;

  String get label => switch (this) {
        ManagedGroundBallType.leather => 'Leather',
        ManagedGroundBallType.tennis => 'Tennis',
        ManagedGroundBallType.indoor => 'Indoor',
      };

  String get wireValue => name;

  static ManagedGroundBallType? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final s in ManagedGroundBallType.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return null;
  }
}

enum ManagedGroundAvailability {
  available,
  occupied,
  closed,
  underMaintenance;

  String get label => switch (this) {
        ManagedGroundAvailability.available => 'Available',
        ManagedGroundAvailability.occupied => 'Occupied',
        ManagedGroundAvailability.closed => 'Closed',
        ManagedGroundAvailability.underMaintenance => 'Under Maintenance',
      };

  String get wireValue => name;

  static ManagedGroundAvailability parse(String? raw) {
    if (raw == null || raw.isEmpty) return ManagedGroundAvailability.available;
    for (final s in ManagedGroundAvailability.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return ManagedGroundAvailability.available;
  }
}

/// Known facility keys for ground profiles.
abstract final class GroundFacilityKeys {
  static const pavilion = 'pavilion';
  static const dressingRooms = 'dressingRooms';
  static const washrooms = 'washrooms';
  static const parking = 'parking';
  static const floodlights = 'floodlights';
  static const practiceNets = 'practiceNets';
  static const scoreboard = 'scoreboard';
  static const seating = 'seating';
  static const refreshments = 'refreshments';
  static const medicalRoom = 'medicalRoom';
  static const liveStreaming = 'liveStreaming';
  static const powerBackup = 'powerBackup';
  static const wifi = 'wifi';

  static const all = [
    pavilion,
    dressingRooms,
    washrooms,
    parking,
    floodlights,
    practiceNets,
    scoreboard,
    seating,
    refreshments,
    medicalRoom,
    liveStreaming,
    powerBackup,
    wifi,
  ];

  static String label(String key) => switch (key) {
        pavilion => 'Pavilion',
        dressingRooms => 'Dressing Rooms',
        washrooms => 'Washrooms',
        parking => 'Parking',
        floodlights => 'Floodlights',
        practiceNets => 'Practice Nets',
        scoreboard => 'Scoreboard',
        seating => 'Seating',
        refreshments => 'Refreshments',
        medicalRoom => 'Medical Room',
        liveStreaming => 'Live Streaming Support',
        powerBackup => 'Power Backup',
        wifi => 'Wi-Fi',
        _ => key,
      };
}
