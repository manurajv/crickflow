import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/providers/match_squads_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../data/models/post_match_snapshot.dart';
import '../../domain/post_match_snapshot_builder.dart';

enum PostMatchPhase {
  idle,
  matchSummary,
  thankYou,
  complete,
}

class PostMatchController extends StateNotifier<PostMatchPhase> {
  PostMatchController() : super(PostMatchPhase.idle);

  PostMatchSnapshot? _frozenSnapshot;
  Timer? _summaryTimer;
  Timer? _endTimer;

  static const summaryDuration = Duration(seconds: 10);
  static const liveEndDelay = Duration(minutes: 2);

  PostMatchSnapshot? get frozenSnapshot => _frozenSnapshot;

  void cacheSnapshot(PostMatchSnapshot snapshot) {
    if (_frozenSnapshot == null && snapshot.isValid) {
      _frozenSnapshot = snapshot;
    }
  }

  void onMatchUpdated(MatchModel match, {required bool isStreamLive}) {
    if (!isStreamLive) return;
    if (state != PostMatchPhase.idle) return;
    if (match.status != MatchStatus.completed) return;
    _beginPostMatch();
  }

  void _beginPostMatch() {
    _summaryTimer?.cancel();
    _endTimer?.cancel();
    state = PostMatchPhase.matchSummary;

    _summaryTimer = Timer(summaryDuration, () {
      if (state == PostMatchPhase.matchSummary) {
        state = PostMatchPhase.thankYou;
      }
    });

    _endTimer = Timer(liveEndDelay, () {
      if (state == PostMatchPhase.matchSummary ||
          state == PostMatchPhase.thankYou) {
        state = PostMatchPhase.complete;
      }
    });
  }

  void reset() {
    _summaryTimer?.cancel();
    _endTimer?.cancel();
    _summaryTimer = null;
    _endTimer = null;
    _frozenSnapshot = null;
    state = PostMatchPhase.idle;
  }

  @override
  void dispose() {
    _summaryTimer?.cancel();
    _endTimer?.cancel();
    super.dispose();
  }
}

final postMatchControllerProvider = StateNotifierProvider.autoDispose
    .family<PostMatchController, PostMatchPhase, String>(
  (ref, matchId) => PostMatchController(),
);

PostMatchSnapshot _buildPostMatchSnapshot(Ref ref, String matchId) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  if (match == null) return PostMatchSnapshot.empty;

  final squads = ref.watch(matchDualSquadsProvider(matchId)).valueOrNull;
  if (squads == null) return PostMatchSnapshot.empty;

  final tournamentId = match.tournamentId;
  final tournament = tournamentId != null && tournamentId.isNotEmpty
      ? ref.watch(tournamentProvider(tournamentId)).valueOrNull
      : null;
  final sponsors = tournamentId != null && tournamentId.isNotEmpty
      ? ref.watch(tournamentSponsorsProvider(tournamentId)).valueOrNull
      : null;

  return PostMatchSnapshotBuilder.build(
    match: match,
    squads: squads,
    tournamentName: tournament?.name,
    tournamentLogoUrl: tournament?.logoUrl,
    sponsorLogoUrls: sponsors
            ?.map((s) => s.logoUrl)
            .whereType<String>()
            .where((u) => u.isNotEmpty)
            .toList() ??
        const [],
  );
}

final postMatchSnapshotProvider = Provider.autoDispose
    .family<PostMatchSnapshot, String>((ref, matchId) {
  final phase = ref.watch(postMatchControllerProvider(matchId));
  if (phase == PostMatchPhase.idle) {
    final frozen =
        ref.read(postMatchControllerProvider(matchId).notifier).frozenSnapshot;
    return frozen ?? PostMatchSnapshot.empty;
  }

  final notifier = ref.read(postMatchControllerProvider(matchId).notifier);
  final cached = notifier.frozenSnapshot;
  if (cached != null) return cached;

  final built = _buildPostMatchSnapshot(ref, matchId);
  if (built.isValid) {
    notifier.cacheSnapshot(built);
  }
  return notifier.frozenSnapshot ?? built;
});
