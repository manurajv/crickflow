import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../core/utils/cf_team_id_format.dart';
import '../../../../../data/models/location_model.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../../../shared/providers/team_players_provider.dart';
import '../../../../../shared/providers/team_profile_provider.dart';
import '../../../../../shared/widgets/venue_location_sheet.dart';
import '../../utils/team_location_parts.dart';
import '../widgets/team_profile_empty_state.dart';

class TeamInfoTab extends ConsumerStatefulWidget {
  const TeamInfoTab({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamInfoTab> createState() => _TeamInfoTabState();
}

class _TeamInfoTabState extends ConsumerState<TeamInfoTab> {
  bool _aboutExpanded = false;

  @override
  Widget build(BuildContext context) {
    final snapAsync = ref.watch(teamProfileSnapshotProvider(widget.teamId));

    return snapAsync.when(
      loading: () => const TeamProfileSkeleton(),
      error: (e, _) => TeamProfileEmptyState(
        icon: Icons.error_outline,
        title: 'Unable to load profile',
        subtitle: '$e',
      ),
      data: (snap) {
        final team = snap.team;
        final captain = snap.captain == null
            ? '—'
            : (snap.captain!.fullName.trim().isNotEmpty
                ? snap.captain!.fullName
                : snap.captain!.name);
        final parts = TeamLocationParts.fromStored(team.location);
        final locationLabel = _labelOrDash(parts.teamLocation.displayLabel);
        final homeGroundLabel = parts.homeGround.placeName.trim().isEmpty
            ? '—'
            : _labelOrDash(parts.homeGround.displayLabel);
        final about = _aboutText(team.name, locationLabel);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(teamByIdProvider(widget.teamId));
            ref.invalidate(teamPlayersProvider(widget.teamId));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppDimens.listPadding,
            children: [
              _SectionCard(
                title: 'About Team',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      about,
                      maxLines: _aboutExpanded ? null : 3,
                      overflow: _aboutExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _aboutExpanded = !_aboutExpanded),
                      child: Text(_aboutExpanded ? 'Show less' : 'Read more'),
                    ),
                  ],
                ),
              ),
              _SectionCard(
                title: 'Team details',
                child: Column(
                  children: [
                    _row(context, 'Team ID', CfTeamIdFormat.displayLabel(team.teamCode)),
                    _locationRow(
                      context,
                      label: 'Home Ground',
                      value: homeGroundLabel,
                      location: homeGroundLabel == '—'
                          ? null
                          : parts.homeGround,
                    ),
                    _row(context, 'Location', locationLabel),
                    _row(context, 'Captain', captain),
                    _row(
                      context,
                      'Coach',
                      (team.coachName?.trim().isNotEmpty ?? false)
                          ? team.coachName!.trim()
                          : '—',
                    ),
                    _row(
                      context,
                      'Manager / Contact',
                      (team.contactNumber?.trim().isNotEmpty ?? false)
                          ? team.contactNumber!.trim()
                          : '—',
                    ),
                    _row(
                      context,
                      'Established',
                      team.createdAt == null ? '—' : '${team.createdAt!.year}',
                    ),
                    _row(
                      context,
                      'Members',
                      '${team.memberCount > 0 ? team.memberCount : snap.players.length}',
                    ),
                  ],
                ),
              ),
              _SectionCard(
                title: 'Preferred formats',
                child: Text(
                  'T20 · One Day · Friendly',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.cf.textSecondary,
                      ),
                ),
              ),
              _SectionCard(
                title: 'Achievements',
                child: Text(
                  snap.stats.tournamentWins > 0
                      ? '${snap.stats.tournamentWins} tournament win${snap.stats.tournamentWins == 1 ? '' : 's'} recorded from match results.'
                      : 'No tournament titles recorded yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              _SectionCard(
                title: 'Social & contact',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share the team invite from the header to grow the following.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.cf.textSecondary,
                          ),
                    ),
                    if (team.contactNumber != null &&
                        team.contactNumber!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppDimens.spaceSm),
                      Text(
                        'Contact: ${team.contactNumber}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _labelOrDash(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty || trimmed == '—' ? '—' : trimmed;
  }

  String _aboutText(String name, String location) {
    final loc = location.isEmpty || location == '—' ? 'their region' : location;
    return '$name is a CrickFlow cricket team based in $loc. '
        'Follow the squad for match updates, leaderboards, and member highlights. '
        'Team information is managed by the owner and captains.';
  }

  Widget _locationRow(
    BuildContext context, {
    required String label,
    required String value,
    LocationModel? location,
  }) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: location == null
                ? Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  )
                : TappableVenueLocation(
                    label: value,
                    location: location,
                    maxLines: 3,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: cfCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          child,
        ],
      ),
    );
  }
}
