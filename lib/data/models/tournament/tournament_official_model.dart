import 'package:equatable/equatable.dart';
import '../../../core/constants/enums.dart';

class TournamentOfficialModel extends Equatable {
  const TournamentOfficialModel({
    required this.id,
    required this.tournamentId,
    required this.userId,
    required this.role,
    this.displayName = '',
    this.phone = '',
    this.rating = 0,
    this.createdAt,
  });

  final String id;
  final String tournamentId;
  final String userId;
  final TournamentOfficialRole role;
  final String displayName;
  final String phone;
  final double rating;
  final DateTime? createdAt;

  factory TournamentOfficialModel.fromMap(String id, Map<String, dynamic> map) {
    return TournamentOfficialModel(
      id: id,
      tournamentId: map['tournamentId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      role: TournamentOfficialRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => TournamentOfficialRole.scorer,
      ),
      displayName: map['displayName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentId': tournamentId,
        'userId': userId,
        'role': role.name,
        'displayName': displayName,
        'phone': phone,
        'rating': rating,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, userId, role];
}
