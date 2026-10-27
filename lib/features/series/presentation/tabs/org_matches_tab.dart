import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_model.dart';
import '../../../../domain/services/series/org_competition_access.dart';
import '../../../../domain/services/series/org_competition_lists.dart';
import '../../../../domain/services/series/org_standings.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/series_providers.dart';
import '../../../../shared/widgets/match_list_card.dart';
import '../widgets/series_ui.dart';
import 'org_list_ui.dart';

/// Org Matches tab: every official match of the org (including matches of its
/// tournaments) as the same cards My Cricket uses, grouped Live / Upcoming /
/// Completed with status + tournament filters.
class OrgMatchesTab extends ConsumerStatefulWidget {
  const OrgMatchesTab({super.key, required this.seriesId});
  final String seriesId;

  @override
  ConsumerState<OrgMatchesTab> createState() => _OrgMatchesTabState();
}

class _OrgMatchesTabState extends ConsumerState<OrgMatchesTab> {
  OrgStatusFilter _status = OrgStatusFilter.all;
  String? _tournament;

  @override
  Widget build(BuildContext context) {
    final seriesId = widget.seriesId;
    final access = ref.watch(orgCompetitionAccessProvider(seriesId));
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final matchesAsync = ref.watch(seriesMatchesProvider(seriesId));
    final tournaments = orgApprovedTournaments(
      ref.watch(seriesTournamentsProvider(seriesId)).valueOrNull ?? const [],
    );

    return matchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (all) {
        final visible = visibleOrgMatches(
          all,
          isAdmin: access.isAdmin,
          uid: uid,
        );
        final scoped = visible
            .where((m) => matchPassesTournamentFilter(m, _tournament))
            .toList();
        final counts = orgBucketCounts<MatchModel>(scoped, orgMatchBucket);
        final sections = groupOrgMatches(
          visible,
          status: _status,
          tournamentFilter: _tournament,
        );

        return ListView(
          key: const Key('org_matches_list'),
          padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
          children: [
            if (access.match != OrgStartMode.none)
              OrgStartButton(
                buttonKey: const Key('org_start_match'),
                label: OrgCompetitionAccess.actionLabel(
                  access.match,
                  tournament: false,
                ),
                icon: Icons.sports_cricket_outlined,
                onPressed: () =>
                    context.push('/series/$seriesId/propose-match'),
              ),
            OrgStatusChips(
              selected: _status,
              counts: counts,
              onChanged: (f) => setState(() => _status = f),
              trailing: tournaments.isEmpty
                  ? null
                  : OrgCompetitionFilterChip(
                      tournaments: tournaments,
                      value: _tournament,
                      onChanged: (v) => setState(() => _tournament = v),
                    ),
            ),
            if (sections.isEmpty)
              _empty(context, hasAny: visible.isNotEmpty, access: access)
            else
              for (final section in sections) ...[
                OrgSectionHeader(
                  bucket: section.bucket,
                  title: section.title,
                  count: section.items.length,
                ),
                for (final m in section.items)
                  MatchListCard(
                    key: ValueKey('org_match_${m.id}'),
                    match: m,
                  ),
              ],
          ],
        );
      },
    );
  }

  Widget _empty(
    BuildContext context, {
    required bool hasAny,
    required OrgCompetitionAccess access,
  }) {
    if (hasAny) {
      return const SeriesEmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'No matches in this filter',
        message: 'Try another status or tournament.',
      );
    }
    return SeriesEmptyState(
      icon: Icons.sports_cricket_outlined,
      title: 'No matches yet',
      message: access.match == OrgStartMode.none
          ? 'Official org matches will appear here.'
          : access.isAdmin
              ? 'Start a match between two org teams.'
              : 'Request a match for your team. Org admins approve it.',
    );
  }
}
