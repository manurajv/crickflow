import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/player_model.dart';
import '../../../../domain/services/player_analysis_models.dart';
import '../../../../features/my_cricket/my_cricket_filters.dart';
import '../../../../shared/providers/badge_provider.dart';
import '../../../../shared/providers/player_analysis_provider.dart';
import '../../../../shared/providers/providers.dart';
import 'widgets/profile_match_filter_button.dart';
import 'widgets/analysis/analysis_sections.dart';

/// Professional player analytics dashboard for My Cricket Profile.
class PlayerAnalysisScreen extends ConsumerWidget {
  const PlayerAnalysisScreen({
    super.key,
    required this.playerId,
    this.player,
    this.matches,
  });

  final String playerId;
  final PlayerModel? player;
  final List<MatchModel>? matches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final resolvedPlayer =
        player ?? ref.watch(playerDetailProvider(playerId)).valueOrNull;
    final allMatches = ref.watch(matchesProvider).valueOrNull ?? const [];
    final uid = ref.watch(authStateProvider).value?.uid;
    final userTeamIds =
        (ref.watch(teamsProvider).valueOrNull ?? []).map((t) => t.id).toSet();
    final participated = resolvedPlayer == null
        ? const <MatchModel>[]
        : allMatches
            .where(
              (m) => userParticipatedInMatch(
                m,
                uid: uid,
                player: resolvedPlayer,
                userTeamIds: userTeamIds,
              ),
            )
            .toList();
    final filterMatches = matches ?? participated;
    final analysisAsync = ref.watch(playerAdvancedAnalysisProvider(playerId));

    return Scaffold(
      backgroundColor: cf.surface,
      appBar: AppBar(
        title: Text(resolvedPlayer?.name ?? 'Analysis'),
        backgroundColor: cf.surface,
        foregroundColor: cf.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: analysisAsync.when(
        data: (snapshot) {
          if (!snapshot.hasEnoughData) {
            return _EmptyAnalysis(
              cf: cf,
              completedMatches: snapshot.completedMatches,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(playerAdvancedAnalysisProvider(playerId));
            },
            child: ListView(
              padding: AppDimens.listPadding,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (resolvedPlayer != null)
                  ProfileMatchFilterButton(
                    matches: filterMatches,
                    compact: false,
                  ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Player Analytics',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cf.textPrimary,
                      ),
                ),
                Text(
                  '${snapshot.completedMatches} completed matches analysed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textSecondary,
                      ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                PlayerSummarySection(summary: snapshot.summary, cf: cf),
                BattingAnalysisSection(snapshot: snapshot, cf: cf),
                BowlingAnalysisSection(snapshot: snapshot, cf: cf),
                FieldingAnalysisSection(fielding: snapshot.fielding, cf: cf),
                if (snapshot.captaincy.matchesAsCaptain > 0)
                  CaptaincyAnalysisSection(
                    captaincy: snapshot.captaincy,
                    cf: cf,
                  ),
                OpponentAnalysisSection(snapshot: snapshot, cf: cf),
                MatchSituationSection(situations: snapshot.situations, cf: cf),
                ProgressionAnalysisSection(snapshot: snapshot, cf: cf),
                HeatmapsSection(snapshot: snapshot, cf: cf, player: resolvedPlayer),
                const SizedBox(height: AppDimens.spaceXl),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _EmptyAnalysis extends StatelessWidget {
  const _EmptyAnalysis({
    required this.cf,
    required this.completedMatches,
  });

  final CfColors cf;
  final int completedMatches;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppDimens.listPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: cf.textSecondary),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'More matches required for analysis.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cf.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              completedMatches == 0
                  ? 'Play and complete matches to unlock your analytics dashboard.'
                  : '$completedMatches of $kAnalysisMinMatches completed matches recorded.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
