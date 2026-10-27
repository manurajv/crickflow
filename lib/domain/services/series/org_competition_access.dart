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

  String get description => switch (this) {
        OrgProposeAccess.admins =>
          'Only the owner and org admins can start or request matches and '
              'tournaments.',
        OrgProposeAccess.teamAdmins =>
          'Admins of an org team can request a match or tournament. '
              'Players cannot.',
        OrgProposeAccess.everyone =>
          'Team admins and every player on an org team can request a match '
              'or tournament.',
      };

  static OrgProposeAccess? fromWire(Object? value) {
    for (final v in OrgProposeAccess.values) {
      if (v.name == value) return v;
    }
    return null;
  }
}

/// Org setting: who may request tournaments / matches and whether those
/// requests need approval. Stored on `series/{id}.competitionPolicy`.
///
/// Older orgs only have `membersCanRequest`; it maps to [OrgProposeAccess]
/// (`true` → everyone, otherwise team admins) until the owner saves the new
/// permission. [toMap] keeps writing `membersCanRequest` for older app builds.
class OrgCompetitionPolicy extends Equatable {
  const OrgCompetitionPolicy({
    this.tournamentRequestsNeedApproval = true,
    this.matchRequestsNeedApproval = true,
    this.proposeAccess = OrgProposeAccess.teamAdmins,
  });

  final bool tournamentRequestsNeedApproval;
  final bool matchRequestsNeedApproval;
  final OrgProposeAccess proposeAccess;

  /// Legacy flag: players may propose.
  bool get membersCanRequest => proposeAccess == OrgProposeAccess.everyone;

  factory OrgCompetitionPolicy.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const OrgCompetitionPolicy();
    return OrgCompetitionPolicy(
      tournamentRequestsNeedApproval:
          map['tournamentRequestsNeedApproval'] != false,
      matchRequestsNeedApproval: map['matchRequestsNeedApproval'] != false,
      proposeAccess: OrgProposeAccess.fromWire(map['proposeAccess']) ??
          (map['membersCanRequest'] == true
              ? OrgProposeAccess.everyone
              : OrgProposeAccess.teamAdmins),
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentRequestsNeedApproval': tournamentRequestsNeedApproval,
        'matchRequestsNeedApproval': matchRequestsNeedApproval,
        'proposeAccess': proposeAccess.wire,
        'membersCanRequest': membersCanRequest,
      };

  OrgCompetitionPolicy copyWith({
    bool? tournamentRequestsNeedApproval,
    bool? matchRequestsNeedApproval,
    OrgProposeAccess? proposeAccess,
  }) =>
      OrgCompetitionPolicy(
        tournamentRequestsNeedApproval:
            tournamentRequestsNeedApproval ?? this.tournamentRequestsNeedApproval,
        matchRequestsNeedApproval:
            matchRequestsNeedApproval ?? this.matchRequestsNeedApproval,
        proposeAccess: proposeAccess ?? this.proposeAccess,
      );

  @override
  List<Object?> get props => [
        tournamentRequestsNeedApproval,
        matchRequestsNeedApproval,
        proposeAccess,
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
  bool get _canRequest => switch (policy.proposeAccess) {
        OrgProposeAccess.admins => false,
        OrgProposeAccess.teamAdmins => role == SeriesRole.clubAdmin,
        OrgProposeAccess.everyone =>
          role == SeriesRole.clubAdmin || role == SeriesRole.seriesPlayer,
      };

  OrgStartMode _mode(bool needsApproval) {
    if (isAdmin) return OrgStartMode.direct;
    if (!_canRequest) return OrgStartMode.none;
    return needsApproval
        ? OrgStartMode.request
        : OrgStartMode.requestAutoApproved;
  }

  OrgStartMode get tournament => _mode(policy.tournamentRequestsNeedApproval);
  OrgStartMode get match => _mode(policy.matchRequestsNeedApproval);

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
