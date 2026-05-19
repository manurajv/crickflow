import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';

class BadgeModel extends Equatable {
  const BadgeModel({
    required this.id,
    required this.title,
    required this.type,
    this.description = '',
    this.iconName = 'star',
    this.playerId,
    this.teamId,
    this.matchId,
    this.earnedAt,
  });

  final String id;
  final String title;
  final BadgeType type;
  final String description;
  final String iconName;
  final String? playerId;
  final String? teamId;
  final String? matchId;
  final DateTime? earnedAt;

  factory BadgeModel.fromMap(String id, Map<String, dynamic> map) {
    return BadgeModel(
      id: id,
      title: map['title'] as String? ?? '',
      type: BadgeType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => BadgeType.milestone,
      ),
      description: map['description'] as String? ?? '',
      iconName: map['iconName'] as String? ?? 'star',
      playerId: map['playerId'] as String?,
      teamId: map['teamId'] as String?,
      matchId: map['matchId'] as String?,
      earnedAt: DateTime.tryParse(map['earnedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'type': type.name,
        'description': description,
        'iconName': iconName,
        if (playerId != null) 'playerId': playerId,
        if (teamId != null) 'teamId': teamId,
        if (matchId != null) 'matchId': matchId,
        'earnedAt': (earnedAt ?? DateTime.now()).toIso8601String(),
      };

  @override
  List<Object?> get props => [id, title, type];
}
