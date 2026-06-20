import 'package:equatable/equatable.dart';

import 'match_player_snapshot.dart';

/// Named official assigned during match setup (snapshot at match creation).
class MatchOfficialEntry extends Equatable {
  const MatchOfficialEntry({
    this.playerId,
    this.userId,
    required this.name,
    this.email,
    this.photoUrl,
    this.slotLabel = '',
  });

  final String? playerId;
  final String? userId;
  final String name;
  final String? email;
  final String? photoUrl;
  final String slotLabel;

  Map<String, dynamic> toMap() => {
        if (playerId != null && playerId!.isNotEmpty) 'playerId': playerId,
        if (userId != null && userId!.isNotEmpty) 'userId': userId,
        'name': name,
        if (email != null) 'email': email,
        if (photoUrl != null && photoUrl!.isNotEmpty) 'profilePhoto': photoUrl,
        if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
        if (slotLabel.isNotEmpty) 'slotLabel': slotLabel,
      };

  factory MatchOfficialEntry.fromMap(Map<String, dynamic> map) {
    return MatchOfficialEntry(
      playerId: map['playerId'] as String?,
      userId: map['userId'] as String?,
      name: map['name'] as String? ?? '',
      email: map['email'] as String?,
      photoUrl: map['profilePhoto'] as String? ?? map['photoUrl'] as String?,
      slotLabel: map['slotLabel'] as String? ?? '',
    );
  }

  MatchOfficialEntry copyWith({
    String? playerId,
    String? userId,
    String? name,
    String? email,
    String? photoUrl,
    String? slotLabel,
  }) {
    return MatchOfficialEntry(
      playerId: playerId ?? this.playerId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      slotLabel: slotLabel ?? this.slotLabel,
    );
  }

  @override
  List<Object?> get props =>
      [playerId, userId, name, email, photoUrl, slotLabel];
}

/// Squad + toss data collected before the match goes live.
class MatchSetupData extends Equatable {
  const MatchSetupData({
    this.teamAPlayingPlayers = const [],
    this.teamASubstitutePlayers = const [],
    this.teamBPlayingPlayers = const [],
    this.teamBSubstitutePlayers = const [],
    this.teamACaptainId,
    this.teamAViceCaptainId,
    this.teamAWicketKeeperId,
    this.teamBCaptainId,
    this.teamBViceCaptainId,
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
  final String? teamAViceCaptainId;
  final String? teamAWicketKeeperId;
  final String? teamBCaptainId;
  final String? teamBViceCaptainId;
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

  String? get scorer1UserId =>
      scorers.isNotEmpty ? scorers.first.userId : null;

  String? get scorer2UserId =>
      scorers.length > 1 ? scorers[1].userId : null;

  /// Snapshots team vice-captain ids when they are in the playing XI.
  MatchSetupData withViceCaptainsFromTeams({
    String? teamAViceCaptainId,
    String? teamBViceCaptainId,
  }) {
    final playingA = teamAPlayingPlayers.map((p) => p.id).toSet();
    final playingB = teamBPlayingPlayers.map((p) => p.id).toSet();
    return copyWith(
      teamAViceCaptainId:
          teamAViceCaptainId != null && playingA.contains(teamAViceCaptainId)
              ? teamAViceCaptainId
              : null,
      teamBViceCaptainId:
          teamBViceCaptainId != null && playingB.contains(teamBViceCaptainId)
              ? teamBViceCaptainId
              : null,
    );
  }

  MatchSetupData copyWith({
    List<MatchPlayerSnapshot>? teamAPlayingPlayers,
    List<MatchPlayerSnapshot>? teamASubstitutePlayers,
    List<MatchPlayerSnapshot>? teamBPlayingPlayers,
    List<MatchPlayerSnapshot>? teamBSubstitutePlayers,
    String? teamACaptainId,
    String? teamAViceCaptainId,
    String? teamAWicketKeeperId,
    String? teamBCaptainId,
    String? teamBViceCaptainId,
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
      teamAViceCaptainId: teamAViceCaptainId ?? this.teamAViceCaptainId,
      teamAWicketKeeperId: teamAWicketKeeperId ?? this.teamAWicketKeeperId,
      teamBCaptainId: teamBCaptainId ?? this.teamBCaptainId,
      teamBViceCaptainId: teamBViceCaptainId ?? this.teamBViceCaptainId,
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
      if (teamAViceCaptainId != null) 'teamAViceCaptainId': teamAViceCaptainId,
      if (teamAWicketKeeperId != null) 'teamAWicketKeeperId': teamAWicketKeeperId,
      if (teamBCaptainId != null) 'teamBCaptainId': teamBCaptainId,
      if (teamBViceCaptainId != null) 'teamBViceCaptainId': teamBViceCaptainId,
      if (teamBWicketKeeperId != null) 'teamBWicketKeeperId': teamBWicketKeeperId,
      'officials': _officialsToMap(),
      if (scorer1UserId != null) 'scorer1UserId': scorer1UserId,
      if (scorer2UserId != null) 'scorer2UserId': scorer2UserId,
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
      teamAViceCaptainId: map['teamAViceCaptainId'] as String?,
      teamAWicketKeeperId: map['teamAWicketKeeperId'] as String?,
      teamBCaptainId: map['teamBCaptainId'] as String?,
      teamBViceCaptainId: map['teamBViceCaptainId'] as String?,
      teamBWicketKeeperId: map['teamBWicketKeeperId'] as String?,
      umpires: _umpiresFromOfficials(officials),
      scorers: _scorersFromOfficials(officials, map),
      commentators: _commentatorsFromOfficials(officials),
      referee: _refereeFromOfficials(officials),
      liveStreamers: _streamersFromOfficials(officials),
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

  Map<String, dynamic> _officialsToMap() {
    final map = <String, dynamic>{
      'umpires': umpires.map((e) => e.toMap()).toList(),
      'scorers': scorers.map((e) => e.toMap()).toList(),
      'commentators': commentators.map((e) => e.toMap()).toList(),
      'liveStreamers': liveStreamers.map((e) => e.toMap()).toList(),
    };
    if (referee != null) {
      map['referee'] = referee!.toMap();
      map['matchReferee'] = referee!.toMap();
    }

    const umpireKeys = ['umpire1', 'umpire2', 'thirdUmpire', 'umpire4'];
    for (var i = 0; i < umpires.length && i < umpireKeys.length; i++) {
      if (umpires[i].name.isNotEmpty) {
        map[umpireKeys[i]] = umpires[i].toMap();
      }
    }
    if (scorers.isNotEmpty && scorers.first.name.isNotEmpty) {
      map['scorer1'] = scorers.first.toMap();
    }
    if (scorers.length > 1 && scorers[1].name.isNotEmpty) {
      map['scorer2'] = scorers[1].toMap();
    }
    for (var i = 0; i < commentators.length && i < 2; i++) {
      if (commentators[i].name.isNotEmpty) {
        map[i == 0 ? 'commentator1' : 'commentator2'] =
            commentators[i].toMap();
      }
    }
    if (liveStreamers.isNotEmpty && liveStreamers.first.name.isNotEmpty) {
      map['liveStreamer1'] = liveStreamers.first.toMap();
    }
    return map;
  }

  static List<MatchOfficialEntry> _umpiresFromOfficials(
    Map<String, dynamic>? officials,
  ) {
    if (officials == null) return const [];
    final named = [
      _officialAt(officials, 'umpire1'),
      _officialAt(officials, 'umpire2'),
      _officialAt(officials, 'thirdUmpire'),
      _officialAt(officials, 'umpire4'),
    ].whereType<MatchOfficialEntry>().toList();
    if (named.isNotEmpty) return named;
    return _officialList(officials['umpires']);
  }

  static List<MatchOfficialEntry> _scorersFromOfficials(
    Map<String, dynamic>? officials,
    Map<String, dynamic> map,
  ) {
    if (officials != null) {
      final named = [
        _officialAt(officials, 'scorer1'),
        _officialAt(officials, 'scorer2'),
      ].whereType<MatchOfficialEntry>().toList();
      if (named.isNotEmpty) return named;
      final fromArray = _officialList(officials['scorers']);
      if (fromArray.isNotEmpty) return fromArray;
    }
    return const [];
  }

  static List<MatchOfficialEntry> _commentatorsFromOfficials(
    Map<String, dynamic>? officials,
  ) {
    if (officials == null) return const [];
    final named = [
      _officialAt(officials, 'commentator1'),
      _officialAt(officials, 'commentator2'),
    ].whereType<MatchOfficialEntry>().toList();
    if (named.isNotEmpty) return named;
    return _officialList(officials['commentators']);
  }

  static MatchOfficialEntry? _refereeFromOfficials(
    Map<String, dynamic>? officials,
  ) {
    if (officials == null) return null;
    return _officialAt(officials, 'matchReferee') ??
        _officialAt(officials, 'referee');
  }

  static List<MatchOfficialEntry> _streamersFromOfficials(
    Map<String, dynamic>? officials,
  ) {
    if (officials == null) return const [];
    final named = [_officialAt(officials, 'liveStreamer1')]
        .whereType<MatchOfficialEntry>()
        .toList();
    if (named.isNotEmpty) return named;
    return _officialList(officials['liveStreamers']);
  }

  static MatchOfficialEntry? _officialAt(
    Map<String, dynamic> officials,
    String key,
  ) {
    final raw = officials[key];
    if (raw is! Map) return null;
    final entry = MatchOfficialEntry.fromMap(Map<String, dynamic>.from(raw));
    return entry.name.isNotEmpty ? entry : null;
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
