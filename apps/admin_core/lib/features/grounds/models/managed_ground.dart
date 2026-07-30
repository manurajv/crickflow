import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'ground_enums.dart';

/// Admin ground row — registry doc and/or derived from tournament `grounds[]`.
///
/// Mobile still stores free-text ground names on tournaments; this model is
/// admin-only. Match `venue` is intentionally not used as the source.
class ManagedGround extends Equatable {
  const ManagedGround({
    required this.id,
    required this.name,
    this.groundCode,
    this.description = '',
    this.photoUrl,
    this.galleryUrls = const [],
    this.address = '',
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.pinCode = '',
    this.latitude,
    this.longitude,
    this.contactPerson = '',
    this.contactNumber = '',
    this.email = '',
    this.website = '',
    this.ownerId,
    this.ownerName = '',
    this.establishedYear,
    this.capacity,
    this.boundarySize,
    this.groundType,
    this.pitchType,
    this.ballTypes = const {},
    this.availability = ManagedGroundAvailability.available,
    this.facilities = const {},
    this.floodlights = false,
    this.parking = false,
    this.matchesHosted = 0,
    this.rating = 0,
    this.reviewCount = 0,
    this.createdAt,
    this.updatedAt,
    this.adminFeatured = false,
    this.adminVerified = false,
    this.adminStatus = ManagedGroundStatus.active,
    this.recordStatus = AdminGroundRecordStatus.active,
    this.organizationId,
    this.deletedAt,
    this.deletedBy,
    this.tournamentIds = const [],
    this.source = GroundDataSource.registry,
  });

  final String id;
  final String name;
  final String? groundCode;
  final String description;
  final String? photoUrl;
  final List<String> galleryUrls;
  final String address;
  final String country;
  final String stateProvince;
  final String city;
  final String pinCode;
  final double? latitude;
  final double? longitude;
  final String contactPerson;
  final String contactNumber;
  final String email;
  final String website;
  final String? ownerId;
  final String ownerName;
  final int? establishedYear;
  final int? capacity;
  final String? boundarySize;
  final ManagedGroundType? groundType;
  final ManagedGroundPitchType? pitchType;
  final Set<ManagedGroundBallType> ballTypes;
  final ManagedGroundAvailability availability;
  final Set<String> facilities;
  final bool floodlights;
  final bool parking;
  final int matchesHosted;
  final double rating;
  final int reviewCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool adminFeatured;
  final bool adminVerified;
  final ManagedGroundStatus adminStatus;
  final AdminGroundRecordStatus recordStatus;
  final String? organizationId;
  final DateTime? deletedAt;
  final String? deletedBy;
  final List<String> tournamentIds;
  final GroundDataSource source;

  bool get isSoftDeleted => recordStatus.isSoftDeleted;
  bool get isVerified =>
      adminVerified || adminStatus == ManagedGroundStatus.verified;
  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isTournamentDerived =>
      source == GroundDataSource.tournament || tournamentIds.isNotEmpty;

  ManagedGroundStatus get displayStatus => ManagedGroundStatus.derive(
        recordStatus: recordStatus,
        adminStatus: adminStatus.wireValue,
        adminVerified: adminVerified,
      );

  String get locationLabel {
    final parts = [
      if (city.isNotEmpty) city,
      if (stateProvince.isNotEmpty) stateProvince,
      if (country.isNotEmpty) country,
    ];
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  String get shortLabel =>
      (groundCode != null && groundCode!.isNotEmpty) ? groundCode! : id;

  String get mapsUrl {
    if (hasCoordinates) {
      return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    }
    final q = Uri.encodeComponent(
      [name, address, city, stateProvince, country]
          .where((e) => e.isNotEmpty)
          .join(', '),
    );
    return 'https://www.google.com/maps/search/?api=1&query=$q';
  }

  /// Deterministic id for tournament-derived grounds (stable across refreshes).
  /// Identity is by normalized ground **name** only — tournament city is shared
  /// across multi-ground events and must not create duplicate rows.
  static String stableIdFor({required String name, String city = ''}) {
    final n = normalizeNameKey(name);
    final clipped = n.length > 120 ? n.substring(0, 120) : n;
    return 'tg_$clipped';
  }

  /// Lowercase slug used for de-duplication.
  static String normalizeNameKey(String raw) {
    final s = raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return s.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  factory ManagedGround.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final ballRaw = List<String>.from(map['ballTypes'] as List? ?? const []);
    final facilityRaw =
        List<String>.from(map['facilities'] as List? ?? const []);
    final recordStatus =
        AdminGroundRecordStatus.parse(map['adminRecordStatus'] as String?);
    final adminVerified = map['adminVerified'] as bool? ?? false;
    final tournamentIds =
        List<String>.from(map['tournamentIds'] as List? ?? const []);
    final sourceRaw = map['source'] as String?;

    return ManagedGround(
      id: id,
      name: map['name'] as String? ?? '',
      groundCode: map['groundCode'] as String?,
      description: map['description'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      galleryUrls: List<String>.from(map['galleryUrls'] as List? ?? const []),
      address: map['address'] as String? ?? '',
      country: map['country'] as String? ?? '',
      stateProvince: (map['stateProvince'] as String?) ??
          (map['state'] as String?) ??
          '',
      city: map['city'] as String? ?? '',
      pinCode: map['pinCode'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      contactPerson: map['contactPerson'] as String? ?? '',
      contactNumber: map['contactNumber'] as String? ?? '',
      email: map['email'] as String? ?? '',
      website: map['website'] as String? ?? '',
      ownerId: map['ownerId'] as String?,
      ownerName: map['ownerName'] as String? ?? '',
      establishedYear: (map['establishedYear'] as num?)?.toInt(),
      capacity: (map['capacity'] as num?)?.toInt(),
      boundarySize: map['boundarySize'] as String?,
      groundType: ManagedGroundType.tryParse(map['groundType'] as String?),
      pitchType: ManagedGroundPitchType.tryParse(map['pitchType'] as String?),
      ballTypes: {
        for (final b in ballRaw)
          if (ManagedGroundBallType.tryParse(b) != null)
            ManagedGroundBallType.tryParse(b)!,
      },
      availability:
          ManagedGroundAvailability.parse(map['availability'] as String?),
      facilities: facilityRaw.toSet(),
      floodlights: map['floodlights'] as bool? ??
          facilityRaw.contains(GroundFacilityKeys.floodlights),
      parking: map['parking'] as bool? ??
          facilityRaw.contains(GroundFacilityKeys.parking),
      matchesHosted: (map['matchesHosted'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      adminFeatured: map['adminFeatured'] as bool? ?? false,
      adminVerified: adminVerified,
      adminStatus: ManagedGroundStatus.parse(map['adminStatus'] as String?),
      recordStatus: recordStatus,
      organizationId: map['organizationId'] as String?,
      deletedAt: _parseDate(map['adminDeletedAt']),
      deletedBy: map['adminDeletedBy'] as String?,
      tournamentIds: tournamentIds,
      source: GroundDataSource.parse(sourceRaw) ??
          (tournamentIds.isNotEmpty
              ? GroundDataSource.tournament
              : GroundDataSource.registry),
    );
  }

  Map<String, dynamic> toCreateMap({required String actorUid}) {
    final now = DateTime.now().toIso8601String();
    return {
      'name': name,
      if (groundCode != null) 'groundCode': groundCode,
      'description': description,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'galleryUrls': galleryUrls,
      'address': address,
      'country': country,
      'stateProvince': stateProvince,
      'city': city,
      'pinCode': pinCode,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'contactPerson': contactPerson,
      'contactNumber': contactNumber,
      'email': email,
      'website': website,
      if (ownerId != null) 'ownerId': ownerId,
      'ownerName': ownerName,
      if (establishedYear != null) 'establishedYear': establishedYear,
      if (capacity != null) 'capacity': capacity,
      if (boundarySize != null) 'boundarySize': boundarySize,
      if (groundType != null) 'groundType': groundType!.wireValue,
      if (pitchType != null) 'pitchType': pitchType!.wireValue,
      'ballTypes': ballTypes.map((e) => e.wireValue).toList(),
      'availability': availability.wireValue,
      'facilities': facilities.toList(),
      'floodlights': floodlights,
      'parking': parking,
      'matchesHosted': matchesHosted,
      'rating': rating,
      'reviewCount': reviewCount,
      'adminFeatured': adminFeatured,
      'adminVerified': adminVerified,
      'adminStatus': adminStatus.wireValue,
      'adminRecordStatus': recordStatus.wireValue,
      if (organizationId != null) 'organizationId': organizationId,
      'tournamentIds': tournamentIds,
      'source': source.wireValue,
      'createdBy': actorUid,
      'createdAt': now,
      'updatedAt': now,
    };
  }

  ManagedGround copyWith({
    String? description,
    bool? adminFeatured,
    bool? adminVerified,
    ManagedGroundStatus? adminStatus,
    AdminGroundRecordStatus? recordStatus,
    List<String>? tournamentIds,
    GroundDataSource? source,
    int? matchesHosted,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? organizationId,
    double? latitude,
    double? longitude,
    String? country,
    String? stateProvince,
    String? city,
    String? address,
  }) {
    return ManagedGround(
      id: id,
      name: name,
      groundCode: groundCode,
      description: description ?? this.description,
      photoUrl: photoUrl,
      galleryUrls: galleryUrls,
      address: address ?? this.address,
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      city: city ?? this.city,
      pinCode: pinCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      contactPerson: contactPerson,
      contactNumber: contactNumber,
      email: email,
      website: website,
      ownerId: ownerId,
      ownerName: ownerName,
      establishedYear: establishedYear,
      capacity: capacity,
      boundarySize: boundarySize,
      groundType: groundType,
      pitchType: pitchType,
      ballTypes: ballTypes,
      availability: availability,
      facilities: facilities,
      floodlights: floodlights,
      parking: parking,
      matchesHosted: matchesHosted ?? this.matchesHosted,
      rating: rating,
      reviewCount: reviewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      adminFeatured: adminFeatured ?? this.adminFeatured,
      adminVerified: adminVerified ?? this.adminVerified,
      adminStatus: adminStatus ?? this.adminStatus,
      recordStatus: recordStatus ?? this.recordStatus,
      organizationId: organizationId ?? this.organizationId,
      deletedAt: deletedAt,
      deletedBy: deletedBy,
      tournamentIds: tournamentIds ?? this.tournamentIds,
      source: source ?? this.source,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        raw > 9999999999 ? raw : raw * 1000,
      );
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        adminFeatured,
        adminVerified,
        adminStatus,
        recordStatus,
        updatedAt,
        tournamentIds,
      ];
}

enum GroundDataSource {
  tournament,
  registry;

  String get wireValue => name;

  static GroundDataSource? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final v in GroundDataSource.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

class GroundPageResult {
  const GroundPageResult({
    required this.grounds,
    required this.hasMore,
    this.pageCursor,
  });

  final List<ManagedGround> grounds;
  final bool hasMore;

  /// Last ground id on this page (for offset pagination of the catalog).
  final String? pageCursor;
}

class GroundSummaryStats {
  const GroundSummaryStats({
    this.total = 0,
    this.verified = 0,
    this.active = 0,
    this.pendingVerification = 0,
    this.indoor = 0,
    this.outdoor = 0,
    this.turf = 0,
    this.matting = 0,
  });

  final int total;
  final int verified;
  final int active;
  final int pendingVerification;
  final int indoor;
  final int outdoor;
  final int turf;
  final int matting;
}
