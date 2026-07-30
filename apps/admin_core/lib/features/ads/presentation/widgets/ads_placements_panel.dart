import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../models/ads_enums.dart';
import '../../models/managed_ads.dart';

class AdsPlacementsPanel extends StatelessWidget {
  const AdsPlacementsPanel({
    super.key,
    required this.campaigns,
    required this.isLoading,
  });

  final List<ManagedAdCampaign> campaigns;
  final bool isLoading;

  static String descriptionFor(ManagedAdPlacement placement) {
    return switch (placement) {
      ManagedAdPlacement.home =>
        'Promotional slots on the home feed and hero banners.',
      ManagedAdPlacement.communityFeed =>
        'Native ads between community posts and discussions.',
      ManagedAdPlacement.discoverFeed =>
        'Sponsored cards in the discover / explore feed.',
      ManagedAdPlacement.tournamentScreen =>
        'Banner or native units on tournament detail pages.',
      ManagedAdPlacement.matchHub =>
        'Ads shown around match hub navigation and tabs.',
      ManagedAdPlacement.matchScorecard =>
        'Scorecard overlays and inline units during live matches.',
      ManagedAdPlacement.playerProfile =>
        'Profile header or tab content sponsorship slots.',
      ManagedAdPlacement.teamProfile =>
        'Team profile pages and roster sections.',
      ManagedAdPlacement.groundProfile =>
        'Ground detail pages and booking funnels.',
      ManagedAdPlacement.liveMatchList =>
        'List placements on live and upcoming match listings.',
      ManagedAdPlacement.searchResults =>
        'Promoted results within global search.',
      ManagedAdPlacement.news =>
        'News and editorial content sections.',
    };
  }

  int _campaignCount(ManagedAdPlacement placement) {
    return campaigns
        .where((c) => c.placements.contains(placement))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.info.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: colors.info),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Custom ad placements below are managed in admin. Mobile AdMob placements remain unchanged until synced.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CfCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < ManagedAdPlacement.values.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.border),
                _PlacementRow(
                  placement: ManagedAdPlacement.values[i],
                  campaignCount: _campaignCount(ManagedAdPlacement.values[i]),
                  isLoading: isLoading,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PlacementRow extends StatelessWidget {
  const _PlacementRow({
    required this.placement,
    required this.campaignCount,
    required this.isLoading,
  });

  final ManagedAdPlacement placement;
  final int campaignCount;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return ListTile(
      leading: Icon(Icons.place_outlined, color: colors.info),
      title: Text(
        placement.label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(AdsPlacementsPanel.descriptionFor(placement)),
      trailing: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Chip(
              label: Text('$campaignCount campaign${campaignCount == 1 ? '' : 's'}'),
              visualDensity: VisualDensity.compact,
            ),
    );
  }
}
