import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/providers/match_squads_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../data/models/innings_break_snapshot.dart';
import '../../data/models/opening_batsmen_snapshot.dart';
import '../../data/models/opening_bowler_snapshot.dart';
import '../../domain/innings_break_snapshot_builder.dart';

enum InningsBreakPhase {
  idle,
  slideshow,
  chaseOpeningBatsmen,
  chaseOpeningBowler,
  complete,
}

class InningsBreakController extends StateNotifier<InningsBreakPhase> {
  InningsBreakController() : super(InningsBreakPhase.idle);

  InningsBreakSnapshot? _frozenSlideshowSnapshot;

  InningsBreakSnapshot? get frozenSlideshowSnapshot => _frozenSlideshowSnapshot;

  void cacheSlideshowSnapshot(InningsBreakSnapshot snapshot) {
    if (_frozenSlideshowSnapshot == null && snapshot.isValid) {
      _frozenSlideshowSnapshot = snapshot;
    }
  }

  void onMatchUpdated(MatchModel match, {required bool isStreamLive}) {
    if (!isStreamLive) return;

    if (state == InningsBreakPhase.idle && _shouldStartSlideshow(match)) {
      state = InningsBreakPhase.slideshow;
      return;
    }

    if (state == InningsBreakPhase.slideshow && _isChaseLineupReady(match)) {
      state = InningsBreakPhase.chaseOpeningBatsmen;
    }
  }

  void onChaseOpeningBatsmenFinished({required bool hasOpeningBowler}) {
    if (state != InningsBreakPhase.chaseOpeningBatsmen) return;
    state = hasOpeningBowler
        ? InningsBreakPhase.chaseOpeningBowler
        : InningsBreakPhase.complete;
  }

  void onChaseOpeningBowlerFinished() {
    if (state == InningsBreakPhase.chaseOpeningBowler) {
      state = InningsBreakPhase.complete;
    }
  }

  void reset() {
    _frozenSlideshowSnapshot = null;
    state = InningsBreakPhase.idle;
  }

  static bool _hasCompletedFirstInnings(MatchModel match) {
    for (final inn in match.innings) {
      if (inn.inningsNumber == 1 &&
          !inn.isSuperOver &&
          inn.status == InningsStatus.completed) {
        return true;
      }
    }
    return false;
  }

  static bool _shouldStartSlideshow(MatchModel match) {
    if (!_hasCompletedFirstInnings(match)) return false;
    if (match.status == MatchStatus.inningsBreak) return true;
    if (match.status == MatchStatus.live) {
      final inn = match.currentInnings;
      if (inn != null &&
          inn.inningsNumber >= 2 &&
          !_isChaseLineupReady(match)) {
        return true;
      }
    }
    return false;
  }

  static bool _isChaseLineupReady(MatchModel match) {
    if (match.status != MatchStatus.live) return false;
    final inn = match.currentInnings;
    if (inn == null || inn.inningsNumber < 2) return false;
    if (inn.status != InningsStatus.inProgress) return false;
    return inn.strikerId?.isNotEmpty == true &&
        inn.nonStrikerId?.isNotEmpty == true &&
        inn.currentBowlerId?.isNotEmpty == true;
  }
}

final inningsBreakControllerProvider = StateNotifierProvider.autoDispose
    .family<InningsBreakController, InningsBreakPhase, String>(
  (ref, matchId) => InningsBreakController(),
);

InningsBreakSnapshot _buildInningsBreakSnapshot(
  Ref ref,
  String matchId,
) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  if (match == null) return InningsBreakSnapshot.empty;

  final events = ref.watch(ballEventsProvider(matchId)).valueOrNull ?? const [];
  final squads = ref.watch(matchDualSquadsProvider(matchId)).valueOrNull;
  if (squads == null) return InningsBreakSnapshot.empty;

  final tournamentId = match.tournamentId;
  final tournament = tournamentId != null && tournamentId.isNotEmpty
      ? ref.watch(tournamentProvider(tournamentId)).valueOrNull
      : null;
  final sponsors = tournamentId != null && tournamentId.isNotEmpty
      ? ref.watch(tournamentSponsorsProvider(tournamentId)).valueOrNull
      : null;

  return InningsBreakSnapshotBuilder.build(
    match: match,
    events: events,
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

final inningsBreakSnapshotProvider = Provider.autoDispose
    .family<InningsBreakSnapshot, String>((ref, matchId) {
  final phase = ref.watch(inningsBreakControllerProvider(matchId));
  if (phase != InningsBreakPhase.slideshow) {
    final frozen = ref
        .read(inningsBreakControllerProvider(matchId).notifier)
        .frozenSlideshowSnapshot;
    if (frozen != null) return frozen;
    return InningsBreakSnapshot.empty;
  }

  final notifier =
      ref.read(inningsBreakControllerProvider(matchId).notifier);
  final cached = notifier.frozenSlideshowSnapshot;
  if (cached != null) return cached;

  final built = _buildInningsBreakSnapshot(ref, matchId);
  if (built.isValid) {
    notifier.cacheSlideshowSnapshot(built);
  }
  return notifier.frozenSlideshowSnapshot ?? built;
});

final chaseOpeningBatsmenSnapshotProvider = Provider.autoDispose
    .family<ChaseOpeningBatsmenSnapshot?, String>((ref, matchId) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  if (match == null) return null;
  final squads = ref.watch(matchDualSquadsProvider(matchId)).valueOrNull;
  return InningsBreakSnapshotBuilder.buildChaseOpeningBatsmen(
    match: match,
    squads: squads,
  );
});

final chaseOpeningBowlerSnapshotProvider = Provider.autoDispose
    .family<ChaseOpeningBowlerSnapshot?, String>((ref, matchId) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  if (match == null) return null;
  return InningsBreakSnapshotBuilder.buildChaseOpeningBowler(match: match);
});

/// Same overlay widgets as stream start — opening pair after chase lineup.
final chaseAsOpeningBatsmenProvider = Provider.autoDispose
    .family<OpeningBatsmenSnapshot?, String>((ref, matchId) {
  final phase = ref.watch(inningsBreakControllerProvider(matchId));
  if (phase != InningsBreakPhase.chaseOpeningBatsmen) return null;
  final chase = ref.watch(chaseOpeningBatsmenSnapshotProvider(matchId));
  if (chase == null) return null;
  return OpeningBatsmenSnapshot(
    striker: OpeningBatterSlot(
      playerId: chase.strikerId,
      fallbackName: chase.strikerName,
      onStrike: true,
    ),
    nonStriker: OpeningBatterSlot(
      playerId: chase.nonStrikerId,
      fallbackName: chase.nonStrikerName,
    ),
    matchTitle: chase.matchTitle,
    crickflowLogoUrl: chase.crickflowLogoUrl,
  );
});

/// Same overlay widget as stream start — opening bowler with scorebug.
final chaseAsOpeningBowlerProvider = Provider.autoDispose
    .family<OpeningBowlerSnapshot?, String>((ref, matchId) {
  final phase = ref.watch(inningsBreakControllerProvider(matchId));
  if (phase != InningsBreakPhase.chaseOpeningBowler) return null;
  final chase = ref.watch(chaseOpeningBowlerSnapshotProvider(matchId));
  if (chase == null) return null;
  return OpeningBowlerSnapshot(
    playerId: chase.playerId,
    fallbackName: chase.fallbackName,
  );
});
