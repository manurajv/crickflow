import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/innings_model.dart';
import '../../../data/models/match_model.dart';
import '../../../domain/scoring/toss_team_policy.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/start_match_draft_provider.dart';
import 'widgets/cf_selection_card.dart';
import 'widgets/toss_coin_flip.dart';
import '../../../shared/widgets/scoring_ui_kit.dart';
import '../../../shared/widgets/start_match_ui.dart';
import '../../../core/theme/cf_colors.dart';

/// Toss: coin flip, then winner, bat/bowl, then create match and start scoring.
class MatchTossScreen extends ConsumerStatefulWidget {
  const MatchTossScreen({super.key});

  @override
  ConsumerState<MatchTossScreen> createState() => _MatchTossScreenState();
}

class _MatchTossScreenState extends ConsumerState<MatchTossScreen> {
  bool? _winnerIsTeamA;
  bool? _winnerBatsFirst;
  String? _coinResult;
  bool _saving = false;

  bool get _tossChoicesEnabled => _coinResult != null;

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

  void _onCoinResult(String result) {
    ref.read(startMatchDraftProvider.notifier).setCoinResult(result);
    setState(() => _coinResult = result);
  }

  void _syncTossDraft() {
    if (_winnerIsTeamA == null || _winnerBatsFirst == null) return;
    ref.read(startMatchDraftProvider.notifier).setToss(
          winnerIsTeamA: _winnerIsTeamA!,
          winnerBatsFirst: _winnerBatsFirst!,
          coinResult: _coinResult,
        );
  }

  bool get _canPlay =>
      _coinResult != null &&
      _winnerIsTeamA != null &&
      _winnerBatsFirst != null &&
      !_saving;

  Future<void> _letsPlay() async {
    var draft = ref.read(startMatchDraftProvider);
    var setup = draft.setup;

    if (!setup.playingSquadsReady(draft.rules.playersPerTeam) ||
        !setup.rolesReady) {
      final playersPerTeam = draft.rules.playersPerTeam;
      final teamAError =
          setup.playingSquadError(draft.resolvedTeamAName, playersPerTeam, true);
      final teamBError =
          setup.playingSquadError(draft.resolvedTeamBName, playersPerTeam, false);
      final message = teamAError ??
          teamBError ??
          'Complete captain and wicket keeper for both teams';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    if (_coinResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flip the coin first')),
      );
      return;
    }
    if (_winnerIsTeamA == null || _winnerBatsFirst == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select toss winner and bat or bowl')),
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
    if (uid != null) {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      final player =
          await ref.read(playerRepositoryProvider).getPlayerByUserId(uid);
      await ref.read(startMatchDraftProvider.notifier).ensureDefaultScorer1(
            userId: uid,
            name: profile?.displayName ??
                profile?.name ??
                player?.name ??
                'Scorer',
            photoUrl: profile?.photoUrl ?? player?.photoUrl,
            playerId: player?.playerId,
            playerDocId: player?.id,
          );
    }

    draft = ref.read(startMatchDraftProvider);
    setup = draft.setup.withViceCaptainsFromTeams(
      teamAViceCaptainId: draft.teamA?.viceCaptainId,
      teamBViceCaptainId: draft.teamB?.viceCaptainId,
    );
    final scorerIds = setup.scorers
        .map((s) => s.userId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
    final city = draft.location.city.trim();
    final ground = draft.venue.trim();

    final match = MatchModel(
      id: draft.matchId,
      title: '${draft.resolvedTeamAName} vs ${draft.resolvedTeamBName}',
      matchType: MatchType.single,
      status: MatchStatus.tossCompleted,
      teamAId: draft.teamA?.id,
      teamBId: draft.teamB?.id,
      teamAName: draft.resolvedTeamAName,
      teamBName: draft.resolvedTeamBName,
      rules: draft.rules,
      location: draft.location.copyWith(city: city),
      venue: ground,
      scheduledAt: draft.scheduledAt ?? DateTime.now(),
      createdBy: uid,
      scorerIds: scorerIds,
      setup: setup,
    );

    final teams = TossTeamPolicy.firstInningsTeams(match);
    final battingTeamId = teams.battingTeamId;
    final bowlingTeamId = teams.bowlingTeamId;

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

  Widget _lockedSection({required Widget child}) {
    return AnimatedOpacity(
      opacity: _tossChoicesEnabled ? 1 : 0.42,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: !_tossChoicesEnabled,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
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
      backgroundColor: cf.background,
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StartMatchFlowProgress(currentIndex: StartMatchFlowStep.toss),
          Expanded(
            child: ListView(
              padding: AppDimens.listPadding,
              children: [
          const _SectionTitle('Flip the coin'),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            _tossChoicesEnabled
                ? 'Record who won and what they chose.'
                : 'Flip first, then select the toss winner and bat or bowl.',
            style: TextStyle(
              fontSize: 13,
              color: cf.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Center(
            child: TossCoinFlip(
              result: _coinResult,
              onResult: _onCoinResult,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXl),
          _lockedSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      onTap: () {
                        setState(() => _winnerIsTeamA = true);
                        _syncTossDraft();
                      },
                    ),
                    CfSelectionCard(
                      label: draft.resolvedTeamBName.toUpperCase(),
                      avatarLetter: draft.resolvedTeamBName.isNotEmpty
                          ? draft.resolvedTeamBName[0].toUpperCase()
                          : 'B',
                      selected: _winnerIsTeamA == false,
                      onTap: () {
                        setState(() => _winnerIsTeamA = false);
                        _syncTossDraft();
                      },
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
                      onTap: () {
                        setState(() => _winnerBatsFirst = true);
                        _syncTossDraft();
                      },
                    ),
                    CfSelectionCard(
                      label: 'Bowl',
                      icon: Icons.sports_baseball,
                      selected: _winnerBatsFirst == false,
                      onTap: () {
                        setState(() => _winnerBatsFirst = false);
                        _syncTossDraft();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceXl),
              ],
            ),
          ),
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
                style: ScoringUiKit.primaryButtonStyle(context).copyWith(
                  minimumSize: WidgetStateProperty.all(
                    const Size(160, AppDimens.buttonHeightLarge),
                  ),
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
    final cf = context.cf;
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
