import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../domain/scoring/match_lifecycle.dart';
import '../../../../shared/providers/match_upcoming_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../widgets/upcoming/upcoming_match_sections.dart';

/// Pre-match hub — preview, head-to-head, info, milestones, and actions.
class UpcomingMatchInfoTab extends ConsumerWidget {
  const UpcomingMatchInfoTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(matchProvider(matchId)).valueOrNull;
    final upcomingAsync = ref.watch(matchUpcomingProvider(matchId));

    if (match != null && !MatchLifecycle.isUpcoming(match)) {
      return const Center(child: Text('Match has started'));
    }

    return upcomingAsync.when(
      data: (snapshot) {
        return ListView(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
          children: [
            UpcomingPreviewCard(preview: snapshot.preview),
            UpcomingInsightsBanner(matchId: matchId),
            UpcomingHeadToHeadSection(
              matchId: matchId,
              snapshot: snapshot.headToHead,
              teamAName: snapshot.preview.teamAName,
              teamBName: snapshot.preview.teamBName,
              teamALogoUrl: snapshot.preview.teamALogoUrl,
              teamBLogoUrl: snapshot.preview.teamBLogoUrl,
            ),
            UpcomingInfoSection(rows: snapshot.infoRows),
            UpcomingOfficialsSection(officials: snapshot.officials),
            UpcomingMilestonesSection(milestones: snapshot.milestones),
            UpcomingBannersSection(banners: snapshot.banners),
            if (match != null) UpcomingQuickActions(match: match),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}
