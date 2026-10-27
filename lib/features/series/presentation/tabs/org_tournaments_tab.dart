import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../domain/services/series/org_competition_access.dart';
import '../../../../domain/services/series/org_competition_lists.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/series_providers.dart';
import '../../../../shared/widgets/tournament_list_card.dart';
import '../widgets/series_ui.dart';
import 'org_list_ui.dart';

/// Org Tournaments tab: the org's tournaments as the same cards My Cricket
/// uses, grouped Live / Upcoming / Completed with a status filter.
class OrgTournamentsTab extends ConsumerStatefulWidget {
  const OrgTournamentsTab({super.key, required this.seriesId});
  final String seriesId;

  @override
  ConsumerState<OrgTournamentsTab> createState() => _OrgTournamentsTabState();
}

class _OrgTournamentsTabState extends ConsumerState<OrgTournamentsTab> {
  OrgStatusFilter _status = OrgStatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final seriesId = widget.seriesId;
    final access = ref.watch(orgCompetitionAccessProvider(seriesId));
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final async = ref.watch(seriesTournamentsProvider(seriesId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (all) {
        final visible = visibleOrgTournaments(
          all,
          isAdmin: access.isAdmin,
          uid: uid,
        );
        final counts = orgBucketCounts<TournamentModel>(
          visible,
          orgTournamentBucket,
        );
        final sections = groupOrgTournaments(visible, status: _status);

        return ListView(
          key: const Key('org_tournaments_list'),
          padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
          children: [
            if (access.tournament != OrgStartMode.none)
              OrgStartButton(
                buttonKey: const Key('org_start_tournament'),
                label: OrgCompetitionAccess.actionLabel(
                  access.tournament,
                  tournament: true,
                ),
                icon: Icons.emoji_events_outlined,
                onPressed: () =>
                    context.push('/series/$seriesId/propose-tournament'),
              ),
            OrgStatusChips(
              selected: _status,
              counts: counts,
              onChanged: (f) => setState(() => _status = f),
            ),
            if (sections.isEmpty)
              _empty(hasAny: visible.isNotEmpty, access: access)
            else
              for (final section in sections) ...[
                OrgSectionHeader(
                  bucket: section.bucket,
                  title: section.title,
                  count: section.items.length,
                ),
                for (final t in section.items)
                  TournamentListCard(
                    key: ValueKey('org_tournament_${t.id}'),
                    tournament: t,
                    onTap: () => context.push('/tournaments/${t.id}'),
                  ),
              ],
          ],
        );
      },
    );
  }

  Widget _empty({
    required bool hasAny,
    required OrgCompetitionAccess access,
  }) {
    if (hasAny) {
      return const SeriesEmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'No tournaments in this filter',
        message: 'Try another status.',
      );
    }
    return SeriesEmptyState(
      icon: Icons.emoji_events_outlined,
      title: 'No tournaments yet',
      message: access.tournament == OrgStartMode.none
          ? 'Official org tournaments will appear here.'
          : access.isAdmin
              ? 'Start a tournament for this org.'
              : 'Request a tournament for your team. Org admins approve it.',
    );
  }
}
