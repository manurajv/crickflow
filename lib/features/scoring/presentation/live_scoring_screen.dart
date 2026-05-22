import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/match_permissions.dart';
import '../../../data/models/innings_model.dart';
import '../../../data/models/lineup_player.dart';
import '../../../data/models/match_model.dart';
import '../../../domain/services/commentary_service.dart';
import '../../../domain/services/scoring_engine.dart';
import '../../../shared/providers/lineup_providers.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/player_lineup_picker.dart';
import '../../../shared/widgets/wicket_picker_sheet.dart';
import '../../matches/presentation/match_scoring_rules_screen.dart';
import 'utils/scoring_display_utils.dart';
import 'widgets/innings_break_dialog.dart';
import 'widgets/live_scoring_header.dart';
import 'widgets/live_scoring_keypad.dart';
import 'widgets/live_scoring_players_strip.dart'
    show BowlingSide, LiveScoringPlayersStrip;
import 'widgets/over_complete_dialog.dart';
import 'widgets/scoring_extra_dialogs.dart';
import 'widgets/scoring_quick_options_sheet.dart';
import '../../../shared/widgets/scoring_ui_kit.dart';
import 'widgets/select_bowler_sheet.dart';

class LiveScoringScreen extends ConsumerStatefulWidget {
  const LiveScoringScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<LiveScoringScreen> createState() => _LiveScoringScreenState();
}

class _LiveScoringScreenState extends ConsumerState<LiveScoringScreen> {
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

  Future<void> _record(BallEventInput input) async {
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    if (match == null) return;

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

    setState(() => _isRecording = true);
    final sequence = _ballSequence + 1;
    final fullInput = BallEventInput(
      type: input.type,
      runs: input.runs,
      wicketType: input.wicketType,
      dismissedPlayerId: input.dismissedPlayerId,
      fielderId: input.fielderId,
      noBallRunsMode: input.noBallRunsMode,
      commentary: CommentaryService.forBall(
        type: input.type,
        runs: input.runs,
        wicketType: input.wicketType,
      ),
    );

    try {
      await ref.read(matchRepositoryProvider).recordBall(
            match: match,
            input: fullInput,
            sequence: sequence,
          );
      setState(() => _ballSequence = sequence);
      HapticFeedback.lightImpact();

      final updated = ref.read(matchProvider(widget.matchId)).valueOrNull;
      final updatedInn = updated?.currentInnings;
      if (updated != null && updatedInn != null && mounted) {
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

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OverCompleteDialog(
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
      ),
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
    final excluded = <String>{};
    if (excludeLastOverBowler) {
      final id = ScoringDisplayUtils.bowlerWhoFinishedLastOver(
        inn: inn,
        events: events,
        ballsPerOver: match.rules.ballsPerOver,
      );
      if (id != null) excluded.add(id);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SelectBowlerSheet(
        match: match,
        innings: inn,
        bowlingSquad: squads.bowling,
        overNumber: overNumber,
        ballsPerOver: match.rules.ballsPerOver,
        excludedBowlerIds: excluded,
        onSelected: (p) async {
          final latest =
              ref.read(matchProvider(widget.matchId)).valueOrNull ?? match;
          final latestInn = latest.currentInnings;
          if (latestInn == null ||
              latestInn.strikerId == null ||
              latestInn.nonStrikerId == null) {
            return;
          }
          await ref.read(matchRepositoryProvider).updateLineup(
                matchId: widget.matchId,
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
                bowlerId: p.id,
                bowlerName: p.name,
              );
        },
      ),
    );
  }

  Future<void> _recordWicket() async {
    final type = await showWicketPickerSheet(context);
    if (type == null || !mounted) return;
    await _record(BallEventInput(
      type: BallEventType.wicket,
      wicketType: type,
    ));
    if (!mounted) return;
    final updated = ref.read(matchProvider(widget.matchId)).valueOrNull;
    final inn = updated?.currentInnings;
    if (updated != null &&
        inn != null &&
        !ScoringDisplayUtils.isInningsComplete(updated, inn)) {
      await _fillVacantCrease(updated, inn);
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

  Future<void> _fillVacantCrease(MatchModel match, InningsModel inn) async {
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

    final picked = await showModalBottomSheet<LineupPlayer>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: eligible.length,
                itemBuilder: (_, i) {
                  final p = eligible[i];
                  return ListTile(
                    leading: const Icon(Icons.sports_cricket),
                    title: Text(p.name),
                    onTap: () => Navigator.pop(ctx, p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;

    final latest = ref.read(matchProvider(widget.matchId)).valueOrNull;
    final latestInn = latest?.currentInnings;
    if (latest == null || latestInn == null) return;

    try {
      await ref.read(matchRepositoryProvider).updateLineup(
            matchId: widget.matchId,
            strikerId: forStriker
                ? picked.id
                : (latestInn.strikerId ?? picked.id),
            strikerName: forStriker
                ? picked.name
                : ScoringDisplayUtils.batsman(latestInn, latestInn.strikerId)
                        ?.playerName ??
                    picked.name,
            nonStrikerId: forStriker
                ? (latestInn.nonStrikerId ?? picked.id)
                : picked.id,
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

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => InningsBreakDialog(
        match: match,
        innings: innings,
        allowUndo: allowUndo,
        onUndo: () async {
          Navigator.pop(ctx);
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
          Navigator.pop(ctx);
          setState(() => _inningsBreakDialogOpen = false);
          await _confirmInningsBreak(match, innings);
        },
      ),
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
      final hasNext = innings.inningsNumber < match.rules.maxInnings;

      if (innings.status == InningsStatus.inProgress) {
        await repo.endCurrentInnings(widget.matchId);
      }

      if (!hasNext) {
        final completed = await repo.completeMatch(widget.matchId);
        if (completed != null) {
          await ref
              .read(tournamentRepositoryProvider)
              .advanceKnockoutFromMatch(completed);
        }
        if (mounted) context.go('/match/${widget.matchId}');
        return;
      }

      final fresh = await repo.getMatch(widget.matchId);
      if (fresh != null && fresh.innings.length == innings.inningsNumber) {
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
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('End match?'),
          content: const Text('Complete this match?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Complete'),
            ),
          ],
        ),
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
      }
      return;
    }

    final inn = match.currentInnings;
    if (inn != null && ScoringDisplayUtils.isInningsComplete(match, inn)) {
      await _showInningsBreakDialog(match, inn, allowUndo: true);
      return;
    }

    await ref.read(matchRepositoryProvider).endCurrentInnings(widget.matchId);
    if (mounted) {
      final fresh = ref.read(matchProvider(widget.matchId)).valueOrNull;
      final ended = fresh?.currentInnings;
      if (fresh != null && ended != null) {
        await _showInningsBreakDialog(fresh, ended, allowUndo: false);
      }
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

    final picked = await showModalBottomSheet<LineupPlayer>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: eligible
              .map(
                (p) => ListTile(
                  leading: const Icon(Icons.sports_cricket),
                  title: Text(p.name),
                  onTap: () => Navigator.pop(ctx, p),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final player = picked;
    await ref.read(matchRepositoryProvider).updateLineup(
          matchId: widget.matchId,
          strikerId: striker ? picked.id : inn.strikerId!,
          strikerName: striker
              ? player.name
              : ScoringDisplayUtils.batsman(inn, inn.strikerId)?.playerName ??
                  '',
          nonStrikerId: striker ? inn.nonStrikerId! : picked.id,
          nonStrikerName: striker
              ? ScoringDisplayUtils.batsman(inn, inn.nonStrikerId)
                      ?.playerName ??
                  ''
              : player.name,
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
    final inn = match.currentInnings;
    squadsAsync.whenData((squads) {
      final inn = match.currentInnings;
      final batting = inn == null
          ? squads.batting
          : ScoringDisplayUtils.eligibleBatters(
              inn,
              squads.batting,
              idOf: (p) => p.id,
            );
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: PlayerLineupPicker(
            battingSquad: batting,
            bowlingSquad: squads.bowling,
            initialStrikerId: inn?.strikerId,
            initialNonStrikerId: inn?.nonStrikerId,
            initialBowlerId: inn?.currentBowlerId,
            onSave: ({
              required strikerId,
              required strikerName,
              required nonStrikerId,
              required nonStrikerName,
              required bowlerId,
              required bowlerName,
            }) async {
              await ref.read(matchRepositoryProvider).updateLineup(
                    matchId: widget.matchId,
                    strikerId: strikerId,
                    strikerName: strikerName,
                    nonStrikerId: nonStrikerId,
                    nonStrikerName: nonStrikerName,
                    bowlerId: bowlerId,
                    bowlerName: bowlerName,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ),
      );
    });
  }

  void _openQuickOptions(MatchModel match) {
    ScoringUiKit.showSheet(
      context,
      builder: (ctx) => ScoringQuickOptionsSheet(
        onEditLineup: () {
          Navigator.pop(ctx);
          _openLineupSheet(match);
        },
        onEndInnings: () {
          Navigator.pop(ctx);
          _endInnings();
        },
        onScorecard: () {
          Navigator.pop(ctx);
          context.push('/match/${widget.matchId}/scorecard');
        },
        onMatchRules: () async {
          Navigator.pop(ctx);
          final updated = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  MatchScoringRulesScreen(initialRules: match.rules),
            ),
          );
          if (updated != null) {
            await ref.read(matchRepositoryProvider).updateMatch(
                  match.copyWith(rules: updated),
                );
          }
        },
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
