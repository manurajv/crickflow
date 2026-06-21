import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/match_audience_repository.dart';

final matchAudienceRepositoryProvider = Provider<MatchAudienceRepository>((ref) {
  final repo = MatchAudienceRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final matchTotalViewsProvider =
    StreamProvider.family<int, String>((ref, matchId) {
  return ref.watch(matchAudienceRepositoryProvider).watchTotalViews(matchId);
});

final matchLiveViewerCountProvider =
    StreamProvider.family<int, String>((ref, matchId) {
  return ref
      .watch(matchAudienceRepositoryProvider)
      .watchLiveViewerCount(matchId);
});
