import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/match_analytics_models.dart';
import '../../domain/services/match_analytics_service.dart';
import 'providers.dart';

final matchAnalyticsServiceProvider =
    Provider((ref) => MatchAnalyticsService());

final matchAnalyticsProvider =
    Provider.family<MatchAnalyticsSnapshot, String>((ref, matchId) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  final events = ref.watch(ballEventsProvider(matchId)).valueOrNull ?? [];
  final revisions =
      ref.watch(matchRevisionsProvider(matchId)).valueOrNull ?? const [];

  if (match == null) {
    return const MatchAnalyticsSnapshot();
  }

  return ref.watch(matchAnalyticsServiceProvider).build(
        match: match,
        ballEvents: events,
        revisions: revisions,
      );
});
