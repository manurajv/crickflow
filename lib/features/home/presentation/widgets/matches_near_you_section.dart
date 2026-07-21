import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../shared/widgets/match_list_card.dart';
import '../../domain/nearby_match_item.dart';
import '../../providers/nearby_matches_provider.dart';

/// Card width so the next item peeks (~78% of screen).
double nearbyCarouselCardWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return (w * 0.78).clamp(260.0, 340.0);
}

/// Horizontally scrollable nearby matches using [MatchListCard].
class MatchesNearYouSection extends ConsumerWidget {
  const MatchesNearYouSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(nearbyMatchesProvider);
    final cf = context.cf;

    return async.when(
      loading: () => const _NearbySkeleton(title: 'Matches Near You'),
      error: (e, _) => _NearbyMessage(
        title: 'Matches Near You',
        message: 'Unable to load nearby matches.',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(nearbyMatchesProvider),
      ),
      data: (state) {
        switch (state.status) {
          case NearbyMatchesStatus.loading:
            return const _NearbySkeleton(title: 'Matches Near You');
          case NearbyMatchesStatus.permissionDenied:
          case NearbyMatchesStatus.serviceDisabled:
            return _NearbyMessage(
              title: 'Matches Near You',
              message: state.message,
              actionLabel: 'Browse All Matches',
              onAction: () => context.go('/matches'),
            );
          case NearbyMatchesStatus.empty:
            return _NearbyMessage(
              title: 'Matches Near You',
              message: state.message.isNotEmpty
                  ? state.message
                  : 'No matches are currently scheduled near you.',
              actionLabel: 'Browse All Matches',
              onAction: () => context.go('/matches'),
            );
          case NearbyMatchesStatus.error:
            return _NearbyMessage(
              title: 'Matches Near You',
              message: state.message,
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(nearbyMatchesProvider),
            );
          case NearbyMatchesStatus.ready:
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
                              'Matches Near You',
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/matches'),
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 190,
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
                            margin: EdgeInsets.zero,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXs),
              ],
            );
        }
      },
    );
  }
}

class _NearbySkeleton extends StatelessWidget {
  const _NearbySkeleton({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final cardWidth = nearbyCarouselCardWidth(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceXs,
          ),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        SizedBox(
          height: 160,
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

class _NearbyMessage extends StatelessWidget {
  const _NearbyMessage({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
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
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimens.spaceSm),
          Container(
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
        ],
      ),
    );
  }
}
