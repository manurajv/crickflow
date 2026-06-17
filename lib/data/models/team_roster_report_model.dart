import 'package:equatable/equatable.dart';

/// Player reports they were added to a team without consent.
class TeamRosterReportModel extends Equatable {
  const TeamRosterReportModel({
    required this.id,
    required this.reporterUserId,
    required this.reporterName,
    required this.teamId,
    required this.teamName,
    required this.playerId,
    this.addedByUserId,
    this.message,
    this.status = 'pending',
    this.createdAt,
  });

  final String id;
  final String reporterUserId;
  final String reporterName;
  final String teamId;
  final String teamName;
  final String playerId;
  final String? addedByUserId;
  final String? message;
  final String status;
  final DateTime? createdAt;

  factory TeamRosterReportModel.fromMap(String id, Map<String, dynamic> map) {
    return TeamRosterReportModel(
      id: id,
      reporterUserId: map['reporterUserId'] as String? ?? '',
      reporterName: map['reporterName'] as String? ?? '',
      teamId: map['teamId'] as String? ?? '',
      teamName: map['teamName'] as String? ?? '',
      playerId: map['playerId'] as String? ?? '',
      addedByUserId: map['addedByUserId'] as String?,
      message: map['message'] as String?,
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'reporterUserId': reporterUserId,
        'reporterName': reporterName,
        'teamId': teamId,
        'teamName': teamName,
        'playerId': playerId,
        if (addedByUserId != null) 'addedByUserId': addedByUserId,
        if (message != null && message!.isNotEmpty) 'message': message,
        'status': status,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  @override
  List<Object?> get props => [id, teamId, playerId, status];
}
