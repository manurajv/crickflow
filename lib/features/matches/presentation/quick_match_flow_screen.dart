import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/match_rules_model.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/start_match_draft_provider.dart';
import '../../../shared/widgets/scoring_ui_kit.dart';
import '../../../shared/widgets/start_match_ui.dart';
import 'models/ground_pick_result.dart';
import 'widgets/start_match_setup_form.dart';

/// Quick Match: teams (registered or typed) → setup → toss (no Playing XI).
class QuickMatchFlowScreen extends ConsumerStatefulWidget {
  const QuickMatchFlowScreen({super.key});

  @override
  ConsumerState<QuickMatchFlowScreen> createState() =>
      _QuickMatchFlowScreenState();
}

class _QuickMatchFlowScreenState extends ConsumerState<QuickMatchFlowScreen> {
  int _step = 0;
  final _venueController = TextEditingController();
  final _cityController = TextEditingController();
  final _oversController = TextEditingController();
  final _oversPerBowlerController = TextEditingController();
  final _teamANameController = TextEditingController();
  final _teamBNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draft = ref.read(startMatchDraftProvider);
      if (!draft.isQuickMatch) {
        ref.read(startMatchDraftProvider.notifier).reset(mode: MatchMode.quick);
      }
      final fresh = ref.read(startMatchDraftProvider);
      if (fresh.teamA == null && fresh.teamAName.isNotEmpty) {
        _teamANameController.text = fresh.teamAName;
      }
      if (fresh.teamB == null && fresh.teamBName.isNotEmpty) {
        _teamBNameController.text = fresh.teamBName;
      }
    });
  }

  @override
  void dispose() {
    _venueController.dispose();
    _cityController.dispose();
    _oversController.dispose();
    _oversPerBowlerController.dispose();
    _teamANameController.dispose();
    _teamBNameController.dispose();
    super.dispose();
  }

  void _syncOversFromRules(MatchRulesModel rules) {
    final overs = '${rules.totalOvers}';
    final perBowler = '${rules.oversPerBowler}';
    if (_oversController.text != overs) _oversController.text = overs;
    if (_oversPerBowlerController.text != perBowler) {
      _oversPerBowlerController.text = perBowler;
    }
  }

  void _onRulesChanged(MatchRulesModel rules) {
    // Indoor defaults to 1 innings; Quick Match always plays a chase.
    final next = rules.maxInnings < 2
        ? rules.copyWith(maxInnings: 2)
        : rules;
    ref.read(startMatchDraftProvider.notifier).updateRules(next);
    _syncOversFromRules(next);
  }

  Future<void> _pickRegisteredTeam(bool isTeamA) async {
    final team = await context.push<TeamModel>(
      '/match/create/select-team?slot=${isTeamA ? 'a' : 'b'}',
    );
    if (team == null || !mounted) return;
    final notifier = ref.read(startMatchDraftProvider.notifier);
    if (isTeamA) {
      _teamANameController.clear();
      notifier.setTeamA(team);
    } else {
      _teamBNameController.clear();
      notifier.setTeamB(team);
    }
    if (_cityController.text.isEmpty && team.location.city.isNotEmpty) {
      _cityController.text = team.location.city;
      final d = ref.read(startMatchDraftProvider);
      notifier.updateLocation(d.location.copyWith(city: team.location.city));
    }
  }

  void _applyTypedTeamName(bool isTeamA, String raw) {
    final name = raw.trim();
    final notifier = ref.read(startMatchDraftProvider.notifier);
    if (isTeamA) {
      notifier.setTeamA(null, customName: name);
    } else {
      notifier.setTeamB(null, customName: name);
    }
  }

  void _clearTeam(bool isTeamA) {
    final notifier = ref.read(startMatchDraftProvider.notifier);
    if (isTeamA) {
      _teamANameController.clear();
      notifier.setTeamA(null, customName: '');
    } else {
      _teamBNameController.clear();
      notifier.setTeamB(null, customName: '');
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('EEE, MMM d yyyy · hh:mm a').format(dt);
  }

  Future<void> _pickDateTime() async {
    final draft = ref.read(startMatchDraftProvider);
    final date = await showDatePicker(
      context: context,
      initialDate: draft.scheduledAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(draft.scheduledAt ?? DateTime.now()),
    );
    if (time == null || !mounted) return;
    ref.read(startMatchDraftProvider.notifier).updateScheduledAt(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
  }

  Future<void> _pickGroundOnMap() async {
    final draft = ref.read(startMatchDraftProvider);
    final result = await context.push<GroundPickResult>(
      '/match/create/pick-ground',
      extra: {
        'location': draft.location,
        'groundName': draft.venue,
      },
    );
    if (result == null || !mounted) return;
    _venueController.text = result.groundName;
    if (result.location.city.isNotEmpty) {
      _cityController.text = result.location.city;
    }
    ref.read(startMatchDraftProvider.notifier)
      ..updateVenue(result.groundName)
      ..updateLocation(result.location);
  }

  void _applyGroundLocation(LocationModel location) {
    ref.read(startMatchDraftProvider.notifier).updateLocation(location);
    if (location.city.isNotEmpty && _cityController.text.trim().isEmpty) {
      _cityController.text = location.city;
    }
  }

  Future<void> _goToToss() async {
    final draft = ref.read(startMatchDraftProvider);
    final city = _cityController.text.trim();
    final ground = _venueController.text.trim();
    if (!draft.hasBothTeams) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select or enter both team names')),
      );
      return;
    }
    if (city.isEmpty || ground.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter city and ground')),
      );
      return;
    }
    ref.read(startMatchDraftProvider.notifier)
      ..updateLocation(draft.location.copyWith(city: city))
      ..updateVenue(ground)
      ..setMatchMode(MatchMode.quick);
    if (mounted) context.push('/match/create/toss');
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(startMatchDraftProvider);
    final cf = context.cf;

    return Scaffold(
      appBar: StartMatchWizardAppBar(
        title: Text(_step == 0 ? 'Quick Match — teams' : 'Quick Match — setup'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: Text(
              _step == 0
                  ? 'Step 1 of 3 · Teams'
                  : 'Step 2 of 3 · Match settings',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cf.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: _step == 0 ? _teamsStep(draft) : _setupStep(draft),
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
          child: _step == 0
              ? FilledButton(
                  onPressed: draft.hasBothTeams
                      ? () {
                          _syncOversFromRules(draft.rules);
                          setState(() => _step = 1);
                        }
                      : null,
                  style: ScoringUiKit.primaryButtonStyle(context).copyWith(
                    minimumSize: WidgetStateProperty.all(
                      const Size(double.infinity, AppDimens.buttonHeightLarge),
                    ),
                  ),
                  child: const Text('Continue to match settings'),
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step = 0),
                        style: ScoringUiKit.outlinedButtonStyle(context)
                            .copyWith(
                          minimumSize: WidgetStateProperty.all(
                            const Size(0, AppDimens.buttonHeightLarge),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: FilledButton(
                        onPressed: draft.canProceedToQuickToss ? _goToToss : null,
                        style: ScoringUiKit.primaryButtonStyle(context).copyWith(
                          minimumSize: WidgetStateProperty.all(
                            const Size(0, AppDimens.buttonHeightLarge),
                          ),
                        ),
                        child: const Text('Next — Toss'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _teamsStep(StartMatchDraft draft) {
    return ListView(
      padding: AppDimens.listPadding,
      children: [
        const StartMatchInfoBanner(
          message:
              'Pick a registered team or type a temporary name. Typed teams exist only for this match.',
        ),
        const SizedBox(height: AppDimens.spaceLg),
        StartMatchCard(
          child: Column(
            children: [
              _QuickTeamSlot(
                label: 'Team 1',
                registeredTeam: draft.teamA,
                nameController: _teamANameController,
                displayName: draft.resolvedTeamAName,
                onPickRegistered: () => _pickRegisteredTeam(true),
                onTypedNameChanged: (v) => _applyTypedTeamName(true, v),
                onClear: () => _clearTeam(true),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
                child: Text(
                  'VS',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: context.cf.accent,
                  ),
                ),
              ),
              _QuickTeamSlot(
                label: 'Team 2',
                registeredTeam: draft.teamB,
                nameController: _teamBNameController,
                displayName: draft.resolvedTeamBName,
                onPickRegistered: () => _pickRegisteredTeam(false),
                onTypedNameChanged: (v) => _applyTypedTeamName(false, v),
                onClear: () => _clearTeam(false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _setupStep(StartMatchDraft draft) {
    if (_cityController.text.isEmpty && draft.location.city.isNotEmpty) {
      _cityController.text = draft.location.city;
    }
    if (_venueController.text.isEmpty && draft.venue.isNotEmpty) {
      _venueController.text = draft.venue;
    }
    _syncOversFromRules(draft.rules);

    return StartMatchSetupForm(
      rules: draft.rules,
      setup: draft.setup,
      cityController: _cityController,
      venueController: _venueController,
      oversController: _oversController,
      oversPerBowlerController: _oversPerBowlerController,
      dateTimeLabel: _formatDateTime(draft.scheduledAt),
      onPickDateTime: _pickDateTime,
      onRulesChanged: _onRulesChanged,
      onCityChanged: (v) {
        ref.read(startMatchDraftProvider.notifier).updateLocation(
              draft.location.copyWith(city: v),
            );
      },
      onVenueChanged: (v) =>
          ref.read(startMatchDraftProvider.notifier).updateVenue(v),
      onLocationResolved: _applyGroundLocation,
      onPickGroundOnMap: _pickGroundOnMap,
    );
  }
}

class _QuickTeamSlot extends StatelessWidget {
  const _QuickTeamSlot({
    required this.label,
    required this.registeredTeam,
    required this.nameController,
    required this.displayName,
    required this.onPickRegistered,
    required this.onTypedNameChanged,
    required this.onClear,
  });

  final String label;
  final TeamModel? registeredTeam;
  final TextEditingController nameController;
  final String displayName;
  final VoidCallback onPickRegistered;
  final ValueChanged<String> onTypedNameChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final hasRegistered = registeredTeam != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: cf.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        if (hasRegistered)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: cf.sectionBackground,
              backgroundImage: registeredTeam!.logoUrl != null
                  ? CachedNetworkImageProvider(registeredTeam!.logoUrl!)
                  : null,
              child: registeredTeam!.logoUrl == null
                  ? Text(
                      registeredTeam!.name.isNotEmpty
                          ? registeredTeam!.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: cf.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
            title: Text(
              registeredTeam!.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Registered team'),
            trailing: IconButton(
              tooltip: 'Clear',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: onPickRegistered,
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Select registered team'),
            style: ScoringUiKit.outlinedButtonStyle(context),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'OR',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cf.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Enter team name',
              hintText: 'Temporary team for this match only',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: onTypedNameChanged,
          ),
          if (displayName.isNotEmpty && nameController.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Using: $displayName',
                style: TextStyle(color: cf.textSecondary, fontSize: 12),
              ),
            ),
        ],
      ],
    );
  }
}
