import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/match_insights_service.dart';
import 'providers.dart';

final matchInsightsServiceProvider = Provider((ref) => MatchInsightsService());

final matchInsightsProvider =
    Provider.family<MatchInsightsSnapshot, String>((ref, matchId) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  final events = ref.watch(ballEventsProvider(matchId)).valueOrNull ?? [];
  if (match == null) {
    return const MatchInsightsSnapshot();
  }
  return ref.watch(matchInsightsServiceProvider).build(
        match: match,
        ballEvents: events,
      );
});
