import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/match_media_naming.dart';
import '../../data/models/location_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_player_snapshot.dart';
import '../../data/models/match_rules_model.dart';
import '../../data/models/match_setup_draft_models.dart';
import '../../data/models/team_model.dart';

/// Synthetic match-only team ids (not written to the `teams` collection).
abstract final class MatchOnlyTeamIds {
  static const teamA = 'team_a';
  static const teamB = 'team_b';

  static bool isSynthetic(String? id) =>
      id == null || id.isEmpty || id == teamA || id == teamB;
}

class MatchDraftMedia {
  const MatchDraftMedia({
    required this.code,
    required this.downloadUrl,
    this.localPath,
  });

  final String code;
  final String downloadUrl;
  final String? localPath;
}

class StartMatchDraft {
  StartMatchDraft({
    required this.matchId,
    this.matchMode = MatchMode.normal,
    this.teamA,
    this.teamB,
    this.teamAName = '',
    this.teamBName = '',
    MatchRulesModel? rules,
    this.location = const LocationModel(country: AppConstants.defaultCountry),
    this.venue = '',
    this.scheduledAt,
    this.media = const [],
    this.setup = const MatchSetupData(),
    this.isExistingMatch = false,
    this.tournamentOfficialsAutoFilled = false,
    this.tournamentId,
    this.seriesId,
    this.seriesTeamIds = const [],
  }) : rules = rules ?? MatchRulesModel.standardT20();

  final String matchId;
  final MatchMode matchMode;
  final String? tournamentId;

  /// Set when started from inside an org: the match is registered there.
  final String? seriesId;

  /// CrickFlow team ids of the org's playable teams (for validation).
  final List<String> seriesTeamIds;
  final TeamModel? teamA;
  final TeamModel? teamB;
  final String teamAName;
  final String teamBName;
  final MatchRulesModel rules;
  final LocationModel location;
  final String venue;
  final DateTime? scheduledAt;
  final List<MatchDraftMedia> media;
  final MatchSetupData setup;
  final bool isExistingMatch;
  final bool tournamentOfficialsAutoFilled;

  bool get isQuickMatch => matchMode == MatchMode.quick;

  String get resolvedTeamAName =>
      teamA?.name ?? (teamAName.isNotEmpty ? teamAName : '');
  String get resolvedTeamBName =>
      teamB?.name ?? (teamBName.isNotEmpty ? teamBName : '');

  /// Registered team id, or synthetic match-only id when a typed name is used.
  String? get resolvedTeamAId =>
      teamA?.id ??
      (resolvedTeamAName.isNotEmpty ? MatchOnlyTeamIds.teamA : null);

  String? get resolvedTeamBId =>
      teamB?.id ??
      (resolvedTeamBName.isNotEmpty ? MatchOnlyTeamIds.teamB : null);

  bool get hasBothTeams =>
      resolvedTeamAName.isNotEmpty && resolvedTeamBName.isNotEmpty;

  bool get canProceedToSquad =>
      hasBothTeams && venue.trim().isNotEmpty && location.city.trim().isNotEmpty;

  /// Quick Match: teams + venue/city enough to reach toss.
  bool get canProceedToQuickToss => canProceedToSquad;

  int get nextMediaIndex =>
      MatchMediaNaming.nextIndex(media.map((m) => m.code));

  StartMatchDraft copyWith({
    MatchMode? matchMode,
    TeamModel? teamA,
    TeamModel? teamB,
    bool clearTeamA = false,
    bool clearTeamB = false,
    String? teamAName,
    String? teamBName,
    MatchRulesModel? rules,
    LocationModel? location,
    String? venue,
    DateTime? scheduledAt,
    List<MatchDraftMedia>? media,
    MatchSetupData? setup,
    bool? isExistingMatch,
    bool? tournamentOfficialsAutoFilled,
    String? tournamentId,
    bool clearTournamentId = false,
  }) {
    return StartMatchDraft(
      matchId: matchId,
      matchMode: matchMode ?? this.matchMode,
      teamA: clearTeamA ? null : (teamA ?? this.teamA),
      teamB: clearTeamB ? null : (teamB ?? this.teamB),
      teamAName: teamAName ?? this.teamAName,
      teamBName: teamBName ?? this.teamBName,
      rules: rules ?? this.rules,
      location: location ?? this.location,
      venue: venue ?? this.venue,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      media: media ?? this.media,
      setup: setup ?? this.setup,
      isExistingMatch: isExistingMatch ?? this.isExistingMatch,
      tournamentOfficialsAutoFilled:
          tournamentOfficialsAutoFilled ?? this.tournamentOfficialsAutoFilled,
      tournamentId:
          clearTournamentId ? null : (tournamentId ?? this.tournamentId),
      seriesId: seriesId,
      seriesTeamIds: seriesTeamIds,
    );
  }
}

class StartMatchDraftNotifier extends StateNotifier<StartMatchDraft> {
  StartMatchDraftNotifier()
      : super(
          StartMatchDraft(
            matchId: const Uuid().v4(),
            rules: MatchRulesModel.standardT20(),
            scheduledAt: DateTime.now(),
          ),
        );

  /// Starts a fresh wizard. Pass [tournamentId] when the match is started
  /// from inside a tournament so it is created as a tournament match.
  void reset({
    MatchMode mode = MatchMode.normal,
    String? tournamentId,
    String? seriesId,
    List<String> seriesTeamIds = const [],
  }) {
    final tid = tournamentId?.trim();
    final sid = seriesId?.trim();
    state = StartMatchDraft(
      matchId: const Uuid().v4(),
      matchMode: mode,
      tournamentId: tid == null || tid.isEmpty ? null : tid,
      seriesId: sid == null || sid.isEmpty ? null : sid,
      seriesTeamIds: seriesTeamIds,
      rules: MatchRulesModel.standardT20(),
      scheduledAt: DateTime.now(),
    );
  }

  void setMatchMode(MatchMode mode) {
    state = state.copyWith(matchMode: mode);
  }

  /// Hydrates the in-memory wizard from an existing scheduled match.
  void loadFromMatch({
    required MatchModel match,
    TeamModel? teamA,
    TeamModel? teamB,
  }) {
    state = StartMatchDraft(
      matchId: match.id,
      matchMode: match.matchMode,
      teamA: teamA,
      teamB: teamB,
      teamAName: match.teamAName,
      teamBName: match.teamBName,
      rules: match.rules,
      location: match.location,
      venue: match.venue,
      scheduledAt: match.scheduledAt ?? DateTime.now(),
      setup: match.setup ?? const MatchSetupData(),
      isExistingMatch: true,
      tournamentId: match.tournamentId,
    );
  }

  void setTeamA(TeamModel? team, {String? customName}) {
    state = state.copyWith(
      teamA: team,
      clearTeamA: team == null,
      teamAName: team?.name ?? customName ?? '',
      setup: const MatchSetupData(),
    );
  }

  void setTeamB(TeamModel? team, {String? customName}) {
    state = state.copyWith(
      teamB: team,
      clearTeamB: team == null,
      teamBName: team?.name ?? customName ?? '',
      setup: state.setup.copyWith(
        teamBPlayingPlayers: const [],
        teamBSubstitutePlayers: const [],
        teamBCaptainId: null,
        teamBWicketKeeperId: null,
      ),
    );
  }

  void setMatchSquad({
    required bool isTeamA,
    required List<MatchPlayerSnapshot> playing,
    required List<MatchPlayerSnapshot> substitutes,
  }) {
    final playingIds = playing.map((p) => p.id).toSet();
    final setup = isTeamA
        ? state.setup.copyWith(
            teamAPlayingPlayers: playing,
            teamASubstitutePlayers: substitutes,
            teamACaptainId: playingIds.contains(state.setup.teamACaptainId)
                ? state.setup.teamACaptainId
                : null,
            teamAWicketKeeperId:
                playingIds.contains(state.setup.teamAWicketKeeperId)
                    ? state.setup.teamAWicketKeeperId
                    : null,
          )
        : state.setup.copyWith(
            teamBPlayingPlayers: playing,
            teamBSubstitutePlayers: substitutes,
            teamBCaptainId: playingIds.contains(state.setup.teamBCaptainId)
                ? state.setup.teamBCaptainId
                : null,
            teamBWicketKeeperId:
                playingIds.contains(state.setup.teamBWicketKeeperId)
                    ? state.setup.teamBWicketKeeperId
                    : null,
          );
    state = state.copyWith(setup: setup);
  }

  void setTeamRoles({
    required bool isTeamA,
    required String captainId,
    required String wicketKeeperId,
  }) {
    final setup = isTeamA
        ? state.setup.copyWith(
            teamACaptainId: captainId,
            teamAWicketKeeperId: wicketKeeperId,
          )
        : state.setup.copyWith(
            teamBCaptainId: captainId,
            teamBWicketKeeperId: wicketKeeperId,
          );
    state = state.copyWith(setup: setup);
  }

  void updateOfficials(MatchSetupData setup) {
    state = state.copyWith(
      setup: setup,
      tournamentOfficialsAutoFilled: false,
    );
  }

  void applyTournamentOfficialsAutoFill(
    MatchSetupData setup, {
    required bool autoFilled,
  }) {
    state = state.copyWith(
      setup: setup,
      tournamentOfficialsAutoFilled: autoFilled,
    );
  }

  Future<void> ensureDefaultScorer1({
    required String userId,
    required String name,
    String? photoUrl,
    String? playerId,
    String? playerDocId,
  }) async {
    final setup = state.setup;
    if (setup.scorers.isNotEmpty && setup.scorers.first.name.isNotEmpty) {
      return;
    }
    final entry = MatchOfficialEntry(
      userId: userId,
      playerId: playerId ?? playerDocId,
      name: name,
      photoUrl: photoUrl,
      slotLabel: 'Scorer 1',
    );
    final scorers = [entry, ...setup.scorers.skip(1)];
    state = state.copyWith(setup: setup.copyWith(scorers: scorers));
  }

  void setCoinResult(String coinResult) {
    state = state.copyWith(
      setup: state.setup.copyWith(coinResult: coinResult),
    );
  }

  void setToss({
    required bool winnerIsTeamA,
    required bool winnerBatsFirst,
    String? coinResult,
  }) {
    state = state.copyWith(
      setup: state.setup.copyWith(
        tossWinnerIsTeamA: winnerIsTeamA,
        tossWinnerBatsFirst: winnerBatsFirst,
        coinResult: coinResult,
      ),
    );
  }

  void addMedia(MatchDraftMedia item) {
    state = state.copyWith(media: [...state.media, item]);
  }

  void removeMedia(String code) {
    state = state.copyWith(
      media: state.media.where((m) => m.code != code).toList(),
    );
  }

  void updateRules(MatchRulesModel rules) {
    state = state.copyWith(rules: rules);
  }

  void updateLocation(LocationModel location) {
    state = state.copyWith(location: location);
  }

  void updateVenue(String venue) {
    state = state.copyWith(venue: venue);
  }

  void updateScheduledAt(DateTime when) {
    state = state.copyWith(scheduledAt: when);
  }
}

final startMatchDraftProvider =
    StateNotifierProvider<StartMatchDraftNotifier, StartMatchDraft>(
  (ref) => StartMatchDraftNotifier(),
);


/// Validation for matches started inside a tournament: both sides must be
/// registered tournament teams. Returns an error message, or null when OK.
String? tournamentTeamsError(StartMatchDraft draft, List<String> tournamentTeamIds) {
  final tid = draft.tournamentId;
  if (tid == null || tid.isEmpty) return null;
  final a = draft.resolvedTeamAId;
  final b = draft.resolvedTeamBId;
  if (a == null || a.isEmpty || b == null || b.isEmpty) {
    return 'Pick both teams from the tournament';
  }
  if (!tournamentTeamIds.contains(a) || !tournamentTeamIds.contains(b)) {
    return 'Both teams must be part of this tournament';
  }
  return null;
}


/// Validation for matches started inside an org: both sides must be the org's
/// teams. Returns an error message, or null when OK / not an org match.
String? seriesTeamsError(StartMatchDraft draft) {
  final sid = draft.seriesId;
  if (sid == null || sid.isEmpty || draft.seriesTeamIds.isEmpty) return null;
  final a = draft.resolvedTeamAId;
  final b = draft.resolvedTeamBId;
  if (a == null || a.isEmpty || b == null || b.isEmpty) {
    return 'Pick both teams from the org';
  }
  if (!draft.seriesTeamIds.contains(a) || !draft.seriesTeamIds.contains(b)) {
    return 'Both teams must be teams of this org';
  }
  return null;
}
