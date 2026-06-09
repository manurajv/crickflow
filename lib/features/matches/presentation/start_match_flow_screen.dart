import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/match_rules_model.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/start_match_draft_provider.dart';
import '../../../shared/widgets/cf_underlined_field.dart';
import 'match_scoring_rules_screen.dart';
import 'widgets/start_match_setup_form.dart';

/// Start match: select teams → setup → create.
class StartMatchFlowScreen extends ConsumerStatefulWidget {
  const StartMatchFlowScreen({super.key});

  @override
  ConsumerState<StartMatchFlowScreen> createState() =>
      _StartMatchFlowScreenState();
}

class _StartMatchFlowScreenState extends ConsumerState<StartMatchFlowScreen> {
  int _step = 0;
  bool _saving = false;
  final _venueController = TextEditingController();
  final _cityController = TextEditingController();
  final _oversController = TextEditingController();
  final _oversPerBowlerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(startMatchDraftProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _venueController.dispose();
    _cityController.dispose();
    _oversController.dispose();
    _oversPerBowlerController.dispose();
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
    ref.read(startMatchDraftProvider.notifier).updateRules(rules);
    _syncOversFromRules(rules);
  }

  Future<void> _pickTeam(bool isTeamA) async {
    final team = await context.push<TeamModel>(
      '/match/create/select-team?slot=${isTeamA ? 'a' : 'b'}',
    );
    if (team == null || !mounted) return;
    final notifier = ref.read(startMatchDraftProvider.notifier);
    if (isTeamA) {
      notifier.setTeamA(team);
    } else {
      notifier.setTeamB(team);
    }
    if (_cityController.text.isEmpty && team.location.city.isNotEmpty) {
      _cityController.text = team.location.city;
      final d = ref.read(startMatchDraftProvider);
      notifier.updateLocation(d.location.copyWith(city: team.location.city));
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
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    ref.read(startMatchDraftProvider.notifier).updateScheduledAt(combined);
  }

  Future<void> _submitMatch({required bool scheduleOnly}) async {
    final draft = ref.read(startMatchDraftProvider);
    if (!draft.hasBothTeams) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select both teams first')),
      );
      return;
    }

    final city = _cityController.text.trim();
    final ground = _venueController.text.trim();
    if (city.isEmpty || ground.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter city and ground')),
      );
      return;
    }

    setState(() => _saving = true);
    final uid = ref.read(authStateProvider).value?.uid;

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
    );

    try {
      await ref.read(matchRepositoryProvider).createMatch(match);
      ref.read(startMatchDraftProvider.notifier).reset();
      if (mounted) context.go('/match/${draft.matchId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create match: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goToSquadFlow() {
    final draft = ref.read(startMatchDraftProvider);
    if (!draft.canProceedToSquad) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter city and ground first')),
      );
      return;
    }
    final city = _cityController.text.trim();
    final ground = _venueController.text.trim();
    ref.read(startMatchDraftProvider.notifier)
      ..updateLocation(draft.location.copyWith(city: city))
      ..updateVenue(ground);
    context.push('/match/create/squad/a');
  }

  Future<void> _openMatchRules() async {
    final draft = ref.read(startMatchDraftProvider);
    final updated = await Navigator.of(context).push<MatchRulesModel>(
      MaterialPageRoute(
        builder: (_) => MatchScoringRulesScreen(initialRules: draft.rules),
      ),
    );
    if (updated != null) _onRulesChanged(updated);
  }

  void _showTestMatchOversSheet() {
    final draft = ref.read(startMatchDraftProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppDimens.spaceLg,
            right: AppDimens.spaceLg,
            top: AppDimens.spaceLg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppDimens.spaceLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Overs & bowler limits',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              CfUnderlinedField(
                controller: _oversController,
                label: 'No. of overs',
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n > 0) {
                    _onRulesChanged(draft.rules.withTotalOvers(n));
                  }
                },
              ),
              const SizedBox(height: AppDimens.fieldSpacing),
              CfUnderlinedField(
                controller: _oversPerBowlerController,
                label: 'Overs per bowler',
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n >= 1) {
                    _onRulesChanged(draft.rules.withManualOversPerBowler(n));
                  }
                },
              ),
              if (draft.rules.isManualOversPerBowler)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _onRulesChanged(
                      draft.rules.resetOversPerBowlerToAuto(),
                    ),
                    icon: const Icon(Icons.autorenew, size: 18),
                    label: const Text('Reset to Auto'),
                  ),
                ),
              const SizedBox(height: AppDimens.spaceLg),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onSetupMenuSelected(String value) {
    switch (value) {
      case 'rules':
        _openMatchRules();
      case 'overs':
        _showTestMatchOversSheet();
      case 'delayed':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match delayed — set during scoring')),
        );
      case 'abandoned':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match abandoned — set during scoring')),
        );
      case 'walkover':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Walkover — set during scoring')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(startMatchDraftProvider);
    final isSetup = _step == 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 0 ? 'Select playing teams' : 'Start a match'),
        actions: [
          if (isSetup)
            PopupMenuButton<String>(
              icon: const Icon(Icons.tune),
              tooltip: 'Match options',
              onSelected: _onSetupMenuSelected,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rules',
                  child: ListTile(
                    leading: Icon(Icons.rule),
                    title: Text('Match rules'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (draft.rules.isTestMatch)
                  const PopupMenuItem(
                    value: 'overs',
                    child: ListTile(
                      leading: Icon(Icons.format_list_numbered),
                      title: Text('Overs & bowler limits'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delayed',
                  child: ListTile(
                    leading: Icon(Icons.schedule),
                    title: Text('Match delayed'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'abandoned',
                  child: ListTile(
                    leading: Icon(Icons.cancel_outlined),
                    title: Text('Match abandoned'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'walkover',
                  child: ListTile(
                    leading: Icon(Icons.flag_outlined),
                    title: Text('Walkover'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _step == 0 ? _teamsStep(draft) : _setupStep(draft),
      bottomNavigationBar: _bottomBar(draft),
    );
  }

  Widget _teamsStep(StartMatchDraft draft) {
    return ListView(
      padding: AppDimens.listPadding,
      children: [
        Text(
          '* Scoring a match on CrickFlow is free.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppDimens.spaceXl),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimens.spaceXl,
              horizontal: AppDimens.spaceLg,
            ),
            child: Column(
              children: [
                _TeamSlot(
                  label: 'Team A',
                  team: draft.teamA,
                  name: draft.resolvedTeamAName,
                  onSelect: () => _pickTeam(true),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                const _VsBadge(),
                const SizedBox(height: AppDimens.spaceLg),
                _TeamSlot(
                  label: 'Team B',
                  team: draft.teamB,
                  name: draft.resolvedTeamBName,
                  onSelect: () => _pickTeam(false),
                ),
              ],
            ),
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
      onManageOfficials: () => context.push('/match/create/officials'),
    );
  }

  Widget? _bottomBar(StartMatchDraft draft) {
    return SafeArea(
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
                style: FilledButton.styleFrom(
                  minimumSize:
                      const Size(double.infinity, AppDimens.buttonHeightLarge),
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Continue to match setup'),
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => _submitMatch(scheduleOnly: true),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, AppDimens.buttonHeightLarge),
                      ),
                      child: const Text('Schedule match'),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _goToSquadFlow,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, AppDimens.buttonHeightLarge),
                        backgroundColor: AppColors.primaryBlue,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Next (toss)'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TeamSlot extends StatelessWidget {
  const _TeamSlot({
    required this.label,
    required this.team,
    required this.name,
    required this.onSelect,
  });

  final String label;
  final TeamModel? team;
  final String name;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final hasTeam = name.isNotEmpty;
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: AppColors.surfaceElevated,
          backgroundImage: team?.logoUrl != null
              ? CachedNetworkImageProvider(team!.logoUrl!)
              : null,
          child: team?.logoUrl == null
              ? Icon(
                  hasTeam ? Icons.groups : Icons.add,
                  size: 40,
                  color: AppColors.textSecondary,
                )
              : null,
        ),
        const SizedBox(height: AppDimens.spaceSm),
        if (hasTeam)
          Text(
            name,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: AppDimens.spaceSm),
        FilledButton(
          onPressed: onSelect,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            minimumSize: const Size(220, AppDimens.buttonHeightLarge),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: Text(
            hasTeam ? 'Change $label' : 'Select $label',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _VsBadge extends StatelessWidget {
  const _VsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        shape: BoxShape.circle,
      ),
      child: Text(
        'vs',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.gold,
            ),
      ),
    );
  }
}
