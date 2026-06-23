import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/tournament/tournament_create_draft.dart';
import '../../../domain/services/tournament_create_service.dart';
import '../../matches/presentation/models/ground_pick_result.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_create_draft_provider.dart';
import '../../../shared/widgets/start_match_ui.dart';
import 'widgets/tournament_create/tournament_create_basic_step.dart';
import 'widgets/tournament_create/tournament_create_officials_step.dart';
import 'widgets/tournament_create/tournament_create_teams_step.dart';
import 'widgets/tournament_create/tournament_create_ui.dart';

/// Multi-step tournament creation wizard (CricHeroes-inspired, CrickFlow themed).
class TournamentCreateFlowScreen extends ConsumerStatefulWidget {
  const TournamentCreateFlowScreen({super.key});

  @override
  ConsumerState<TournamentCreateFlowScreen> createState() =>
      _TournamentCreateFlowScreenState();
}

class _TournamentCreateFlowScreenState
    extends ConsumerState<TournamentCreateFlowScreen> {
  int _stepIndex = 0;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tournamentCreateDraftProvider.notifier).reset();
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile != null) {
        ref.read(tournamentCreateDraftProvider.notifier).seedFromProfile(
              displayName: profile.displayName,
              phone: profile.effectiveMobile,
              email: profile.email,
              location: profile.location,
            );
      }
    });
  }

  void _onDraftChanged(TournamentCreateDraft draft) {
    ref.read(tournamentCreateDraftProvider.notifier).updateDraft(draft);
    setState(() {});
  }

  Future<void> _pickGroundOnMap(TournamentCreateDraft draft) async {
    final result = await context.push<GroundPickResult>(
      '/match/create/pick-ground',
      extra: {
        'location': draft.location,
        'groundName': draft.ground,
      },
    );
    if (result == null || !mounted) return;
    _onDraftChanged(
      draft.copyWith(
        ground: result.groundName,
        city: result.location.city.isNotEmpty ? result.location.city : draft.city,
        location: result.location,
      ),
    );
  }

  Future<void> _pickTeamLocationOnMap(TournamentCreateDraft draft) async {
    final result = await context.push<GroundPickResult>(
      '/match/create/pick-ground',
      extra: {
        'location': draft.setup.teamLocation,
        'groundName': draft.setup.primaryGround,
      },
    );
    if (result == null || !mounted) return;
    _onDraftChanged(
      draft.copyWith(
        setup: draft.setup.copyWith(teamLocation: result.location),
        location: result.location,
        city: result.location.city.isNotEmpty ? result.location.city : draft.city,
      ),
    );
  }

  Future<void> _next(TournamentCreateDraft draft) async {
    final steps = draft.activeSteps;
    if (_stepIndex >= steps.length - 1) {
      _submit(draft);
      return;
    }
    if (steps[_stepIndex] == TournamentCreateFlowStep.basic &&
        !draft.canProceedFromBasic) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fill all required fields on this step'),
        ),
      );
      return;
    }
    setState(() => _stepIndex++);
  }

  void _skip(TournamentCreateDraft draft) {
    final steps = draft.activeSteps;
    if (_stepIndex >= steps.length - 1) {
      _submit(draft);
      return;
    }
    setState(() => _stepIndex++);
  }

  Future<void> _submit(TournamentCreateDraft draft) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    if (!draft.canProceedFromBasic) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete tournament details first')),
      );
      setState(() => _stepIndex = 0);
      return;
    }

    setState(() => _saving = true);
    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      final id = await ref.read(tournamentCreateServiceProvider).submit(
            draft: draft,
            uid: uid,
            ownerDisplayName: profile?.displayName ?? draft.organizerName,
          );
      ref.read(tournamentCreateDraftProvider.notifier).reset();
      if (mounted) context.go('/tournaments/$id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(tournamentCreateDraftProvider);
    final steps = draft.activeSteps;
    final safeIndex = _stepIndex.clamp(0, steps.length - 1);
    if (safeIndex != _stepIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _stepIndex = safeIndex);
      });
    }

    final current = steps[safeIndex];
    final isLast = safeIndex >= steps.length - 1;
    final showSkip = current != TournamentCreateFlowStep.basic;

    return Scaffold(
      backgroundColor: context.cf.background,
      appBar: AppBar(
        title: const Text('Add a tournament / series'),
      ),
      body: Column(
        children: [
          if (steps.length > 1)
            StartMatchStepBar(
              steps: draft.stepLabels,
              currentIndex: safeIndex,
            ),
          Expanded(
            child: switch (current) {
              TournamentCreateFlowStep.basic => TournamentCreateBasicStep(
                  draft: draft,
                  onChanged: _onDraftChanged,
                  onPickGroundOnMap: () => _pickGroundOnMap(draft),
                ),
              TournamentCreateFlowStep.officials =>
                TournamentCreateOfficialsStep(
                  draft: draft,
                  onChanged: _onDraftChanged,
                ),
              TournamentCreateFlowStep.teams => TournamentCreateTeamsStep(
                  draft: draft,
                  onChanged: _onDraftChanged,
                  onPickLocationOnMap: () => _pickTeamLocationOnMap(draft),
                ),
            },
          ),
          TournamentCreateFooter(
            primaryLabel: isLast ? 'Create tournament' : 'Next',
            isLoading: _saving,
            showSkip: showSkip,
            onSkip: _saving ? null : () => _skip(draft),
            onPrimary: _saving
                ? null
                : () {
                    requireAuthVoid(
                      context: context,
                      ref: ref,
                      returnPath: '/tournaments/create',
                      action: () async => _next(draft),
                    );
                  },
          ),
        ],
      ),
    );
  }
}
