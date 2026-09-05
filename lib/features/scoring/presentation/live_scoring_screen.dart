import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/tournament/tournament_official_model.dart';
import '../../../core/utils/match_permissions.dart';
import '../../../core/utils/match_share_utils.dart';
import '../../../core/utils/quick_match_squad_utils.dart';
import '../../../core/utils/tournament_match_permissions.dart';
import '../../../shared/providers/tournament_providers.dart';
import '../../../data/models/ball_event_model.dart';
import '../../../data/models/innings_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/over_note_model.dart';
import '../../../domain/scoring/ball_event_aggregator.dart';
import '../../../domain/services/commentary_service.dart';
import '../../../domain/services/dismissal_formatter.dart';
import '../../../domain/services/scoring_engine.dart';
import '../../../domain/scoring/match_completion_policy.dart';
import '../../../domain/scoring/match_lifecycle.dart';
import '../../../shared/providers/lineup_providers.dart';
import '../../../shared/providers/my_cricket_ui_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_analytics_providers.dart';
import '../../../data/models/lineup_player.dart';
import '../../../shared/widgets/player_lineup_picker.dart';
import '../../../data/models/dismissal_fielder.dart';
import '../../matches/presentation/widgets/select_quick_match_player_sheet.dart';
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
import 'widgets/offline_sync_badge.dart';
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
  /// True while ending/starting next innings after slide confirm — blocks
  /// the match listener from re-opening the break sheet mid-confirm.
  bool _inningsBreakConfirmInFlight = false;
  bool _suppressInningsBreakCheck = false;
  /// Innings numbers whose break was already confirmed this session.
  /// Blocks stale `inningsBreak` snapshots from re-opening the slide sheet
  /// (Quick Match race: overlay/stream can still show completed innings 1).
  final Set<int> _dismissedInningsBreakNumbers = {};
  bool _bowlerPickerOpen = false;
  BowlingSide _bowlingSide = BowlingSide.over;
  /// After "Continue over", skip re-prompt until this over ends.
  bool _overContinuationActive = false;
  /// Set when an over ends until the next bowler is picked (offline-safe).
  bool _awaitingNextOverBowlerPick = false;
  String? _lastKnownScorerId;
  String? _scorerTransferBanner;

  @override
  void initState() {
    super.initState();
    _loadSequence();
    ref.read(notificationServiceProvider).subscribeToMatch(widget.matchId);
  }

  bool _canScoreThisMatch(MatchModel match) {
    final uid = ref.read(authStateProvider).value?.uid;
    final role =
        ref.read(currentUserProfileProvider).valueOrNull?.role ??
            UserRole.organizer;
    final tid = match.tournamentId;
    final tournament = tid != null && tid.isNotEmpty
        ? ref.read(tournamentProvider(tid)).valueOrNull
        : null;
    final officials = tid != null && tid.isNotEmpty
        ? ref.read(tournamentOfficialsProvider(tid)).valueOrNull ??
            const <TournamentOfficialModel>[]
        : const <TournamentOfficialModel>[];
    return canScoreTournamentMatch(
      match: match,
      userId: uid,
      role: role,
      tournament: tournament,
      officials: officials,
    );
  }

  bool _guardActiveScorer(MatchModel match) {
    if (_canScoreThisMatch(match)) {
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

  Future<MatchModel?> _record(
    BallEventInput input, {
    String? undoGroupId,
    MatchModel? matchOverride,
    bool deferOverCompletionPrompt = false,
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
      return null;
    }
    if (!_guardActiveScorer(match)) return null;

    final inn = match.currentInnings;
    if (inn?.currentBowlerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set lineup before scoring')),
        );
        _openLineupSheet(match);
      }
      return null;
    }
    if (inn?.strikerId == null || inn?.nonStrikerId == null) {
      if (mounted) {
        await _fillVacantCrease(match, inn!);
      }
      return null;
    }

    if (_inningsBreakDialogOpen ||
        ScoringDisplayUtils.isInningsComplete(match, inn!) ||
        match.status == MatchStatus.inningsBreak) {
      return null;
    }

    final events =
        ref.read(ballEventsProvider(widget.matchId)).valueOrNull ?? [];
    if (_awaitingNextOverBowlerPick ||
        ScoringDisplayUtils.needsNextOverBowler(
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
      return null;
    }

    WagonWheelData? wagonWheel;
    if (WagonWheelEligibility.shouldCapture(input, match.rules) && mounted) {
      final batsmanRuns = WagonWheelEligibility.batsmanRunsForShot(input);
      wagonWheel = await WagonWheelSelectionSheet.show(
        context,
        batsmanRuns: batsmanRuns,
      );
      if (wagonWheel == null) return null;
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
      setState(() => _ballSequence = result.event.sequence);
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
            fullInput.type != BallEventType.noBall &&
            !deferOverCompletionPrompt) {
          final bpo = updated.rules.ballsPerOver;
          if (!_overContinuationActive &&
              ScoringDisplayUtils.shouldPromptOverCompletion(updatedInn, bpo)) {
            await _promptOverCompletion(updated, updatedInn);
          }
        }
      }
      return updated;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scoring error: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  /// Persists crease/bowler changes as ball events (replay-safe).
  Future<MatchModel?> _recordLineupChange({
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
    String? commentary,
    MatchModel? matchOverride,
  }) async {
    final matchForWrite =
        ref.read(matchProvider(widget.matchId)).valueOrNull ??
            matchOverride ??
            match;
    if (!_guardActiveScorer(matchForWrite)) return null;

    setState(() => _isRecording = true);
    final sequence = _ballSequence + 1;
    final scorerUid = ref.read(authStateProvider).valueOrNull?.uid;
    try {
      final result = await ref.read(matchRepositoryProvider).recordBall(
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
              commentary: commentary ??
                  (previousBowlerId != null
                      ? 'Bowler changed'
                      : 'Lineup updated'),
              undoGroupId: undoGroupId,
            ),
            sequence: sequence,
          );
      setState(() => _ballSequence = result.event.sequence);
      HapticFeedback.lightImpact();
      if (previousBowlerId != null) {
        debugPrint('Bowler change completed');
      }
      return result.match;
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        final wkBlocked = msg.contains('Wicket keeper cannot bowl');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wkBlocked
                  ? ScoringDisplayUtils.wicketKeeperCannotBowlReason
                  : previousBowlerId != null
                      ? 'Unable to change bowler. Please try again.'
                      : 'Lineup error: $e',
            ),
          ),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _promptOverCompletion(
    MatchModel match,
    InningsModel innings, {
    bool preserveCreaseOnEndOver = false,
  }) async {
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
        preserveCreaseOnEndOver: preserveCreaseOnEndOver,
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
    bool preserveCreaseOnEndOver = false,
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
      final result = await ref.read(matchRepositoryProvider).recordBall(
            match: match,
            input: BallEventInput(
              type: BallEventType.endOver,
              commentary: 'Over ended',
              createdBy: scorerUid,
              preserveCreaseOnEndOver: preserveCreaseOnEndOver,
            ),
            sequence: sequence,
            overNote: overNote,
          );
      setState(() => _ballSequence = result.event.sequence);
      setState(() => _overContinuationActive = false);
      setState(() => _awaitingNextOverBowlerPick = true);
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

    final shouldPickNextBowler = await OverCompleteDialog.show(
      context,
      overNumber: overNum,
      bowlerName: bowler?.playerName ?? 'Bowler',
      overEvents: overEvents,
      innings: innings,
      rules: match.rules,
    );
    if (shouldPickNextBowler && mounted) {
      final fresh =
          ref.read(matchProvider(widget.matchId)).valueOrNull ?? match;
      await _pickBowlerForNextOver(fresh, overNum + 1);
    }
  }

  Future<void> _runExclusiveBowlerFlow(Future<void> Function() flow) async {
    if (_bowlerPickerOpen) return;
    _bowlerPickerOpen = true;
    if (mounted) setState(() {});
    try {
      await flow();
    } finally {
      _bowlerPickerOpen = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickBowlerForNextOver(
    MatchModel match,
    int overNumber, {
    bool excludeLastOverBowler = true,
  }) async {
    await _runExclusiveBowlerFlow(
      () => _openBowlerPicker(
        match,
        overNumber: overNumber,
        mode: BowlerPickMode.nextOver,
        excludeLastOverBowler: excludeLastOverBowler,
      ),
    );
  }

  Future<void> _changeBowler(MatchModel match) async {
    await _runExclusiveBowlerFlow(() async {
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
    });
  }

  Future<MatchLineupSquads> _resolveLineupSquads(MatchModel match) async {
    final cached =
        ref.read(matchLineupSquadsProvider(widget.matchId)).valueOrNull;
    if (cached != null &&
        (cached.bowling.isNotEmpty || cached.batting.isNotEmpty)) {
      return cached;
    }

    final offline = matchLineupSquadsFromMatch(match);
    if (offline.bowling.isNotEmpty || match.isQuickMatch) {
      return offline;
    }

    try {
      return await ref
          .read(matchLineupSquadsProvider(widget.matchId).future)
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      if (offline.bowling.isNotEmpty || offline.batting.isNotEmpty) {
        return offline;
      }
      rethrow;
    }
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
      squads = await _resolveLineupSquads(match);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              match.isQuickMatch
                  ? 'Unable to load bowlers. You can still add a walk-in player.'
                  : 'Unable to load bowlers. Check connection or try again.',
            ),
          ),
        );
      }
      if (!match.isQuickMatch) return;
      squads = matchLineupSquadsFromMatch(match);
    }

    if (!mounted) return;
    if (squads.bowling.isEmpty && !match.isQuickMatch) {
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

    final LineupPlayer? picked;
    if (match.isQuickMatch) {
      final bowlingTeamId = inn.bowlingTeamId;
      final bowlingIsA = matchTeamIsTeamA(match, bowlingTeamId);
      final walkIns = quickMatchWalkInsForTeam(
        match: match,
        teamId: bowlingTeamId,
        teamPlayers: squads.bowling,
      );
      // Same eligibility as ChangeBowlerSheet (max overs, WK, last over, current).
      final disabled = <String, String>{};
      final seen = <String>{};
      for (final p in [...squads.bowling, ...walkIns]) {
        if (!seen.add(p.id)) continue;
        final reason = ChangeBowlerSheet.ineligibility(
          player: p,
          match: match,
          innings: inn,
          mode: mode,
          excludedBowlerIds: excluded,
          wicketKeeperId: activeKeeper.id,
        );
        if (reason != BowlerIneligibility.none) {
          disabled[p.id] =
              ChangeBowlerSheet.ineligibilityLabel(reason, match.rules);
        }
      }
      picked = await SelectQuickMatchPlayerSheet.show(
        context,
        title: mode == BowlerPickMode.nextOver
            ? 'Select bowler — over $overNumber'
            : 'Change bowler',
        teamPlayers: squads.bowling,
        walkInPlayers: walkIns,
        disabledIds: disabled,
        playerSubtitles: buildBowlerPickerSubtitles(
          inn,
          match.rules.ballsPerOver,
        ),
        teamSectionLabel:
            '${quickMatchTeamLabel(match, bowlingTeamId)} · bowlers',
      );
      if (picked != null) {
        final pickReason = ChangeBowlerSheet.ineligibility(
          player: picked,
          match: match,
          innings: inn,
          mode: mode,
          excludedBowlerIds: excluded,
          wicketKeeperId: activeKeeper.id,
        );
        if (pickReason != BowlerIneligibility.none) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ChangeBowlerSheet.ineligibilityLabel(
                    pickReason,
                    match.rules,
                  ),
                ),
              ),
            );
          }
          return;
        }
        await ref.read(matchRepositoryProvider).ensurePlayersOnMatchSquad(
              matchId: widget.matchId,
              isTeamA: bowlingIsA,
              players: [snapshotFromLineupPlayer(picked)],
            );
        ref.invalidate(matchLineupSquadsProvider(widget.matchId));
      }
    } else {
      picked = await ChangeBowlerSheet.show(
        context,
        match: match,
        innings: inn,
        bowlingSquad: squads.bowling,
        overNumber: overNumber,
        mode: mode,
        excludedBowlerIds: excluded,
        wicketKeeperId: activeKeeper.id,
      );
    }
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

    final violation = ScoringDisplayUtils.wicketKeeperBowlingViolation(
      rules: latest.rules,
      bowlerId: picked.id,
      wicketKeeperId: ScoringDisplayUtils.activeWicketKeeper(
        match: latest,
        inn: latestInn,
        events: ref.read(ballEventsProvider(widget.matchId)).valueOrNull ?? [],
      ).id,
    );
    if (violation != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(violation)),
        );
      }
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
      previousBowlerId: previousBowlerId,
      bowlerChangeReason: bowlerChangeReason,
    );
    if (mounted) {
      setState(() => _awaitingNextOverBowlerPick = false);
    }
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
    RunOutLineupResult? runOutLineup;
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
        pickFielder: match.isQuickMatch
            ? ({required title, required excludeIds}) =>
                _pickBowlingSidePlayer(
                  match: match,
                  inn: inn,
                  bowlingSquad: squads.bowling,
                  title: title,
                  excludeIds: excludeIds,
                )
            : null,
      );
      if (runOutResult == null || !mounted) return;

      dismissedPlayerId = runOutResult.dismissedPlayerId;
      fielders = runOutResult.fielders;
      if (fielders.isNotEmpty) {
        fielderId = fielders.first.playerId;
        fielderName = fielders.first.playerName;
      }
      runsBeforeDismissal = runOutResult.completedRuns;

      if (!ScoringDisplayUtils.isInningsComplete(match, inn)) {
        final survivorId =
            runOutSurvivorId(inn, runOutResult.dismissedPlayerId);
        final eligible = ScoringDisplayUtils.eligibleBatters(
          inn,
          squads.batting,
          idOf: (p) => p.id,
          excludePlayerId: runOutResult.dismissedPlayerId,
        ).where((p) => survivorId == null || p.id != survivorId).toList();

        if (eligible.isNotEmpty) {
          final newBatterOptions = eligible
              .map(
                (p) {
                  final b = ScoringDisplayUtils.batsman(inn, p.id);
                  final runs = b?.runs ?? 0;
                  final balls = b?.balls ?? 0;
                  final returning = b != null &&
                      (b.retiredHurt || b.isEligibleToReturn) &&
                      !b.isOut;
                  return CreaseBatterOption(
                    playerId: p.id,
                    name: p.name,
                    runs: runs,
                    balls: balls,
                    roleLabel: returning
                        ? 'Returning · $runs($balls)'
                        : 'Available',
                  );
                },
              )
              .toList();

          runOutLineup = await showRunOutNextStrikerFlow(
            context,
            innings: inn,
            dismissedPlayerId: runOutResult.dismissedPlayerId,
            newBatterOptions: newBatterOptions,
          );
          if (runOutLineup == null || !mounted) return;
        }
      }
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
      final fielder = await _pickBowlingSidePlayer(
        match: match,
        inn: inn,
        bowlingSquad: squads.bowling,
        title: DismissalFormatter.fielderPickerTitle(wicketType),
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
    } else if (wicketType == WicketType.retiredHurt ||
        wicketType == WicketType.retiredOut) {
      dismissedPlayerId = await showRetirementBatterPicker(
        context,
        innings: inn,
        wicketType: wicketType,
      );
      if (dismissedPlayerId == null || !mounted) return;
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
    final dismissedRuns = ScoringDisplayUtils.batsman(
          inn,
          dismissedPlayerId,
        )?.runs ??
        0;

    final isKeeperCatch = dismissalSubType == DismissalSubType.caughtBehind;

    final isRunOut = wicketType == WicketType.runOut;
    final isRetiredHurt = wicketType == WicketType.retiredHurt;
    final isRetiredOut = wicketType == WicketType.retiredOut;

    final recorded = await _record(
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
        nextStrikerId: runOutLineup?.strikerId,
        nextStrikerName: runOutLineup?.strikerName,
        runOutDeliveryKind: runOutResult?.deliveryKind,
        completedRuns:
            runOutResult?.completedRuns ?? runsBeforeDismissal,
        noBallRunsMode: runOutResult?.noBallRunsMode,
        commentary: isRetiredHurt
            ? CommentaryService.forRetiredHurt(
                batterName: dismissedPlayerName,
                runs: dismissedRuns,
              )
            : isRetiredOut
                ? CommentaryService.forRetiredOut(
                    batterName: dismissedPlayerName,
                    runs: dismissedRuns,
                  )
                : CommentaryService.forWicket(
                    wicketType: wicketType,
                    fielderName: isMankad ? bowlerName : fielderName,
                    bowlerName: bowlerName,
                    batterName: dismissedPlayerName,
                    isMankad: isMankad,
                    isWicketKeeper:
                        isKeeperCatch || wicketType == WicketType.stumped,
                  ),
      ),
      undoGroupId: undoGroupId,
      matchOverride: match,
      deferOverCompletionPrompt: true,
    );
    if (!mounted || recorded == null) return;
    final updated = recorded;
    final updatedInn = updated.currentInnings;
    if (updatedInn != null &&
        !ScoringDisplayUtils.isInningsComplete(updated, updatedInn)) {
      if (isRunOut && runOutLineup != null) {
        await _recordLineupChange(
          match: updated,
          strikerId: runOutLineup.strikerId,
          strikerName: runOutLineup.strikerName,
          nonStrikerId: runOutLineup.nonStrikerId,
          nonStrikerName: runOutLineup.nonStrikerName,
          bowlerId: updatedInn.currentBowlerId ?? '',
          bowlerName: ScoringDisplayUtils.bowler(
                updatedInn,
                updatedInn.currentBowlerId,
              )?.playerName ??
              '',
          undoGroupId: undoGroupId,
          matchOverride: updated,
        );
        if (!mounted) return;
        final afterLineup =
            ref.read(matchProvider(widget.matchId)).valueOrNull ?? updated;
        final afterLineupInn = afterLineup.currentInnings;
        if (afterLineupInn != null &&
            !_overContinuationActive &&
            ScoringDisplayUtils.shouldPromptOverCompletion(
              afterLineupInn,
              afterLineup.rules.ballsPerOver,
            )) {
          await _promptOverCompletion(
            afterLineup,
            afterLineupInn,
            preserveCreaseOnEndOver: true,
          );
        }
      } else if (!isRunOut) {
        final afterCrease = await _fillVacantCrease(
          updated,
          updatedInn,
          undoGroupId: undoGroupId,
          excludeRecentlyRetiredHurtId:
              isRetiredHurt ? dismissedPlayerId : null,
        );
        if (!mounted) return;
        // Legal-ball count comes from the wicket; crease comes from lineup.
        // Do not preserve crease — end-over must rotate strike normally.
        final forOverPrompt = afterCrease ?? updated;
        final forOverInn = forOverPrompt.currentInnings ?? updatedInn;
        if (!_overContinuationActive &&
            ScoringDisplayUtils.shouldPromptOverCompletion(
              updatedInn,
              updated.rules.ballsPerOver,
            )) {
          await _promptOverCompletion(forOverPrompt, forOverInn);
        }
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

  Future<MatchModel?> _fillVacantCrease(
    MatchModel match,
    InningsModel inn, {
    String? undoGroupId,
    String? excludeRecentlyRetiredHurtId,
  }) async {
    if (inn.strikerId != null && inn.nonStrikerId != null) return match;

    if (ScoringDisplayUtils.isInningsComplete(match, inn)) {
      await _showInningsCompleteIfNeeded(match, inn);
      return match;
    }

    final needStriker = inn.strikerId == null;
    final bothEndsVacant = inn.strikerId == null && inn.nonStrikerId == null;
    var latestMatch = await _pickBatsman(
      match,
      inn,
      forStriker: needStriker,
      title: needStriker ? 'Select striker' : 'Select non-striker',
      undoGroupId: undoGroupId,
      excludeRecentlyRetiredHurtId: excludeRecentlyRetiredHurtId,
    );

    // Only when both crease ends were empty (rare) do we need a second pick.
    // After a normal wicket, one pick fills the vacant end — re-reading the
    // provider here is often stale and would open the sheet twice.
    if (bothEndsVacant && mounted) {
      final after = latestMatch ??
          ref.read(matchProvider(widget.matchId)).valueOrNull;
      final afterInn = after?.currentInnings;
      if (after != null &&
          afterInn != null &&
          (afterInn.strikerId == null || afterInn.nonStrikerId == null)) {
        if (ScoringDisplayUtils.isInningsComplete(after, afterInn)) {
          await _showInningsCompleteIfNeeded(after, afterInn);
          return after;
        }
        latestMatch = await _pickBatsman(
          after,
          afterInn,
          forStriker: afterInn.strikerId == null,
          title: afterInn.strikerId == null
              ? 'Select striker'
              : 'Select non-striker',
          undoGroupId: undoGroupId,
          excludeRecentlyRetiredHurtId: excludeRecentlyRetiredHurtId,
        );
      }
    }

    if (!mounted) return latestMatch ?? match;
    final latest = latestMatch ??
        ref.read(matchProvider(widget.matchId)).valueOrNull;
    final latestInn = latest?.currentInnings;
    if (latest != null && latestInn != null) {
      await _showInningsCompleteIfNeeded(latest, latestInn);
    }
    return latestMatch ?? match;
  }

  Future<MatchModel?> _pickBatsman(
    MatchModel match,
    InningsModel inn, {
    required bool forStriker,
    required String title,
    String? undoGroupId,
    String? excludeRecentlyRetiredHurtId,
  }) async {
    final squads =
        ref.read(matchLineupSquadsProvider(widget.matchId)).valueOrNull;
    if (squads == null) return null;

    final otherId = forStriker ? inn.nonStrikerId : inn.strikerId;
    final eligible = ScoringDisplayUtils.eligibleBatters(
      inn,
      squads.batting,
      idOf: (p) => p.id,
      excludePlayerId: otherId,
      excludeRecentlyRetiredHurtId: excludeRecentlyRetiredHurtId,
      // After RH of X, other RH returnable batters may fill X's spot;
      // X themselves are excluded via excludeRecentlyRetiredHurtId.
      includeReturningRetiredHurt: true,
    );

    if (eligible.isEmpty && !match.isQuickMatch) {
      await _showInningsCompleteIfNeeded(match, inn);
      return null;
    }

    late final String pickedPlayerId;
    late final String pickedPlayerName;

    if (match.isQuickMatch) {
      final battingTeamId = inn.battingTeamId;
      final battingIsA = matchTeamIsTeamA(match, battingTeamId);
      final walkIns = quickMatchWalkInsForTeam(
        match: match,
        teamId: battingTeamId,
        teamPlayers: squads.batting,
      );
      final quickPick = await SelectQuickMatchPlayerSheet.show(
        context,
        title: title,
        teamPlayers: eligible.isNotEmpty ? eligible : squads.batting,
        walkInPlayers: walkIns,
        excludeIds: {
          if (otherId != null) otherId,
          if (excludeRecentlyRetiredHurtId != null)
            excludeRecentlyRetiredHurtId,
        },
        teamSectionLabel:
            '${quickMatchTeamLabel(match, battingTeamId)} · batters',
      );
      if (quickPick == null || !mounted) return null;
      pickedPlayerId = quickPick.id;
      pickedPlayerName = quickPick.name;
      await ref.read(matchRepositoryProvider).ensurePlayersOnMatchSquad(
            matchId: widget.matchId,
            isTeamA: battingIsA,
            players: [snapshotFromLineupPlayer(quickPick)],
          );
      ref.invalidate(matchLineupSquadsProvider(widget.matchId));
    } else {
      final cardOptions = eligible
          .map(
            (p) {
              final b = ScoringDisplayUtils.batsman(inn, p.id);
              final runs = b?.runs ?? 0;
              final balls = b?.balls ?? 0;
              final returning = b != null &&
                  (b.retiredHurt || b.isEligibleToReturn) &&
                  !b.isOut;
              return CreaseBatterOption(
                playerId: p.id,
                name: p.name,
                runs: runs,
                balls: balls,
                roleLabel: returning
                    ? 'Returning · $runs($balls)'
                    : 'Available',
              );
            },
          )
          .toList();

      CreaseBatterOption? picked;
      while (picked == null && mounted) {
        picked = await showNewBatterPicker(
          context,
          title: title,
          subtitle: 'Select the incoming batter',
          options: cardOptions,
        );
      }
      if (picked == null || !mounted) return null;
      pickedPlayerId = picked.playerId;
      pickedPlayerName = picked.name;
    }

    final bowlerId = inn.currentBowlerId;
    if (bowlerId == null) return null;

    try {
      return await _recordLineupChange(
            match: match,
            strikerId: forStriker
                ? pickedPlayerId
                : (inn.strikerId ?? pickedPlayerId),
            strikerName: forStriker
                ? pickedPlayerName
                : ScoringDisplayUtils.batsman(inn, inn.strikerId)
                        ?.playerName ??
                    pickedPlayerName,
            nonStrikerId: forStriker
                ? (inn.nonStrikerId ?? pickedPlayerId)
                : pickedPlayerId,
            nonStrikerName: forStriker
                ? ScoringDisplayUtils.batsman(inn, inn.nonStrikerId)
                        ?.playerName ??
                    pickedPlayerName
                : pickedPlayerName,
            bowlerId: bowlerId,
            bowlerName: ScoringDisplayUtils.bowler(inn, bowlerId)?.playerName ??
                '',
            undoGroupId: undoGroupId,
            matchOverride: match,
            commentary: CommentaryService.forIncomingBatter(pickedPlayerName),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
      return null;
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
    if (_inningsBreakDialogOpen ||
        _inningsBreakConfirmInFlight ||
        !mounted) {
      return;
    }
    setState(() => _inningsBreakDialogOpen = true);

    try {
      await InningsBreakDialog.show(
        context,
        match: match,
        innings: innings,
        allowUndo: allowUndo,
        onUndo: () async {
          Navigator.pop(context);
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
          // Confirm before pop so the sheet future stays open and the
          // listener cannot reopen another slide while we end/start innings.
          _inningsBreakConfirmInFlight = true;
          await _confirmInningsBreak(match, innings);
          if (mounted) Navigator.pop(context);
        },
      );
    } finally {
      _inningsBreakConfirmInFlight = false;
      if (mounted) setState(() => _inningsBreakDialogOpen = false);
    }
  }

  Future<void> _confirmInningsBreak(
    MatchModel match,
    InningsModel innings,
  ) async {
    setState(() {
      _isRecording = true;
      _suppressInningsBreakCheck = true;
    });
    // Mark before async work so stale stream snapshots cannot reopen the sheet.
    _dismissedInningsBreakNumbers.add(innings.inningsNumber);
    try {
      final repo = ref.read(matchRepositoryProvider);

      if (innings.status == InningsStatus.inProgress ||
          (match.status == MatchStatus.live &&
              match.currentInnings?.status == InningsStatus.inProgress)) {
        await repo.endCurrentInnings(widget.matchId);
      }

      var fresh = await repo.getMatch(widget.matchId) ?? match;
      final ended = fresh.innings.length > innings.inningsNumber - 1
          ? fresh.innings[innings.inningsNumber - 1]
          : innings;

      if (MatchCompletionPolicy.shouldOfferSuperOver(fresh) ||
          MatchCompletionPolicy.isTiedChaseComplete(fresh, ended)) {
        await repo.startSuperOver(widget.matchId);
        if (!mounted) return;
        if (fresh.isQuickMatch) {
          ref.invalidate(matchProvider(widget.matchId));
          ref.invalidate(matchLineupSquadsProvider(widget.matchId));
        } else {
          context.go('/match/${widget.matchId}/start-innings');
        }
        return;
      }

      final wantsNext =
          MatchCompletionPolicy.shouldContinueAfterInnings(fresh, ended);
      final nextAlreadyStarted = !ended.isSuperOver &&
          fresh.innings.any(
            (i) => !i.isSuperOver && i.inningsNumber > ended.inningsNumber,
          );

      if (!wantsNext && !nextAlreadyStarted) {
        if (await _tryAutoCompleteMatch(fresh)) return;
        await _showMatchResultDialog(fresh, ended);
        return;
      }

      // Start chase when first innings is done (retry once if patch lagging).
      if (!repo.canStartNextInnings(fresh)) {
        fresh = await repo.getMatch(widget.matchId) ?? fresh;
      }
      if (repo.canStartNextInnings(fresh)) {
        await repo.startNextInnings(widget.matchId);
        fresh = await repo.getMatch(widget.matchId) ?? fresh;
      } else if (wantsNext &&
          !nextAlreadyStarted &&
          fresh.isQuickMatch &&
          ended.inningsNumber == 1) {
        throw StateError(
          'Could not start 2nd innings — try Slide again',
        );
      }
      if (!mounted) return;
      if (fresh.isQuickMatch) {
        // Stay on live scoring — openers are picked via the lineup banner.
        ref.invalidate(matchProvider(widget.matchId));
        ref.invalidate(matchLineupSquadsProvider(widget.matchId));
        final latest = await repo.getMatch(widget.matchId) ?? fresh;
        if (mounted &&
            MatchLifecycle.currentInningsNeedsOpeningLineup(latest)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openLineupSheet(latest);
          });
        }
      } else {
        context.go('/match/${widget.matchId}/start-innings');
      }
    } catch (e) {
      _dismissedInningsBreakNumbers.remove(innings.inningsNumber);
      if (mounted) {
        setState(() => _suppressInningsBreakCheck = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not continue: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  void _handleInningsBreakState(MatchModel match) {
    if (_inningsBreakDialogOpen ||
        _inningsBreakConfirmInFlight ||
        !mounted) {
      return;
    }
    // Keep suppress until we leave inningsBreak so stale snapshots cannot reopen.
    if (_suppressInningsBreakCheck) {
      if (match.status == MatchStatus.inningsBreak) return;
      _suppressInningsBreakCheck = false;
    }

    final inn = match.currentInnings;
    if (inn == null) return;

    // Chase already started (or opening lineup needed) — never re-prompt break.
    final nextAlreadyStarted = !inn.isSuperOver &&
        match.innings.any(
          (i) => !i.isSuperOver && i.inningsNumber > inn.inningsNumber,
        );
    if (nextAlreadyStarted) return;
    if (MatchLifecycle.currentInningsNeedsOpeningLineup(match)) return;
    if (_dismissedInningsBreakNumbers.contains(inn.inningsNumber)) return;

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
        final freshEvents =
            ref.read(ballEventsProvider(widget.matchId)).valueOrNull ?? [];
        final freshInn = fresh?.currentInnings;
        if (fresh != null && freshInn != null) {
          final stillNeeds = ScoringDisplayUtils.needsNextOverBowler(
            freshInn,
            fresh.rules.ballsPerOver,
            freshEvents,
          );
          setState(() => _awaitingNextOverBowlerPick = stillNeeds);
        } else {
          setState(() => _awaitingNextOverBowlerPick = false);
        }
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
    final completed = await ref
        .read(matchRepositoryProvider)
        .finalizeMatchIfReady(widget.matchId);
    if (completed == null || completed.status != MatchStatus.completed) {
      return false;
    }
    await ref
        .read(tournamentRepositoryProvider)
        .advanceKnockoutFromMatch(completed);
    await syncTournamentAnalyticsAfterMatch(ref, completed);
    if (mounted) {
      // For tournament matches, go to tournament dashboard (points table).
      if (completed.tournamentId != null &&
          completed.tournamentId!.isNotEmpty) {
        context.go('/tournaments/${completed.tournamentId}?tab=points-table');
      } else {
        context.go('/match/${widget.matchId}');
      }
    }
    return true;
  }

  Future<void> _completeMatchAndExit() async {
    final completed =
        await ref.read(matchRepositoryProvider).completeMatch(widget.matchId);
    if (completed != null) {
      await ref
          .read(tournamentRepositoryProvider)
          .advanceKnockoutFromMatch(completed);
      await syncTournamentAnalyticsAfterMatch(ref, completed);
    }
    if (mounted) {
      // For tournament matches, go to tournament dashboard (points table).
      final match = completed ??
          ref.read(matchProvider(widget.matchId)).valueOrNull;
      _navigateAfterCompletion(match);
    }
  }

  void _navigateAfterCompletion(MatchModel? match) {
    if (!mounted) return;
    if (match != null &&
        match.tournamentId != null &&
        match.tournamentId!.isNotEmpty) {
      context.go('/tournaments/${match.tournamentId}?tab=points-table');
    } else {
      context.go('/match/${widget.matchId}');
    }
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
          if (mounted) _navigateAfterCompletion(match);
          return;
        }

        if (input.isDraw) {
          await revRepo.setMatchResult(
            matchId: widget.matchId,
            isDraw: true,
            considerAllOversForNrr: input.considerAllOversForNrr,
            userId: uid,
          );
          if (mounted) _navigateAfterCompletion(match);
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

    if (match.effectiveMaxInnings <= 1) {
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
            final runs = b?.runs ?? 0;
            final balls = b?.balls ?? 0;
            final returning = b != null &&
                (b.retiredHurt || b.isEligibleToReturn) &&
                !b.isOut;
            return CreaseBatterOption(
              playerId: p.id,
              name: p.name,
              runs: runs,
              balls: balls,
              roleLabel: returning
                  ? 'Returning · $runs($balls)'
                  : 'Available',
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
    final inn = match.currentInnings;
    if (inn != null && ScoringDisplayUtils.needsVacantCreaseFill(inn)) {
      _fillVacantCrease(match, inn);
      return;
    }
    final squadsAsync = ref.read(matchLineupSquadsProvider(widget.matchId));
    squadsAsync.whenData((squads) {
      final inn = match.currentInnings;
      // Opening a new innings needs the full batting XI. Mid-innings edits
      // filter to batters who may still bat.
      final openingLineup =
          MatchLifecycle.currentInningsNeedsOpeningLineup(match) ||
              (inn != null &&
                  inn.legalBalls == 0 &&
                  inn.totalWickets == 0 &&
                  (inn.strikerId == null || inn.nonStrikerId == null));
      final batting = inn == null || openingLineup || match.isQuickMatch
          ? squads.batting
          : ScoringDisplayUtils.eligibleBatters(
              inn,
              squads.batting,
              idOf: (p) => p.id,
            );
      final events =
          ref.read(ballEventsProvider(widget.matchId)).valueOrNull ?? [];
      final keeperId = inn != null
          ? ScoringDisplayUtils.activeWicketKeeper(
              match: match,
              inn: inn,
              events: events,
            ).id
          : null;
      final battingTeamId = inn?.battingTeamId;
      final bowlingTeamId = inn?.bowlingTeamId;
      final battingWalkIns = quickMatchWalkInsForTeam(
        match: match,
        teamId: battingTeamId,
        teamPlayers: batting,
      );
      final bowlingWalkIns = quickMatchWalkInsForTeam(
        match: match,
        teamId: bowlingTeamId,
        teamPlayers: squads.bowling,
      );
      final bowlerSubtitles = inn != null
          ? buildBowlerPickerSubtitles(inn, match.rules.ballsPerOver)
          : const <String, String>{};
      final battingTeamLabel = quickMatchTeamLabel(match, battingTeamId);
      final bowlingTeamLabel = quickMatchTeamLabel(match, bowlingTeamId);

      PlayerLineupPicker.show(
        context,
        battingSquad: batting,
        bowlingSquad: squads.bowling,
        battingWalkIns: battingWalkIns,
        bowlingWalkIns: bowlingWalkIns,
        bowlerSubtitles: bowlerSubtitles,
        battingTeamSectionLabel: '$battingTeamLabel · batters',
        bowlingTeamSectionLabel: '$bowlingTeamLabel · bowlers',
        quickMatchMode: match.isQuickMatch,
        openingLineup: openingLineup,
        initialStrikerId: openingLineup ? null : inn?.strikerId,
        initialNonStrikerId: openingLineup ? null : inn?.nonStrikerId,
        initialBowlerId: openingLineup ? null : inn?.currentBowlerId,
        wicketKeeperId: keeperId,
        wicketKeeperCanBowl: match.rules.wicketKeeperCanBowl,
        onSave: ({
          required strikerId,
          required strikerName,
          required nonStrikerId,
          required nonStrikerName,
          required bowlerId,
          required bowlerName,
        }) async {
          final violation = ScoringDisplayUtils.wicketKeeperBowlingViolation(
            rules: match.rules,
            bowlerId: bowlerId,
            wicketKeeperId: keeperId,
          );
          if (violation != null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(violation)),
              );
            }
            return;
          }
          await _applyOpeningOrEditedLineup(
            match: match,
            strikerId: strikerId,
            strikerName: strikerName,
            nonStrikerId: nonStrikerId,
            nonStrikerName: nonStrikerName,
            bowlerId: bowlerId,
            bowlerName: bowlerName,
          );
          if (mounted) Navigator.pop(context);
        },
      );
    });
  }

  Future<void> _applyOpeningOrEditedLineup({
    required MatchModel match,
    required String strikerId,
    required String strikerName,
    required String nonStrikerId,
    required String nonStrikerName,
    required String bowlerId,
    required String bowlerName,
  }) async {
    final repo = ref.read(matchRepositoryProvider);
    final inn = match.currentInnings;
    if (match.isQuickMatch && inn != null) {
      final battingIsA = matchTeamIsTeamA(match, inn.battingTeamId);
      await repo.ensurePlayersOnMatchSquad(
        matchId: widget.matchId,
        isTeamA: battingIsA,
        players: [
          snapshotFromLineupPlayer(
            LineupPlayer(id: strikerId, name: strikerName),
          ),
          snapshotFromLineupPlayer(
            LineupPlayer(id: nonStrikerId, name: nonStrikerName),
          ),
        ],
      );
      await repo.ensurePlayersOnMatchSquad(
        matchId: widget.matchId,
        isTeamA: !battingIsA,
        players: [
          snapshotFromLineupPlayer(
            LineupPlayer(id: bowlerId, name: bowlerName),
          ),
        ],
      );
    }

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
      await repo.updateLineup(
        matchId: widget.matchId,
        strikerId: strikerId,
        strikerName: strikerName,
        nonStrikerId: nonStrikerId,
        nonStrikerName: nonStrikerName,
        bowlerId: bowlerId,
        bowlerName: bowlerName,
      );
    }

    // Promote Quick Match (or any post-toss) to live after opening lineup.
    final fresh = await repo.getMatch(widget.matchId);
    final freshInn = fresh?.currentInnings;
    if (fresh != null &&
        freshInn != null &&
        fresh.status == MatchStatus.tossCompleted) {
      final uid = ref.read(authStateProvider).value?.uid;
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      await repo.startMatch(
        widget.matchId,
        InningsModel(
          inningsNumber: freshInn.inningsNumber,
          battingTeamId: freshInn.battingTeamId,
          bowlingTeamId: freshInn.bowlingTeamId,
          status: InningsStatus.inProgress,
          strikerId: freshInn.strikerId,
          nonStrikerId: freshInn.nonStrikerId,
          currentBowlerId: freshInn.currentBowlerId,
          batsmen: freshInn.batsmen,
          bowlers: freshInn.bowlers,
          targetRuns: freshInn.targetRuns,
          isSuperOver: freshInn.isSuperOver,
        ),
        scorerId: uid,
        scorerName: profile?.displayName,
        scorerPhoto: profile?.photoUrl,
      );
    }

    ref.invalidate(matchLineupSquadsProvider(widget.matchId));
  }

  /// Fielder / keeper from bowling side. Quick Match: team + walk-in + add.
  Future<LineupPlayer?> _pickBowlingSidePlayer({
    required MatchModel match,
    required InningsModel inn,
    required List<LineupPlayer> bowlingSquad,
    required String title,
    Set<String> excludeIds = const {},
    String? currentWicketKeeperId,
  }) async {
    if (match.isQuickMatch) {
      final bowlingTeamId = inn.bowlingTeamId;
      final bowlingIsA = matchTeamIsTeamA(match, bowlingTeamId);
      final walkIns = quickMatchWalkInsForTeam(
        match: match,
        teamId: bowlingTeamId,
        teamPlayers: bowlingSquad,
      );
      final picked = await SelectQuickMatchPlayerSheet.show(
        context,
        title: title,
        teamPlayers: bowlingSquad,
        walkInPlayers: walkIns,
        excludeIds: excludeIds,
        teamSectionLabel:
            '${quickMatchTeamLabel(match, bowlingTeamId)} · fielders',
      );
      if (picked != null) {
        await ref.read(matchRepositoryProvider).ensurePlayersOnMatchSquad(
              matchId: widget.matchId,
              isTeamA: bowlingIsA,
              players: [snapshotFromLineupPlayer(picked)],
            );
        ref.invalidate(matchLineupSquadsProvider(widget.matchId));
      }
      return picked;
    }

    return FielderPickerSheet.show(
      context,
      title: title,
      players: bowlingSquad,
      excludeIds: excludeIds,
      currentWicketKeeperId: currentWicketKeeperId,
    );
  }

  Future<void> _changeWicketKeeper(MatchModel match) async {
    if (!_guardActiveScorer(match)) return;
    final inn = match.currentInnings;
    if (inn == null) return;

    final squads =
        ref.read(matchLineupSquadsProvider(widget.matchId)).valueOrNull;
    if (squads == null) return;
    if (!match.isQuickMatch && squads.bowling.isEmpty) return;

    final events =
        ref.read(ballEventsProvider(widget.matchId)).valueOrNull ?? [];
    final activeKeeper = ScoringDisplayUtils.activeWicketKeeper(
      match: match,
      inn: inn,
      events: events,
    );

    final picked = await _pickBowlingSidePlayer(
      match: match,
      inn: inn,
      bowlingSquad: squads.bowling,
      title: 'Select wicketkeeper',
      currentWicketKeeperId: activeKeeper.id,
    );
    if (picked == null || !mounted) return;

    if (picked.id == activeKeeper.id) return;

    setState(() => _isRecording = true);
    final sequence = _ballSequence + 1;
    final scorerUid = ref.read(authStateProvider).valueOrNull?.uid;
    try {
      final result = await ref.read(matchRepositoryProvider).recordBall(
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
      setState(() => _ballSequence = result.event.sequence);
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

  Future<void> _shareLiveScore(MatchModel match) async {
    final events =
        ref.read(ballEventsProvider(widget.matchId)).valueOrNull ?? [];
    final displayMatch = events.isEmpty
        ? match
        : BallEventAggregator.reprojectMatchFromEvents(match, events);
    final inn = displayMatch.currentInnings;
    final teamName = inn != null
        ? ScoringDisplayUtils.battingTeamName(displayMatch, inn)
        : displayMatch.title;
    final scoreLine = inn == null
        ? '${displayMatch.teamAName} vs ${displayMatch.teamBName}'
        : '$teamName ${inn.totalRuns}/${inn.totalWickets} '
            '(${ScoringDisplayUtils.inningsOversDisplay(inn, displayMatch.rules)} Ov)';
    try {
      await shareLiveScore(
        matchId: displayMatch.id,
        title: displayMatch.title,
        scoreLine: scoreLine,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    }
  }

  void _openQuickOptions(MatchModel match) {
    final canEditToss = ScoringDisplayUtils.canEditTossDecision(match);
    final canScore = _canScoreThisMatch(match);
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

    ref.listen<AsyncValue<List<BallEventModel>>>(
      ballEventsProvider(widget.matchId),
      (prev, next) {
        final events = next.valueOrNull;
        if (events == null || events.isEmpty || !_sequenceLoaded) return;
        final seq = events.last.sequence;
        if (mounted && seq != _ballSequence) {
          setState(() => _ballSequence = seq);
        }
      },
    );

    final cf = context.cf;

    return Scaffold(
      backgroundColor: cf.background,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: cf.chromeBackground,
        foregroundColor: cf.chromeForeground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cf.chromeForeground),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            ref.read(myCricketInitialTabProvider.notifier).state = 0;
            context.go('/matches');
          },
        ),
        automaticallyImplyLeading: false,
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
              final m = matchAsync.valueOrNull;
              if (m != null) {
                unawaited(_shareLiveScore(m));
              }
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

          final events = eventsAsync.valueOrNull ?? [];
          final displayMatch = events.isEmpty
              ? match
              : BallEventAggregator.reprojectMatchFromEvents(match, events);
          final displayInn = displayMatch.currentInnings ?? inn;

          final canScore = _canScoreThisMatch(match);
          final onBreak = match.isMatchBreakActive;
          final canRecord = canScore && !onBreak;

          final needsVacantCrease = canRecord &&
              ScoringDisplayUtils.needsVacantCreaseFill(displayInn);
          final needsOpeningLineup = canRecord &&
              ScoringDisplayUtils.needsOpeningLineupPicker(match, displayInn);
          final needsLineup = needsVacantCrease || needsOpeningLineup;
          final vacantCreaseLabel = displayInn.strikerId == null ||
                  displayInn.strikerId!.isEmpty
              ? 'Select striker'
              : 'Select non-striker';

          final overEvents = ScoringDisplayUtils.currentOverEvents(
            events: events,
            inn: displayInn,
            ballsPerOver: match.rules.ballsPerOver,
          );
          final needsNextOverBowlerFromEvents = canRecord &&
              ScoringDisplayUtils.needsNextOverBowler(
                displayInn,
                match.rules.ballsPerOver,
                events,
              );
          final needsNextOverBowler = canRecord &&
              (_awaitingNextOverBowlerPick || needsNextOverBowlerFromEvents);
          final nextOverNumber = ScoringDisplayUtils.currentOverNumber(
            displayInn,
            match.rules.ballsPerOver,
          );

          return Column(
            children: [
              OfflineSyncBadge(matchId: widget.matchId),
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
                  match: displayMatch,
                  innings: displayInn,
                  rules: match.rules,
                ),
              ),
              if (needsLineup)
                MaterialBanner(
                  backgroundColor: cf.surfaceElevated,
                  content: Text(
                    needsVacantCrease
                        ? vacantCreaseLabel
                        : 'Tap to set striker, non-striker & bowler',
                    style: TextStyle(color: cf.textPrimary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        if (needsVacantCrease) {
                          _fillVacantCrease(match, displayInn);
                        } else {
                          _openLineupSheet(match);
                        }
                      },
                      child: Text(
                        needsVacantCrease ? 'Select batter' : 'Set lineup',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cf.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              LiveScoringPlayersStrip(
                innings: displayInn,
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
                onReplaceBowler: needsLineup ||
                        !canRecord ||
                        needsNextOverBowler ||
                        _bowlerPickerOpen
                    ? null
                    : () => _replaceBowler(match),
                onTapBowler: needsNextOverBowler && !_bowlerPickerOpen
                    ? () => _pickBowlerForNextOver(match, nextOverNumber)
                    : null,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause_circle_outline,
                      size: 36, color: cf.accent),
                  const SizedBox(height: 8),
                  const Text(
                    'Match on break',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Scoring is paused. Slide to resume on the banner above.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cf.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
