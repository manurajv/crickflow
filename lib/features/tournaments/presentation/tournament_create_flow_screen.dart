import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/tournament/tournament_create_draft.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/services/tournament_create_service.dart';
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
  int _maxStepIndex = 0;
  var _saving = false;
  var _seededFromProfile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tournamentCreateDraftProvider.notifier).reset();
      _seededFromProfile = false;
      _stepIndex = 0;
      _maxStepIndex = 0;
    });
  }

  void _seedOrganizerFromProfile(UserModel profile) {
    if (_seededFromProfile) return;
    _seededFromProfile = true;
    ref.read(tournamentCreateDraftProvider.notifier).seedFromProfile(
          displayName: profile.effectiveName,
          phone: profile.effectiveMobile,
          email: profile.email,
          location: profile.location,
        );
    setState(() {});
  }

  void _onDraftChanged(TournamentCreateDraft draft) {
    ref.read(tournamentCreateDraftProvider.notifier).updateDraft(draft);
    setState(() {
      final steps = draft.activeSteps;
      if (_maxStepIndex >= steps.length) {
        _maxStepIndex = steps.length - 1;
      }
      if (_stepIndex >= steps.length) {
        _stepIndex = steps.length - 1;
      }
    });
  }

  void _goToStep(int index, {required List<TournamentCreateFlowStep> steps}) {
    if (index < 0 || index >= steps.length) return;
    setState(() => _stepIndex = index);
  }

  void _advanceStep(int nextIndex) {
    setState(() {
      _stepIndex = nextIndex;
      if (nextIndex > _maxStepIndex) _maxStepIndex = nextIndex;
    });
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
    _advanceStep(_stepIndex + 1);
  }

  void _skip(TournamentCreateDraft draft) {
    final steps = draft.activeSteps;
    if (_stepIndex >= steps.length - 1) {
      _submit(draft);
      return;
    }
    _advanceStep(_stepIndex + 1);
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
      final organizerName = draft.organizerName.trim();
      final id = await ref.read(tournamentCreateServiceProvider).submit(
            draft: draft,
            uid: uid,
            ownerDisplayName: organizerName.isNotEmpty
                ? organizerName
                : (profile?.effectiveName ?? ''),
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
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    if (profile != null && !_seededFromProfile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _seededFromProfile) return;
        _seedOrganizerFromProfile(profile);
      });
    }

    final draft = ref.watch(tournamentCreateDraftProvider);
    final steps = draft.activeSteps;
    final safeIndex = _stepIndex.clamp(0, steps.length - 1);
    final maxIndex = _maxStepIndex.clamp(0, steps.length - 1);
    if (safeIndex != _stepIndex || maxIndex != _maxStepIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _stepIndex = safeIndex;
          _maxStepIndex = maxIndex;
        });
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
              isStepTappable: (i) => i <= maxIndex,
              onStepTap: (i) => _goToStep(i, steps: steps),
            ),
          Expanded(
            child: switch (current) {
              TournamentCreateFlowStep.basic => TournamentCreateBasicStep(
                  draft: draft,
                  onChanged: _onDraftChanged,
                ),
              TournamentCreateFlowStep.officials =>
                TournamentCreateOfficialsStep(
                  draft: draft,
                  onChanged: _onDraftChanged,
                ),
              TournamentCreateFlowStep.teams => TournamentCreateTeamsStep(
                  draft: draft,
                  onChanged: _onDraftChanged,
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
