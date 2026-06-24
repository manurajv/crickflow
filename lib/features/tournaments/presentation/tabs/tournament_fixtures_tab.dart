import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../widgets/tournament_bracket_widget.dart';
import '../widgets/tournament_module_empty_state.dart';

class TournamentFixturesTab extends ConsumerStatefulWidget {
  const TournamentFixturesTab({
    super.key,
    required this.tournament,
    required this.role,
  });

  final TournamentModel tournament;
  final TournamentRole role;

  @override
  ConsumerState<TournamentFixturesTab> createState() =>
      _TournamentFixturesTabState();
}

class _TournamentFixturesTabState extends ConsumerState<TournamentFixturesTab> {
  var _busy = false;

  Future<bool> _confirmGenerate(String label) async {
    final matches =
        ref.read(tournamentMatchesProvider(widget.tournament.id)).valueOrNull ??
            [];
    if (matches.isEmpty) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Generate $label?'),
        content: Text(
          'This tournament already has ${matches.length} '
          '${matches.length == 1 ? 'match' : 'matches'}. '
          'Generating again will add more fixtures.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _generate(
    Future<List<String>> Function() action,
    String label,
  ) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    if (!await _confirmGenerate(label)) return;

    setState(() => _busy = true);
    try {
      final ids = await action();
      ref.invalidate(tournamentProvider(widget.tournament.id));
      ref.invalidate(tournamentMatchesProvider(widget.tournament.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label: ${ids.length} matches created'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('Nested arrays')) {
      return 'Could not save bracket. Please update the app and try again.';
    }
    if (text.contains('Add at least 2 teams')) {
      return 'Add at least 2 teams before generating fixtures.';
    }
    if (text.contains('Create groups first')) {
      return 'Create groups before generating group-stage fixtures.';
    }
    if (text.contains('Each group needs at least 2 teams')) {
      return 'Each group needs at least 2 teams.';
    }
    return text.replaceFirst('StateError: ', '').replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final canManage = ref
        .watch(tournamentPermissionServiceProvider)
        .canManageFixtures(widget.role);
    final repo = ref.read(tournamentRepositoryProvider);
    final uid = ref.read(authStateProvider).value?.uid ?? '';
    final liveTournament =
        ref.watch(tournamentProvider(widget.tournament.id)).valueOrNull ??
            widget.tournament;
    final matchesAsync =
        ref.watch(tournamentMatchesProvider(widget.tournament.id));

    return matchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (matches) {
        final hasBracket = liveTournament.bracketRounds.isNotEmpty;
        final teamCount = liveTournament.teamIds.length;

        if (matches.isEmpty && !canManage) {
          return const TournamentModuleEmptyState(
            icon: Icons.calendar_month_outlined,
            title: 'No fixtures yet',
            description: 'Fixtures will appear here once the organizer schedules matches.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tournamentProvider(widget.tournament.id));
            ref.invalidate(tournamentMatchesProvider(widget.tournament.id));
          },
          child: ListView(
            padding: AppDimens.screenPadding,
            children: [
              _SummaryCard(
                teamCount: teamCount,
                matchCount: matches.length,
                hasBracket: hasBracket,
              ),
              if (canManage) ...[
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  'Generate fixtures',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                _GenerateTile(
                  icon: Icons.sync_outlined,
                  title: 'Round robin (league)',
                  subtitle: 'Every team plays every other team once.',
                  isPrimary: true,
                  isLoading: _busy,
                  onTap: _busy
                      ? null
                      : () => _generate(
                            () => repo.generateLeagueFixtures(
                              tournamentId: widget.tournament.id,
                              createdBy: uid,
                            ),
                            'League fixtures',
                          ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                _GenerateTile(
                  icon: Icons.grid_view_outlined,
                  title: 'Group stage',
                  subtitle: 'Round robin within each group.',
                  isLoading: _busy,
                  onTap: _busy
                      ? null
                      : () => _generate(
                            () => repo.generateGroupStageFixtures(
                              tournamentId: widget.tournament.id,
                              createdBy: uid,
                            ),
                            'Group fixtures',
                          ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                _GenerateTile(
                  icon: Icons.account_tree_outlined,
                  title: 'Knockout bracket',
                  subtitle: 'Single elimination with bye support.',
                  isLoading: _busy,
                  onTap: _busy
                      ? null
                      : () => _generate(
                            () => repo.generateKnockoutBracket(
                              tournamentId: widget.tournament.id,
                              createdBy: uid,
                            ),
                            'Knockout',
                          ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Or schedule individual matches from the Matches tab.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textMuted,
                      ),
                ),
              ],
              if (hasBracket) ...[
                const SizedBox(height: AppDimens.spaceLg),
                TournamentBracketWidget(tournament: liveTournament),
              ],
              if (matches.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceLg),
                Text(
                  '${matches.length} ${matches.length == 1 ? 'match' : 'matches'} scheduled. '
                  'Open the Matches tab to view and manage fixtures.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textSecondary,
                      ),
                ),
              ] else if (!canManage)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spaceLg),
                  child: Text(
                    'No fixtures yet.',
                    style: TextStyle(color: cf.textSecondary),
                  ),
                ),
              const SizedBox(height: AppDimens.spaceLg),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.teamCount,
    required this.matchCount,
    required this.hasBracket,
  });

  final int teamCount;
  final int matchCount;
  final bool hasBracket;

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
              child: _SummaryStat(
                label: 'Format',
                value: hasBracket ? 'Knockout' : (matchCount > 0 ? 'League' : '—'),
              ),
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

class _GenerateTile extends StatelessWidget {
  const _GenerateTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isPrimary;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Material(
      color: isPrimary ? cf.accent : cf.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isPrimary ? null : Border.all(color: cf.border),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isPrimary ? Colors.white : cf.accent,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isPrimary ? Colors.white : cf.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isPrimary
                                ? Colors.white.withValues(alpha: 0.85)
                                : cf.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isPrimary ? Colors.white : cf.accent,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: isPrimary ? Colors.white70 : cf.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
