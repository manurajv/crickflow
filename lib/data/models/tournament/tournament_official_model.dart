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
    this.playerId = '',
    this.photoUrl,
    this.rating = 0,
    this.status = TournamentOfficialStatus.active,
    this.invitedByUserId = '',
    this.createdAt,
  });

  final String id;
  final String tournamentId;
  final String userId;
  final TournamentOfficialRole role;
  final String displayName;
  final String phone;
  final String playerId;
  final String? photoUrl;
  final double rating;
  final TournamentOfficialStatus status;
  final String invitedByUserId;
  final DateTime? createdAt;

  bool get isActive => status == TournamentOfficialStatus.active;
  bool get isPending => status == TournamentOfficialStatus.pending;

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
      playerId: map['playerId'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      status: TournamentOfficialStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TournamentOfficialStatus.active,
      ),
      invitedByUserId: map['invitedByUserId'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentId': tournamentId,
        'userId': userId,
        'role': role.name,
        'displayName': displayName,
        'phone': phone,
        'playerId': playerId,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'rating': rating,
        'status': status.name,
        'invitedByUserId': invitedByUserId,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  TournamentOfficialModel copyWith({
    TournamentOfficialStatus? status,
    String? displayName,
  }) {
    return TournamentOfficialModel(
      id: id,
      tournamentId: tournamentId,
      userId: userId,
      role: role,
      displayName: displayName ?? this.displayName,
      phone: phone,
      playerId: playerId,
      photoUrl: photoUrl,
      rating: rating,
      status: status ?? this.status,
      invitedByUserId: invitedByUserId,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, role, status];
}
