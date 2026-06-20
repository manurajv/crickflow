import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/match_mvp_models.dart';
import '../../domain/services/match_mvp_service.dart';
import 'providers.dart';

final matchMvpServiceProvider = Provider((ref) => MatchMvpService());

final matchMvpProvider =
    Provider.family<MatchMvpSnapshot, String>((ref, matchId) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  final events = ref.watch(ballEventsProvider(matchId)).valueOrNull ?? [];

  if (match == null) {
    return const MatchMvpSnapshot();
  }

  return ref.watch(matchMvpServiceProvider).build(
        match: match,
        ballEvents: events,
      );
});
