import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../data/models/match_rules_model.dart';
import '../../../../../data/models/tournament_model.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../../../shared/providers/tournament_match_providers.dart';
import '../../../../../shared/providers/tournament_providers.dart';
import '../../../../../shared/widgets/cf_button.dart';
import '../../../../../shared/widgets/cf_underlined_field.dart';
import '../tournament_create/tournament_create_ui.dart';

Future<void> showManualMatchScheduleSheet({
  required BuildContext context,
  required TournamentModel tournament,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => _ManualMatchScheduleSheet(tournament: tournament),
  );
}

List<String> tournamentGroundNames(TournamentModel tournament) =>
    tournament.grounds.map((g) => g.trim()).where((g) => g.isNotEmpty).toList();

class _ManualMatchScheduleSheet extends ConsumerStatefulWidget {
  const _ManualMatchScheduleSheet({required this.tournament});

  final TournamentModel tournament;

  @override
  ConsumerState<_ManualMatchScheduleSheet> createState() =>
      _ManualMatchScheduleSheetState();
}

class _ManualMatchScheduleSheetState
    extends ConsumerState<_ManualMatchScheduleSheet> {
  String? _roundId;
  String? _groupId;
  String? _teamAId;
  String? _teamBId;
  String? _selectedGround;
  late DateTime _scheduledAt;
  late final TextEditingController _oversController;
  CricketMatchType _matchType = CricketMatchType.limitedOvers;
  var _busy = false;
  var _groundInitialized = false;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _scheduledAt = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      10,
      0,
    );
    _oversController = TextEditingController(
      text: '${widget.tournament.defaultRules.totalOvers}',
    );
    _matchType = widget.tournament.setupMeta.cricketMatchType;
  }

  @override
  void dispose() {
    _oversController.dispose();
    super.dispose();
  }

  void _initGroundSelection(TournamentModel live) {
    if (_groundInitialized) return;
    final grounds = tournamentGroundNames(live);
    if (grounds.length == 1) {
      _selectedGround = grounds.first;
    }
    _groundInitialized = true;
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('EEE, MMM d yyyy · hh:mm a').format(dt);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  int? _parsedOvers() {
    final n = int.tryParse(_oversController.text.trim());
    if (n == null || n < 1) return null;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(tournamentProvider(widget.tournament.id)).valueOrNull ??
        widget.tournament;
    _initGroundSelection(live);
    final rounds =
        ref.watch(tournamentActiveRoundsProvider(widget.tournament.id));
    final groups =
        ref.watch(tournamentGroupsProvider(widget.tournament.id)).valueOrNull ??
            [];
    final teamOptions = live.teamIds;
    final uid = ref.watch(authStateProvider).value?.uid;
    final grounds = tournamentGroundNames(live);
    final showOvers = _matchType != CricketMatchType.testMatch;
    final oversValid = !showOvers || _parsedOvers() != null;
    final groundValid = grounds.isNotEmpty && _selectedGround != null;
    final canSave = !_busy &&
        uid != null &&
        _teamAId != null &&
        _teamBId != null &&
        groundValid &&
        oversValid;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            MediaQuery.viewInsetsOf(context).bottom + AppDimens.spaceMd,
          ),
          children: [
            Text(
              'Schedule match',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            if (rounds.isEmpty)
              Card(
                child: ListTile(
                  title: const Text('No rounds created yet'),
                  subtitle: const Text('Create a round to label this fixture.'),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/tournaments/${widget.tournament.id}/rounds');
                    },
                    child: const Text('Create round'),
                  ),
                ),
              )
            else
              DropdownButtonFormField<String?>(
                value: _roundId,
                decoration: const InputDecoration(
                  labelText: 'Round',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Select round')),
                  ...rounds.map(
                    (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _roundId = v),
              ),
            const SizedBox(height: AppDimens.spaceSm),
            DropdownButtonFormField<String?>(
              value: _groupId,
              decoration: const InputDecoration(
                labelText: 'Group (optional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('No group')),
                ...groups.map(
                  (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                ),
              ],
              onChanged: (v) => setState(() => _groupId = v),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            DropdownButtonFormField<String>(
              value: _teamAId,
              decoration: const InputDecoration(
                labelText: 'Team A',
                border: OutlineInputBorder(),
              ),
              items: teamOptions
                  .map(
                    (id) => DropdownMenuItem(
                      value: id,
                      child: Text(_teamLabel(live, id)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _teamAId = v),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            DropdownButtonFormField<String>(
              value: _teamBId,
              decoration: const InputDecoration(
                labelText: 'Team B',
                border: OutlineInputBorder(),
              ),
              items: teamOptions
                  .where((id) => id != _teamAId)
                  .map(
                    (id) => DropdownMenuItem(
                      value: id,
                      child: Text(_teamLabel(live, id)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _teamBId = v),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'Ground',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            if (grounds.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: const Text('No grounds added'),
                  subtitle: const Text(
                    'Add tournament grounds in tournament settings before scheduling.',
                  ),
                ),
              )
            else if (grounds.length == 1)
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Ground',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  grounds.first,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedGround,
                decoration: const InputDecoration(
                  labelText: 'Select ground',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Select a ground'),
                  ),
                  ...grounds.map(
                    (g) => DropdownMenuItem(value: g, child: Text(g)),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedGround = v),
              ),
            const SizedBox(height: AppDimens.spaceMd),
            CfPickerField(
              label: 'Date & time',
              value: _formatDateTime(_scheduledAt),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'Match type',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            TournamentCricketMatchTypePicker(
              selected: _matchType,
              onSelected: (type) => setState(() => _matchType = type),
            ),
            if (showOvers) ...[
              const SizedBox(height: AppDimens.spaceMd),
              CfUnderlinedField(
                controller: _oversController,
                label: 'Total overs',
                required: true,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: AppDimens.spaceLg),
            CfButton(
              label: 'Save match',
              isGold: true,
              isLoading: _busy,
              onPressed: !canSave
                  ? null
                  : () async {
                      final userId = uid;
                      if (userId == null) return;
                      setState(() => _busy = true);
                      try {
                        final round = rounds
                            .where((r) => r.id == _roundId)
                            .firstOrNull;
                        final overs = showOvers
                            ? _parsedOvers()!
                            : MatchRulesModel.forMatchType(_matchType)
                                .totalOvers;
                        await ref
                            .read(tournamentRepositoryProvider)
                            .scheduleTournamentMatch(
                              tournament: live,
                              createdBy: userId,
                              teamAId: _teamAId!,
                              teamBId: _teamBId!,
                              roundId: _roundId,
                              roundName: round?.name,
                              groupId: _groupId,
                              venue: _selectedGround!,
                              scheduledAt: _scheduledAt,
                              totalOvers: overs,
                              cricketMatchType: _matchType,
                            );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Match scheduled')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
            ),
          ],
        );
      },
    );
  }

  String _teamLabel(TournamentModel t, String id) {
    return t.pointsTable.where((e) => e.teamId == id).firstOrNull?.teamName ??
        id;
  }
}
