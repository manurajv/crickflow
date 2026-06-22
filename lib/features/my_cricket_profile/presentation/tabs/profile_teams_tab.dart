import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/services/player_cricket_profile_models.dart';
import '../../../../domain/services/player_teams_profile_service.dart';

class ProfileTeamsTab extends StatefulWidget {
  const ProfileTeamsTab({super.key, required this.teams});

  final List<PlayerTeamProfile> teams;

  @override
  State<ProfileTeamsTab> createState() => _ProfileTeamsTabState();
}

class _ProfileTeamsTabState extends State<ProfileTeamsTab> {
  PlayerTeamSort _sort = PlayerTeamSort.recent;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final list = sortTeamProfiles(widget.teams, _sort);

    if (list.isEmpty) {
      return Center(
        child: Text(
          'No team history yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cf.textSecondary,
              ),
        ),
      );
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          child: Row(
            children: [
              _sortChip(cf, 'Recent', PlayerTeamSort.recent),
              _sortChip(cf, 'Most matches', PlayerTeamSort.mostMatches),
              _sortChip(cf, 'Best performance', PlayerTeamSort.bestPerformance),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: AppDimens.listPadding,
            itemCount: list.length,
            itemBuilder: (_, i) => _TeamCard(team: list[i]),
          ),
        ),
      ],
    );
  }

  Widget _sortChip(CfColors cf, String label, PlayerTeamSort sort) {
    final selected = _sort == sort;
    return Padding(
      padding: const EdgeInsets.only(right: AppDimens.spaceXs),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _sort = sort),
        selectedColor: cf.accent.withValues(alpha: 0.15),
        checkmarkColor: cf.accent,
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team});

  final PlayerTeamProfile team;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final since = team.since != null
        ? DateFormat('MMM yyyy').format(team.since!)
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      decoration: cfCardDecoration(context),
      child: InkWell(
        onTap: () => context.push('/teams/${team.teamId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cf.accent.withValues(alpha: 0.15),
                    backgroundImage: team.logoUrl != null
                        ? CachedNetworkImageProvider(team.logoUrl!)
                        : null,
                    child: team.logoUrl == null
                        ? Text(
                            team.teamName.isNotEmpty
                                ? team.teamName[0].toUpperCase()
                                : 'T',
                            style: TextStyle(
                              color: cf.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.teamName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        Text(
                          'Since $since · ${team.teamRole}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cf.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Wrap(
                spacing: AppDimens.spaceMd,
                runSpacing: AppDimens.spaceXs,
                children: [
                  _stat(context, '${team.matches}', 'Matches'),
                  _stat(context, '${team.wins}W/${team.losses}L', 'Record'),
                  _stat(
                    context,
                    '${team.winPct.toStringAsFixed(0)}%',
                    'Win %',
                  ),
                  _stat(context, '${team.runs}', 'Runs'),
                  _stat(context, '${team.wickets}', 'Wkts'),
                  _stat(context, team.strikeRate.toStringAsFixed(1), 'SR'),
                  if (team.captainMatches > 0)
                    _stat(context, '${team.captainMatches}', 'As C'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
