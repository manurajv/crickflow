import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/providers.dart';
import '../../domain/match_highlights_merger.dart';
import 'streaming_studio_providers.dart';

final matchHighlightsMergerProvider =
    Provider((ref) => const MatchHighlightsMerger());

/// Ball-event highlights merged with stream replay markers for a match.
final matchHighlightsMergedProvider =
    Provider.autoDispose.family<List<MatchHighlightItem>, String>((ref, matchId) {
  final events = ref.watch(ballEventsProvider(matchId)).valueOrNull ?? const [];
  final markers =
      ref.watch(replayMarkersProvider(matchId)).valueOrNull ?? const [];
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  return ref.watch(matchHighlightsMergerProvider).merge(
        ballEvents: events,
        replayMarkers: markers,
        match: match,
      );
});
