import 'package:equatable/equatable.dart';

enum FantasyLeagueStatus { open, locked, closed }

class FantasyLeagueModel extends Equatable {
  const FantasyLeagueModel({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.matchId,
    required this.matchTitle,
    required this.createdBy,
    this.status = FantasyLeagueStatus.open,
    this.squadSize = 11,
    this.captainMultiplier = 2.0,
    this.viceCaptainMultiplier = 1.5,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String joinCode;
  final String matchId;
  final String matchTitle;
  final String createdBy;
  final FantasyLeagueStatus status;
  final int squadSize;
  final double captainMultiplier;
  final double viceCaptainMultiplier;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOpen => status == FantasyLeagueStatus.open;

  factory FantasyLeagueModel.fromMap(String id, Map<String, dynamic> map) {
    return FantasyLeagueModel(
      id: id,
      name: map['name'] as String? ?? 'Fantasy League',
      joinCode: map['joinCode'] as String? ?? '',
      matchId: map['matchId'] as String? ?? '',
      matchTitle: map['matchTitle'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      status: FantasyLeagueStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => FantasyLeagueStatus.open,
      ),
      squadSize: map['squadSize'] as int? ?? 11,
      captainMultiplier: (map['captainMultiplier'] as num?)?.toDouble() ?? 2.0,
      viceCaptainMultiplier:
          (map['viceCaptainMultiplier'] as num?)?.toDouble() ?? 1.5,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'joinCode': joinCode,
      'matchId': matchId,
      'matchTitle': matchTitle,
      'createdBy': createdBy,
      'status': status.name,
      'squadSize': squadSize,
      'captainMultiplier': captainMultiplier,
      'viceCaptainMultiplier': viceCaptainMultiplier,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  FantasyLeagueModel copyWith({
    String? name,
    FantasyLeagueStatus? status,
    DateTime? updatedAt,
  }) {
    return FantasyLeagueModel(
      id: id,
      name: name ?? this.name,
      joinCode: joinCode,
      matchId: matchId,
      matchTitle: matchTitle,
      createdBy: createdBy,
      status: status ?? this.status,
      squadSize: squadSize,
      captainMultiplier: captainMultiplier,
      viceCaptainMultiplier: viceCaptainMultiplier,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [id, joinCode, matchId, status];
}
