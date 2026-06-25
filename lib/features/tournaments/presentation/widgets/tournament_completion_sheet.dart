import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/team_model.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_analytics_providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/match_team_avatar.dart';

Future<void> showTournamentCompletionSheet(
  BuildContext context,
  WidgetRef ref, {
  required TournamentModel tournament,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (ctx) => _TournamentCompletionSheet(
      tournament: tournament,
      ref: ref,
    ),
  );
}

class _TournamentCompletionSheet extends ConsumerStatefulWidget {
  const _TournamentCompletionSheet({
    required this.tournament,
    required this.ref,
  });

  final TournamentModel tournament;
  final WidgetRef ref;

  @override
  ConsumerState<_TournamentCompletionSheet> createState() =>
      _TournamentCompletionSheetState();
}

class _TournamentCompletionSheetState
    extends ConsumerState<_TournamentCompletionSheet> {
  String? _championId;
  String? _runnerUpId;
  String? _thirdPlaceId;
  var _saving = false;
  List<TeamModel> _teams = const [];
  var _teamsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    final repo = widget.ref.read(teamRepositoryProvider);
    final loaded = <TeamModel>[];
    for (final id in widget.tournament.teamIds) {
      final team = await repo.getTeam(id);
      if (team != null) loaded.add(team);
    }
    loaded.sort((a, b) => a.name.compareTo(b.name));
    if (mounted) {
      setState(() {
        _teams = loaded;
        _teamsLoaded = true;
      });
    }
  }

  TeamModel? _teamById(String? id) {
    if (id == null) return null;
    for (final team in _teams) {
      if (team.id == id) return team;
    }
    return null;
  }

  String _teamName(String? id) => _teamById(id)?.name ?? 'Unknown team';

  List<TeamModel> _eligibleTeams({String? excludeA, String? excludeB}) {
    return _teams
        .where(
          (t) => t.id != excludeA && t.id != excludeB,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final heroes =
        ref.watch(tournamentHeroesProvider(widget.tournament.id)).valueOrNull;

    return Padding(
      padding: EdgeInsets.only(
        left: AppDimens.spaceMd,
        right: AppDimens.spaceMd,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppDimens.spaceMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Finish tournament',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Confirm the podium and lock further edits.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          if (!_teamsLoaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_teams.isEmpty)
            Text(
              'Add teams to the tournament before finishing.',
              style: TextStyle(color: cf.textSecondary),
            )
          else ...[
            _TeamPodiumPicker(
              label: 'Champion',
              required: true,
              value: _championId,
              teams: _teams,
              onChanged: (v) => setState(() {
                _championId = v;
                if (_runnerUpId == v) _runnerUpId = null;
                if (_thirdPlaceId == v) _thirdPlaceId = null;
              }),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _TeamPodiumPicker(
              label: 'Runner-up',
              teams: _eligibleTeams(excludeA: _championId),
              value: _runnerUpId,
              onChanged: (v) => setState(() {
                _runnerUpId = v;
                if (_thirdPlaceId == v) _thirdPlaceId = null;
              }),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _TeamPodiumPicker(
              label: 'Third place (optional)',
              teams: _eligibleTeams(
                excludeA: _championId,
                excludeB: _runnerUpId,
              ),
              value: _thirdPlaceId,
              onChanged: (v) => setState(() => _thirdPlaceId = v),
            ),
          ],
          if (heroes != null && heroes.hasData) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Container(
              padding: const EdgeInsets.all(AppDimens.spaceSm),
              decoration: BoxDecoration(
                color: cf.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: cf.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Player awards will be filled from the Heroes tab.',
                      style: TextStyle(color: cf.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppDimens.spaceMd),
          CfButton(
            label: 'Complete tournament',
            isGold: true,
            isLoading: _saving,
            onPressed: _championId == null || _saving || _teams.isEmpty
                ? null
                : _finish,
          ),
        ],
      ),
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final heroes = await widget.ref
          .read(tournamentHeroesProvider(widget.tournament.id).future);
      final awards = <String, String>{};
      for (final h in heroes.heroes) {
        awards[h.award.name] = h.playerId;
      }

      await widget.ref.read(tournamentRepositoryProvider).completeTournament(
            tournamentId: widget.tournament.id,
            championTeamId: _championId!,
            championTeamName: _teamName(_championId),
            runnerUpTeamId: _runnerUpId,
            runnerUpTeamName:
                _runnerUpId != null ? _teamName(_runnerUpId) : null,
            thirdPlaceTeamId: _thirdPlaceId,
            awards: awards,
          );
      widget.ref.invalidate(tournamentProvider(widget.tournament.id));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tournament completed — teams have been notified'),
          ),
        );
      }
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
}

class _TeamPodiumPicker extends StatelessWidget {
  const _TeamPodiumPicker({
    required this.label,
    required this.teams,
    required this.onChanged,
    this.value,
    this.required = false,
  });

  final String label;
  final List<TeamModel> teams;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final selected = teams.where((t) => t.id == value).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          required ? '$label *' : label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: value,
          decoration: InputDecoration(
            hintText: required ? 'Select team' : 'Optional',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          items: [
            if (!required)
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Not set'),
              ),
            ...teams.map(
              (team) => DropdownMenuItem<String?>(
                value: team.id,
                child: _TeamPickerRow(team: team),
              ),
            ),
          ],
          selectedItemBuilder: (_) {
            if (selected == null) {
              return [
                Text(
                  required ? 'Select team' : 'Not set',
                  style: TextStyle(color: cf.textMuted),
                ),
              ];
            }
            return [_TeamPickerRow(team: selected)];
          },
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TeamPickerRow extends StatelessWidget {
  const _TeamPickerRow({required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MatchTeamAvatar(
          name: team.name,
          logoUrl: team.profileImageUrl,
          size: 32,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
