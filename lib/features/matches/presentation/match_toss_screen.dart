import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/innings_model.dart';
import '../../../data/models/match_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/start_match_draft_provider.dart';
import 'widgets/cf_selection_card.dart';

/// Toss: winner, bat/bowl, coin flip, then create match and start scoring.
class MatchTossScreen extends ConsumerStatefulWidget {
  const MatchTossScreen({super.key});

  @override
  ConsumerState<MatchTossScreen> createState() => _MatchTossScreenState();
}

class _MatchTossScreenState extends ConsumerState<MatchTossScreen> {
  bool? _winnerIsTeamA;
  bool? _winnerBatsFirst;
  String? _coinResult;
  bool _flipping = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final setup = ref.read(startMatchDraftProvider).setup;
      setState(() {
        _winnerIsTeamA = setup.tossWinnerIsTeamA;
        _winnerBatsFirst = setup.tossWinnerBatsFirst;
        _coinResult = setup.coinResult;
      });
    });
  }

  Future<void> _flipCoin() async {
    if (_flipping) return;
    if (_winnerIsTeamA == null || _winnerBatsFirst == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select toss winner and bat or bowl first'),
        ),
      );
      return;
    }
    setState(() => _flipping = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final heads = Random().nextBool();
    final result = heads ? 'heads' : 'tails';
    ref.read(startMatchDraftProvider.notifier).setToss(
          winnerIsTeamA: _winnerIsTeamA ?? true,
          winnerBatsFirst: _winnerBatsFirst ?? true,
          coinResult: result,
        );
    if (mounted) {
      setState(() {
        _coinResult = result;
        _flipping = false;
      });
    }
  }

  bool get _canPlay =>
      _winnerIsTeamA != null &&
      _winnerBatsFirst != null &&
      _coinResult != null &&
      !_saving;

  Future<void> _letsPlay() async {
    final draft = ref.read(startMatchDraftProvider);
    final setup = draft.setup;

    if (!setup.squadsReady || !setup.rolesReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete squad and captain / wicket keeper first'),
        ),
      );
      return;
    }
    if (_winnerIsTeamA == null || _winnerBatsFirst == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select toss winner and bat or bowl')),
      );
      return;
    }
    if (_coinResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flip the coin first')),
      );
      return;
    }

    ref.read(startMatchDraftProvider.notifier).setToss(
          winnerIsTeamA: _winnerIsTeamA!,
          winnerBatsFirst: _winnerBatsFirst!,
          coinResult: _coinResult,
        );

    setState(() => _saving = true);
    final uid = ref.read(authStateProvider).value?.uid;
    final city = draft.location.city.trim();
    final ground = draft.venue.trim();

    final battingIsTeamA = _winnerIsTeamA! == _winnerBatsFirst!;
    final battingTeamId =
        battingIsTeamA ? (draft.teamA?.id ?? 'team_a') : (draft.teamB?.id ?? 'team_b');
    final bowlingTeamId =
        battingIsTeamA ? (draft.teamB?.id ?? 'team_b') : (draft.teamA?.id ?? 'team_a');

    final match = MatchModel(
      id: draft.matchId,
      title: '${draft.resolvedTeamAName} vs ${draft.resolvedTeamBName}',
      matchType: MatchType.single,
      status: MatchStatus.scheduled,
      teamAId: draft.teamA?.id,
      teamBId: draft.teamB?.id,
      teamAName: draft.resolvedTeamAName,
      teamBName: draft.resolvedTeamBName,
      rules: draft.rules,
      location: draft.location.copyWith(city: city),
      venue: ground,
      scheduledAt: draft.scheduledAt ?? DateTime.now(),
      createdBy: uid,
      setup: ref.read(startMatchDraftProvider).setup,
    );

    final firstInnings = InningsModel(
      inningsNumber: 1,
      battingTeamId: battingTeamId,
      bowlingTeamId: bowlingTeamId,
      status: InningsStatus.notStarted,
    );

    try {
      await ref.read(matchRepositoryProvider).createMatch(
            match.copyWith(
              innings: [firstInnings],
              currentInningsIndex: 0,
            ),
          );
      ref.read(startMatchDraftProvider.notifier).reset();
      if (mounted) context.go('/match/${draft.matchId}/start-innings');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start match: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(startMatchDraftProvider);
    final setup = draft.setup;

    if (!setup.squadsReady) {
      return Scaffold(
        appBar: AppBar(title: const Text('Toss')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Select squads for both teams before the toss'),
              const SizedBox(height: AppDimens.spaceMd),
              FilledButton(
                onPressed: () => context.push('/match/create/squad/a'),
                child: const Text('Select squad'),
              ),
            ],
          ),
        ),
      );
    }

    if (!setup.rolesReady) {
      return Scaffold(
        appBar: AppBar(title: const Text('Toss')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Assign captain and wicket keeper for both teams'),
              const SizedBox(height: AppDimens.spaceMd),
              FilledButton(
                onPressed: () => context.push('/match/create/roles/a'),
                child: const Text('Continue setup'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Toss'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_camera_outlined),
            tooltip: 'Capture toss moment',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Toss photo — coming soon')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: AppDimens.listPadding,
        children: [
          const _SectionTitle('Who won the toss?'),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CfSelectionCard(
                label: draft.resolvedTeamAName.toUpperCase(),
                avatarLetter: draft.resolvedTeamAName.isNotEmpty
                    ? draft.resolvedTeamAName[0].toUpperCase()
                    : 'A',
                selected: _winnerIsTeamA == true,
                onTap: () => setState(() => _winnerIsTeamA = true),
              ),
              CfSelectionCard(
                label: draft.resolvedTeamBName.toUpperCase(),
                avatarLetter: draft.resolvedTeamBName.isNotEmpty
                    ? draft.resolvedTeamBName[0].toUpperCase()
                    : 'B',
                selected: _winnerIsTeamA == false,
                onTap: () => setState(() => _winnerIsTeamA = false),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceXl),
          const _SectionTitle('Winner of the toss elected to?'),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CfSelectionCard(
                label: 'Bat',
                icon: Icons.sports_cricket,
                selected: _winnerBatsFirst == true,
                onTap: () => setState(() => _winnerBatsFirst = true),
              ),
              CfSelectionCard(
                label: 'Bowl',
                icon: Icons.sports_baseball,
                selected: _winnerBatsFirst == false,
                onTap: () => setState(() => _winnerBatsFirst = false),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceXl),
          _SectionTitle(
            _coinResult == null
                ? 'Tap the coin to flip'
                : "It's ${_coinResult!}!",
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Center(
            child: GestureDetector(
              onTap: _flipCoin,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.surfaceElevated,
                      AppColors.surface,
                    ],
                  ),
                  border: Border.all(
                    color: _flipping ? AppColors.gold : AppColors.border,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _flipping
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: AppColors.gold,
                          strokeWidth: 2,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'CRICKFLOW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gold.withValues(alpha: 0.9),
                              letterSpacing: 1,
                            ),
                          ),
                          const Icon(
                            Icons.sports_cricket,
                            size: 36,
                            color: AppColors.gold,
                          ),
                          Text(
                            (_coinResult ?? 'FLIP').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceXl),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
          ),
          child: Row(
            children: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Toss help — coming soon')),
                  );
                },
                child: const Text('Need help?'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _canPlay ? _letsPlay : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, AppDimens.buttonHeightLarge),
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Let's play"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
