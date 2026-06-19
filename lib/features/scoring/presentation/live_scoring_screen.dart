import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../core/utils/match_permissions.dart';
import '../../../data/models/innings_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/over_note_model.dart';
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
import 'widgets/over_completion_prompt_dialog.dart';
import 'widgets/manual_over_note_dialog.dart';
import 'widgets/run_out_sheet.dart';
import 'widgets/scoring_extra_dialogs.dart';
import 'widgets/scoring_quick_options_sheet.dart';
import 'widgets/change_scorer_sheet.dart';
import '../../../shared/widgets/scoring_ui_kit.dart';
import 'widgets/change_bowler_sheet.dart';
import 'widgets/change_batters_sheet.dart';
import 'widgets/mid_over_bowler_change_dialog.dart';
import 'widgets/revise_target_sheet.dart';
import 'widgets/end_innings_sheet.dart';
import 'widgets/match_result_sheet.dart';
import 'widgets/target_revision_banner.dart';
import 'widgets/need_help_sheet.dart';
import 'widgets/power_play_management_sheet.dart';
import 'widgets/match_breaks_sheet.dart';
import 'widgets/match_break_banner.dart';
import 'live_change_squad_screen.dart';
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
  /// After "Continue over", skip re-prompt until this over ends.
  bool _overContinuationActive = false;
  String? _lastKnownScorerId;
  String? _scorerTransferBanner;

  @override
  void initState() {
    super.initState();
    _loadSequence();
    ref.read(notificationServiceProvider).subscribeToMatch(widget.matchId);
  }

  bool _guardActiveScorer(MatchModel match) {
    final uid = ref.read(authStateProvider).value?.uid;
    final role =
        ref.read(currentUserProfileProvider).valueOrNull?.role ??
            UserRole.organizer;
    if (canScoreMatch(match: match, userId: uid, role: role)) {
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not the active scorer of this match.'),
        ),
      );
    }
    return false;
  }

  void _handleScorerOwnershipChange(MatchModel? prev, MatchModel? next) {
    if (next == null) return;
    final uid = ref.read(authStateProvider).value?.uid;
    final newScorer = effectiveScorerId(next);
    if (_lastKnownScorerId == null) {
      _lastKnownScorerId = newScorer;
      return;
    }
    if (newScorer == _lastKnownScorerId) return;

    final name = next.currentScorerName.isNotEmpty
        ? next.currentScorerName
        : 'another user';
    if (uid != null && newScorer != uid && mounted) {
      setState(() {
        _scorerTransferBanner = 'Scoring control transferred to $name';
      });
    }
    _lastKnownScorerId = newScorer;
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
    if (!_guardActiveScorer(match)) return;

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
        final overNum = ScoringDisplayUtils.currentOverNumber(
          fresh.currentInnings!,
          fresh.rules.ballsPerOver,
        );
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
      swapReason: input.swapReason,
      runsCancelled: input.runsCancelled,
      swapNote: input.swapNote,
      creaseStrikerId: input.creaseStrikerId,
      creaseNonStrikerId: input.creaseNonStrikerId,
      creaseStrikerName: input.creaseStrikerName,
      creaseNonStrikerName: input.creaseNonStrikerName,
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
          if (!_overContinuationActive &&
              ScoringDisplayUtils.shouldPromptOverCompletion(updatedInn, bpo)) {
            await _promptOverCompletion(updated, updatedInn);
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
    String? previousBowlerId,
    String? bowlerChangeReason,
    MatchModel? matchOverride,
  }) async {
    final matchForWrite =
        ref.read(matchProvider(widget.matchId)).valueOrNull ??
            matchOverride ??
            match;
    if (!_guardActiveScorer(matchForWrite)) return;

    setState(() => _isRecording = true);
    final sequence = _ballSequence + 1;
    final scorerUid = ref.read(authStateProvider).valueOrNull?.uid;
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
              previousBowlerId: previousBowlerId,
              bowlerChangeReason: bowlerChangeReason,
              createdBy: scorerUid,
              commentary: previousBowlerId != null
                  ? 'Bowler changed'
                  : 'Lineup updated',
              undoGroupId: undoGroupId,
            ),
            sequence: sequence,
          );
      setState(() => _ballSequence = sequence);
      HapticFeedback.lightImpact();
      if (previousBowlerId != null) {
        debugPrint('Bowler change completed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              previousBowlerId != null
                  ? 'Unable to change bowler. Please try again.'
                  : 'Lineup error: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _promptOverCompletion(
    MatchModel match,
    InningsModel innings,
  ) async {
    final bpo = match.rules.ballsPerOver;
    final actual = ScoringDisplayUtils.ballsInCurrentOver(innings);
    final choice = await OverCompletionPromptDialog.show(
      context,
      legalDeliveries: actual,
      expectedBalls: bpo,
    );
    if (!mounted || choice == null) return;
    if (choice == OverCompletionChoice.endOver) {
      await _finishOver(
        match,
        requireNoteIfAdjusted: actual != bpo,
      );
    } else {
      setState(() => _overContinuationActive = true);
    }
  }

  Future<void> _manualEndOver(MatchModel match) async {
    final inn = match.currentInnings;
    if (inn == null) return;
    if (ScoringDisplayUtils.ballsInCurrentOver(inn) <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No legal deliveries in this over yet')),
        );
      }
      return;
    }
    await _finishOver(match, requireNoteIfAdjusted: true);
  }

  Future<void> _finishOver(
    MatchModel match, {
    required bool requireNoteIfAdjusted,
  }) async {
    if (!_guardActiveScorer(match)) return;
    final inn = match.currentInnings!;
    final bpo = match.rules.ballsPerOver;
    final actual = ScoringDisplayUtils.ballsInCurrentOver(inn);
    if (actual <= 0) return;

    String? noteReason;
    if (requireNoteIfAdjusted && actual != bpo) {
      noteReason = await ManualOverNoteDialog.show(
        context,
        expectedBalls: bpo,
        actualBalls: actual,
      );
      if (!mounted || noteReason == null) return;
    }

    setState(() => _isRecording = true);
    final sequence = _ballSequence + 1;
    final scorerUid = ref.read(authStateProvider).valueOrNull?.uid;
    OverNoteModel? overNote;
    if (noteReason != null) {
      overNote = OverNoteModel(
        inningsNumber: inn.inningsNumber,
        overNumber: ScoringDisplayUtils.currentOverNumber(inn, bpo),
        expectedBalls: bpo,
        actualBalls: actual,
        reason: noteReason,
        createdAt: DateTime.now(),
        scorerId: scorerUid,
      );
    }

    try {
      await ref.read(matchRepositoryProvider).recordBall(
            match: match,
            input: BallEventInput(
              type: BallEventType.endOver,
              commentary: 'Over ended',
              createdBy: scorerUid,
            ),
            sequence: sequence,
            overNote: overNote,
          );
      setState(() => _ballSequence = sequence);
      setState(() => _overContinuationActive = false);
      final fresh = ref.read(matchProvider(widget.matchId)).valueOrNull ?? match;
      final freshInn = fresh.currentInnings;
      if (freshInn != null && mounted) {
        await _showOverComplete(fresh, freshInn);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not end over: $e')),
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
    final overNum = ScoringDisplayUtils.ballsInCurrentOver(innings) == 0
        ? ScoringDisplayUtils.currentOverNumber(innings, match.rules.ballsPerOver) -
            1
        : ScoringDisplayUtils.currentOverNumber(innings, match.rules.ballsPerOver);
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
    await _openBowlerPicker(
      match,
      overNumber: overNumber,
      mode: BowlerPickMode.nextOver,
      excludeLastOverBowler: excludeLastOverBowler,
    );
  }

  Future<void> _changeBowler(MatchModel match) async {
    debugPrint('Change Bowler tapped');
    if (!_guardActiveScorer(match)) return;
    final inn = match.currentInnings;
    if (inn == null) return;
    if (inn.strikerId == null || inn.nonStrikerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set lineup before changing bowler')),
        );
      }
      return;
    }

    final bpo = match.rules.ballsPerOver;
    final overNum = ScoringDisplayUtils.currentOverNumber(inn, bpo);
    final ballsInOver = ScoringDisplayUtils.ballsInCurrentOver(inn);
    String? changeReason;

    if (ballsInOver > 0) {
      final overDisplay =
          ScoringDisplayUtils.inningsOversDisplay(inn, match.rules);
      changeReason = await MidOverBowlerChangeDialog.show(
        context,
        overDisplay: overDisplay,
        ballInOver: ballsInOver,
      );
      if (!mounted || changeReason == null) return;
    }

    await _openBowlerPicker(
      match,
      overNumber: overNum,
      mode: BowlerPickMode.changeBowler,
      excludeLastOverBowler: false,
      bowlerChangeReason: changeReason,
    );
  }

  Future<void> _openBowlerPicker(
    MatchModel match, {
    required int overNumber,
    required BowlerPickMode mode,
    required bool excludeLastOverBowler,
    String? bowlerChangeReason,
  }) async {
    debugPrint('Loading bowlers');
    MatchLineupSquads squads;
    try {
      squads = await ref.read(matchLineupSquadsProvider(widget.matchId).future);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load bowlers. Please try again.'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    if (squads.bowling.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No eligible bowlers available.')),
      );
      return;
    }

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

    final eligible = ChangeBowlerSheet.eligibleCount(
      squad: squads.bowling,
      match: match,
      innings: inn,
      mode: mode,
      excludedBowlerIds: excluded,
      wicketKeeperId: activeKeeper.id,
    );
    if (eligible == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No eligible bowlers available.')),
        );
      }
      return;
    }

    final picked = await ChangeBowlerSheet.show(
      context,
      match: match,
      innings: inn,
      bowlingSquad: squads.bowling,
      overNumber: overNumber,
      mode: mode,
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

    final previousBowlerId = latestInn.currentBowlerId;
    if (picked.id == previousBowlerId) return;

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
      previousBowlerId: previousBowlerId,
      bowlerChangeReason: bowlerChangeReason,
    );
  }

  Future<void> _recordWicket() async {
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    if (match == null || !_guardActiveScorer(match)) return;

    var wicketType = await showWicketPickerSheet(context);
    if (wicketType == null || !mounted) return;

    final inn = match.currentInnings;
    if (inn == null) return;

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
    RunOutResult? runOutResult;
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
      runOutResult = await showRunOutSheet(
        context,
        innings: inn,
        rules: match.rules,
        bowlingSquad: squads.bowling,
      );
      if (runOutResult == null || !mounted) return;

      dismissedPlayerId = runOutResult.dismissedPlayerId;
      fielders = runOutResult.fielders;
      if (fielders.isNotEmpty) {
        fielderId = fielders.first.playerId;
        fielderName = fielders.first.playerName;
      }
      runsBeforeDismissal = runOutResult.completedRuns;
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
        nextStrikerId: null,
        nextStrikerName: null,
        runOutDeliveryKind: runOutResult?.deliveryKind,
        completedRuns:
            runOutResult?.completedRuns ?? runsBeforeDismissal,
        noBallRunsMode: runOutResult?.noBallRunsMode,
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
      if (wicketType == WicketType.runOut && runOutResult != null) {
        final fresh =
            ref.read(matchProvider(widget.matchId)).valueOrNull ?? updated;
        final freshInn = fresh.currentInnings;
        if (freshInn != null) {
          final survivorId = freshInn.strikerId ?? freshInn.nonStrikerId;
          final eligible = ScoringDisplayUtils.eligibleBatters(
            freshInn,
            squads.batting,
            idOf: (p) => p.id,
            excludePlayerId: runOutResult.dismissedPlayerId,
          ).where((p) => p.id != survivorId).toList();

          if (eligible.isNotEmpty) {
            final newBatterOptions = eligible
                .map(
                  (p) {
                    final b = ScoringDisplayUtils.batsman(freshInn, p.id);
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

            final lineup = await showRunOutNextStrikerFlow(
              context,
              innings: freshInn,
              dismissedPlayerId: runOutResult.dismissedPlayerId,
              newBatterOptions: newBatterOptions,
            );
            if (lineup != null && mounted) {
              await _recordLineupChange(
                match: fresh,
                strikerId: lineup.strikerId,
                strikerName: lineup.strikerName,
                nonStrikerId: lineup.nonStrikerId,
                nonStrikerName: lineup.nonStrikerName,
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
          }
        }
      } else {
        await _fillVacantCrease(updated, updatedInn, undoGroupId: undoGroupId);
      }
    }
  }

  Future<void> _changeBatters(MatchModel match) async {
    final inn = match.currentInnings;
    if (inn == null ||
        inn.strikerId == null ||
        inn.nonStrikerId == null ||
        !_guardActiveScorer(match)) {
      return;
    }

    final result = await showChangeBattersSheet(context);
    if (result == null || !mounted) return;

    final strikerId = inn.strikerId!;
    final nonStrikerId = inn.nonStrikerId!;
    final strikerName =
        ScoringDisplayUtils.batsman(inn, strikerId)?.playerName ?? strikerId;
    final nonStrikerName =
        ScoringDisplayUtils.batsman(inn, nonStrikerId)?.playerName ??
            nonStrikerId;

    final swap = result.swapEnds;
    final newStrikerId = swap ? nonStrikerId : strikerId;
    final newNonStrikerId = swap ? strikerId : nonStrikerId;
    final newStrikerName = swap ? nonStrikerName : strikerName;
    final newNonStrikerName = swap ? strikerName : nonStrikerName;

    final commentary = switch (result.reason) {
      BatterSwapReason.manual => 'Striker and non-striker swapped',
      BatterSwapReason.shortRun => 'Short run — 1 run cancelled',
      BatterSwapReason.crossedBeforeWicket =>
        'Batters crossed before wicket',
      BatterSwapReason.umpireCorrection => 'Umpire correction — batters swapped',
      BatterSwapReason.other => 'Scoring adjustment',
    };

    await _record(
      BallEventInput(
        type: BallEventType.batterSwap,
        swapReason: result.reason.name,
        runsCancelled: result.runsCancelled,
        swapNote: result.note,
        creaseStrikerId: newStrikerId,
        creaseNonStrikerId: newNonStrikerId,
        creaseStrikerName: newStrikerName,
        creaseNonStrikerName: newNonStrikerName,
        commentary: result.note != null && result.note!.isNotEmpty
            ? '$commentary (${result.note})'
            : commentary,
      ),
    );
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
        if (await _tryAutoCompleteMatch(fresh)) return;
        await _showMatchResultDialog(fresh, ended);
        return;
      }

      if (fresh.innings.length == ended.inningsNumber &&
          repo.canStartNextInnings(fresh)) {
        await repo.startNextInnings(widget.matchId);
      }
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/match/${widget.matchId}/start-innings');
          }
        });
      }
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

  void _promptInningsBreakIfNeeded(MatchModel match) {
    _handleInningsBreakState(match);
  }

  Future<void> _undo() async {
    await _performUndo(showConfirm: true);
  }

  Future<void> _performUndo({required bool showConfirm}) async {
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    if (match == null || !_guardActiveScorer(match)) return;
    if (!ScoringDisplayUtils.canUndoInnings(match)) {
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
          _overContinuationActive = false;
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

  /// Completes the match when [MatchCompletionPolicy] already knows the winner.
  Future<bool> _tryAutoCompleteMatch(MatchModel match) async {
    final computed = MatchCompletionPolicy.compute(match);
    if (computed.winnerTeamId == null || computed.offerSuperOver) {
      return false;
    }
    await _completeMatchAndExit();
    return true;
  }

  Future<void> _completeMatchAndExit() async {
    final completed =
        await ref.read(matchRepositoryProvider).completeMatch(widget.matchId);
    if (completed != null) {
      await ref
          .read(tournamentRepositoryProvider)
          .advanceKnockoutFromMatch(completed);
    }
    if (mounted) context.go('/match/${widget.matchId}');
  }

  Future<void> _showMatchResultDialog(
    MatchModel match,
    InningsModel innings,
  ) async {
    if (!mounted) return;
    final uid = ref.read(authStateProvider).value?.uid ?? '';
    final revRepo = ref.read(matchTargetRevisionRepositoryProvider);
    final matchRepo = ref.read(matchRepositoryProvider);

    await MatchResultSheet.show(
      context,
      match: match,
      onConfirm: (input) async {
        if (input.isAbandoned) {
          await revRepo.setMatchResult(
            matchId: widget.matchId,
            isAbandoned: true,
            abandonedReason: input.abandonedReason,
            considerAllOversForNrr: input.considerAllOversForNrr,
            userId: uid,
          );
          if (mounted) context.go('/match/${widget.matchId}');
          return;
        }

        if (input.isDraw) {
          await revRepo.setMatchResult(
            matchId: widget.matchId,
            isDraw: true,
            considerAllOversForNrr: input.considerAllOversForNrr,
            userId: uid,
          );
          if (mounted) context.go('/match/${widget.matchId}');
          return;
        }

        var fresh = await matchRepo.getMatch(widget.matchId) ?? match;
        fresh = fresh.copyWith(
          winnerTeamId: input.winnerTeamId,
          targetState: fresh.targetState.copyWith(
            considerAllOversForNrr: input.considerAllOversForNrr,
          ),
        );
        await matchRepo.updateMatch(fresh);
        await _completeMatchAndExit();
      },
    );
  }

  Future<void> _endInnings() async {
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    if (match == null || !_guardActiveScorer(match)) return;

    if (match.rules.maxInnings <= 1) {
      final go = await ScoringUiKit.confirmAction(
        context,
        title: 'End match?',
        message: 'Complete this match?',
        confirmLabel: 'Complete',
      );
      if (go == true) {
        await _completeMatchAndExit();
      }
      return;
    }

    final inn = match.currentInnings;
    if (inn != null && ScoringDisplayUtils.isInningsComplete(match, inn)) {
      await _showInningsBreakDialog(match, inn, allowUndo: true);
      return;
    }

    await _openEndInningsSheet(match);
  }

  Future<void> _replaceBatsman(MatchModel match, {required bool striker}) async {
    if (!_guardActiveScorer(match)) return;
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
    await _changeBowler(match);
  }

  void _openLineupSheet(MatchModel match) {
    if (!_guardActiveScorer(match)) return;
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
    if (!_guardActiveScorer(match)) return;
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

  Future<void> _openReviseTarget(MatchModel match) async {
    if (!_guardActiveScorer(match)) return;
    final inn = match.currentInnings;
    if (inn == null) return;
    final uid = ref.read(authStateProvider).value?.uid ?? '';
    final repo = ref.read(matchTargetRevisionRepositoryProvider);

    await ReviseTargetSheet.show(
      context,
      match: match,
      innings: inn,
      onApplyDls: (input) async {
        await repo.applyScorerDlsRevision(
          matchId: widget.matchId,
          input: input,
          userId: uid,
        );
        if (mounted) {
          final isSecond =
              (match.currentInnings?.inningsNumber ?? 0) >= 2 &&
                  !(match.currentInnings?.isSuperOver ?? false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                input.continueInnings && !isSecond
                    ? 'Overs reduced to ${input.revisedOvers}'
                    : isSecond
                        ? 'Overs ${input.revisedOvers}, target ${input.revisedTarget}'
                        : 'DLS target saved — end innings to continue',
              ),
            ),
          );
        }
      },
      onApplyManual: (target, reason) async {
        await repo.applyManualTargetRevision(
          matchId: widget.matchId,
          revisedTarget: target,
          reason: reason,
          userId: uid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Target revised to $target')),
          );
        }
      },
      onEndInnings: () async {
        final fresh =
            ref.read(matchProvider(widget.matchId)).valueOrNull ?? match;
        await _openEndInningsSheet(fresh);
      },
    );
  }

  Future<void> _openEndInningsSheet(MatchModel match) async {
    if (!_guardActiveScorer(match)) return;
    final inn = match.currentInnings;
    if (inn == null) return;
    final uid = ref.read(authStateProvider).value?.uid ?? '';

    await EndInningsSheet.show(
      context,
      match: match,
      innings: inn,
      onConfirm: (result) async {
        try {
          await ref
              .read(matchTargetRevisionRepositoryProvider)
              .endInningsWithReason(
                matchId: widget.matchId,
                endReason: result.endReason,
                considerAllOversForNrr: result.considerAllOversForNrr,
                penaltyRuns: result.penaltyRuns,
                penaltyReason: result.penaltyReason,
                userId: uid,
              );
          if (!mounted) return;
          final fresh =
              await ref.read(matchRepositoryProvider).getMatch(widget.matchId);
          if (fresh == null) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _promptInningsBreakIfNeeded(fresh);
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not end innings: $e')),
            );
          }
          rethrow;
        }
      },
    );
  }

  void _openQuickOptions(MatchModel match) {
    final canEditToss = ScoringDisplayUtils.canEditTossDecision(match);
    final uid = ref.read(authStateProvider).value?.uid;
    final role = ref.read(currentUserProfileProvider).valueOrNull?.role ??
        UserRole.organizer;
    final canScore = canScoreMatch(match: match, userId: uid, role: role);
    ScoringUiKit.showSheet(
      context,
      isScrollControlled: true,
      builder: (ctx) => ScoringQuickOptionsSheet(
        onEditLineup: () => _openLineupSheet(match),
        onChangeWicketkeeper: () => _changeWicketKeeper(match),
        onChangeBowler: () => _changeBowler(match),
        onEndInnings: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _endInnings();
          });
        },
        onReviseTarget: canScore ? () => _openReviseTarget(match) : null,
        onEndOver: () => _manualEndOver(match),
        onScorecard: () => context.push('/match/${widget.matchId}/scorecard'),
        onMatchRules: () => _openMatchRules(match),
        onNeedHelp: canScore
            ? () => NeedHelpSheet.show(
                  context,
                  matchId: widget.matchId,
                )
            : null,
        onPowerPlay: canScore
            ? () => PowerPlayManagementSheet.show(context, match)
            : null,
        onChangeSquad: canScore
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        LiveChangeSquadScreen(matchId: widget.matchId),
                  ),
                )
            : null,
        onMatchBreaks: canScore
            ? () => MatchBreaksSheet.show(context, match)
            : null,
        onChangeScorer: canInitiateScorerTransfer(
          match: match,
          userId: ref.read(authStateProvider).value?.uid,
        )
            ? () => ChangeScorerSheet.show(context, match)
            : null,
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
    if (!_guardActiveScorer(match)) return;
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
      final prevMatch = prev?.valueOrNull;
      next.whenData((match) {
        if (match != null) {
          _handleScorerOwnershipChange(prevMatch, match);
          if (mounted && _sequenceLoaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _handleInningsBreakState(match);
            });
          }
        }
      });
    });

    final cf = context.cf;

    return Scaffold(
      backgroundColor: cf.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: cf.chromeBackground,
        foregroundColor: cf.chromeForeground,
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
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 0.3,
                color: cf.textPrimary,
              ),
            );
          },
          loading: () => const Text('Live scoring'),
          error: (_, __) => const Text('Live scoring'),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.ios_share_outlined,
              color: cf.chromeForeground,
            ),
            tooltip: 'Share',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share scorecard — coming soon')),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: cf.chromeForeground,
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

          final role = profile?.role ?? UserRole.organizer;
          if (uid == null || role == UserRole.viewer) {
            return _lockedView(context);
          }

          if (!_sequenceLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final inn = match.currentInnings;
          if (inn == null) {
            return const Center(child: Text('No active innings'));
          }

          final canScore = canScoreMatch(
            match: match,
            userId: uid,
            role: role,
          );
          final onBreak = match.isMatchBreakActive;
          final canRecord = canScore && !onBreak;
          final needsLineup =
              canRecord &&
              (inn.strikerId == null || inn.currentBowlerId == null);

          final events = eventsAsync.valueOrNull ?? [];
          final overEvents = ScoringDisplayUtils.currentOverEvents(
            events: events,
            inn: inn,
            ballsPerOver: match.rules.ballsPerOver,
          );

          return Column(
            children: [
              TargetRevisionBanner(
                match: match,
                onDismiss: () async {
                  await ref
                      .read(matchTargetRevisionRepositoryProvider)
                      .dismissLiveBanner(widget.matchId);
                },
              ),
              if (_scorerTransferBanner != null)
                MaterialBanner(
                  backgroundColor: cf.surfaceElevated,
                  content: Text(
                    _scorerTransferBanner!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cf.info,
                    ),
                  ),
                  leading: Icon(Icons.info_outline, color: cf.info),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          setState(() => _scorerTransferBanner = null),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              if (onBreak) MatchBreakBanner(match: match),
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
                onBowlingSideChanged: canRecord
                    ? (s) => setState(() => _bowlingSide = s)
                    : null,
                onReplaceStriker: needsLineup
                    ? null
                    : canRecord
                        ? () => _replaceBatsman(match, striker: true)
                        : null,
                onReplaceNonStriker: needsLineup
                    ? null
                    : canRecord
                        ? () => _replaceBatsman(match, striker: false)
                        : null,
                onChangeBatters: needsLineup || !canRecord
                    ? null
                    : () => _changeBatters(match),
                onReplaceBowler: needsLineup || !canRecord
                    ? null
                    : () => _replaceBowler(match),
              ),
              Flexible(
                flex: 40,
                fit: FlexFit.tight,
                child: onBreak && canScore
                    ? _breakKeypadPlaceholder(context)
                    : canRecord
                    ? LayoutBuilder(
                        builder: (context, keypadConstraints) {
                          return LiveScoringKeypad(
                            height: keypadConstraints.maxHeight,
                            isBusy: _isRecording,
                            onRun: (r) => _record(
                              BallEventInput(
                                type: BallEventType.runs,
                                runs: r,
                              ),
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
                              final input = await ScoringExtraDialogs.showLegBye(
                                context,
                              );
                              if (input != null) await _record(input);
                            },
                            onOut: _recordWicket,
                            onUndo: _undo,
                          );
                        },
                      )
                    : _readOnlyKeypadPlaceholder(context, match),
              ),
              SizedBox(
                height: 46,
                child: InkWell(
                  onTap: () => _openQuickOptions(match),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: cf.surface,
                      border: Border(
                        top: BorderSide(color: cf.border),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          canScore ? 'Scoring shortcuts' : 'View shortcuts',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: cf.textSecondary,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_up,
                          color: cf.accent,
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

  Widget _breakKeypadPlaceholder(BuildContext context) {
    final cf = context.cf;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pause_circle_outline,
                size: 40, color: cf.accent),
            const SizedBox(height: 12),
            const Text(
              'Match on break',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scoring is paused. Slide to resume on the banner above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cf.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyKeypadPlaceholder(BuildContext context, MatchModel match) {
    final cf = context.cf;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_outlined, size: 40, color: cf.accent),
            const SizedBox(height: 12),
            Text(
              'You are not an assigned scorer for this match.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cf.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/match/${widget.matchId}'),
              child: const Text('View Match'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  context.push('/match/${widget.matchId}/scorecard'),
              child: const Text('View scorecard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lockedView(BuildContext context) {
    final cf = context.cf;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 48, color: cf.accent),
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
