import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../utils/tournament_display_utils.dart';
import '../widgets/fixtures/tournament_fixtures_schedule.dart';
import '../widgets/matches/schedule_matches_bottom_sheet.dart';
import '../widgets/tournament_bracket_widget.dart';
import '../widgets/tournament_module_empty_state.dart';

class TournamentFixturesTab extends ConsumerWidget {
  const TournamentFixturesTab({
    super.key,
    required this.tournament,
    required this.role,
  });

  final TournamentModel tournament;
  final TournamentRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final canManage = ref
        .watch(tournamentPermissionServiceProvider)
        .canManageFixtures(role);
    final liveTournament =
        ref.watch(tournamentProvider(tournament.id)).valueOrNull ?? tournament;
    final matchesAsync = ref.watch(tournamentMatchesProvider(tournament.id));

    return matchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (matches) {
        final formatLabel = tournamentFormatLabel(liveTournament.format);
        final knockoutMatches =
            matches.where((m) => m.bracketRound != null).toList();
        final showBracket = liveTournament.bracketRounds.isNotEmpty &&
            knockoutMatches.isNotEmpty;
        final showSchedule = matches.isNotEmpty;

        if (!showSchedule && !canManage) {
          return const TournamentModuleEmptyState(
            icon: Icons.calendar_month_outlined,
            title: 'No fixtures yet',
            description:
                'Fixtures will appear here once the organizer schedules matches.',
          );
        }

        if (!showSchedule && canManage) {
          return RefreshIndicator(
            onRefresh: () => _refresh(ref, tournament.id),
            child: TournamentModuleEmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'No fixtures scheduled',
              description:
                  'Generate a round robin, group stage, or knockout bracket '
                  'from the Matches tab — or use Schedule below.',
              primaryAction: (
                label: 'Schedule fixtures',
                onPressed: () => showScheduleMatchesBottomSheet(
                  context: context,
                  tournament: liveTournament,
                  canManage: canManage,
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _refresh(ref, tournament.id),
          child: ListView(
            padding: AppDimens.screenPadding,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _SummaryCard(
                teamCount: liveTournament.teamIds.length,
                matchCount: matches.length,
                formatLabel: formatLabel,
              ),
              if (canManage) ...[
                const SizedBox(height: AppDimens.spaceMd),
                OutlinedButton.icon(
                  onPressed: () => showScheduleMatchesBottomSheet(
                    context: context,
                    tournament: liveTournament,
                    canManage: canManage,
                  ),
                  icon: const Icon(Icons.event_available_outlined, size: 18),
                  label: const Text('Schedule or generate fixtures'),
                ),
              ],
              if (showBracket) ...[
                const SizedBox(height: AppDimens.spaceLg),
                TournamentBracketWidget(
                  tournament: liveTournament,
                  existingMatchIds: matches.map((m) => m.id).toSet(),
                ),
              ],
              if (showSchedule) ...[
                const SizedBox(height: AppDimens.spaceLg),
                Text(
                  'Fixture schedule',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Tap a fixture to open match details. Manage or delete matches '
                  'from the Matches tab.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textSecondary,
                      ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                TournamentFixturesSchedule(
                  tournamentId: liveTournament.id,
                  matches: matches,
                  showKnockoutSection: !showBracket,
                ),
              ],
              const SizedBox(height: AppDimens.spaceLg),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refresh(WidgetRef ref, String tournamentId) async {
    ref.invalidate(tournamentProvider(tournamentId));
    ref.invalidate(tournamentMatchesProvider(tournamentId));
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.teamCount,
    required this.matchCount,
    required this.formatLabel,
  });

  final int teamCount;
  final int matchCount;
  final String formatLabel;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Card(
      elevation: 0,
      color: cf.sectionBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cf.border),
      ),
      child: Padding(
        padding: AppDimens.cardPadding,
        child: Row(
          children: [
            Expanded(
              child: _SummaryStat(label: 'Teams', value: '$teamCount'),
            ),
            Container(width: 1, height: 36, color: cf.border),
            Expanded(
              child: _SummaryStat(label: 'Fixtures', value: '$matchCount'),
            ),
            Container(width: 1, height: 36, color: cf.border),
            Expanded(
              child: _SummaryStat(label: 'Format', value: formatLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cf.textMuted,
              ),
        ),
      ],
    );
  }
}
