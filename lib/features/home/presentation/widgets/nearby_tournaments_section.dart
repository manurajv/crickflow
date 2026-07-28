import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/tournament_list_card.dart';
import '../../domain/nearby_tournament_item.dart';
import '../../providers/nearby_anchor_location_provider.dart';
import '../../providers/nearby_tournaments_provider.dart';
import 'matches_near_you_section.dart';

class NearbyTournamentsSection extends ConsumerWidget {
  const NearbyTournamentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nearbyTournamentsProvider);
    final anchor = ref.watch(nearbyAnchorLocationProvider);
    final title = nearbyTournamentsSectionTitle(anchor);

    return async.when(
      loading: () => NearbySectionSkeleton(
        title: title,
        onFilterLocation: () => openNearbyLocationFilter(ref, context),
        locationFiltered: anchor != null,
      ),
      error: (_, _) => NearbySectionMessage(
        title: title,
        message: 'Unable to load nearby tournaments.',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(nearbyTournamentsProvider),
        onFilterLocation: () => openNearbyLocationFilter(ref, context),
        locationFiltered: anchor != null,
      ),
      data: (state) {
        switch (state.status) {
          case NearbyTournamentsStatus.loading:
            return NearbySectionSkeleton(
              title: title,
              onFilterLocation: () => openNearbyLocationFilter(ref, context),
              locationFiltered: anchor != null,
            );
          case NearbyTournamentsStatus.permissionDenied:
          case NearbyTournamentsStatus.serviceDisabled:
            return NearbySectionMessage(
              title: title,
              message: state.message,
              actionLabel: 'Browse All Tournaments',
              onAction: () => openMyCricketTournamentsAll(ref, context),
              onFilterLocation: () => openNearbyLocationFilter(ref, context),
              locationFiltered: anchor != null,
            );
          case NearbyTournamentsStatus.empty:
            return NearbySectionMessage(
              title: title,
              message: state.message.isNotEmpty
                  ? state.message
                  : 'No tournaments near you right now.',
              actionLabel: 'Browse All Tournaments',
              onAction: () => openMyCricketTournamentsAll(ref, context),
              onFilterLocation: () => openNearbyLocationFilter(ref, context),
              locationFiltered: anchor != null,
            );
          case NearbyTournamentsStatus.error:
            return NearbySectionMessage(
              title: title,
              message: state.message,
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(nearbyTournamentsProvider),
              onFilterLocation: () => openNearbyLocationFilter(ref, context),
              locationFiltered: anchor != null,
            );
          case NearbyTournamentsStatus.ready:
            final cardWidth = nearbyCarouselCardWidth(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NearbySectionHeader(
                  title: title,
                  subtitle: nearbyLocationSubtitle(
                    regionLabel: state.regionLabel,
                    message: state.message,
                  ),
                  onFilterLocation: () => openNearbyLocationFilter(ref, context),
                  locationFiltered: anchor != null,
                ),
                SizedBox(
                  height: kNearbyCarouselHeight,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(
                      left: AppDimens.spaceMd,
                      right: AppDimens.spaceMd,
                      bottom: 2,
                    ),
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppDimens.spaceSm),
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: cardWidth,
                          child: TournamentListCard(
                            tournament: item.tournament,
                            attributionLabel: item.attributionLabel,
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
