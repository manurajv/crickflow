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
  /// Selected team id per place index (0 = champion).
  List<String?> _placeTeamIds = [null];
  var _placeCount = 1;
  var _saving = false;
  List<TeamModel> _teams = const [];
  Map<String, PointsTableEntry> _standingsByTeam = const {};
  var _teamsLoaded = false;

  int get _maxPlaces => _teams.isEmpty ? 1 : _teams.length.clamp(1, 5);

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  List<PointsTableEntry> _resolveStandings() {
    final byTeam = <String, PointsTableEntry>{};

    void consider(PointsTableEntry entry) {
      if (entry.teamId.isEmpty) return;
      final existing = byTeam[entry.teamId];
      if (existing == null) {
        byTeam[entry.teamId] = entry;
        return;
      }
      if (_compareStandings(entry, existing) < 0) {
        byTeam[entry.teamId] = entry;
      }
    }

    for (final entry in widget.tournament.pointsTable) {
      consider(entry);
    }

    final groupTables = widget.ref
            .read(tournamentPointsTablesProvider(widget.tournament.id))
            .valueOrNull ??
        const [];
    for (final table in groupTables) {
      for (final entry in table.entries) {
        consider(entry);
      }
    }

    final ranked = byTeam.values.toList()..sort(_compareStandings);
    return ranked;
  }

  static int _compareStandings(PointsTableEntry a, PointsTableEntry b) {
    final byPts = b.points.compareTo(a.points);
    if (byPts != 0) return byPts;
    return b.netRunRate.compareTo(a.netRunRate);
  }

  Future<void> _loadTeams() async {
    final repo = widget.ref.read(teamRepositoryProvider);
    final loaded = <TeamModel>[];
    for (final id in widget.tournament.teamIds) {
      final team = await repo.getTeam(id);
      if (team != null) loaded.add(team);
    }

    final standings = _resolveStandings();
    final standingsByTeam = {
      for (final e in standings) e.teamId: e,
    };
    final rankIndex = {
      for (var i = 0; i < standings.length; i++) standings[i].teamId: i,
    };

    loaded.sort((a, b) {
      final ai = rankIndex[a.id];
      final bi = rankIndex[b.id];
      if (ai == null && bi == null) return a.name.compareTo(b.name);
      if (ai == null) return 1;
      if (bi == null) return -1;
      return ai.compareTo(bi);
    });

    if (!mounted) return;

    final maxPlaces = loaded.isEmpty ? 1 : loaded.length.clamp(1, 5);
    // Default: show top 3 when enough teams, else all teams.
    final initialCount = maxPlaces.clamp(1, 3);
    final ids = List<String?>.generate(
      initialCount,
      (i) => i < loaded.length ? loaded[i].id : null,
    );

    setState(() {
      _teams = loaded;
      _standingsByTeam = standingsByTeam;
      _teamsLoaded = true;
      _placeCount = initialCount;
      _placeTeamIds = ids;
    });
  }

  void _setPlaceCount(int count) {
    final next = count.clamp(1, _maxPlaces);
    setState(() {
      _placeCount = next;
      if (_placeTeamIds.length < next) {
        _placeTeamIds = [
          ..._placeTeamIds,
          ...List<String?>.filled(next - _placeTeamIds.length, null),
        ];
        // Prefill empty slots from standings order when unused.
        final used = _placeTeamIds.whereType<String>().toSet();
        for (var i = 0; i < next; i++) {
          if (_placeTeamIds[i] != null) continue;
          for (final team in _teams) {
            if (!used.contains(team.id)) {
              _placeTeamIds[i] = team.id;
              used.add(team.id);
              break;
            }
          }
        }
      } else if (_placeTeamIds.length > next) {
        _placeTeamIds = _placeTeamIds.sublist(0, next);
      }
    });
  }

  TeamModel? _teamById(String? id) {
    if (id == null) return null;
    for (final team in _teams) {
      if (team.id == id) return team;
    }
    return null;
  }

  String _teamName(String? id) => _teamById(id)?.name ?? 'Unknown team';

  List<TeamModel> _eligibleForSlot(int slotIndex) {
    final taken = <String>{};
    for (var i = 0; i < _placeTeamIds.length; i++) {
      if (i == slotIndex) continue;
      final id = _placeTeamIds[i];
      if (id != null) taken.add(id);
    }
    return _teams.where((t) => !taken.contains(t.id)).toList();
  }

  bool get _canFinish {
    if (_saving || _teams.isEmpty) return false;
    if (_placeTeamIds.isEmpty || _placeTeamIds.first == null) return false;
    for (var i = 0; i < _placeCount; i++) {
      if (_placeTeamIds[i] == null) return false;
    }
    return true;
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
      child: SingleChildScrollView(
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
              _standingsByTeam.isNotEmpty
                  ? 'Teams are ordered by points table. Choose how many places to award, then confirm.'
                  : 'Choose how many places to award, then confirm and lock further edits.',
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
              Text(
                'Places to award',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var n = 1; n <= _maxPlaces; n++)
                    ChoiceChip(
                      label: Text(n == 1 ? '1 team' : '$n teams'),
                      selected: _placeCount == n,
                      onSelected: (_) => _setPlaceCount(n),
                    ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceMd),
              for (var i = 0; i < _placeCount; i++) ...[
                if (i > 0) const SizedBox(height: AppDimens.spaceMd),
                _TeamPodiumPicker(
                  label: TournamentPodiumPlace.labelFor(i + 1),
                  required: true,
                  value: _placeTeamIds[i],
                  teams: _eligibleForSlot(i),
                  standingsByTeam: _standingsByTeam,
                  onChanged: (v) => setState(() => _placeTeamIds[i] = v),
                ),
              ],
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
              onPressed: _canFinish ? _finish : null,
            ),
          ],
        ),
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

      final podium = <TournamentPodiumPlace>[];
      for (var i = 0; i < _placeCount; i++) {
        final id = _placeTeamIds[i];
        if (id == null) continue;
        podium.add(
          TournamentPodiumPlace(
            place: i + 1,
            teamId: id,
            teamName: _teamName(id),
          ),
        );
      }

      await widget.ref.read(tournamentRepositoryProvider).completeTournament(
            tournamentId: widget.tournament.id,
            podium: podium,
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
    required this.standingsByTeam,
    this.value,
    this.required = false,
  });

  final String label;
  final List<TeamModel> teams;
  final Map<String, PointsTableEntry> standingsByTeam;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final options = List<TeamModel>.from(teams);

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
          isExpanded: true,
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
            ...options.map(
              (team) => DropdownMenuItem<String?>(
                value: team.id,
                child: _TeamPickerRow(
                  team: team,
                  standing: standingsByTeam[team.id],
                ),
              ),
            ),
          ],
          // Selected row must not use Expanded/Flexible — dropdown width is unbounded.
          selectedItemBuilder: (_) {
            final widgets = <Widget>[
              if (!required)
                Text(
                  'Not set',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cf.textMuted),
                ),
              ...options.map((team) {
                final standing = standingsByTeam[team.id];
                final subtitle = standing == null
                    ? null
                    : '${standing.points} pts';
                return Text(
                  subtitle == null
                      ? team.name
                      : '${team.name} · $subtitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              }),
            ];
            return widgets;
          },
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TeamPickerRow extends StatelessWidget {
  const _TeamPickerRow({
    required this.team,
    this.standing,
  });

  final TeamModel team;
  final PointsTableEntry? standing;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final ptsLabel = standing == null
        ? null
        : '${standing!.points} pts · NRR ${standing!.netRunRate.toStringAsFixed(3)}';

    // Menu items are laid out with a finite width; Expanded is safe here.
    return Row(
      children: [
        MatchTeamAvatar(
          name: team.name,
          logoUrl: team.profileImageUrl,
          size: 32,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (ptsLabel != null)
                Text(
                  ptsLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textSecondary,
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
