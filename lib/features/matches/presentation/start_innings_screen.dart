import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/innings_model.dart';
import '../../../data/models/lineup_player.dart';
import '../../../data/models/match_model.dart';
import '../../../shared/providers/lineup_providers.dart';
import '../../../shared/providers/providers.dart';
import 'match_scoring_rules_screen.dart';
import 'widgets/innings_player_slot_card.dart';
import 'widgets/select_lineup_player_sheet.dart';

/// After toss: pick opening striker, non-striker, and bowler before live scoring.
class StartInningsScreen extends ConsumerStatefulWidget {
  const StartInningsScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<StartInningsScreen> createState() => _StartInningsScreenState();
}

class _StartInningsScreenState extends ConsumerState<StartInningsScreen> {
  LineupPlayer? _striker;
  LineupPlayer? _nonStriker;
  LineupPlayer? _bowler;
  bool _starting = false;
  String? _lineupBattingTeamId;
  String? _lineupBowlingTeamId;

  void _syncLineupTeamsFromMatch(MatchModel match) {
    final inn = match.currentInnings ?? match.innings.firstOrNull;
    if (inn == null) return;
    if (_lineupBattingTeamId == inn.battingTeamId &&
        _lineupBowlingTeamId == inn.bowlingTeamId) {
      return;
    }
    _lineupBattingTeamId = inn.battingTeamId;
    _lineupBowlingTeamId = inn.bowlingTeamId;
    _striker = null;
    _nonStriker = null;
    _bowler = null;
  }

  String _battingTeamName(MatchModel match) {
    final inn = match.currentInnings ?? match.innings.firstOrNull;
    if (inn == null) return match.teamAName;
    if (inn.battingTeamId == match.teamAId) return match.teamAName;
    if (inn.battingTeamId == match.teamBId) return match.teamBName;
    return match.teamAName;
  }

  String _bowlingTeamName(MatchModel match) {
    final inn = match.currentInnings ?? match.innings.firstOrNull;
    if (inn == null) return match.teamBName;
    if (inn.bowlingTeamId == match.teamAId) return match.teamAName;
    if (inn.bowlingTeamId == match.teamBId) return match.teamBName;
    return match.teamBName;
  }

  Future<void> _pickStriker(List<LineupPlayer> batting) async {
    final p = await SelectLineupPlayerSheet.show(
      context,
      title: 'Select striker',
      players: batting,
      excludeIds: {_nonStriker?.id ?? ''},
    );
    if (p != null && mounted) setState(() => _striker = p);
  }

  Future<void> _pickNonStriker(List<LineupPlayer> batting) async {
    final p = await SelectLineupPlayerSheet.show(
      context,
      title: 'Select non-striker',
      players: batting,
      excludeIds: {_striker?.id ?? ''},
    );
    if (p != null && mounted) setState(() => _nonStriker = p);
  }

  Future<void> _pickBowler(List<LineupPlayer> bowling) async {
    final p = await SelectLineupPlayerSheet.show(
      context,
      title: 'Select bowler',
      players: bowling,
    );
    if (p != null && mounted) setState(() => _bowler = p);
  }

  bool get _canStart =>
      _striker != null && _nonStriker != null && _bowler != null && !_starting;

  Future<void> _startScoring(MatchModel match) async {
    if (!_canStart) return;
    setState(() => _starting = true);
    final uid = ref.read(authStateProvider).value?.uid;

    try {
      await ref.read(matchRepositoryProvider).updateLineup(
            matchId: widget.matchId,
            strikerId: _striker!.id,
            strikerName: _striker!.name,
            nonStrikerId: _nonStriker!.id,
            nonStrikerName: _nonStriker!.name,
            bowlerId: _bowler!.id,
            bowlerName: _bowler!.name,
          );

      final fresh =
          await ref.read(matchRepositoryProvider).getMatch(widget.matchId);
      final inn = fresh?.currentInnings;
      final isOpeningInnings = fresh != null &&
          inn != null &&
          (fresh.status == MatchStatus.tossCompleted ||
              (fresh.innings.length == 1 &&
                  inn.status != InningsStatus.completed));

      if (isOpeningInnings) {
        await ref.read(matchRepositoryProvider).startMatch(
              widget.matchId,
              InningsModel(
                inningsNumber: inn!.inningsNumber,
                battingTeamId: inn.battingTeamId,
                bowlingTeamId: inn.bowlingTeamId,
                status: InningsStatus.inProgress,
                strikerId: inn.strikerId,
                nonStrikerId: inn.nonStrikerId,
                currentBowlerId: inn.currentBowlerId,
                batsmen: inn.batsmen,
                bowlers: inn.bowlers,
                targetRuns: inn.targetRuns,
                isSuperOver: inn.isSuperOver,
              ),
              scorerId: uid,
            );
      } else if (uid != null) {
        await ref.read(matchRepositoryProvider).addScorer(widget.matchId, uid);
      }

      if (mounted) context.go('/match/${widget.matchId}/score');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start scoring: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchProvider(widget.matchId));
    final squadsAsync = ref.watch(matchLineupSquadsProvider(widget.matchId));

    ref.listen<AsyncValue<MatchModel?>>(matchProvider(widget.matchId), (prev, next) {
      next.whenData((match) {
        if (match == null || !mounted) return;
        setState(() => _syncLineupTeamsFromMatch(match));
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Start innings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Choose who faces first and who bowls the opening over.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (match) {
          if (match == null) {
            return const Center(child: Text('Match not found'));
          }

          final inn = match.currentInnings ?? match.innings.firstOrNull;
          if (inn != null &&
              match.status == MatchStatus.live &&
              inn.status == InningsStatus.inProgress &&
              inn.strikerId != null &&
              inn.nonStrikerId != null &&
              inn.currentBowlerId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.go('/match/${widget.matchId}/score');
            });
            return const Center(child: CircularProgressIndicator());
          }

          return squadsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Squads: $e')),
            data: (squads) {
              if (squads.batting.isEmpty || squads.bowling.isEmpty) {
                return Center(
                  child: Padding(
                    padding: AppDimens.listPadding,
                    child: Text(
                      'Squads are empty. Add players to teams in match setup.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              return Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceSm,
                      AppDimens.spaceMd,
                      100,
                    ),
                    children: [
                      Text(
                        'Batting — ${_battingTeamName(match)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InningsPlayerSlotCard(
                            placeholder: 'Select striker',
                            player: _striker,
                            icon: Icons.sports_cricket,
                            onTap: () => _pickStriker(squads.batting),
                          ),
                          const SizedBox(width: AppDimens.spaceSm),
                          InningsPlayerSlotCard(
                            placeholder: 'Select non-striker',
                            player: _nonStriker,
                            icon: Icons.directions_run,
                            onTap: () => _pickNonStriker(squads.batting),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.spaceXl),
                      Text(
                        'Bowling — ${_bowlingTeamName(match)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      Row(
                        children: [
                          InningsPlayerSlotCard(
                            placeholder: 'Select bowler',
                            player: _bowler,
                            icon: Icons.sports_baseball_outlined,
                            flex: 1,
                            onTap: () => _pickBowler(squads.bowling),
                          ),
                          const Spacer(flex: 1),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: AppDimens.spaceMd,
                    bottom: 88,
                    child: FloatingActionButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening photo — coming soon'),
                          ),
                        );
                      },
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      child: const Icon(Icons.photo_camera_outlined),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: matchAsync.maybeWhen(
        data: (match) {
          if (match == null) return null;
          return SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppColors.surface,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MatchScoringRulesScreen(
                              initialRules: match.rules,
                            ),
                          ),
                        );
                      },
                      child: const SizedBox(
                        height: AppDimens.buttonHeightLarge,
                        child: Center(
                          child: Text(
                            'Match rules',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Material(
                    color: AppColors.primaryBlue,
                    child: InkWell(
                      onTap: _canStart ? () => _startScoring(match) : null,
                      child: SizedBox(
                        height: AppDimens.buttonHeightLarge,
                        child: Center(
                          child: _starting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textPrimary,
                                  ),
                                )
                              : Text(
                                  'Start scoring',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _canStart
                                        ? AppColors.textPrimary
                                        : AppColors.textMuted,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }
}
