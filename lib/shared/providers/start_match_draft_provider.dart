import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/match_media_naming.dart';
import '../../data/models/location_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_player_snapshot.dart';
import '../../data/models/match_rules_model.dart';
import '../../data/models/match_setup_draft_models.dart';
import '../../data/models/team_model.dart';

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
  }) : rules = rules ?? MatchRulesModel.standardT20();

  final String matchId;
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

  String get resolvedTeamAName =>
      teamA?.name ?? (teamAName.isNotEmpty ? teamAName : '');
  String get resolvedTeamBName =>
      teamB?.name ?? (teamBName.isNotEmpty ? teamBName : '');

  bool get hasBothTeams =>
      resolvedTeamAName.isNotEmpty && resolvedTeamBName.isNotEmpty;

  bool get canProceedToSquad =>
      hasBothTeams && venue.trim().isNotEmpty && location.city.trim().isNotEmpty;

  int get nextMediaIndex =>
      MatchMediaNaming.nextIndex(media.map((m) => m.code));

  StartMatchDraft copyWith({
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
  }) {
    return StartMatchDraft(
      matchId: matchId,
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

  void reset() {
    state = StartMatchDraft(
      matchId: const Uuid().v4(),
      rules: MatchRulesModel.standardT20(),
      scheduledAt: DateTime.now(),
    );
  }

  /// Hydrates the in-memory wizard from an existing scheduled match.
  void loadFromMatch({
    required MatchModel match,
    TeamModel? teamA,
    TeamModel? teamB,
  }) {
    state = StartMatchDraft(
      matchId: match.id,
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
    state = state.copyWith(setup: setup);
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
