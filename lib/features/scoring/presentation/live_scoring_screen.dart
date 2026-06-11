import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/match_permissions.dart';
import '../../../data/models/innings_model.dart';
import '../../../data/models/match_model.dart';
import '../../../domain/services/commentary_service.dart';
import '../../../domain/services/dismissal_formatter.dart';
import '../../../domain/services/scoring_engine.dart';
import '../../../domain/scoring/match_completion_policy.dart';
import '../../../shared/providers/lineup_providers.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/player_lineup_picker.dart';
import '../../../data/models/dismissal_fielder.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/services/dismissal_sub_type.dart';
import 'widgets/crease_picker_sheets.dart';
import '../../../shared/widgets/fielder_picker_sheet.dart';
import '../../../shared/widgets/wicket_picker_sheet.dart';
import '../../matches/presentation/match_scoring_rules_screen.dart';
import '../../matches/presentation/widgets/edit_toss_decision_sheet.dart';
import 'utils/scoring_display_utils.dart';
import 'widgets/innings_break_dialog.dart';
import 'widgets/live_scoring_header.dart';
import 'widgets/live_scoring_keypad.dart';
import 'widgets/live_scoring_players_strip.dart'
    show BowlingSide, LiveScoringPlayersStrip;
import 'widgets/over_complete_dialog.dart';
import 'widgets/run_out_sheet.dart';
import 'widgets/scoring_extra_dialogs.dart';
import 'widgets/scoring_quick_options_sheet.dart';
import '../../../shared/widgets/scoring_ui_kit.dart';
import 'widgets/select_bowler_sheet.dart';
import '../../../data/models/wagon_wheel_data.dart';
import '../../../domain/wagon_wheel/wagon_wheel_eligibility.dart';
import '../../wagon_wheel/presentation/wagon_wheel_selection_sheet.dart';

class LiveScoringScreen extends ConsumerStatefulWidget {
  const LiveScoringScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<LiveScoringScreen> createState() => _LiveScoringScreenState();
}

class _LiveScoringScreenState extends ConsumerState<LiveScoringScreen> {
  static const _uuid = Uuid();
  int _ballSequence = 0;
  bool _isRecording = false;
  bool _sequenceLoaded = false;
  bool _inningsBreakDialogOpen = false;
  bool _suppressInningsBreakCheck = false;
  BowlingSide _bowlingSide = BowlingSide.over;

  @override
  void initState() {
    super.initState();
    _loadSequence();
    ref.read(notificationServiceProvider).subscribeToMatch(widget.matchId);
  }

  Future<void> _loadSequence() async {
    final seq = await ref
        .read(matchRepositoryProvider)
        .lastBallSequence(widget.matchId);
    if (mounted) {
      setState(() {
        _ballSequence = seq;
        _sequenceLoaded = true;
      });
    }
  }

  Future<void> _record(
    BallEventInput input, {
    String? undoGroupId,
    MatchModel? matchOverride,
  }) async {
    final match =
        ref.read(matchProvider(widget.matchId)).valueOrNull ?? matchOverride;
    if (match == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match data unavailable — try again'),
          ),
        );
      }
      return;
    }

    final inn = match.currentInnings;
    if (inn?.currentBowlerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set lineup before scoring')),
        );
        _openLineupSheet(match);
      }
      return;
    }
    if (inn?.strikerId == null || inn?.nonStrikerId == null) {
      if (mounted) {
        await _fillVacantCrease(match, inn!);
      }
      return;
    }

    if (_inningsBreakDialogOpen ||
        ScoringDisplayUtils.isInningsComplete(match, inn!) ||
        match.status == MatchStatus.inningsBreak) {
      return;
    }

    final events =
        ref.read(ballEventsProvider(widget.matchId)).valueOrNull ?? [];
    if (ScoringDisplayUtils.needsNextOverBowler(
      inn,
      match.rules.ballsPerOver,
      events,
    )) {
      if (mounted) {
        final fresh = ref.read(matchProvider(widget.matchId)).valueOrNull ?? match;
        final overNum =
            fresh.currentInnings!.legalBalls ~/ fresh.rules.ballsPerOver + 1;
        await _pickBowlerForNextOver(fresh, overNum);
      }
      return;
    }

    WagonWheelData? wagonWheel;
    if (WagonWheelEligibility.shouldCapture(input, match.rules) && mounted) {
      final batsmanRuns = WagonWheelEligibility.batsmanRunsForShot(input);
      wagonWheel = await WagonWheelSelectionSheet.show(
        context,
        batsmanRuns: batsmanRuns,
      );
      if (wagonWheel == null) return;
    }

    setState(() => _isRecording = true);
    final sequence = _ballSequence + 1;
    final scorerUid = ref.read(authStateProvider).valueOrNull?.uid;
    final fullInput = BallEventInput(
      type: input.type,
      runs: input.runs,
      wicketType: input.wicketType,
      dismissedPlayerId: input.dismissedPlayerId,
      dismissedPlayerName: input.dismissedPlayerName,
      fielderId: input.fielderId,
      fielderName: input.fielderName,
      fielders: input.fielders,
      isMankad: input.isMankad,
      wicketKeeperId: input.wicketKeeperId,
      wicketKeeperName: input.wicketKeeperName,
      bowlerId: input.bowlerId,
      bowlerName: input.bowlerName,
      dismissalSubType: input.dismissalSubType,
      currentWicketKeeperId: input.currentWicketKeeperId,
      currentWicketKeeperName: input.currentWicketKeeperName,
      undoGroupId: undoGroupId ?? input.undoGroupId,
      noBallRunsMode: input.noBallRunsMode,
      nextStrikerId: input.nextStrikerId,
      nextStrikerName: input.nextStrikerName,
      runOutDeliveryKind: input.runOutDeliveryKind,
      completedRuns: input.completedRuns,
      wagonWheel: wagonWheel,
      createdBy: scorerUid,
      commentary: input.commentary.isNotEmpty
          ? input.commentary
          : CommentaryService.forBall(
              type: input.type,
              runs: input.runs,
              wicketType: input.wicketType,
              fielderName: input.fielderName,
              bowlerName: input.bowlerName,
            ),
    );

    try {
      final result = await ref.read(matchRepositoryProvider).recordBall(
            match: match,
            input: fullInput,
            sequence: sequence,
          );
      setState(() => _ballSequence = sequence);
      HapticFeedback.lightImpact();

      final updated = result.match;
      final updatedInn = updated.currentInnings;
      if (updatedInn != null && mounted) {
        if (ScoringDisplayUtils.isInningsComplete(updated, updatedInn)) {
          await _showInningsBreakDialog(
            updated,
            updatedInn,
            allowUndo: true,
          );
        } else if (fullInput.type != BallEventType.wide &&
            fullInput.type != BallEventType.noBall) {
          final bpo = updated.rules.ballsPerOver;
          if (updatedInn.legalBalls > 0 &&
              updatedInn.legalBalls % bpo == 0) {
            await _showOverComplete(updated, updatedInn);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scoring error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  /// Persists crease/bowler changes as ball events (replay-safe).
  Future<void> _recordLineupChange({
    required MatchModel match,
    required String strikerId,
    required String strikerName,
    required String nonStrikerId,
    required String nonStrikerName,
    required String bowlerId,
    required String bowlerName,
    String? undoGroupId,
    MatchModel? matchOverride,
  }) async {
    setState(() => _isRecording = true);
    final sequence = _ballSequence + 1;
    final scorerUid = ref.read(authStateProvider).valueOrNull?.uid;
    final matchForWrite =
        ref.read(matchProvider(widget.matchId)).valueOrNull ??
            matchOverride ??
            match;
    try {
      await ref.read(matchRepositoryProvider).recordBall(
            match: matchForWrite,
            input: BallEventInput(
              type: BallEventType.lineupChange,
              creaseStrikerId: strikerId,
              creaseNonStrikerId: nonStrikerId,
              creaseStrikerName: strikerName,
              creaseNonStrikerName: nonStrikerName,
              bowlerId: bowlerId,
              bowlerName: bowlerName,
              createdBy: scorerUid,
              commentary: 'Lineup updated',
              undoGroupId: undoGroupId,
            ),
            sequence: sequence,
          );
      setState(() => _ballSequence = sequence);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lineup error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _showOverComplete(MatchModel match, InningsModel innings) async {
    final events =
        ref.read(ballEventsProvider(widget.matchId)).valueOrNull ?? [];
    final overEvents = ScoringDisplayUtils.completedOverEvents(
      events: events,
      inn: innings,
      ballsPerOver: match.rules.ballsPerOver,
    );
    final overNum = innings.legalBalls ~/ match.rules.ballsPerOver;
    final finishedBowlerId = overEvents.isNotEmpty
        ? overEvents.last.bowlerId
        : ScoringDisplayUtils.bowlerWhoFinishedLastOver(
            inn: innings,
            events: events,
            ballsPerOver: match.rules.ballsPerOver,
          );
    final bowler = ScoringDisplayUtils.bowler(
      innings,
      finishedBowlerId ?? innings.currentBowlerId,
    );

    await OverCompleteDialog.show(
      context,
      overNumber: overNum,
      bowlerName: bowler?.playerName ?? 'Bowler',
      overEvents: overEvents,
      innings: innings,
      rules: match.rules,
      onStartNextOver: () {
        final fresh =
            ref.read(matchProvider(widget.matchId)).valueOrNull ?? match;
        _pickBowlerForNextOver(fresh, overNum + 1);
      },
    );
  }

  Future<void> _pickBowlerForNextOver(
    MatchModel match,
    int overNumber, {
    bool excludeLastOverBowler = true,
  }) async {
    final squads =
        ref.read(matchLineupSquadsProvider(widget.matchId)).valueOrNull;
    if (squads == null || squads.bowling.isEmpty) return;

    final events =
        ref.read(ballEventsProvider(widget.matchId)).valueOrNull ?? [];
    final inn = match.currentInnings!;
    final activeKeeper = ScoringDisplayUtils.activeWicketKeeper(
      match: match,
      inn: inn,
      events: events,
    );
    final excluded = <String>{};
    if (excludeLastOverBowler) {
      final id = ScoringDisplayUtils.bowlerWhoFinishedLastOver(
        inn: inn,
        events: events,
        ballsPerOver: match.rules.ballsPerOver,
      );
      if (id != null) excluded.add(id);
    }

    final picked = await SelectBowlerSheet.show(
      context,
      match: match,
      innings: inn,
      bowlingSquad: squads.bowling,
      overNumber: overNumber,
      excludedBowlerIds: excluded,
      wicketKeeperId: activeKeeper.id,
    );
    if (picked == null || !mounted) return;

    final latest =
        ref.read(matchProvider(widget.matchId)).valueOrNull ?? match;
    final latestInn = latest.currentInnings;
    if (latestInn == null ||
        latestInn.strikerId == null ||
        latestInn.nonStrikerId == null) {
      return;
    }
    await _recordLineupChange(
      match: latest,
      strikerId: latestInn.strikerId!,
      strikerName: ScoringDisplayUtils.batsman(
            latestInn,
            latestInn.strikerId,
          )?.playerName ??
          '',
      nonStrikerId: latestInn.nonStrikerId!,
      nonStrikerName: ScoringDisplayUtils.batsman(
            latestInn,
            latestInn.nonStrikerId,
          )?.playerName ??
          '',
      bowlerId: picked.id,
      bowlerName: picked.name,
    );
  }

  Future<void> _recordWicket() async {
    var wicketType = await showWicketPickerSheet(context);
    if (wicketType == null || !mounted) return;

    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    final inn = match?.currentInnings;
    if (match == null || inn == null) return;

    final squads =
        ref.read(matchLineupSquadsProvider(widget.matchId)).valueOrNull;
    if (squads == null) return;

    final events =
        ref.read(ballEventsProvider(widget.matchId)).valueOrNull ?? [];
    final activeKeeper = ScoringDisplayUtils.activeWicketKeeper(
      match: match,
      inn: inn,
      events: events,
    );

    final bowlerId = inn.currentBowlerId;
    final bowlerName =
        ScoringDisplayUtils.bowler(inn, bowlerId)?.playerName ?? '';
    String? dismissedPlayerId;
    String? fielderId;
    String? fielderName;
    String? wicketKeeperId;
    String? wicketKeeperName;
    String? dismissalSubType;
    List<DismissalFielder> fielders = const [];

    var runsBeforeDismissal = 0;
    RunOutFlowResult? runOutFlow;
    final isMankad = wicketType == WicketType.mankad;
    final undoGroupId = _uuid.v4();

    if (isMankad) {
      dismissedPlayerId = inn.nonStrikerId;
      if (dismissedPlayerId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No non-striker to dismiss for Mankad')),
        );
        return;
      }
      if (bowlerId != null) {
        fielderId = bowlerId;
        fielderName = bowlerName;
        fielders = [
          DismissalFielder(playerId: bowlerId, playerName: bowlerName),
        ];
      }
    } else if (wicketType == WicketType.runOut) {
      runOutFlow = await showRunOutSheet(
        context,
        innings: inn,
        rules: match.rules,
        bowlingSquad: squads.bowling,
        resolveLineup: (ctx, runOut) async {
          final survivorId = inn.strikerId == runOut.dismissedPlayerId
              ? inn.nonStrikerId
              : inn.strikerId;
          final eligible = ScoringDisplayUtils.eligibleBatters(
            inn,
            squads.batting,
            idOf: (p) => p.id,
            excludePlayerId: runOut.dismissedPlayerId,
          ).where((p) => p.id != survivorId).toList();

          if (eligible.isEmpty) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('No batters available — innings complete'),
                ),
              );
            }
            return null;
          }

          final newBatterOptions = eligible
              .map(
                (p) {
                  final b = ScoringDisplayUtils.batsman(inn, p.id);
                  return CreaseBatterOption(
                    playerId: p.id,
                    name: p.name,
                    runs: b?.runs ?? 0,
                    balls: b?.balls ?? 0,
                    roleLabel: 'Available',
                  );
                },
              )
              .toList();

          return showRunOutNextStrikerFlow(
            ctx,
            innings: inn,
            dismissedPlayerId: runOut.dismissedPlayerId,
            newBatterOptions: newBatterOptions,
          );
        },
      );
      if (runOutFlow == null || !mounted) return;

      final runOut = runOutFlow.runOut;
      dismissedPlayerId = runOut.dismissedPlayerId;
      fielders = runOut.fielders;
      if (fielders.isNotEmpty) {
        fielderId = fielders.first.playerId;
        fielderName = fielders.first.playerName;
      }
      runsBeforeDismissal = runOut.completedRuns;
    } else if (DismissalFormatter.usesWicketKeeper(wicketType)) {
      dismissedPlayerId = inn.strikerId;
      if (activeKeeper.id == null || activeKeeper.id!.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select a wicketkeeper in match setup first'),
          ),
        );
        return;
      }
      wicketKeeperId = activeKeeper.id;
      wicketKeeperName = activeKeeper.name;
      fielderId = activeKeeper.id;
      fielderName = activeKeeper.name ?? activeKeeper.id!;
      fielders = [
        DismissalFielder(
          playerId: activeKeeper.id!,
          playerName: fielderName,
        ),
      ];
    } else if (wicketType == WicketType.caught) {
      dismissedPlayerId = inn.strikerId;
      final fielder = await FielderPickerSheet.show(
        context,
        title: DismissalFormatter.fielderPickerTitle(wicketType),
        players: squads.bowling,
      );
      if (fielder == null || !mounted) return;
      fielderId = fielder.id;
      fielderName = fielder.name;
      fielders = [
        DismissalFielder(playerId: fielder.id, playerName: fielder.name),
      ];
      final resolved = DismissalFormatter.resolveCaughtDismissal(
        fielderId: fielder.id,
        bowlerId: bowlerId,
        wicketKeeperId: activeKeeper.id,
      );
      wicketType = resolved.wicketType;
      dismissalSubType = resolved.dismissalSubType;
      if (wicketType == WicketType.caughtAndBowled && bowlerId != null) {
        fielderId = bowlerId;
        fielderName = bowlerName;
        fielders = [
          DismissalFielder(playerId: bowlerId, playerName: bowlerName),
        ];
      } else if (dismissalSubType == DismissalSubType.caughtBehind) {
        wicketKeeperId = activeKeeper.id;
        wicketKeeperName = activeKeeper.name ?? fielder.name;
      }
    } else {
      dismissedPlayerId = DismissalFormatter.defaultDismissedPlayerId(
        type: wicketType,
        strikerId: inn.strikerId,
        nonStrikerId: inn.nonStrikerId,
      );
    }

    final dismissedPlayerName = ScoringDisplayUtils.batsman(
          inn,
          dismissedPlayerId,
        )?.playerName ??
        '';

    final isKeeperCatch = dismissalSubType == DismissalSubType.caughtBehind;

    await _record(
      BallEventInput(
        type: BallEventType.wicket,
        runs: runsBeforeDismissal,
        wicketType: wicketType,
        dismissalSubType: dismissalSubType,
        isMankad: isMankad,
        dismissedPlayerId: dismissedPlayerId,
        dismissedPlayerName: dismissedPlayerName,
        fielderId: fielderId,
        fielderName: fielderName,
        bowlerId: bowlerId,
        bowlerName: bowlerName.isEmpty ? null : bowlerName,
        fielders: fielders,
        wicketKeeperId: wicketKeeperId,
        wicketKeeperName: wicketKeeperName,
        currentWicketKeeperId: activeKeeper.id,
        currentWicketKeeperName: activeKeeper.name,
        nextStrikerId: runOutFlow?.lineup.strikerId,
        nextStrikerName: runOutFlow?.lineup.strikerName,
        runOutDeliveryKind: runOutFlow?.runOut.deliveryKind,
        completedRuns:
            runOutFlow?.runOut.completedRuns ?? runsBeforeDismissal,
        noBallRunsMode: runOutFlow?.runOut.noBallRunsMode,
        commentary: CommentaryService.forWicket(
          wicketType: wicketType,
          fielderName: isMankad ? bowlerName : fielderName,
          bowlerName: bowlerName,
          isMankad: isMankad,
          isWicketKeeper: isKeeperCatch || wicketType == WicketType.stumped,
        ),
      ),
      undoGroupId: undoGroupId,
      matchOverride: match,
    );
    if (!mounted) return;
    final updated =
        ref.read(matchProvider(widget.matchId)).valueOrNull ?? match;
    final updatedInn = updated.currentInnings;
    if (updatedInn != null &&
        !ScoringDisplayUtils.isInningsComplete(updated, updatedInn)) {
      if (wicketType == WicketType.runOut && runOutFlow != null) {
        final fresh =
            ref.read(matchProvider(widget.matchId)).valueOrNull ?? updated;
        final freshInn = fresh.currentInnings;
        if (freshInn != null) {
          await _recordLineupChange(
            match: fresh,
            strikerId: runOutFlow.lineup.strikerId,
            strikerName: runOutFlow.lineup.strikerName,
            nonStrikerId: runOutFlow.lineup.nonStrikerId,
            nonStrikerName: runOutFlow.lineup.nonStrikerName,
            bowlerId: freshInn.currentBowlerId ?? '',
            bowlerName: ScoringDisplayUtils.bowler(
                  freshInn,
                  freshInn.currentBowlerId,
                )?.playerName ??
                '',
            undoGroupId: undoGroupId,
            matchOverride: fresh,
          );
        }
      } else {
        await _fillVacantCrease(updated, updatedInn, undoGroupId: undoGroupId);
      }
    }
  }

  Future<void> _showInningsCompleteIfNeeded(
    MatchModel match,
    InningsModel inn,
  ) async {
    if (!mounted || _inningsBreakDialogOpen) return;
    if (ScoringDisplayUtils.isInningsComplete(match, inn)) {
      await _showInningsBreakDialog(match, inn, allowUndo: true);
    }
  }

  Future<void> _fillVacantCrease(
    MatchModel match,
    InningsModel inn, {
    String? undoGroupId,
  }) async {
    if (inn.strikerId != null && inn.nonStrikerId != null) return;

    if (ScoringDisplayUtils.isInningsComplete(match, inn)) {
      await _showInningsCompleteIfNeeded(match, inn);
      return;
    }

    final needStriker = inn.strikerId == null;
    await _pickBatsman(
      match,
      inn,
      forStriker: needStriker,
      title: needStriker ? 'Select striker' : 'Select non-striker',
      undoGroupId: undoGroupId,
    );

    if (!mounted) return;
    final after = ref.read(matchProvider(widget.matchId)).valueOrNull;
    final afterInn = after?.currentInnings;
    if (after != null &&
        afterInn != null &&
        (afterInn.strikerId == null || afterInn.nonStrikerId == null)) {
      if (ScoringDisplayUtils.isInningsComplete(after, afterInn)) {
        await _showInningsCompleteIfNeeded(after, afterInn);
        return;
      }
      await _pickBatsman(
        after,
        afterInn,
        forStriker: afterInn.strikerId == null,
        title: afterInn.strikerId == null
            ? 'Select striker'
            : 'Select non-striker',
        undoGroupId: undoGroupId,
      );
    }

    if (!mounted) return;
    final latest = ref.read(matchProvider(widget.matchId)).valueOrNull;
    final latestInn = latest?.currentInnings;
    if (latest != null && latestInn != null) {
      await _showInningsCompleteIfNeeded(latest, latestInn);
    }
  }

  Future<void> _pickBatsman(
    MatchModel match,
    InningsModel inn, {
    required bool forStriker,
    required String title,
    String? undoGroupId,
  }) async {
    final squads =
        ref.read(matchLineupSquadsProvider(widget.matchId)).valueOrNull;
    if (squads == null) return;

    final otherId = forStriker ? inn.nonStrikerId : inn.strikerId;
    final eligible = ScoringDisplayUtils.eligibleBatters(
      inn,
      squads.batting,
      idOf: (p) => p.id,
      excludePlayerId: otherId,
    );

    if (eligible.isEmpty) {
      await _showInningsCompleteIfNeeded(match, inn);
      return;
    }

    final cardOptions = eligible
        .map(
          (p) {
            final b = ScoringDisplayUtils.batsman(inn, p.id);
            return CreaseBatterOption(
              playerId: p.id,
              name: p.name,
              runs: b?.runs ?? 0,
              balls: b?.balls ?? 0,
              roleLabel: 'Available',
            );
          },
        )
        .toList();

    final picked = await showNewBatterPicker(
      context,
      title: title,
      subtitle: 'Select the incoming batter',
      options: cardOptions,
    );

    if (picked == null || !mounted) return;

    final latest = ref.read(matchProvider(widget.matchId)).valueOrNull;
    final latestInn = latest?.currentInnings;
    if (latest == null || latestInn == null) return;

    try {
      await _recordLineupChange(
            match: latest,
            strikerId: forStriker
                ? picked.playerId
                : (latestInn.strikerId ?? picked.playerId),
            strikerName: forStriker
                ? picked.name
                : ScoringDisplayUtils.batsman(latestInn, latestInn.strikerId)
                        ?.playerName ??
                    picked.name,
            nonStrikerId: forStriker
                ? (latestInn.nonStrikerId ?? picked.playerId)
                : picked.playerId,
            nonStrikerName: forStriker
                ? ScoringDisplayUtils.batsman(
                        latestInn, latestInn.nonStrikerId)
                    ?.playerName ??
                    picked.name
                : picked.name,
            bowlerId: latestInn.currentBowlerId!,
            bowlerName: ScoringDisplayUtils.bowler(
                  latestInn,
                  latestInn.currentBowlerId,
                )?.playerName ??
                '',
            undoGroupId: undoGroupId,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _recordExtra(
    Future<BallEventInput?> Function() dialog,
  ) async {
    final input = await dialog();
    if (input != null) await _record(input);
  }

  Future<void> _showInningsBreakDialog(
    MatchModel match,
    InningsModel innings, {
    required bool allowUndo,
  }) async {
    if (_inningsBreakDialogOpen || !mounted) return;
    setState(() => _inningsBreakDialogOpen = true);

    await InningsBreakDialog.show(
      context,
      match: match,
      innings: innings,
      allowUndo: allowUndo,
      onUndo: () async {
        Navigator.pop(context);
        setState(() => _inningsBreakDialogOpen = false);
        await _performUndo(showConfirm: false);
        if (!mounted) return;
        final fresh = ref.read(matchProvider(widget.matchId)).valueOrNull;
        final freshInn = fresh?.currentInnings;
        if (fresh != null &&
            freshInn != null &&
            fresh.status == MatchStatus.live &&
            ScoringDisplayUtils.isInningsComplete(fresh, freshInn)) {
          await _showInningsBreakDialog(fresh, freshInn, allowUndo: true);
        }
      },
      onConfirm: () async {
        Navigator.pop(context);
        setState(() => _inningsBreakDialogOpen = false);
        await _confirmInningsBreak(match, innings);
      },
    );

    if (mounted) setState(() => _inningsBreakDialogOpen = false);
  }

  Future<void> _confirmInningsBreak(
    MatchModel match,
    InningsModel innings,
  ) async {
    setState(() => _isRecording = true);
    try {
      final repo = ref.read(matchRepositoryProvider);

      if (innings.status == InningsStatus.inProgress) {
        await repo.endCurrentInnings(widget.matchId);
      }

      final fresh = await repo.getMatch(widget.matchId) ?? match;
      final ended = fresh.innings.length > innings.inningsNumber - 1
          ? fresh.innings[innings.inningsNumber - 1]
          : innings;

      if (MatchCompletionPolicy.shouldOfferSuperOver(fresh) ||
          MatchCompletionPolicy.isTiedChaseComplete(fresh, ended)) {
        await repo.startSuperOver(widget.matchId);
        if (mounted) context.go('/match/${widget.matchId}/start-innings');
        return;
      }

      final superOvers = fresh.innings.where((i) => i.isSuperOver).length;
      final regularCount =
          fresh.innings.where((i) => !i.isSuperOver).length;
      final hasNext = ended.isSuperOver
          ? superOvers < 2
          : regularCount < fresh.rules.maxInnings;

      if (!hasNext) {
        final completed = await repo.completeMatch(widget.matchId);
        if (completed != null) {
          await ref
              .read(tournamentRepositoryProvider)
              .advanceKnockoutFromMatch(completed);
        }
        if (mounted) {
          context.go('/match/${widget.matchId}');
        }
        return;
      }

      if (fresh.innings.length == ended.inningsNumber) {
        await repo.startNextInnings(widget.matchId);
      }
      if (mounted) context.go('/match/${widget.matchId}/start-innings');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not continue: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  void _handleInningsBreakState(MatchModel match) {
    if (_inningsBreakDialogOpen || _suppressInningsBreakCheck || !mounted) {
      return;
    }
    final inn = match.currentInnings;
    if (inn == null) return;

    if (match.status == MatchStatus.inningsBreak &&
        inn.status == InningsStatus.completed) {
      _showInningsBreakDialog(match, inn, allowUndo: false);
      return;
    }

    if (match.status == MatchStatus.live &&
        inn.status == InningsStatus.inProgress &&
        ScoringDisplayUtils.isInningsComplete(match, inn)) {
      _showInningsBreakDialog(match, inn, allowUndo: true);
    }
  }

  Future<void> _undo() async {
    await _performUndo(showConfirm: true);
  }

  Future<void> _performUndo({required bool showConfirm}) async {
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    if (match != null && !ScoringDisplayUtils.canUndoInnings(match)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot undo after innings is marked complete'),
          ),
        );
      }
      return;
    }

    if (showConfirm) {
      final confirmed = await ScoringUiKit.confirmAction(
        context,
        title: 'Undo?',
        message: 'Undo last ball?',
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isRecording = true;
      _suppressInningsBreakCheck = true;
    });
    try {
      await ref.read(matchRepositoryProvider).undoLastBall(widget.matchId);
      final seq = await ref
          .read(matchRepositoryProvider)
          .lastBallSequence(widget.matchId);
      if (mounted) setState(() => _ballSequence = seq);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Undo failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _suppressInningsBreakCheck = false;
        });
        final fresh = ref.read(matchProvider(widget.matchId)).valueOrNull;
        final freshInn = fresh?.currentInnings;
        if (fresh != null &&
            freshInn != null &&
            fresh.status == MatchStatus.live &&
            ScoringDisplayUtils.isInningsComplete(fresh, freshInn)) {
          _handleInningsBreakState(fresh);
        }
      }
    }
  }

  Future<void> _endInnings() async {
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    if (match == null) return;

    if (match.rules.maxInnings <= 1) {
      final go = await ScoringUiKit.confirmAction(
        context,
        title: 'End match?',
        message: 'Complete this match?',
        confirmLabel: 'Complete',
      );
      if (go == true) {
        final completed = await ref
            .read(matchRepositoryProvider)
            .completeMatch(widget.matchId);
        if (completed != null) {
          await ref
              .read(tournamentRepositoryProvider)
              .advanceKnockoutFromMatch(completed);
        }
        if (mounted) {
          context.go('/match/${widget.matchId}');
        }
      }
      return;
    }

    final inn = match.currentInnings;
    if (inn != null && ScoringDisplayUtils.isInningsComplete(match, inn)) {
      await _showInningsBreakDialog(match, inn, allowUndo: true);
      return;
    }

    await ref.read(matchRepositoryProvider).endCurrentInnings(widget.matchId);
    if (!mounted) return;

    final fresh = await ref.read(matchRepositoryProvider).getMatch(widget.matchId);
    final ended = fresh?.currentInnings;
    if (fresh != null && ended != null && mounted) {
      await _showInningsBreakDialog(fresh, ended, allowUndo: false);
    }
  }

  Future<void> _replaceBatsman(MatchModel match, {required bool striker}) async {
    final squads =
        ref.read(matchLineupSquadsProvider(widget.matchId)).valueOrNull;
    final inn = match.currentInnings;
    if (squads == null || inn == null) return;

    final eligible = ScoringDisplayUtils.eligibleBatters(
      inn,
      squads.batting,
      idOf: (p) => p.id,
      excludePlayerId: striker ? inn.nonStrikerId : inn.strikerId,
    );

    if (eligible.isEmpty) {
      await _showInningsCompleteIfNeeded(match, inn);
      return;
    }

    final cardOptions = eligible
        .map(
          (p) {
            final b = ScoringDisplayUtils.batsman(inn, p.id);
            return CreaseBatterOption(
              playerId: p.id,
              name: p.name,
              runs: b?.runs ?? 0,
              balls: b?.balls ?? 0,
              roleLabel: 'Available',
            );
          },
        )
        .toList();

    final picked = await showNewBatterPicker(
      context,
      title: striker ? 'Replace striker' : 'Replace non-striker',
      subtitle: 'Select the incoming batter',
      options: cardOptions,
    );
    if (picked == null || !mounted) return;

    await _recordLineupChange(
          match: match,
          strikerId: striker ? picked.playerId : inn.strikerId!,
          strikerName: striker
              ? picked.name
              : ScoringDisplayUtils.batsman(inn, inn.strikerId)?.playerName ??
                  '',
          nonStrikerId: striker ? inn.nonStrikerId! : picked.playerId,
          nonStrikerName: striker
              ? ScoringDisplayUtils.batsman(inn, inn.nonStrikerId)
                      ?.playerName ??
                  ''
              : picked.name,
          bowlerId: inn.currentBowlerId!,
          bowlerName:
              ScoringDisplayUtils.bowler(inn, inn.currentBowlerId)?.playerName ??
                  '',
        );
  }

  Future<void> _replaceBowler(MatchModel match) async {
    final inn = match.currentInnings;
    if (inn == null) return;
    final bpo = match.rules.ballsPerOver;
    final overNum = inn.legalBalls ~/ bpo + 1;
    final atOverStart = inn.legalBalls % bpo == 0;
    await _pickBowlerForNextOver(
      match,
      overNum,
      excludeLastOverBowler: atOverStart && inn.legalBalls > 0,
    );
  }

  void _openLineupSheet(MatchModel match) {
    final squadsAsync = ref.read(matchLineupSquadsProvider(widget.matchId));
    squadsAsync.whenData((squads) {
      final inn = match.currentInnings;
      final batting = inn == null
          ? squads.batting
          : ScoringDisplayUtils.eligibleBatters(
              inn,
              squads.batting,
              idOf: (p) => p.id,
            );
      final keeperId = inn != null
          ? ScoringDisplayUtils.wicketKeeperIdForTeam(match, inn.bowlingTeamId)
          : null;
      PlayerLineupPicker.show(
        context,
        battingSquad: batting,
        bowlingSquad: squads.bowling,
        initialStrikerId: inn?.strikerId,
        initialNonStrikerId: inn?.nonStrikerId,
        initialBowlerId: inn?.currentBowlerId,
        wicketKeeperId: keeperId,
        onSave: ({
          required strikerId,
          required strikerName,
          required nonStrikerId,
          required nonStrikerName,
          required bowlerId,
          required bowlerName,
        }) async {
          final events =
              ref.read(ballEventsProvider(widget.matchId)).valueOrNull ?? [];
          if (events.isNotEmpty) {
            await _recordLineupChange(
              match: match,
              strikerId: strikerId,
              strikerName: strikerName,
              nonStrikerId: nonStrikerId,
              nonStrikerName: nonStrikerName,
              bowlerId: bowlerId,
              bowlerName: bowlerName,
            );
          } else {
            await ref.read(matchRepositoryProvider).updateLineup(
                  matchId: widget.matchId,
                  strikerId: strikerId,
                  strikerName: strikerName,
                  nonStrikerId: nonStrikerId,
                  nonStrikerName: nonStrikerName,
                  bowlerId: bowlerId,
                  bowlerName: bowlerName,
                );
          }
          if (mounted) Navigator.pop(context);
        },
      );
    });
  }

  Future<void> _changeWicketKeeper(MatchModel match) async {
    final inn = match.currentInnings;
    if (inn == null) return;

    final squads =
        ref.read(matchLineupSquadsProvider(widget.matchId)).valueOrNull;
    if (squads == null || squads.bowling.isEmpty) return;

    final picked = await FielderPickerSheet.show(
      context,
      title: 'Select wicketkeeper',
      players: squads.bowling,
    );
    if (picked == null || !mounted) return;

    final events =
        ref.read(ballEventsProvider(widget.matchId)).valueOrNull ?? [];
    final activeKeeper = ScoringDisplayUtils.activeWicketKeeper(
      match: match,
      inn: inn,
      events: events,
    );
    if (picked.id == activeKeeper.id) return;

    setState(() => _isRecording = true);
    final sequence = _ballSequence + 1;
    final scorerUid = ref.read(authStateProvider).valueOrNull?.uid;
    try {
      await ref.read(matchRepositoryProvider).recordBall(
            match: match,
            input: BallEventInput(
              type: BallEventType.wicketKeeperChange,
              wicketKeeperId: picked.id,
              wicketKeeperName: picked.name,
              currentWicketKeeperId: picked.id,
              currentWicketKeeperName: picked.name,
              createdBy: scorerUid,
              commentary:
                  'Wicketkeeper changed to ${DismissalFormatter.formatKeeperDisplayName(picked.name)}',
            ),
            sequence: sequence,
          );
      setState(() => _ballSequence = sequence);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Keeper change error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  void _openQuickOptions(MatchModel match) {
    final canEditToss = ScoringDisplayUtils.canEditTossDecision(match);
    ScoringUiKit.showSheet(
      context,
      isScrollControlled: true,
      builder: (ctx) => ScoringQuickOptionsSheet(
        onEditLineup: () => _openLineupSheet(match),
        onChangeWicketkeeper: () => _changeWicketKeeper(match),
        onEndInnings: () => _endInnings(),
        onScorecard: () => context.push('/match/${widget.matchId}/scorecard'),
        onMatchRules: () async {
          final updated = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  MatchScoringRulesScreen(initialRules: match.rules),
            ),
          );
          if (updated != null && mounted) {
            await ref.read(matchRepositoryProvider).updateMatch(
                  match.copyWith(rules: updated),
                );
          }
        },
        onEditToss: canEditToss
            ? () => EditTossDecisionSheet.show(
                  context,
                  matchId: widget.matchId,
                  match: match,
                  redirectToLineup: true,
                )
            : null,
      ),
    );
  }

  Future<void> _openMatchRules(MatchModel match) async {
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchScoringRulesScreen(initialRules: match.rules),
      ),
    );
    if (updated != null) {
      await ref.read(matchRepositoryProvider).updateMatch(
            match.copyWith(rules: updated),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchProvider(widget.matchId));
    final eventsAsync = ref.watch(ballEventsProvider(widget.matchId));
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final uid = ref.watch(authStateProvider).value?.uid;

    ref.listen<AsyncValue<MatchModel?>>(matchProvider(widget.matchId), (prev, next) {
      next.whenData((match) {
        if (match != null && mounted && _sequenceLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _handleInningsBreakState(match);
          });
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.chromeBackground,
        foregroundColor: AppColors.chromeForeground,
        elevation: 0,
        title: matchAsync.when(
          data: (m) {
            final inn = m?.currentInnings;
            if (m == null || inn == null) {
              return const Text('Live scoring');
            }
            return Text(
              ScoringDisplayUtils.battingTeamName(m, inn).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 0.3,
                color: AppColors.textPrimary,
              ),
            );
          },
          loading: () => const Text('Live scoring'),
          error: (_, __) => const Text('Live scoring'),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.ios_share_outlined,
              color: AppColors.chromeForeground,
            ),
            tooltip: 'Share',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share scorecard — coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.chromeForeground,
            ),
            onPressed: () {
              final m = matchAsync.valueOrNull;
              if (m != null) _openMatchRules(m);
            },
          ),
        ],
      ),
      body: matchAsync.when(
        data: (match) {
          if (match == null) {
            return const Center(child: Text('Match not found'));
          }

          if (!canManageMatch(
            match: match,
            userId: uid,
            role: profile?.role ?? UserRole.organizer,
          )) {
            return _lockedView(context);
          }

          if (!_sequenceLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final inn = match.currentInnings;
          if (inn == null) {
            return const Center(child: Text('No active innings'));
          }

          final needsLineup =
              inn.strikerId == null || inn.currentBowlerId == null;

          final events = eventsAsync.valueOrNull ?? [];
          final overEvents = ScoringDisplayUtils.currentOverEvents(
            events: events,
            inn: inn,
            ballsPerOver: match.rules.ballsPerOver,
          );

          return Column(
            children: [
              Flexible(
                flex: 30,
                fit: FlexFit.tight,
                child: LiveScoringHeader(
                  match: match,
                  innings: inn,
                  rules: match.rules,
                ),
              ),
              if (needsLineup)
                MaterialBanner(
                  content: const Text(
                    'Tap to set striker, non-striker & bowler',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => _openLineupSheet(match),
                      child: const Text('Set lineup'),
                    ),
                  ],
                ),
              LiveScoringPlayersStrip(
                innings: inn,
                rules: match.rules,
                overEvents: overEvents,
                bowlingSide: _bowlingSide,
                onBowlingSideChanged: (s) => setState(() => _bowlingSide = s),
                onReplaceStriker: needsLineup
                    ? null
                    : () => _replaceBatsman(match, striker: true),
                onReplaceNonStriker: needsLineup
                    ? null
                    : () => _replaceBatsman(match, striker: false),
                onReplaceBowler:
                    needsLineup ? null : () => _replaceBowler(match),
              ),
              Flexible(
                flex: 40,
                fit: FlexFit.tight,
                child: LayoutBuilder(
                  builder: (context, keypadConstraints) {
                    return LiveScoringKeypad(
                      height: keypadConstraints.maxHeight,
                      isBusy: _isRecording,
                      onRun: (r) => _record(
                        BallEventInput(type: BallEventType.runs, runs: r),
                      ),
                      onWide: () => _recordExtra(
                        () => ScoringExtraDialogs.showWide(
                          context,
                          rules: match.rules,
                        ),
                      ),
                      onNoBall: () => _recordExtra(
                        () => ScoringExtraDialogs.showNoBall(
                          context,
                          rules: match.rules,
                        ),
                      ),
                      onBye: () async {
                        final input =
                            await ScoringExtraDialogs.showBye(context);
                        if (input != null) await _record(input);
                      },
                      onLegBye: () async {
                        final input =
                            await ScoringExtraDialogs.showLegBye(context);
                        if (input != null) await _record(input);
                      },
                      onOut: _recordWicket,
                      onUndo: _undo,
                    );
                  },
                ),
              ),
              SizedBox(
                height: 46,
                child: InkWell(
                  onTap: () => _openQuickOptions(match),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        top: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Scoring shortcuts',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_up,
                          color: AppColors.gold,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _lockedView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.gold),
            const SizedBox(height: 16),
            const Text(
              'Scoring is limited to match organizers and scorers.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/match/${widget.matchId}/scorecard'),
              child: const Text('View scorecard'),
            ),
          ],
        ),
      ),
    );
  }
}
