import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/match_rules_model.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/start_match_draft_provider.dart';
import 'models/ground_pick_result.dart';
import 'widgets/start_match_setup_form.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../shared/widgets/scoring_ui_kit.dart';
import '../../../shared/widgets/start_match_ui.dart';

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

  Future<void> _pickGroundOnMap() async {
    final draft = ref.read(startMatchDraftProvider);
    final result = await context.push<GroundPickResult>(
      '/match/create/pick-ground',
      extra: {
        'location': draft.location,
        'groundName': _venueController.text.trim(),
      },
    );
    if (result == null || !mounted) return;
    _venueController.text = result.groundName;
    if (result.location.city.isNotEmpty) {
      _cityController.text = result.location.city;
    }
    final notifier = ref.read(startMatchDraftProvider.notifier);
    notifier
      ..updateVenue(result.groundName)
      ..updateLocation(
        result.location.copyWith(
          city: result.location.city.isNotEmpty
              ? result.location.city
              : draft.location.city,
        ),
      );
  }

  void _applyGroundLocation(LocationModel location) {
    final draft = ref.read(startMatchDraftProvider);
    ref.read(startMatchDraftProvider.notifier).updateLocation(
          draft.location.copyWith(
            country: location.country.isNotEmpty
                ? location.country
                : draft.location.country,
            stateProvince: location.stateProvince,
            city: location.city,
          ),
        );
    if (location.city.isNotEmpty) {
      _cityController.text = location.city;
    }
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

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(startMatchDraftProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 0 ? 'Select playing teams' : 'Start a match'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StartMatchFlowProgress(
            currentIndex: _step == 0
                ? StartMatchFlowStep.teams
                : StartMatchFlowStep.setup,
          ),
          Expanded(
            child: _step == 0 ? _teamsStep(draft) : _setupStep(draft),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(draft),
    );
  }

  Widget _teamsStep(StartMatchDraft draft) {
    final cf = context.cf;
    return ListView(
      padding: AppDimens.listPadding,
      children: [
        StartMatchInfoBanner(
          message: 'Scoring a match on CrickFlow is free.',
        ),
        const SizedBox(height: AppDimens.spaceLg),
        StartMatchCard(
          child: Column(
            children: [
              // Team A slot
              _TeamSlot(
                label: 'Team A',
                team: draft.teamA,
                name: draft.resolvedTeamAName,
                onSelect: () => _pickTeam(true),
              ),

              // VS divider
              Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.spaceMd),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: cf.border,
                        thickness: 0.5,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceMd),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cf.sectionBackground,
                          border: Border.all(color: cf.border),
                        ),
                        child: Center(
                          child: Text(
                            'VS',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: cf.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: cf.border,
                        thickness: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Team B slot
              _TeamSlot(
                label: 'Team B',
                team: draft.teamB,
                name: draft.resolvedTeamBName,
                onSelect: () => _pickTeam(false),
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
      onManageOfficials: () async {
        await context.push('/match/create/officials');
        if (mounted) setState(() {});
      },
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
                style: ScoringUiKit.primaryButtonStyle(context).copyWith(
                  minimumSize: WidgetStateProperty.all(
                    const Size(double.infinity, AppDimens.buttonHeightLarge),
                  ),
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
                      style: ScoringUiKit.outlinedButtonStyle(context).copyWith(
                        minimumSize: WidgetStateProperty.all(
                          const Size(0, AppDimens.buttonHeightLarge),
                        ),
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      child: const Text(
                        'Schedule',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _goToSquadFlow,
                      style: ScoringUiKit.primaryButtonStyle(context).copyWith(
                        minimumSize: WidgetStateProperty.all(
                          const Size(0, AppDimens.buttonHeightLarge),
                        ),
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Next (toss)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
    final cf = context.cf;
    final hasTeam = name.isNotEmpty;
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
        child: Row(
          children: [
            // Logo / avatar
            if (team != null)
              _MatchTeamAvatar(team: team!, size: 52)
            else
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cf.sectionBackground,
                  border: Border.all(
                    color: cf.border,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.add,
                  size: 24,
                  color: cf.textSecondary,
                ),
              ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cf.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasTeam ? name : 'Tap to select team',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          hasTeam ? FontWeight.w700 : FontWeight.w400,
                      color: hasTeam
                          ? cf.textPrimary
                          : cf.textMuted,
                    ),
                  ),
                  if (team?.location.displayLabel.isNotEmpty == true)
                    Text(
                      team!.location.displayLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: cf.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              hasTeam ? Icons.swap_horiz : Icons.chevron_right,
              color: cf.accent,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Polished circular avatar for a team in the match setup card.
class _MatchTeamAvatar extends StatelessWidget {
  const _MatchTeamAvatar({required this.team, required this.size});

  final TeamModel team;
  final double size;

  String get _initials {
    if (team.name.isEmpty) return '?';
    final words = team.name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words[0]
          .substring(0, words[0].length.clamp(0, 2))
          .toUpperCase();
    }
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final logoUrl = team.profileImageUrl;
    final hasImage = logoUrl != null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasImage
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF1565C0), cf.accent],
              ),
        color: hasImage ? cf.sectionBackground : null,
        border: Border.all(
          color: hasImage
              ? cf.accent.withValues(alpha: 0.55)
              : cf.accent.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: cf.cardShadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: size * 0.3,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: size * 0.3,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  _initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: size * 0.3,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
      ),
    );
  }
}
