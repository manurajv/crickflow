import 'package:equatable/equatable.dart';

enum TournamentTeamRequestType {
  invitation,
  joinRequest,
}

enum TournamentTeamRequestStatus {
  pending,
  approved,
  rejected,
  withdrawn,
}

/// UI-facing status for chips in the teams tab.
enum TournamentTeamDisplayStatus {
  invited,
  pendingApproval,
  approved,
  rejected,
  withdrawn,
}

class TournamentTeamRequestModel extends Equatable {
  const TournamentTeamRequestModel({
    required this.id,
    required this.tournamentId,
    required this.teamId,
    required this.requestType,
    required this.status,
    required this.requestedByUserId,
    this.tournamentName = '',
    this.teamName = '',
    this.approvedByUserId,
    this.rejectedByUserId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tournamentId;
  final String teamId;
  final TournamentTeamRequestType requestType;
  final TournamentTeamRequestStatus status;
  final String requestedByUserId;
  final String tournamentName;
  final String teamName;
  final String? approvedByUserId;
  final String? rejectedByUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == TournamentTeamRequestStatus.pending;

  TournamentTeamDisplayStatus get displayStatus {
    return switch (status) {
      TournamentTeamRequestStatus.approved => TournamentTeamDisplayStatus.approved,
      TournamentTeamRequestStatus.rejected => TournamentTeamDisplayStatus.rejected,
      TournamentTeamRequestStatus.withdrawn => TournamentTeamDisplayStatus.withdrawn,
      TournamentTeamRequestStatus.pending =>
        requestType == TournamentTeamRequestType.invitation
            ? TournamentTeamDisplayStatus.invited
            : TournamentTeamDisplayStatus.pendingApproval,
    };
  }

  factory TournamentTeamRequestModel.fromMap(String id, Map<String, dynamic> map) {
    return TournamentTeamRequestModel(
      id: id,
      tournamentId: map['tournamentId'] as String? ?? '',
      teamId: map['teamId'] as String? ?? '',
      requestType: _typeFromString(map['requestType'] as String?),
      status: _statusFromString(map['status'] as String?),
      requestedByUserId: map['requestedByUserId'] as String? ?? '',
      tournamentName: map['tournamentName'] as String? ?? '',
      teamName: map['teamName'] as String? ?? '',
      approvedByUserId: map['approvedByUserId'] as String?,
      rejectedByUserId: map['rejectedByUserId'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentId': tournamentId,
        'teamId': teamId,
        'requestType': requestType == TournamentTeamRequestType.joinRequest
            ? 'join_request'
            : 'invitation',
        'status': status.name,
        'requestedByUserId': requestedByUserId,
        'tournamentName': tournamentName,
        'teamName': teamName,
        if (approvedByUserId != null) 'approvedByUserId': approvedByUserId,
        if (rejectedByUserId != null) 'rejectedByUserId': rejectedByUserId,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  static TournamentTeamRequestType _typeFromString(String? raw) {
    if (raw == 'join_request') {
      return TournamentTeamRequestType.joinRequest;
    }
    return TournamentTeamRequestType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => TournamentTeamRequestType.invitation,
    );
  }

  static TournamentTeamRequestStatus _statusFromString(String? raw) {
    return TournamentTeamRequestStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => TournamentTeamRequestStatus.pending,
    );
  }

  @override
  List<Object?> get props => [id, tournamentId, teamId, status, requestType];
}

String tournamentTeamDisplayStatusLabel(TournamentTeamDisplayStatus status) =>
    switch (status) {
      TournamentTeamDisplayStatus.invited => 'Invited',
      TournamentTeamDisplayStatus.pendingApproval => 'Pending approval',
      TournamentTeamDisplayStatus.approved => 'Approved',
      TournamentTeamDisplayStatus.rejected => 'Rejected',
      TournamentTeamDisplayStatus.withdrawn => 'Withdrawn',
    };
