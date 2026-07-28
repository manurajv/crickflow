import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/location_model.dart';
import '../../../../features/my_cricket/my_cricket_filters.dart';
import '../../../../shared/providers/my_cricket_ui_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/match_list_card.dart';
import '../../domain/nearby_match_item.dart';
import '../../providers/nearby_anchor_location_provider.dart';
import '../../providers/nearby_matches_provider.dart';
import '../../providers/nearby_tournaments_provider.dart';
import 'nearby_location_filter_sheet.dart';

/// Optional subtitle under nearby section headers (kept empty by design).
String nearbyLocationSubtitle({
  required String regionLabel,
  String message = '',
}) =>
    '';

/// Horizontal carousel height for match / tournament cards on Home.
const double kNearbyCarouselHeight = 220;

/// Card width so the next item peeks (~78% of screen).
double nearbyCarouselCardWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return (w * 0.78).clamp(260.0, 340.0);
}

void openMyCricketMatchesAll(WidgetRef ref, BuildContext context) {
  ref.read(myCricketMatchesInitialScopeProvider.notifier).state =
      MyCricketListScope.all;
  ref.read(myCricketInitialTabProvider.notifier).state = 0;
  context.go('/matches');
}

void openMyCricketTournamentsAll(WidgetRef ref, BuildContext context) {
  ref.read(myCricketTournamentsInitialScopeProvider.notifier).state =
      MyCricketListScope.all;
  ref.read(myCricketInitialTabProvider.notifier).state = 1;
  context.go('/matches?tab=1');
}

var _nearbyLocationFilterOpen = false;

Future<void> openNearbyLocationFilter(WidgetRef ref, BuildContext context) async {
  if (_nearbyLocationFilterOpen) return;
  _nearbyLocationFilterOpen = true;
  try {
    final service = ref.read(googleMapsLocationServiceProvider);
    final current = ref.read(nearbyAnchorLocationProvider);
    LocationModel initial = current ?? const LocationModel();

    if (initial.isEmpty) {
      try {
        final coords = await service.getCurrentCoords();
        if (coords != null) {
          final place = await service.reverseGeocode(coords);
          initial = place.location;
        }
      } catch (_) {}
    }

    if (!context.mounted) return;
    final result = await showNearbyLocationFilterSheet(
      context,
      initial: initial,
      locationService: service,
      onUseCurrentLocation: () async {
        final coords = await service.getCurrentCoords();
        if (coords == null) return null;
        final place = await service.reverseGeocode(coords);
        return place.location;
      },
    );
    if (result == null || !context.mounted) return;

    // Empty result from Reset → back to device GPS.
    ref.read(nearbyAnchorLocationProvider.notifier).state =
        result.isEmpty ? null : result;
    ref.invalidate(nearbyMatchesProvider);
    ref.invalidate(nearbyTournamentsProvider);
  } finally {
    _nearbyLocationFilterOpen = false;
  }
}

/// Horizontally scrollable nearby matches using [MatchListCard].
class MatchesNearYouSection extends ConsumerWidget {
  const MatchesNearYouSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nearbyMatchesProvider);
    final anchor = ref.watch(nearbyAnchorLocationProvider);
    final title = nearbyMatchesSectionTitle(anchor);

    return async.when(
      loading: () => NearbySectionSkeleton(
        title: title,
        onFilterLocation: () => openNearbyLocationFilter(ref, context),
        locationFiltered: anchor != null,
      ),
      error: (e, _) => NearbySectionMessage(
        title: title,
        message: 'Unable to load nearby matches.',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(nearbyMatchesProvider),
        onFilterLocation: () => openNearbyLocationFilter(ref, context),
        locationFiltered: anchor != null,
      ),
      data: (state) {
        switch (state.status) {
          case NearbyMatchesStatus.loading:
            return NearbySectionSkeleton(
              title: title,
              onFilterLocation: () => openNearbyLocationFilter(ref, context),
              locationFiltered: anchor != null,
            );
          case NearbyMatchesStatus.permissionDenied:
          case NearbyMatchesStatus.serviceDisabled:
            return NearbySectionMessage(
              title: title,
              message: state.message,
              actionLabel: 'Browse All Matches',
              onAction: () => openMyCricketMatchesAll(ref, context),
              onFilterLocation: () => openNearbyLocationFilter(ref, context),
              locationFiltered: anchor != null,
            );
          case NearbyMatchesStatus.empty:
            return NearbySectionMessage(
              title: title,
              message: state.message.isNotEmpty
                  ? state.message
                  : 'No matches are currently scheduled near you.',
              actionLabel: 'Browse All Matches',
              onAction: () => openMyCricketMatchesAll(ref, context),
              onFilterLocation: () => openNearbyLocationFilter(ref, context),
              locationFiltered: anchor != null,
            );
          case NearbyMatchesStatus.error:
            return NearbySectionMessage(
              title: title,
              message: state.message,
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(nearbyMatchesProvider),
              onFilterLocation: () => openNearbyLocationFilter(ref, context),
              locationFiltered: anchor != null,
            );
          case NearbyMatchesStatus.ready:
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
                          child: MatchListCard(
                            match: item.match,
                            attributionLabel: item.attributionLabel,
                            margin: EdgeInsets.zero,
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

class NearbySectionHeader extends StatelessWidget {
  const NearbySectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.onFilterLocation,
    this.locationFiltered = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onFilterLocation;
  final bool locationFiltered;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        2,
        AppDimens.spaceSm,
        AppDimens.spaceXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Change location',
                onPressed: onFilterLocation,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                icon: Icon(
                  Icons.location_on_outlined,
                  color: locationFiltered ? cf.accent : cf.textSecondary,
                ),
              ),
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textSecondary,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class NearbySectionSkeleton extends StatelessWidget {
  const NearbySectionSkeleton({
    super.key,
    required this.title,
    this.onFilterLocation,
    this.locationFiltered = false,
  });

  final String title;
  final VoidCallback? onFilterLocation;
  final bool locationFiltered;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final cardWidth = nearbyCarouselCardWidth(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onFilterLocation != null)
          NearbySectionHeader(
            title: title,
            onFilterLocation: onFilterLocation!,
            locationFiltered: locationFiltered,
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              2,
              AppDimens.spaceMd,
              AppDimens.spaceXs,
            ),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        SizedBox(
          height: kNearbyCarouselHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            itemCount: 3,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppDimens.spaceSm),
            itemBuilder: (_, _) => Container(
              width: cardWidth,
              decoration: BoxDecoration(
                color: cf.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cf.border),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NearbySectionMessage extends StatelessWidget {
  const NearbySectionMessage({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onFilterLocation,
    this.locationFiltered = false,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onFilterLocation;
  final bool locationFiltered;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onFilterLocation != null)
          NearbySectionHeader(
            title: title,
            onFilterLocation: onFilterLocation!,
            locationFiltered: locationFiltered,
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              2,
              AppDimens.spaceMd,
              AppDimens.spaceXs,
            ),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            0,
            AppDimens.spaceMd,
            AppDimens.spaceSm,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: BoxDecoration(
              color: cf.surface,
              borderRadius: AppDimens.cardRadius,
              border: Border.all(color: cf.border),
            ),
            child: Column(
              children: [
                Icon(Icons.place_outlined, color: cf.textMuted, size: 32),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cf.textSecondary,
                      ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
