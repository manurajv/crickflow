import 'package:equatable/equatable.dart';

import '../../../data/models/series/series.dart';

/// Who may propose a match or tournament in an org besides its owner and
/// admins (who always start directly).
enum OrgProposeAccess {
  /// Nobody else: only the owner and org admins.
  admins,

  /// Admins of an approved org team (default).
  teamAdmins,

  /// Team admins and every active player of an approved org team.
  everyone;

  String get wire => name;

  String get label => switch (this) {
        OrgProposeAccess.admins => 'Org admins only',
        OrgProposeAccess.teamAdmins => 'Team admins only',
        OrgProposeAccess.everyone => 'Everyone in the team',
      };

  /// [noun] is "matches" or "tournaments".
  String describe(String noun) => switch (this) {
        OrgProposeAccess.admins =>
          'Only the owner and org admins can start or request $noun.',
        OrgProposeAccess.teamAdmins =>
          'Admins of an org team can request $noun. Players cannot.',
        OrgProposeAccess.everyone =>
          'Team admins and every player on an org team can request $noun.',
      };

  static OrgProposeAccess? fromWire(Object? value) {
    for (final v in OrgProposeAccess.values) {
      if (v.name == value) return v;
    }
    return null;
  }
}

/// Org setting: who may propose matches / tournaments (separately), whether
/// each role's requests need approval, and whether walk-in players are allowed.
/// Stored on `series/{id}.competitionPolicy`.
///
/// Older orgs only have one `proposeAccess` / `membersCanRequest` setting and
/// two `*RequestsNeedApproval` flags; they seed both kinds and both roles
/// (`true` → everyone, otherwise team admins) until the owner saves the new
/// permissions. [toMap] also writes those legacy fields (the more permissive
/// access, and "needs approval" when any role needs it) for older app builds.
/// Mirrors `resolvePolicy` in `functions/src/series/seriesCompetitionOps.js`.
class OrgCompetitionPolicy extends Equatable {
  const OrgCompetitionPolicy({
    this.matchProposeAccess = OrgProposeAccess.teamAdmins,
    this.tournamentProposeAccess = OrgProposeAccess.teamAdmins,
    this.matchTeamAdminsNeedApproval = true,
    this.matchPlayersNeedApproval = true,
    this.tournamentTeamAdminsNeedApproval = true,
    this.tournamentPlayersNeedApproval = true,
    this.allowWalkIns = true,
  });

  final OrgProposeAccess matchProposeAccess;
  final OrgProposeAccess tournamentProposeAccess;

  /// Does a request from this role wait for an org admin (true) or start
  /// directly (false)? Org admins always start directly.
  final bool matchTeamAdminsNeedApproval;
  final bool matchPlayersNeedApproval;
  final bool tournamentTeamAdminsNeedApproval;
  final bool tournamentPlayersNeedApproval;

  /// Walk-in / guest players may play in org matches and tournaments.
  final bool allowWalkIns;

  /// Legacy: the more permissive of the two accesses.
  OrgProposeAccess get proposeAccess =>
      matchProposeAccess.index >= tournamentProposeAccess.index
          ? matchProposeAccess
          : tournamentProposeAccess;

  /// Legacy flag: players may propose.
  bool get membersCanRequest => proposeAccess == OrgProposeAccess.everyone;

  bool get matchRequestsNeedApproval =>
      matchTeamAdminsNeedApproval || matchPlayersNeedApproval;

  bool get tournamentRequestsNeedApproval =>
      tournamentTeamAdminsNeedApproval || tournamentPlayersNeedApproval;

  factory OrgCompetitionPolicy.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const OrgCompetitionPolicy();
    final legacyAccess = OrgProposeAccess.fromWire(map['proposeAccess']) ??
        (map['membersCanRequest'] == true
            ? OrgProposeAccess.everyone
            : OrgProposeAccess.teamAdmins);
    final legacyMatchNeeds = map['matchRequestsNeedApproval'] != false;
    final legacyTournamentNeeds =
        map['tournamentRequestsNeedApproval'] != false;
    bool flag(String key, bool fallback) =>
        map[key] is bool ? map[key] as bool : fallback;
    return OrgCompetitionPolicy(
      matchProposeAccess:
          OrgProposeAccess.fromWire(map['matchProposeAccess']) ?? legacyAccess,
      tournamentProposeAccess:
          OrgProposeAccess.fromWire(map['tournamentProposeAccess']) ??
              legacyAccess,
      matchTeamAdminsNeedApproval:
          flag('matchTeamAdminsNeedApproval', legacyMatchNeeds),
      matchPlayersNeedApproval:
          flag('matchPlayersNeedApproval', legacyMatchNeeds),
      tournamentTeamAdminsNeedApproval:
          flag('tournamentTeamAdminsNeedApproval', legacyTournamentNeeds),
      tournamentPlayersNeedApproval:
          flag('tournamentPlayersNeedApproval', legacyTournamentNeeds),
      allowWalkIns: map['allowWalkIns'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'matchProposeAccess': matchProposeAccess.wire,
        'tournamentProposeAccess': tournamentProposeAccess.wire,
        'matchTeamAdminsNeedApproval': matchTeamAdminsNeedApproval,
        'matchPlayersNeedApproval': matchPlayersNeedApproval,
        'tournamentTeamAdminsNeedApproval': tournamentTeamAdminsNeedApproval,
        'tournamentPlayersNeedApproval': tournamentPlayersNeedApproval,
        'allowWalkIns': allowWalkIns,
        // Legacy mirrors for older app builds.
        'proposeAccess': proposeAccess.wire,
        'membersCanRequest': membersCanRequest,
        'matchRequestsNeedApproval': matchRequestsNeedApproval,
        'tournamentRequestsNeedApproval': tournamentRequestsNeedApproval,
      };

  OrgProposeAccess accessFor({required bool tournament}) =>
      tournament ? tournamentProposeAccess : matchProposeAccess;

  /// Does a request of this kind from [role] wait for an org admin?
  bool needsApprovalFor({required bool tournament, required bool teamAdmin}) {
    if (tournament) {
      return teamAdmin
          ? tournamentTeamAdminsNeedApproval
          : tournamentPlayersNeedApproval;
    }
    return teamAdmin ? matchTeamAdminsNeedApproval : matchPlayersNeedApproval;
  }

  OrgCompetitionPolicy copyWith({
    OrgProposeAccess? matchProposeAccess,
    OrgProposeAccess? tournamentProposeAccess,
    bool? matchTeamAdminsNeedApproval,
    bool? matchPlayersNeedApproval,
    bool? tournamentTeamAdminsNeedApproval,
    bool? tournamentPlayersNeedApproval,
    bool? allowWalkIns,
  }) =>
      OrgCompetitionPolicy(
        matchProposeAccess: matchProposeAccess ?? this.matchProposeAccess,
        tournamentProposeAccess:
            tournamentProposeAccess ?? this.tournamentProposeAccess,
        matchTeamAdminsNeedApproval:
            matchTeamAdminsNeedApproval ?? this.matchTeamAdminsNeedApproval,
        matchPlayersNeedApproval:
            matchPlayersNeedApproval ?? this.matchPlayersNeedApproval,
        tournamentTeamAdminsNeedApproval: tournamentTeamAdminsNeedApproval ??
            this.tournamentTeamAdminsNeedApproval,
        tournamentPlayersNeedApproval:
            tournamentPlayersNeedApproval ?? this.tournamentPlayersNeedApproval,
        allowWalkIns: allowWalkIns ?? this.allowWalkIns,
      );

  @override
  List<Object?> get props => [
        matchProposeAccess,
        tournamentProposeAccess,
        matchTeamAdminsNeedApproval,
        matchPlayersNeedApproval,
        tournamentTeamAdminsNeedApproval,
        tournamentPlayersNeedApproval,
        allowWalkIns,
      ];
}

enum OrgStartMode {
  /// Owner / org admin: created and official straight away.
  direct,

  /// Team admin or allowed member: goes to the approvals queue.
  request,

  /// Team admin or allowed member, approval switched off for this type.
  requestAutoApproved,

  /// No access: start actions are hidden.
  none,
}

/// UI mirror of the server rules in `functions/src/series/seriesCompetitionOps.js`.
/// The server is the authority; this only decides what to show.
class OrgCompetitionAccess {
  const OrgCompetitionAccess({
    required this.role,
    required this.policy,
    this.myTeamIds = const [],
  });

  final SeriesRole role;
  final OrgCompetitionPolicy policy;

  /// Org teams (series_clubs ids) the user is a team admin or player of.
  final List<String> myTeamIds;

  bool get isAdmin =>
      role == SeriesRole.superAdmin || role == SeriesRole.seriesAdmin;

  bool get isOwner => role == SeriesRole.superAdmin;

  /// Mirrors `decideAccess` on the server for non-admins.
  bool _canRequest({required bool tournament}) =>
      switch (policy.accessFor(tournament: tournament)) {
        OrgProposeAccess.admins => false,
        OrgProposeAccess.teamAdmins => role == SeriesRole.clubAdmin,
        OrgProposeAccess.everyone =>
          role == SeriesRole.clubAdmin || role == SeriesRole.seriesPlayer,
      };

  OrgStartMode _mode({required bool tournament}) {
    if (isAdmin) return OrgStartMode.direct;
    if (!_canRequest(tournament: tournament)) return OrgStartMode.none;
    final needsApproval = policy.needsApprovalFor(
      tournament: tournament,
      teamAdmin: role == SeriesRole.clubAdmin,
    );
    return needsApproval
        ? OrgStartMode.request
        : OrgStartMode.requestAutoApproved;
  }

  OrgStartMode get tournament => _mode(tournament: true);
  OrgStartMode get match => _mode(tournament: false);

  bool get canStartAnything =>
      tournament != OrgStartMode.none || match != OrgStartMode.none;

  /// Admins pick any two org teams; requesters must include one of theirs.
  String? matchTeamsError(String? teamAId, String? teamBId) {
    if (teamAId == null || teamBId == null) return 'Pick both teams';
    if (teamAId == teamBId) return 'Pick two different teams';
    if (isAdmin) return null;
    if (!myTeamIds.contains(teamAId) && !myTeamIds.contains(teamBId)) {
      return 'One of the teams must be your team';
    }
    return null;
  }

  static String actionLabel(OrgStartMode mode, {required bool tournament}) {
    final noun = tournament ? 'tournament' : 'match';
    return switch (mode) {
      OrgStartMode.request => 'Request a $noun',
      _ => 'Start a $noun',
    };
  }

  static String outcomeMessage({
    required bool autoApproved,
    required bool tournament,
  }) {
    final noun = tournament ? 'Tournament' : 'Match';
    return autoApproved
        ? '$noun added to the org'
        : '$noun sent to the org admins for approval';
  }
}

/// Approved org teams that are linked to a CrickFlow team (can play matches).
List<SeriesClubModel> playableOrgTeams(List<SeriesClubModel> teams) => teams
    .where((t) =>
        t.status == SeriesClubStatus.approved &&
        (t.linkedTeamId ?? '').isNotEmpty)
    .toList();
