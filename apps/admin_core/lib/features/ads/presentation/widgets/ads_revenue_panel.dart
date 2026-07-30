import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_stat_tile.dart';
import '../../models/managed_ads.dart';

class AdsRevenuePanel extends StatelessWidget {
  const AdsRevenuePanel({
    super.key,
    required this.summary,
    required this.campaigns,
    required this.isLoading,
  });

  final AdsSummaryStats summary;
  final List<ManagedAdCampaign> campaigns;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final revenueFmt = NumberFormat.compactCurrency(symbol: '\$');
    final compact = NumberFormat.compact();

    final avgCtr = _averageCtr(campaigns);
    final topCampaigns = [...campaigns]
      ..sort((a, b) => b.estimatedRevenue.compareTo(a.estimatedRevenue));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.analytics_outlined, size: 18, color: colors.warning),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Placeholder analytics — connect AdMob / campaign reporting for live revenue data.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cols = width >= 900 ? 4 : width >= 600 ? 2 : 1;
            const spacing = 12.0;
            final itemWidth = (width - spacing * (cols - 1)) / cols;
            final cards = [
              CfStatTile(
                icon: Icons.visibility_outlined,
                title: 'Impressions',
                value: compact.format(summary.totalImpressions),
                accentColor: colors.info,
                compact: true,
              ),
              CfStatTile(
                icon: Icons.ads_click_outlined,
                title: 'Avg CTR',
                value: '${(avgCtr * 100).toStringAsFixed(2)}%',
                accentColor: AdminColors.primaryBlue,
                compact: true,
              ),
              CfStatTile(
                icon: Icons.payments_outlined,
                title: 'Est. Revenue',
                value: revenueFmt.format(summary.estimatedRevenue),
                accentColor: colors.success,
                compact: true,
              ),
              CfStatTile(
                icon: Icons.campaign_outlined,
                title: 'Campaigns tracked',
                value: '${campaigns.length}',
                accentColor: const Color(0xFF7E57C2),
                compact: true,
              ),
            ];
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final c in cards) SizedBox(width: itemWidth, child: c),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Top campaigns by revenue',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        CfCard(
          padding: EdgeInsets.zero,
          child: isLoading && topCampaigns.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : topCampaigns.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No campaign data available yet.'),
                    )
                  : Builder(
                      builder: (context) {
                        final top = topCampaigns.take(10).toList();
                        return Column(
                          children: [
                            for (var i = 0; i < top.length; i++) ...[
                              if (i > 0)
                                Divider(height: 1, color: colors.border),
                              ListTile(
                                leading: CircleAvatar(
                                  child: Text('${i + 1}'),
                                ),
                                title: Text(
                                  top[i].displayTitle,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  '${compact.format(top[i].impressions)} impressions · ${(top[i].ctr * 100).toStringAsFixed(2)}% CTR',
                                ),
                                trailing: Text(
                                  revenueFmt.format(top[i].estimatedRevenue),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
        ),
      ],
    );
  }

  double _averageCtr(List<ManagedAdCampaign> campaigns) {
    if (campaigns.isEmpty) return 0;
    var totalCtr = 0.0;
    var counted = 0;
    for (final c in campaigns) {
      if (c.impressions > 0) {
        totalCtr += c.ctr;
        counted++;
      }
    }
    return counted == 0 ? 0 : totalCtr / counted;
  }
}
