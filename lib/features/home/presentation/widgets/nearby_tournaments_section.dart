import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/geo_distance.dart';
import '../../../../shared/widgets/tournament_list_card.dart';
import '../../domain/nearby_tournament_item.dart';
import '../../providers/nearby_matches_provider.dart';
import '../../providers/nearby_tournaments_provider.dart';
import 'matches_near_you_section.dart';

class NearbyTournamentsSection extends ConsumerWidget {
  const NearbyTournamentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nearbyTournamentsProvider);
    final cf = context.cf;

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppDimens.spaceMd),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (state) {
        switch (state.status) {
          case NearbyTournamentsStatus.loading:
            return const SizedBox.shrink();
          case NearbyTournamentsStatus.permissionDenied:
          case NearbyTournamentsStatus.serviceDisabled:
          case NearbyTournamentsStatus.empty:
          case NearbyTournamentsStatus.error:
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tournaments Near You',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Text(
                    state.message.isNotEmpty
                        ? state.message
                        : 'No tournaments near you right now.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cf.textSecondary,
                        ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/discover'),
                    child: const Text('Browse Discover'),
                  ),
                ],
              ),
            );
          case NearbyTournamentsStatus.ready:
            final cardWidth = nearbyCarouselCardWidth(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceMd,
                    AppDimens.spaceMd,
                    AppDimens.spaceXs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tournaments Near You',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (state.regionLabel.isNotEmpty ||
                                state.message.isNotEmpty)
                              Text(
                                state.message.isNotEmpty
                                    ? state.message
                                    : 'Within ~${kNearbyMatchRadiusKm.round()} km · ${state.regionLabel}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cf.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/discover'),
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceXs,
                    ),
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppDimens.spaceSm),
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      final distance = item.distanceKm != null
                          ? formatDistanceAway(item.distanceKm!)
                          : (item.regionFallback ? 'Near you' : null);
                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: cardWidth,
                          child: TournamentListCard(
                            tournament: item.tournament,
                            attributionLabel: distance,
                            margin: EdgeInsets.zero,
                            onTap: () => context.push(
                              '/tournaments/${item.tournament.id}',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
        }
      },
    );
  }
}
