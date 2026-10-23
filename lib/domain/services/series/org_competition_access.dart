import 'package:equatable/equatable.dart';

import '../../../data/models/series/series.dart';

/// Org setting: who may request tournaments / matches and whether those
/// requests need approval. Stored on `series/{id}.competitionPolicy`.
class OrgCompetitionPolicy extends Equatable {
  const OrgCompetitionPolicy({
    this.tournamentRequestsNeedApproval = true,
    this.matchRequestsNeedApproval = true,
    this.membersCanRequest = false,
  });

  final bool tournamentRequestsNeedApproval;
  final bool matchRequestsNeedApproval;
  final bool membersCanRequest;

  factory OrgCompetitionPolicy.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const OrgCompetitionPolicy();
    return OrgCompetitionPolicy(
      tournamentRequestsNeedApproval:
          map['tournamentRequestsNeedApproval'] != false,
      matchRequestsNeedApproval: map['matchRequestsNeedApproval'] != false,
      membersCanRequest: map['membersCanRequest'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentRequestsNeedApproval': tournamentRequestsNeedApproval,
        'matchRequestsNeedApproval': matchRequestsNeedApproval,
        'membersCanRequest': membersCanRequest,
      };

  OrgCompetitionPolicy copyWith({
    bool? tournamentRequestsNeedApproval,
    bool? matchRequestsNeedApproval,
    bool? membersCanRequest,
  }) =>
      OrgCompetitionPolicy(
        tournamentRequestsNeedApproval:
            tournamentRequestsNeedApproval ?? this.tournamentRequestsNeedApproval,
        matchRequestsNeedApproval:
            matchRequestsNeedApproval ?? this.matchRequestsNeedApproval,
        membersCanRequest: membersCanRequest ?? this.membersCanRequest,
      );

  @override
  List<Object?> get props =>
      [tournamentRequestsNeedApproval, matchRequestsNeedApproval, membersCanRequest];
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

  bool get _canRequest =>
      role == SeriesRole.clubAdmin ||
      (role == SeriesRole.seriesPlayer && policy.membersCanRequest);

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
