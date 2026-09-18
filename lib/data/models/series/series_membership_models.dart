import 'package:equatable/equatable.dart';

import 'series_enums.dart';

/// Public Series registration (non-sensitive fields).
/// Sensitive identity lives under `private/identity` subdocument.
class SeriesPlayerRegistrationModel extends Equatable {
  const SeriesPlayerRegistrationModel({
    required this.id,
    required this.seriesId,
    required this.userId,
    this.clubId,
    this.playerDocId,
    this.crickFlowPlayerId,
    this.fullName = '',
    this.phoneNumber = '',
    this.profilePhotoUrl,
    this.dateOfBirth,
    this.address = '',
    this.customFields = const <String, dynamic>{},
    this.hasSensitiveIdentity = false,
    this.status = SeriesApprovalStatus.pending,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String seriesId;
  final String? clubId;
  final String userId;
  final String? playerDocId;
  final String? crickFlowPlayerId;
  final String fullName;
  final String phoneNumber;
  final String? profilePhotoUrl;
  final DateTime? dateOfBirth;
  final String address;
  final Map<String, dynamic> customFields;
  final bool hasSensitiveIdentity;
  final SeriesApprovalStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SeriesPlayerRegistrationModel.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return SeriesPlayerRegistrationModel(
      id: id,
      seriesId: map['seriesId'] as String? ?? '',
      clubId: map['clubId'] as String?,
      userId: map['userId'] as String? ?? '',
      playerDocId: map['playerDocId'] as String?,
      crickFlowPlayerId: map['crickFlowPlayerId'] as String?,
      fullName: map['fullName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      profilePhotoUrl: map['profilePhotoUrl'] as String?,
      dateOfBirth: DateTime.tryParse(map['dateOfBirth']?.toString() ?? ''),
      address: map['address'] as String? ?? '',
      customFields: Map<String, dynamic>.from(
        map['customFields'] as Map? ?? const <String, dynamic>{},
      ),
      hasSensitiveIdentity: map['hasSensitiveIdentity'] as bool? ?? false,
      status: SeriesApprovalStatus.parse(map['status'] as String?),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toPublicMap() => {
        'seriesId': seriesId,
        if (clubId != null) 'clubId': clubId,
        'userId': userId,
        if (playerDocId != null) 'playerDocId': playerDocId,
        if (crickFlowPlayerId != null) 'crickFlowPlayerId': crickFlowPlayerId,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
        'address': address,
        'customFields': customFields,
        'hasSensitiveIdentity': hasSensitiveIdentity,
        'status': status.name,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, seriesId, userId, clubId, status];
}

/// Official approved Series club membership (squad).
class SeriesMembershipModel extends Equatable {
  const SeriesMembershipModel({
    required this.id,
    required this.seriesId,
    required this.clubId,
    required this.userId,
    this.playerDocId,
    this.registrationId,
    this.displayName = '',
    this.status = SeriesMembershipStatus.active,
    this.joinedAt,
    this.leftAt,
  });

  final String id;
  final String seriesId;
  final String clubId;
  final String userId;
  final String? playerDocId;
  final String? registrationId;
  final String displayName;
  final SeriesMembershipStatus status;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  bool get isActive => status == SeriesMembershipStatus.active;

  factory SeriesMembershipModel.fromMap(String id, Map<String, dynamic> map) {
    return SeriesMembershipModel(
      id: id,
      seriesId: map['seriesId'] as String? ?? '',
      clubId: map['clubId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      playerDocId: map['playerDocId'] as String?,
      registrationId: map['registrationId'] as String?,
      displayName: map['displayName'] as String? ?? '',
      status: SeriesMembershipStatus.parse(map['status'] as String?),
      joinedAt: DateTime.tryParse(map['joinedAt']?.toString() ?? ''),
      leftAt: DateTime.tryParse(map['leftAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'seriesId': seriesId,
        'clubId': clubId,
        'userId': userId,
        if (playerDocId != null) 'playerDocId': playerDocId,
        if (registrationId != null) 'registrationId': registrationId,
        'displayName': displayName,
        'status': status.name,
        if (joinedAt != null) 'joinedAt': joinedAt!.toIso8601String(),
        if (leftAt != null) 'leftAt': leftAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, seriesId, clubId, userId, status];
}
