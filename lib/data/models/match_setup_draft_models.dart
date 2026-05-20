import 'package:equatable/equatable.dart';

/// Named official assigned during match setup.
class MatchOfficialEntry extends Equatable {
  const MatchOfficialEntry({
    this.playerId,
    required this.name,
    this.email,
    this.slotLabel = '',
  });

  final String? playerId;
  final String name;
  final String? email;
  final String slotLabel;

  Map<String, dynamic> toMap() => {
        if (playerId != null) 'playerId': playerId,
        'name': name,
        if (email != null) 'email': email,
        if (slotLabel.isNotEmpty) 'slotLabel': slotLabel,
      };

  factory MatchOfficialEntry.fromMap(Map<String, dynamic> map) {
    return MatchOfficialEntry(
      playerId: map['playerId'] as String?,
      name: map['name'] as String? ?? '',
      email: map['email'] as String?,
      slotLabel: map['slotLabel'] as String? ?? '',
    );
  }

  MatchOfficialEntry copyWith({
    String? playerId,
    String? name,
    String? email,
    String? slotLabel,
  }) {
    return MatchOfficialEntry(
      playerId: playerId ?? this.playerId,
      name: name ?? this.name,
      email: email ?? this.email,
      slotLabel: slotLabel ?? this.slotLabel,
    );
  }

  @override
  List<Object?> get props => [playerId, name, email, slotLabel];
}

/// Squad + toss data collected before the match goes live.
class MatchSetupData extends Equatable {
  const MatchSetupData({
    this.teamASquadIds = const [],
    this.teamBSquadIds = const [],
    this.teamASquadNames = const {},
    this.teamBSquadNames = const {},
    this.teamACaptainId,
    this.teamAWicketKeeperId,
    this.teamBCaptainId,
    this.teamBWicketKeeperId,
    this.umpires = const [],
    this.scorers = const [],
    this.commentators = const [],
    this.referee,
    this.liveStreamers = const [],
    this.tossWinnerIsTeamA,
    this.tossWinnerBatsFirst,
    this.coinResult,
  });

  final List<String> teamASquadIds;
  final List<String> teamBSquadIds;
  final Map<String, String> teamASquadNames;
  final Map<String, String> teamBSquadNames;
  final String? teamACaptainId;
  final String? teamAWicketKeeperId;
  final String? teamBCaptainId;
  final String? teamBWicketKeeperId;
  final List<MatchOfficialEntry> umpires;
  final List<MatchOfficialEntry> scorers;
  final List<MatchOfficialEntry> commentators;
  final MatchOfficialEntry? referee;
  final List<MatchOfficialEntry> liveStreamers;
  final bool? tossWinnerIsTeamA;
  final bool? tossWinnerBatsFirst;
  final String? coinResult;

  bool get hasTeamASquad => teamASquadIds.isNotEmpty;
  bool get hasTeamBSquad => teamBSquadIds.isNotEmpty;
  bool get squadsReady => hasTeamASquad && hasTeamBSquad;

  bool get teamARolesReady =>
      teamACaptainId != null &&
      teamACaptainId!.isNotEmpty &&
      teamAWicketKeeperId != null &&
      teamAWicketKeeperId!.isNotEmpty;

  bool get teamBRolesReady =>
      teamBCaptainId != null &&
      teamBCaptainId!.isNotEmpty &&
      teamBWicketKeeperId != null &&
      teamBWicketKeeperId!.isNotEmpty;

  bool get rolesReady => teamARolesReady && teamBRolesReady;

  bool get tossReady =>
      tossWinnerIsTeamA != null && tossWinnerBatsFirst != null;

  List<String> squadIdsForTeam(bool isTeamA) =>
      isTeamA ? teamASquadIds : teamBSquadIds;

  Map<String, String> squadNamesForTeam(bool isTeamA) =>
      isTeamA ? teamASquadNames : teamBSquadNames;

  MatchSetupData copyWith({
    List<String>? teamASquadIds,
    List<String>? teamBSquadIds,
    Map<String, String>? teamASquadNames,
    Map<String, String>? teamBSquadNames,
    String? teamACaptainId,
    String? teamAWicketKeeperId,
    String? teamBCaptainId,
    String? teamBWicketKeeperId,
    List<MatchOfficialEntry>? umpires,
    List<MatchOfficialEntry>? scorers,
    List<MatchOfficialEntry>? commentators,
    MatchOfficialEntry? referee,
    bool clearReferee = false,
    List<MatchOfficialEntry>? liveStreamers,
    bool? tossWinnerIsTeamA,
    bool? tossWinnerBatsFirst,
    String? coinResult,
  }) {
    return MatchSetupData(
      teamASquadIds: teamASquadIds ?? this.teamASquadIds,
      teamBSquadIds: teamBSquadIds ?? this.teamBSquadIds,
      teamASquadNames: teamASquadNames ?? this.teamASquadNames,
      teamBSquadNames: teamBSquadNames ?? this.teamBSquadNames,
      teamACaptainId: teamACaptainId ?? this.teamACaptainId,
      teamAWicketKeeperId: teamAWicketKeeperId ?? this.teamAWicketKeeperId,
      teamBCaptainId: teamBCaptainId ?? this.teamBCaptainId,
      teamBWicketKeeperId: teamBWicketKeeperId ?? this.teamBWicketKeeperId,
      umpires: umpires ?? this.umpires,
      scorers: scorers ?? this.scorers,
      commentators: commentators ?? this.commentators,
      referee: clearReferee ? null : (referee ?? this.referee),
      liveStreamers: liveStreamers ?? this.liveStreamers,
      tossWinnerIsTeamA: tossWinnerIsTeamA ?? this.tossWinnerIsTeamA,
      tossWinnerBatsFirst: tossWinnerBatsFirst ?? this.tossWinnerBatsFirst,
      coinResult: coinResult ?? this.coinResult,
    );
  }

  Map<String, dynamic> toMap() => {
        'teamASquadIds': teamASquadIds,
        'teamBSquadIds': teamBSquadIds,
        if (teamACaptainId != null) 'teamACaptainId': teamACaptainId,
        if (teamAWicketKeeperId != null) 'teamAWicketKeeperId': teamAWicketKeeperId,
        if (teamBCaptainId != null) 'teamBCaptainId': teamBCaptainId,
        if (teamBWicketKeeperId != null) 'teamBWicketKeeperId': teamBWicketKeeperId,
        'officials': {
          'umpires': umpires.map((e) => e.toMap()).toList(),
          'scorers': scorers.map((e) => e.toMap()).toList(),
          'commentators': commentators.map((e) => e.toMap()).toList(),
          if (referee != null) 'referee': referee!.toMap(),
          'liveStreamers': liveStreamers.map((e) => e.toMap()).toList(),
        },
        if (tossWinnerIsTeamA != null) 'tossWinnerIsTeamA': tossWinnerIsTeamA,
        if (tossWinnerBatsFirst != null) 'tossWinnerBatsFirst': tossWinnerBatsFirst,
        if (coinResult != null) 'coinResult': coinResult,
      };

  factory MatchSetupData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MatchSetupData();
    final officials = map['officials'] as Map<String, dynamic>?;
    return MatchSetupData(
      teamASquadIds: _stringList(map['teamASquadIds']),
      teamBSquadIds: _stringList(map['teamBSquadIds']),
      teamACaptainId: map['teamACaptainId'] as String?,
      teamAWicketKeeperId: map['teamAWicketKeeperId'] as String?,
      teamBCaptainId: map['teamBCaptainId'] as String?,
      teamBWicketKeeperId: map['teamBWicketKeeperId'] as String?,
      umpires: _officialList(officials?['umpires']),
      scorers: _officialList(officials?['scorers']),
      commentators: _officialList(officials?['commentators']),
      referee: officials?['referee'] is Map
          ? MatchOfficialEntry.fromMap(
              officials!['referee'] as Map<String, dynamic>,
            )
          : null,
      liveStreamers: _officialList(officials?['liveStreamers']),
      tossWinnerIsTeamA: map['tossWinnerIsTeamA'] as bool?,
      tossWinnerBatsFirst: map['tossWinnerBatsFirst'] as bool?,
      coinResult: map['coinResult'] as String?,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e.toString()).toList();
  }

  static List<MatchOfficialEntry> _officialList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => MatchOfficialEntry.fromMap(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }

  @override
  List<Object?> get props => [
        teamASquadIds,
        teamBSquadIds,
        teamACaptainId,
        teamAWicketKeeperId,
        tossWinnerIsTeamA,
      ];
}
