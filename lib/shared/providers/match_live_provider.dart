import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/match_live_models.dart';
import '../../domain/services/match_live_service.dart';
import 'match_audience_provider.dart';
import 'providers.dart';

final matchLiveServiceProvider = Provider((ref) => MatchLiveService());

final matchLiveProvider =
    Provider.family<MatchLiveSnapshot, String>((ref, matchId) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  if (match == null) return MatchLiveSnapshot.empty;

  ref.watch(ballEventsProvider(matchId));

  final feed = ref.watch(commentaryFeedProvider(matchId));
  final revisions =
      ref.watch(matchRevisionsProvider(matchId)).valueOrNull ?? const [];
  final totalViews =
      ref.watch(matchTotalViewsProvider(matchId)).maybeWhen(
            data: (value) => value,
            orElse: () => 0,
          );
  final liveViewers =
      ref.watch(matchLiveViewerCountProvider(matchId)).maybeWhen(
            data: (value) => value,
            orElse: () => 0,
          );

  return ref.watch(matchLiveServiceProvider).build(
        match: match,
        feed: feed,
        revisions: revisions,
        totalViews: totalViews,
        liveViewers: liveViewers,
      );
});
