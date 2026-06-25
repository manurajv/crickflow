import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/match_timeline_event_model.dart';
import '../../domain/services/match_info_models.dart';
import '../../domain/services/match_info_service.dart';
import 'match_analytics_provider.dart';
import 'providers.dart';
import 'tournament_match_providers.dart';
import 'tournament_match_repair.dart';

final matchInfoServiceProvider = Provider((ref) => MatchInfoService());

final matchTimelineProvider =
    StreamProvider.family<List<MatchTimelineEventModel>, String>((ref, matchId) {
  return ref
      .watch(matchTargetRevisionRepositoryProvider)
      .watchMatchTimeline(matchId);
});

final matchInfoTournamentNameProvider =
    FutureProvider.family<String?, String>((ref, tournamentId) async {
  if (tournamentId.isEmpty) return null;
  return (await ref.read(tournamentRepositoryProvider).getTournament(tournamentId))
      ?.name;
});

final matchInfoProvider =
    Provider.family<MatchInfoSnapshot, String>((ref, matchId) {
  final match = ref.watch(matchDisplayProvider(matchId));
  if (match == null) return MatchInfoSnapshot.empty;

  final revisions =
      ref.watch(matchRevisionsProvider(matchId)).valueOrNull ?? const [];
  final timeline =
      ref.watch(matchTimelineProvider(matchId)).valueOrNull ?? const [];
  final analytics = ref.watch(matchAnalyticsProvider(matchId));
  final events = ref.watch(ballEventsProvider(matchId)).valueOrNull ?? const [];

  String? tournamentName;
  String? tournamentRoundName;
  String? tournamentGroupName;
  final tournamentId = match.tournamentId;
  if (tournamentId != null && tournamentId.isNotEmpty) {
    tournamentName =
        ref.watch(matchInfoTournamentNameProvider(tournamentId)).valueOrNull;
    if (match.roundName?.trim().isNotEmpty == true) {
      tournamentRoundName = match.roundName!.trim();
    } else if (match.roundId != null && match.roundId!.isNotEmpty) {
      tournamentRoundName = ref
          .watch(
            tournamentRoundByIdProvider(
              (tournamentId: tournamentId, roundId: match.roundId),
            ),
          )
          ?.name;
    }
    if (match.groupId != null && match.groupId!.isNotEmpty) {
      tournamentGroupName = ref
          .watch(
            tournamentGroupByIdProvider(
              (tournamentId: tournamentId, groupId: match.groupId),
            ),
          )
          ?.name;
    }
  }

  return ref.watch(matchInfoServiceProvider).build(
        match: match,
        revisions: revisions,
        timeline: timeline,
        analytics: analytics,
        ballEvents: events,
        tournamentName: tournamentName,
        tournamentRoundName: tournamentRoundName,
        tournamentGroupName: tournamentGroupName,
      );
});
