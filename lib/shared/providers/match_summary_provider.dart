import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/match_summary_models.dart';
import '../../domain/services/match_summary_service.dart';
import 'match_analytics_provider.dart';
import 'match_mvp_provider.dart';
import 'providers.dart';

final matchSummaryServiceProvider = Provider((ref) => MatchSummaryService());

final matchSummaryProvider =
    Provider.family<MatchSummarySnapshot, String>((ref, matchId) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  if (match == null) return const MatchSummarySnapshot();

  final analytics = ref.watch(matchAnalyticsProvider(matchId));
  final mvp = ref.watch(matchMvpProvider(matchId));
  final events = ref.watch(ballEventsProvider(matchId)).valueOrNull ?? [];
  final revisions =
      ref.watch(matchRevisionsProvider(matchId)).valueOrNull ?? const [];
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;

  return ref.watch(matchSummaryServiceProvider).build(
        match: match,
        analytics: analytics,
        mvp: mvp,
        ballEvents: events,
        revisions: revisions,
        viewerPlayerId: profile?.playerId,
        viewerName: profile?.displayName,
      );
});
