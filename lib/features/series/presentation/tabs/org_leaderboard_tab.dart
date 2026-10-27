import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/series/series.dart';
import '../../../../domain/services/player_rankings/player_rankings_models.dart';
import '../../../../domain/services/player_rankings/player_rankings_service.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../domain/services/series/org_competition_lists.dart';
import '../../../../domain/services/series/org_standings.dart';
import '../../../../shared/providers/series_providers.dart';
import '../../../player_rankings/presentation/player_rankings_screen.dart'
    show PlayerRankingCard;
import '../../../tournaments/presentation/widgets/points/tournament_points_table_view.dart';
import '../widgets/series_ui.dart';
import 'org_list_ui.dart';

enum OrgLeaderboardView { table, players }

/// Org leaderboard: a points table built like a tournament's (P W L T NR Pts
/// NRR) and player rankings in the app's batting / bowling / fielding
/// categories, both computed from the org's official matches only.
class OrgLeaderboardTab extends ConsumerStatefulWidget {
  const OrgLeaderboardTab({
    super.key,
    required this.seriesId,
    required this.series,
  });

  final String seriesId;
  final SeriesModel series;

  @override
  ConsumerState<OrgLeaderboardTab> createState() => _OrgLeaderboardTabState();
}

class _OrgLeaderboardTabState extends ConsumerState<OrgLeaderboardTab> {
  OrgLeaderboardView _view = OrgLeaderboardView.table;
  String? _competition;
  PlayerRankingsSection _section = PlayerRankingsSection.batting;
  PlayerRankingsCategory _category = PlayerRankingsCategory.mostRuns;
  CricketBallType? _ball;

  String get _tableTitle => switch (OrgFamily.forKind(widget.series.kind)) {
        OrgFamily.clubs => 'Squad table',
        OrgFamily.associations => 'Member club table',
        OrgFamily.series => 'Points table',
      };

  @override
  Widget build(BuildContext context) {
    final seriesId = widget.seriesId;
    final tournaments = orgApprovedTournaments(
      ref.watch(seriesTournamentsProvider(seriesId)).valueOrNull ?? const [],
    );
    // A tournament that left the org must not leave a dead filter behind.
    final competition = _competition == null ||
            _competition == kOrgStandaloneFilter ||
            tournaments.any((t) => t.id == _competition)
        ? _competition
        : null;

    return ListView(
      key: const Key('org_leaderboard_list'),
      padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
      children: [
        OrgStatusChipsLike(
          children: [
            _viewChip('Points table', OrgLeaderboardView.table),
            const SizedBox(width: AppDimens.spaceXs),
            _viewChip('Player rankings', OrgLeaderboardView.players),
            const SizedBox(width: AppDimens.spaceXs),
            OrgCompetitionFilterChip(
              tournaments: tournaments,
              value: competition,
              allLabel: 'All competitions',
              onChanged: (v) => setState(() => _competition = v),
            ),
          ],
        ),
        if (_view == OrgLeaderboardView.table)
          _buildTable(competition, tournaments)
        else
          _buildPlayers(competition),
      ],
    );
  }

  Widget _viewChip(String label, OrgLeaderboardView view) {
    final cf = context.cf;
    final selected = _view == view;
    return ChoiceChip(
      key: Key('org_leaderboard_${view.name}'),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _view = view),
      selectedColor: cf.accent,
      backgroundColor: cf.sectionBackground,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? cf.onAccent : cf.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  // ---- Points table -------------------------------------------------------

  Widget _buildTable(
    String? competition,
    List<TournamentModel> tournaments,
  ) {
    final seriesId = widget.seriesId;
    final clubsAsync = ref.watch(clubsForSeriesProvider(seriesId));
    final matches = ref.watch(orgFinishedMatchesProvider(seriesId));
    return clubsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppDimens.spaceLg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Text('$e'),
      ),
      data: (clubs) {
        Set<String>? seed;
        if (competition != null && competition != kOrgStandaloneFilter) {
          for (final t in tournaments) {
            if (t.id == competition) seed = t.teamIds.toSet();
          }
        }
        final rows = buildOrgPointsTable(
          teams: clubs,
          matches: matches,
          rules: widget.series.settings.rankingRules,
          tournamentFilter: competition,
          seedTeamIds: seed,
        );
        if (rows.isEmpty) {
          return SeriesEmptyState(
            icon: Icons.leaderboard_outlined,
            title: 'No standings yet',
            message: 'The ${_tableTitle.toLowerCase()} fills in as official '
                'org matches finish.',
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppDimens.spaceSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TournamentPointsTableView(
                key: const Key('org_points_table'),
                title: _tableTitle,
                entries: rows,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                  AppDimens.spaceMd,
                  0,
                ),
                child: Text(
                  _pointsRulesLine(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.cf.textSecondary,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _pointsRulesLine() {
    final r = widget.series.settings.rankingRules;
    final parts = [
      'Win ${r.winPoints}',
      'Tie ${r.tiePoints}',
      'No result ${r.noResultPoints}',
      'Loss ${r.lossPoints}',
    ];
    return 'Points: ${parts.join(' · ')}'
        '${r.useNetRunRate ? ' · ties broken by NRR' : ''}. '
        'Counts approved, finished org matches between org teams.';
  }

  // ---- Player rankings ----------------------------------------------------

  List<CricketBallType> _ballTypesPresent(List<MatchModel> matches) {
    const service = PlayerRankingsService();
    return [
      for (final type in CricketBallType.values)
        if (matches.any(
          (m) => service.matchPassesRankingsFilters(
            m,
            PlayerRankingsFilter(ballType: type),
          ),
        ))
          type,
    ];
  }

  CricketBallType _defaultBall(List<MatchModel> matches) {
    const service = PlayerRankingsService();
    var best = CricketBallType.leather;
    var bestCount = -1;
    for (final type in CricketBallType.values) {
      final count = matches
          .where(
            (m) => service.matchPassesRankingsFilters(
              m,
              PlayerRankingsFilter(ballType: type),
            ),
          )
          .length;
      if (count > bestCount) {
        best = type;
        bestCount = count;
      }
    }
    return best;
  }

  Widget _buildPlayers(String? competition) {
    final cf = context.cf;
    final seriesId = widget.seriesId;
    final all = ref.watch(orgFinishedMatchesProvider(seriesId));
    final scoped = orgRankingMatches(all, tournamentFilter: competition);
    final present = _ballTypesPresent(scoped);
    final ball = (_ball != null && present.contains(_ball))
        ? _ball!
        : (present.isNotEmpty ? _defaultBall(scoped) : CricketBallType.leather);

    final filter = PlayerRankingsFilter(
      ballType: ball,
      section: _section,
      category: _category,
    );
    final rankings = ref.watch(
      orgPlayerRankingsProvider((
        seriesId: seriesId,
        filter: filter,
        tournamentFilter: competition,
      )),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (present.length > 1)
          OrgStatusChipsLike(
            children: [
              for (final type in present) ...[
                ChoiceChip(
                  key: Key('org_ball_${type.name}'),
                  label: Text(_ballLabel(type)),
                  selected: ball == type,
                  onSelected: (_) => setState(() => _ball = type),
                  selectedColor: cf.accent,
                  backgroundColor: cf.sectionBackground,
                  labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: ball == type ? cf.onAccent : cf.textSecondary,
                        fontWeight:
                            ball == type ? FontWeight.w700 : FontWeight.w500,
                      ),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceXs),
              ],
            ],
          ),
        OrgStatusChipsLike(
          children: [
            for (final section in PlayerRankingsSection.values) ...[
              FilterChip(
                key: Key('org_section_${section.name}'),
                label: Text(section.title),
                selected: _section == section,
                onSelected: (_) => setState(() {
                  _section = section;
                  _category = section.categories.first;
                }),
                selectedColor: cf.accent.withValues(alpha: 0.15),
                checkmarkColor: cf.accent,
              ),
              const SizedBox(width: AppDimens.spaceXs),
            ],
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceXs,
            AppDimens.spaceMd,
            AppDimens.spaceXs,
          ),
          child: DropdownButtonFormField<PlayerRankingsCategory>(
            key: ValueKey('org_${_section.name}_${_category.name}'),
            initialValue: _category,
            decoration: InputDecoration(
              labelText: 'Performance',
              filled: true,
              fillColor: cf.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cf.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cf.border),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
            ),
            items: [
              for (final c in _section.categories)
                DropdownMenuItem(value: c, child: Text(c.title)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            0,
            AppDimens.spaceMd,
            AppDimens.spaceSm,
          ),
          child: Text(
            '${_category.title} · ${_ballLabel(ball)} · org matches only',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cf.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        rankings.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppDimens.spaceLg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Text('Could not load rankings: $e'),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return SeriesEmptyState(
                icon: Icons.sports_cricket_outlined,
                title: 'No rankings yet',
                message: scoped.isEmpty
                    ? 'Player rankings appear after official org matches '
                        'finish.'
                    : 'No player has a ${_category.title.toLowerCase()} '
                        'entry yet. Try another category.',
              );
            }
            return Column(
              key: const Key('org_player_rankings'),
              children: [
                for (final entry in entries.take(100))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      0,
                      AppDimens.spaceMd,
                      AppDimens.spaceSm,
                    ),
                    child: PlayerRankingCard(entry: entry),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _ballLabel(CricketBallType type) => switch (type) {
        CricketBallType.leather => 'Leather',
        CricketBallType.tennis => 'Tennis',
        CricketBallType.indoor => 'Indoor',
      };
}
