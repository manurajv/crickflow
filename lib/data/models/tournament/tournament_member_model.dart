import 'package:equatable/equatable.dart';
import '../../../core/constants/enums.dart';

class TournamentMemberModel extends Equatable {
  const TournamentMemberModel({
    required this.id,
    required this.tournamentId,
    required this.userId,
    this.role = TournamentRole.viewer,
    this.displayName = '',
    this.addedBy,
    this.createdAt,
  });

  final String id;
  final String tournamentId;
  final String userId;
  final TournamentRole role;
  final String displayName;
  final String? addedBy;
  final DateTime? createdAt;

  factory TournamentMemberModel.fromMap(String id, Map<String, dynamic> map) {
    return TournamentMemberModel(
      id: id,
      tournamentId: map['tournamentId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      role: TournamentRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => TournamentRole.viewer,
      ),
      displayName: map['displayName'] as String? ?? '',
      addedBy: map['addedBy'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentId': tournamentId,
        'userId': userId,
        'role': role.name,
        'displayName': displayName,
        if (addedBy != null) 'addedBy': addedBy,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, userId, role];
}
