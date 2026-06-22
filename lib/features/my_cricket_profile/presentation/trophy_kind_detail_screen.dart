import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../domain/services/player_cricket_profile_models.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';

class TrophyKindDetailScreen extends StatelessWidget {
  const TrophyKindDetailScreen({
    super.key,
    required this.kind,
    required this.trophies,
  });

  final PlayerTrophyKind kind;
  final List<PlayerTrophy> trophies;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    const tierColor = Color(0xFFD4AF37);
    final sorted = trophies.toList()..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: CfChromeAppBar(title: Text(kind.label)),
      body: sorted.isEmpty
          ? Center(
              child: Padding(
                padding: AppDimens.listPadding,
                child: Text(
                  'No ${kind.label} awards yet.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cf.textSecondary,
                      ),
                ),
              ),
            )
          : ListView(
              padding: AppDimens.listPadding,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        kind.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kind.label,
                            style:
                                Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                          Text(
                            '${sorted.length} ${sorted.length == 1 ? 'award' : 'awards'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: cf.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceLg),
                ...sorted.map((trophy) => _TrophyEntryCard(trophy: trophy)),
              ],
            ),
    );
  }
}

class _TrophyEntryCard extends StatelessWidget {
  const _TrophyEntryCard({required this.trophy});

  final PlayerTrophy trophy;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    const tierColor = Color(0xFFD4AF37);
    final dateStr = DateFormat('d MMM yyyy').format(trophy.date);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      decoration: cfCardDecoration(context).copyWith(
        border: Border.all(color: tierColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateStr,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
            if (trophy.matchTitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                trophy.matchTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            if (trophy.performance.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                trophy.performance,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cf.accent,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            if (trophy.teamName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                trophy.teamName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (trophy.category == TrophyCategory.tournament) ...[
              const SizedBox(height: 4),
              Text(
                'Tournament',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cf.accent,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
