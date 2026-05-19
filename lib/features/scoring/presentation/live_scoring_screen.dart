import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/match_permissions.dart';
import '../../../core/utils/cricket_math.dart';
import '../../../data/models/ball_event_model.dart';
import '../../../data/models/lineup_player.dart';
import '../../../domain/services/scoring_engine.dart';
import '../../../shared/providers/lineup_providers.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/player_lineup_picker.dart';
import '../../../shared/widgets/scoreboard_card.dart';
import '../../../shared/widgets/wicket_picker_sheet.dart';

final _ballEventsProvider =
    StreamProvider.family<List<BallEventModel>, String>((ref, matchId) {
  return ref.watch(matchRepositoryProvider).watchBallEvents(matchId);
});

void _noopLineup({
  required String strikerId,
  required String strikerName,
  required String nonStrikerId,
  required String nonStrikerName,
  required String bowlerId,
  required String bowlerName,
}) {}

class LiveScoringScreen extends ConsumerStatefulWidget {
  const LiveScoringScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<LiveScoringScreen> createState() => _LiveScoringScreenState();
}

class _LiveScoringScreenState extends ConsumerState<LiveScoringScreen> {
  int _ballSequence = 0;
  final _commentaryController = TextEditingController();
  bool _isRecording = false;
  bool _sequenceLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSequence();
    _subscribeMatchTopic();
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

  Future<void> _subscribeMatchTopic() async {
    await ref
        .read(notificationServiceProvider)
        .subscribeToMatch(widget.matchId);
  }

  Future<void> _record(BallEventInput input) async {
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    if (match == null) return;

    final inn = match.currentInnings;
    if (inn?.strikerId == null || inn?.currentBowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set lineup before scoring')),
      );
      return;
    }

    setState(() => _isRecording = true);
    final sequence = _ballSequence + 1;

    final commentary = _commentaryController.text.trim();
    final fullInput = BallEventInput(
      type: input.type,
      runs: input.runs,
      wicketType: input.wicketType,
      commentary: commentary.isNotEmpty
          ? commentary
          : _defaultCommentary(input),
    );

    try {
      await ref.read(matchRepositoryProvider).recordBall(
            match: match,
            input: fullInput,
            sequence: sequence,
          );
      setState(() => _ballSequence = sequence);
      _commentaryController.clear();
      HapticFeedback.lightImpact();
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

  Future<void> _recordWicket() async {
    final type = await showWicketPickerSheet(context);
    if (type == null || !mounted) return;
    await _record(BallEventInput(
      type: BallEventType.wicket,
      wicketType: type,
      commentary: _wicketCommentary(type),
    ));
  }

  String _wicketCommentary(WicketType type) {
    switch (type) {
      case WicketType.bowled:
        return 'Bowled!';
      case WicketType.caught:
        return 'Caught out!';
      case WicketType.lbw:
        return 'LBW!';
      case WicketType.runOut:
        return 'Run out!';
      case WicketType.stumped:
        return 'Stumped!';
      case WicketType.hitWicket:
        return 'Hit wicket!';
      case WicketType.retired:
        return 'Retired';
      case WicketType.other:
        return 'Wicket!';
    }
  }

  Future<void> _endInnings() async {
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    if (match == null) return;

    if (match.rules.maxInnings <= 1) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('End match?'),
          content: const Text('Single-innings format. Complete this match?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete')),
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

    await ref.read(matchRepositoryProvider).endCurrentInnings(widget.matchId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Innings ended — start 2nd innings from Match Center')),
      );
    }
  }

  Future<void> _undo() async {
    setState(() => _isRecording = true);
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
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _saveLineup({
    required String strikerId,
    required String strikerName,
    required String nonStrikerId,
    required String nonStrikerName,
    required String bowlerId,
    required String bowlerName,
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lineup updated')),
      );
    }
  }

  String _defaultCommentary(BallEventInput input) {
    switch (input.type) {
      case BallEventType.runs:
        if (input.runs == 4) return 'FOUR!';
        if (input.runs == 6) return 'SIX!';
        return '${input.runs} run(s)';
      case BallEventType.wide:
        return 'Wide';
      case BallEventType.noBall:
        return 'No ball';
      case BallEventType.bye:
        return 'Bye';
      case BallEventType.legBye:
        return 'Leg bye';
      case BallEventType.wicket:
        return 'WICKET!';
      case BallEventType.penalty:
        return 'Penalty runs';
    }
  }

  @override
  void dispose() {
    _commentaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchProvider(widget.matchId));
    final squadsAsync = ref.watch(matchLineupSquadsProvider(widget.matchId));
    final eventsAsync = ref.watch(_ballEventsProvider(widget.matchId));
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final uid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Scoring'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            tooltip: 'End innings',
            onPressed: _isRecording ? null : _endInnings,
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo last ball',
            onPressed: _isRecording ? null : _undo,
          ),
        ],
      ),
      body: matchAsync.when(
        data: (match) {
          if (match == null) return const Center(child: Text('Match not found'));

          if (!canManageMatch(
            match: match,
            userId: uid,
            role: profile?.role ?? UserRole.organizer,
          )) {
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
                      onPressed: () =>
                          context.go('/match/${widget.matchId}/scorecard'),
                      child: const Text('View scorecard'),
                    ),
                  ],
                ),
              ),
            );
          }

          final inn = match.currentInnings;
          final rules = match.rules;
          final repo = ref.read(matchRepositoryProvider);
          final targetSummary = match.currentInningsIndex >= 1
              ? repo.firstInningsTarget(match)
              : null;
          final runsNeeded = targetSummary != null && inn != null
              ? (targetSummary.target - inn.totalRuns).clamp(0, 9999)
              : null;
          final ballsLeft = inn != null
              ? (rules.totalBalls - inn.legalBalls).clamp(0, rules.totalBalls)
              : null;

          return Column(
            children: [
              ScoreboardCard(match: match, innings: inn, isLive: true),
              if (targetSummary != null && inn != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Need $runsNeeded off $ballsLeft • Target ${targetSummary.target}',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              squadsAsync.when(
                data: (squads) => PlayerLineupPicker(
                  battingSquad: squads.batting,
                  bowlingSquad: squads.bowling,
                  initialStrikerId: inn?.strikerId,
                  initialNonStrikerId: inn?.nonStrikerId,
                  initialBowlerId: inn?.currentBowlerId,
                  onSave: _saveLineup,
                ),
                loading: () => const PlayerLineupPicker(
                  battingSquad: [],
                  bowlingSquad: [],
                  isLoading: true,
                  onSave: _noopLineup,
                ),
                error: (e, _) => PlayerLineupPicker(
                  battingSquad: [
                    LineupPlayer(
                      id: 'fallback_a',
                      name: match.teamAName,
                    ),
                  ],
                  bowlingSquad: [
                    LineupPlayer(
                      id: 'fallback_b',
                      name: match.teamBName,
                    ),
                  ],
                  initialStrikerId: inn?.strikerId,
                  initialNonStrikerId: inn?.nonStrikerId,
                  initialBowlerId: inn?.currentBowlerId,
                  onSave: _saveLineup,
                ),
              ),
              if (inn != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('RR', CricketMath.runRate(
                              inn.totalRuns, inn.legalBalls, rules.ballsPerOver)
                          .toStringAsFixed(2)),
                      _stat('Partnership',
                          '${inn.partnershipRuns} (${inn.partnershipBalls})'),
                      if (inn.isFreeHitActive)
                        const Chip(
                          label: Text('FREE HIT'),
                          backgroundColor: AppColors.accentRed,
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _commentaryController,
                  decoration: const InputDecoration(
                    hintText: 'Ball commentary (optional)',
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: _scoringPad(),
              ),
              Expanded(
                flex: 2,
                child: !_sequenceLoaded
                    ? const Center(child: CircularProgressIndicator())
                    : eventsAsync.when(
                        data: (events) => ListView.builder(
                          reverse: true,
                          itemCount: events.length,
                          itemBuilder: (_, i) {
                            final e = events[events.length - 1 - i];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.surfaceElevated,
                                child: Text('${e.sequence}',
                                    style: const TextStyle(fontSize: 10)),
                              ),
                              title: Text(e.commentary.isNotEmpty
                                  ? e.commentary
                                  : '${e.eventType.name}: ${e.runs}'),
                              subtitle: Text(
                                  'Ov ${e.overNumber}.${e.ballInOver} • +${e.runs}'),
                            );
                          },
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
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

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.gold)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _scoringPad() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Text('Runs', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(7, (i) {
              return _runButton(i, () => _record(BallEventInput(
                    type: BallEventType.runs,
                    runs: i,
                  )));
            }),
          ),
          const SizedBox(height: 16),
          const Text('Extras & Wickets',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _actionButton('Wide', AppColors.primaryBlue, () => _record(
                  const BallEventInput(type: BallEventType.wide))),
              _actionButton('No Ball', AppColors.primaryBlue, () => _record(
                  const BallEventInput(type: BallEventType.noBall))),
              _actionButton('Bye', AppColors.surfaceElevated, () => _record(
                  const BallEventInput(type: BallEventType.bye, runs: 1))),
              _actionButton('Leg Bye', AppColors.surfaceElevated, () => _record(
                  const BallEventInput(
                      type: BallEventType.legBye, runs: 1))),
              _actionButton('WICKET', AppColors.accentRed, _recordWicket),
            ],
          ),
          if (_isRecording)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _runButton(int runs, VoidCallback onTap) {
    final color = runs == 4
        ? AppColors.primaryBlue
        : runs == 6
            ? AppColors.gold
            : AppColors.surfaceElevated;
    return SizedBox(
      width: 56,
      height: 56,
      child: ElevatedButton(
        onPressed: _isRecording ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: runs == 6 ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('$runs',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: _isRecording ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(label),
    );
  }
}
