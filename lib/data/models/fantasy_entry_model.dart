import 'package:equatable/equatable.dart';

class FantasyEntryModel extends Equatable {
  const FantasyEntryModel({
    required this.id,
    required this.leagueId,
    required this.userId,
    required this.displayName,
    this.playerIds = const [],
    this.captainId,
    this.viceCaptainId,
    this.totalPoints = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String leagueId;
  final String userId;
  final String displayName;
  final List<String> playerIds;
  final String? captainId;
  final String? viceCaptainId;
  final double totalPoints;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasSquad =>
      playerIds.length >= 11 && captainId != null && viceCaptainId != null;

  factory FantasyEntryModel.fromMap(String id, Map<String, dynamic> map) {
    return FantasyEntryModel(
      id: id,
      leagueId: map['leagueId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Player',
      playerIds: List<String>.from(map['playerIds'] as List? ?? []),
      captainId: map['captainId'] as String?,
      viceCaptainId: map['viceCaptainId'] as String?,
      totalPoints: (map['totalPoints'] as num?)?.toDouble() ?? 0,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leagueId': leagueId,
      'userId': userId,
      'displayName': displayName,
      'playerIds': playerIds,
      if (captainId != null) 'captainId': captainId,
      if (viceCaptainId != null) 'viceCaptainId': viceCaptainId,
      'totalPoints': totalPoints,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  FantasyEntryModel copyWith({
    List<String>? playerIds,
    String? captainId,
    String? viceCaptainId,
    double? totalPoints,
    DateTime? updatedAt,
  }) {
    return FantasyEntryModel(
      id: id,
      leagueId: leagueId,
      userId: userId,
      displayName: displayName,
      playerIds: playerIds ?? this.playerIds,
      captainId: captainId ?? this.captainId,
      viceCaptainId: viceCaptainId ?? this.viceCaptainId,
      totalPoints: totalPoints ?? this.totalPoints,
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
  List<Object?> get props => [id, leagueId, userId, totalPoints];
}
