import 'package:equatable/equatable.dart';

import 'match_player_snapshot.dart';

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
    this.teamAPlayingPlayers = const [],
    this.teamASubstitutePlayers = const [],
    this.teamBPlayingPlayers = const [],
    this.teamBSubstitutePlayers = const [],
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

  final List<MatchPlayerSnapshot> teamAPlayingPlayers;
  final List<MatchPlayerSnapshot> teamASubstitutePlayers;
  final List<MatchPlayerSnapshot> teamBPlayingPlayers;
  final List<MatchPlayerSnapshot> teamBSubstitutePlayers;
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

  List<MatchPlayerSnapshot> playingPlayersForTeam(bool isTeamA) =>
      isTeamA ? teamAPlayingPlayers : teamBPlayingPlayers;

  List<MatchPlayerSnapshot> substitutePlayersForTeam(bool isTeamA) =>
      isTeamA ? teamASubstitutePlayers : teamBSubstitutePlayers;

  /// Legacy flat ids — playing XI only.
  List<String> get teamASquadIds => squadIdsForTeam(true);
  List<String> get teamBSquadIds => squadIdsForTeam(false);

  Map<String, String> get teamASquadNames => squadNamesForTeam(true);
  Map<String, String> get teamBSquadNames => squadNamesForTeam(false);

  /// Playing XI ids only — used for lineup, roles, and scoring eligibility.
  List<String> squadIdsForTeam(bool isTeamA) =>
      playingPlayersForTeam(isTeamA).map((p) => p.id).toList();

  Map<String, String> squadNamesForTeam(bool isTeamA) => {
        for (final p in playingPlayersForTeam(isTeamA)) p.id: p.name,
      };

  MatchPlayerSnapshot? findPlayingSnapshot(bool isTeamA, String id) {
    for (final p in playingPlayersForTeam(isTeamA)) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool get hasTeamASquad => teamAPlayingPlayers.isNotEmpty;
  bool get hasTeamBSquad => teamBPlayingPlayers.isNotEmpty;
  bool get squadsReady => hasTeamASquad && hasTeamBSquad;

  bool playingSquadsReady(int playersPerTeam) =>
      teamAPlayingPlayers.length == playersPerTeam &&
      teamBPlayingPlayers.length == playersPerTeam;

  String? playingSquadError(String teamLabel, int playersPerTeam, bool isTeamA) {
    final count = playingPlayersForTeam(isTeamA).length;
    if (count == playersPerTeam) return null;
    if (count < playersPerTeam) {
      final need = playersPerTeam - count;
      return '$teamLabel requires $need more playing player${need == 1 ? '' : 's'}.';
    }
    return '$teamLabel has ${count - playersPerTeam} too many playing players.';
  }

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

  MatchSetupData copyWith({
    List<MatchPlayerSnapshot>? teamAPlayingPlayers,
    List<MatchPlayerSnapshot>? teamASubstitutePlayers,
    List<MatchPlayerSnapshot>? teamBPlayingPlayers,
    List<MatchPlayerSnapshot>? teamBSubstitutePlayers,
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
      teamAPlayingPlayers: teamAPlayingPlayers ?? this.teamAPlayingPlayers,
      teamASubstitutePlayers:
          teamASubstitutePlayers ?? this.teamASubstitutePlayers,
      teamBPlayingPlayers: teamBPlayingPlayers ?? this.teamBPlayingPlayers,
      teamBSubstitutePlayers:
          teamBSubstitutePlayers ?? this.teamBSubstitutePlayers,
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

  Map<String, dynamic> toMap() {
    final playingA = teamAPlayingPlayers.map((e) => e.toMap()).toList();
    final playingB = teamBPlayingPlayers.map((e) => e.toMap()).toList();
    return {
      'teamAPlayingPlayers': playingA,
      'teamASubstitutePlayers':
          teamASubstitutePlayers.map((e) => e.toMap()).toList(),
      'teamBPlayingPlayers': playingB,
      'teamBSubstitutePlayers':
          teamBSubstitutePlayers.map((e) => e.toMap()).toList(),
      // Legacy flat ids for older clients — playing XI only.
      'teamASquadIds': playingA.map((e) => e['id']).toList(),
      'teamBSquadIds': playingB.map((e) => e['id']).toList(),
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
  }

  factory MatchSetupData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MatchSetupData();
    final officials = map['officials'] as Map<String, dynamic>?;

    var playingA = _snapshotList(map['teamAPlayingPlayers']);
    var playingB = _snapshotList(map['teamBPlayingPlayers']);
    final subsA = _snapshotList(map['teamASubstitutePlayers']);
    final subsB = _snapshotList(map['teamBSubstitutePlayers']);

    if (playingA.isEmpty) {
      playingA = _legacySnapshots(_stringList(map['teamASquadIds']));
    }
    if (playingB.isEmpty) {
      playingB = _legacySnapshots(_stringList(map['teamBSquadIds']));
    }

    return MatchSetupData(
      teamAPlayingPlayers: playingA,
      teamASubstitutePlayers: subsA,
      teamBPlayingPlayers: playingB,
      teamBSubstitutePlayers: subsB,
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

  static List<MatchPlayerSnapshot> _snapshotList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => MatchPlayerSnapshot.fromMap(Map<String, dynamic>.from(e)))
        .where((p) => p.id.isNotEmpty)
        .toList();
  }

  static List<MatchPlayerSnapshot> _legacySnapshots(List<String> ids) {
    return ids
        .map(
          (id) => MatchPlayerSnapshot(
            id: id,
            name: 'Player',
          ),
        )
        .toList();
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
        teamAPlayingPlayers,
        teamBPlayingPlayers,
        teamACaptainId,
        tossWinnerIsTeamA,
      ];
}
