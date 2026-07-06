import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/providers/match_info_provider.dart';
import '../../../../shared/providers/match_squads_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_match_providers.dart';
import '../../data/models/match_introduction_snapshot.dart';
import '../../data/models/opening_batsmen_snapshot.dart';
import '../../data/models/opening_bowler_snapshot.dart';
import '../../domain/match_introduction_snapshot_builder.dart';

enum MatchIntroductionPhase {
  idle,
  showing,
  openingBatsmen,
  openingBowler,
  complete,
}

class MatchIntroductionController extends StateNotifier<MatchIntroductionPhase> {
  MatchIntroductionController() : super(MatchIntroductionPhase.idle);

  void onRtmpConnected() {
    if (state != MatchIntroductionPhase.idle) return;
    state = MatchIntroductionPhase.showing;
  }

  void onMatchIntroductionFinished({
    required bool hasOpeningBatsmen,
    required bool hasOpeningBowler,
  }) {
    if (state != MatchIntroductionPhase.showing) return;
    if (hasOpeningBatsmen) {
      state = MatchIntroductionPhase.openingBatsmen;
    } else if (hasOpeningBowler) {
      state = MatchIntroductionPhase.openingBowler;
    } else {
      state = MatchIntroductionPhase.complete;
    }
  }

  void onOpeningBatsmenFinished({required bool hasOpeningBowler}) {
    if (state != MatchIntroductionPhase.openingBatsmen) return;
    state = hasOpeningBowler
        ? MatchIntroductionPhase.openingBowler
        : MatchIntroductionPhase.complete;
  }

  void onOpeningBowlerFinished() {
    if (state == MatchIntroductionPhase.openingBowler) {
      state = MatchIntroductionPhase.complete;
    }
  }

  void reset() {
    state = MatchIntroductionPhase.idle;
  }
}

final matchIntroductionControllerProvider = StateNotifierProvider.autoDispose
    .family<MatchIntroductionController, MatchIntroductionPhase, String>(
  (ref, matchId) => MatchIntroductionController(),
);

final matchIntroductionSnapshotProvider = FutureProvider.autoDispose
    .family<MatchIntroductionSnapshot, String>((ref, matchId) async {
  final match = await ref.watch(matchProvider(matchId).future);
  if (match == null) return MatchIntroductionSnapshot.empty;

  final squads = await ref.watch(matchDualSquadsProvider(matchId).future);
  final playerRepo = ref.read(playerRepositoryProvider);

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

  return MatchIntroductionSnapshotBuilder.build(
    match: match,
    squads: squads,
    playerRepo: playerRepo,
    tournamentName: tournamentName,
    tournamentRoundName: tournamentRoundName,
    tournamentGroupName: tournamentGroupName,
  );
});

final openingBatsmenSnapshotProvider = Provider.autoDispose
    .family<OpeningBatsmenSnapshot?, String>((ref, matchId) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  if (match == null) return null;

  final innings = match.currentInnings;
  if (innings == null) return null;

  final strikerId = innings.strikerId;
  final nonStrikerId = innings.nonStrikerId;
  if (strikerId == null ||
      strikerId.isEmpty ||
      nonStrikerId == null ||
      nonStrikerId.isEmpty) {
    return null;
  }

  final overlay = ref.watch(overlayProvider(matchId)).valueOrNull;
  var strikerName = overlay?.strikerName ?? '';
  var nonStrikerName = overlay?.nonStrikerName ?? '';

  for (final batter in innings.batsmen) {
    if (batter.playerId == strikerId && strikerName.isEmpty) {
      strikerName = batter.playerName;
    }
    if (batter.playerId == nonStrikerId && nonStrikerName.isEmpty) {
      nonStrikerName = batter.playerName;
    }
  }

  final matchTitle = overlay != null &&
          overlay.teamAName.isNotEmpty &&
          overlay.teamBName.isNotEmpty
      ? '${overlay.teamAName} vs ${overlay.teamBName}'
      : (match.teamAName.isNotEmpty && match.teamBName.isNotEmpty
          ? '${match.teamAName} vs ${match.teamBName}'
          : match.title);

  final snapshot = OpeningBatsmenSnapshot(
    striker: OpeningBatterSlot(
      playerId: strikerId,
      fallbackName: strikerName.isNotEmpty ? strikerName : 'Striker',
      onStrike: true,
    ),
    nonStriker: OpeningBatterSlot(
      playerId: nonStrikerId,
      fallbackName: nonStrikerName.isNotEmpty ? nonStrikerName : 'Non-striker',
    ),
    matchTitle: matchTitle,
    crickflowLogoUrl: AppConstants.crickflowLogoUrl,
  );

  return snapshot.isValid ? snapshot : null;
});

final openingBowlerSnapshotProvider = Provider.autoDispose
    .family<OpeningBowlerSnapshot?, String>((ref, matchId) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  if (match == null) return null;

  final innings = match.currentInnings;
  if (innings == null) return null;

  final bowlerId = innings.currentBowlerId;
  if (bowlerId == null || bowlerId.isEmpty) return null;

  final overlay = ref.watch(overlayProvider(matchId)).valueOrNull;
  var bowlerName = overlay?.bowlerName ?? '';

  for (final bowler in innings.bowlers) {
    if (bowler.playerId == bowlerId && bowlerName.isEmpty) {
      bowlerName = bowler.playerName;
    }
  }

  final snapshot = OpeningBowlerSnapshot(
    playerId: bowlerId,
    fallbackName: bowlerName.isNotEmpty ? bowlerName : 'Bowler',
  );

  return snapshot.isValid ? snapshot : null;
});
