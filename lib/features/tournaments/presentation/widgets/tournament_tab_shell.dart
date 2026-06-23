import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../../../shared/widgets/match_list_card.dart';
import '../../../../shared/widgets/start_match_ui.dart';

/// Shared scaffold for tournament dashboard tabs that are not yet implemented.
class TournamentTabShell extends ConsumerWidget {
  const TournamentTabShell({
    super.key,
    required this.tournamentId,
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    this.plannedSections = const [],
    this.onRefresh,
  });

  final String tournamentId;
  final String title;
  final String subtitle;
  final String emptyMessage;
  final List<String> plannedSections;
  final Future<void> Function(WidgetRef ref)? onRefresh;

  Future<void> _handleRefresh(WidgetRef ref) async {
    ref.invalidate(tournamentProvider(tournamentId));
    await onRefresh?.call(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final tournamentAsync = ref.watch(tournamentProvider(tournamentId));

    return tournamentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: AppDimens.screenPadding,
          child: Text(
            '$error',
            textAlign: TextAlign.center,
            style: TextStyle(color: cf.error),
          ),
        ),
      ),
      data: (tournament) {
        if (tournament == null) {
          return const MatchListEmptyState(message: 'Tournament not found');
        }

        return RefreshIndicator(
          onRefresh: () => _handleRefresh(ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppDimens.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cf.textPrimary,
                            ),
                      ),
                      const SizedBox(height: AppDimens.spaceXs),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cf.textSecondary,
                            ),
                      ),
                      if (plannedSections.isNotEmpty) ...[
                        const SizedBox(height: AppDimens.spaceLg),
                        Text(
                          'Planned sections',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cf.textPrimary,
                                  ),
                        ),
                        const SizedBox(height: AppDimens.spaceSm),
                        ...plannedSections.map(
                          (section) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimens.spaceSm,
                            ),
                            child: StartMatchCard(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.layers_outlined,
                                    size: 20,
                                    color: cf.textMuted,
                                  ),
                                  const SizedBox(width: AppDimens.spaceSm),
                                  Expanded(
                                    child: Text(
                                      section,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: cf.textSecondary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppDimens.spaceXl),
                      MatchListEmptyState(message: emptyMessage),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
