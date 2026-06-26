import 'package:equatable/equatable.dart';

enum TeamJoinRequestStatus { pending, accepted, rejected, cancelled }

enum TeamJoinRequestType { joinRequest, invitation }

class TeamJoinRequestModel extends Equatable {
  const TeamJoinRequestModel({
    required this.id,
    required this.teamId,
    this.teamName = '',
    required this.userId,
    required this.playerId,
    required this.playerName,
    this.playerFullName = '',
    this.playerPhotoUrl,
    this.cfPlayerId,
    this.requestType = TeamJoinRequestType.joinRequest,
    this.invitedByUserId,
    this.status = TeamJoinRequestStatus.pending,
    this.createdAt,
    this.updatedAt,
    this.resolvedBy,
    this.resolvedAt,
  });

  final String id;
  final String teamId;
  final String teamName;
  final String userId;
  final String playerId;
  final String playerName;
  final String playerFullName;
  final String? playerPhotoUrl;
  final String? cfPlayerId;
  final TeamJoinRequestType requestType;
  final String? invitedByUserId;
  final TeamJoinRequestStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;

  String get displayName =>
      playerFullName.isNotEmpty ? playerFullName : playerName;

  bool get isPending => status == TeamJoinRequestStatus.pending;

  bool get isInvitation => requestType == TeamJoinRequestType.invitation;

  factory TeamJoinRequestModel.fromMap(
    String id,
    String teamId,
    Map<String, dynamic> map,
  ) {
    return TeamJoinRequestModel(
      id: id,
      teamId: teamId,
      teamName: map['teamName'] as String? ?? '',
      userId: map['userId'] as String? ?? id,
      playerId: map['playerId'] as String? ?? id,
      playerName: map['playerName'] as String? ?? '',
      playerFullName: map['playerFullName'] as String? ?? '',
      playerPhotoUrl: map['playerPhotoUrl'] as String?,
      cfPlayerId: map['cfPlayerId'] as String?,
      requestType: _typeFromString(map['requestType'] as String?),
      invitedByUserId: map['invitedByUserId'] as String?,
      status: _statusFromString(map['status'] as String?),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
      resolvedBy: map['resolvedBy'] as String?,
      resolvedAt: DateTime.tryParse(map['resolvedAt']?.toString() ?? ''),
    );
  }

  static TeamJoinRequestStatus _statusFromString(String? raw) {
    return TeamJoinRequestStatus.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => TeamJoinRequestStatus.pending,
    );
  }

  static TeamJoinRequestType _typeFromString(String? raw) {
    if (raw == 'invitation') return TeamJoinRequestType.invitation;
    return TeamJoinRequestType.joinRequest;
  }

  Map<String, dynamic> toMap() => {
        'teamId': teamId,
        if (teamName.isNotEmpty) 'teamName': teamName,
        'userId': userId,
        'playerId': playerId,
        'playerName': playerName,
        if (playerFullName.isNotEmpty) 'playerFullName': playerFullName,
        if (playerPhotoUrl != null) 'playerPhotoUrl': playerPhotoUrl,
        if (cfPlayerId != null) 'cfPlayerId': cfPlayerId,
        'requestType': requestType == TeamJoinRequestType.invitation
            ? 'invitation'
            : 'join_request',
        if (invitedByUserId != null) 'invitedByUserId': invitedByUserId,
        'status': status.name,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
        if (resolvedBy != null) 'resolvedBy': resolvedBy,
        if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, teamId, userId, status, requestType];
}
