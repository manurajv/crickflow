import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_model.dart';
import '../../../../domain/services/match_insights_service.dart';
import '../../../../shared/providers/match_insights_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_filter.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_navigation.dart';
import '../../../wagon_wheel/presentation/widgets/wagon_wheel_embedded_section.dart';

class MatchInsightsTab extends ConsumerWidget {
  const MatchInsightsTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(matchInsightsProvider(matchId));
    final match = ref.watch(matchProvider(matchId)).valueOrNull;
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final wwEnabled = match?.rules.wagonWheelEnabled ?? false;

    return ListView(
      padding: AppDimens.listPadding,
      children: [
        if (insights.isLive)
          const _LiveChip(),
        if (insights.resultLine != null) ...[
          Text(
            insights.resultLine!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.gold,
                ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
        if (profile != null && match != null)
          _ContributionCard(
            name: profile.displayName,
            match: match,
          ),
        if (insights.hero != null) ...[
          Text('Match hero', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimens.spaceSm),
          _HeroCard(hero: insights.hero!),
          const SizedBox(height: AppDimens.spaceLg),
        ],
        if (insights.topBatters.isNotEmpty) ...[
          Text('Top batters', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimens.spaceSm),
          ...insights.topBatters.map(
            (p) => _PerformerTile(
              performer: p,
              icon: Icons.sports_cricket,
              onTap: () => context.push(
                WagonWheelNavigation.path(
                  filter: WagonWheelFilter(
                    matchId: matchId,
                    batterId: p.playerId,
                  ),
                  title: '${p.playerName} — wagon wheel',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
        if (insights.topBowlers.isNotEmpty) ...[
          Text('Top bowlers', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimens.spaceSm),
          ...insights.topBowlers.map(
            (p) => _PerformerTile(
              performer: p,
              icon: Icons.sports_baseball,
              onTap: () => context.push(
                WagonWheelNavigation.path(
                  filter: WagonWheelFilter(
                    matchId: matchId,
                    bowlerId: p.playerId,
                  ),
                  title: '${p.playerName} — conceded',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
        if (wwEnabled) ...[
          WagonWheelEmbeddedSection(
            title: 'Wagon wheel',
            fullViewTitle: 'Match wagon wheel',
            baseFilter: WagonWheelFilter(matchId: matchId),
            height: 220,
          ),
          const SizedBox(height: AppDimens.spaceLg),
        ],
        if (insights.milestones.isNotEmpty) ...[
          Text('Milestones', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimens.spaceSm),
          Wrap(
            spacing: AppDimens.spaceSm,
            runSpacing: AppDimens.spaceSm,
            children: insights.milestones
                .map(
                  (m) => Chip(
                    label: Text(m),
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                  ),
                )
                .toList(),
          ),
        ],
        if (insights.topBatters.isEmpty &&
            insights.topBowlers.isEmpty &&
            insights.hero == null)
          Center(
            child: Padding(
              padding: AppDimens.listPadding,
              child: Text(
                'Insights appear once scoring starts.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.liveIndicator,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'LIVE',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Text('Updating with each ball', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ContributionCard extends StatelessWidget {
  const _ContributionCard({required this.name, required this.match});

  final String name;
  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: Padding(
        padding: AppDimens.cardPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryBlue,
              child: Icon(Icons.insights, color: Colors.white, size: 20),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Performance insight',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    match.status == MatchStatus.completed
                        ? '$name — thanks for being part of this match.'
                        : '$name — follow live momentum in Comms and Highlights.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.hero});

  final MatchHeroModel hero;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A2744), AppColors.card],
          ),
        ),
        padding: AppDimens.cardPadding,
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.gold,
              child: Icon(Icons.star, color: Colors.black, size: 28),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hero.playerName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    hero.reason,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformerTile extends StatelessWidget {
  const _PerformerTile({
    required this.performer,
    required this.icon,
    this.onTap,
  });

  final PerformerInsight performer;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceXs),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.surfaceElevated,
          child: Icon(icon, size: 18, color: AppColors.primaryBlueLight),
        ),
        title: Text(
          performer.playerName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          performer.teamName.isNotEmpty
              ? '${performer.teamName} · ${performer.statLine}'
              : performer.statLine,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          performer.impactScore.toStringAsFixed(0),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.gold,
              ),
        ),
      ),
    );
  }
}
