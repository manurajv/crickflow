import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/cf_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/match_model.dart';
import '../../data/models/team_model.dart';
import '../../data/models/tournament_model.dart';
import '../../shared/providers/providers.dart';
import 'match_card_ui.dart';

/// Standard match card for all list feeds (Home, My Cricket, Discover, etc.).
class MatchListCard extends ConsumerWidget {
  const MatchListCard({
    super.key,
    required this.match,
    this.tournamentLabel,
    this.showQuickLinks = true,
    this.showTournamentHeader = true,
  });

  final MatchModel match;
  final String? tournamentLabel;
  final bool showQuickLinks;
  final bool showTournamentHeader;

  bool get _isUpcoming =>
      match.status == MatchStatus.scheduled ||
      match.status == MatchStatus.draft ||
      match.status == MatchStatus.tossCompleted;

  bool get _isLive =>
      match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak;

  bool get _isCompleted => match.status == MatchStatus.completed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(allTeamsProvider).valueOrNull ?? [];
    final tournaments = ref.watch(tournamentsProvider).valueOrNull ?? [];
    final teamA = _teamById(teams, match.teamAId);
    final teamB = _teamById(teams, match.teamBId);
    final tournamentHeader = showTournamentHeader
        ? _tournamentHeader(tournaments, tournamentLabel)
        : tournamentLabel;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      decoration: matchListCardDecoration(match, context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openMatchHub(context),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: AppDimens.cardPadding,
                child: MatchCardContent(
                  match: match,
                  tournamentLabel: tournamentHeader,
                  teamALogoUrl: teamA?.profileImageUrl,
                  teamBLogoUrl: teamB?.profileImageUrl,
                ),
              ),
            ),
          ),
          if (showQuickLinks && _actions(context).isNotEmpty) ...[
            Divider(height: 1, color: context.cf.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _actions(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TeamModel? _teamById(List<TeamModel> teams, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  String? _tournamentHeader(
    List<TournamentModel> tournaments,
    String? explicitLabel,
  ) {
    if (explicitLabel != null && explicitLabel.isNotEmpty) {
      return explicitLabel;
    }
    if (match.tournamentId == null) return null;
    for (final t in tournaments) {
      if (t.id == match.tournamentId) {
        return 'League Matches, ${t.name}';
      }
    }
    if (match.title.isNotEmpty && match.title != 'Match') {
      return match.title;
    }
    return null;
  }

  void _openMatchHub(BuildContext context) {
    context.push('/match/${match.id}');
  }

  List<Widget> _actions(BuildContext context) {
    if (_isUpcoming) {
      return [
        _LinkButton(
          label: 'Squads',
          onTap: () => context.push('/match/${match.id}?tab=squads'),
        ),
        _LinkButton(
          label: 'Details',
          onTap: () => _openMatchHub(context),
        ),
      ];
    }
    if (_isLive) {
      return [
        _LinkButton(
          label: 'Live Score',
          onTap: () => context.push('/match/${match.id}/score'),
        ),
        _LinkButton(
          label: 'Scorecard',
          onTap: () => context.push('/match/${match.id}?tab=scorecard'),
        ),
        _LinkButton(
          label: 'Insights',
          onTap: () => context.push('/match/${match.id}?tab=insights'),
        ),
      ];
    }
    if (_isCompleted) {
      return [
        _LinkButton(
          label: 'Scorecard',
          onTap: () => context.push('/match/${match.id}?tab=scorecard'),
        ),
        _LinkButton(
          label: 'Insights',
          onTap: () => context.push('/match/${match.id}?tab=insights'),
        ),
        _LinkButton(
          label: 'Leaderboard',
          onTap: () => context.push('/match/${match.id}?tab=mvp'),
        ),
      ];
    }
    return [
      _LinkButton(
        label: 'Details',
        onTap: () => _openMatchHub(context),
      ),
    ];
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cf.link,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
      ),
    );
  }
}

/// Empty state for match list screens.
class MatchListEmptyState extends StatelessWidget {
  const MatchListEmptyState({
    super.key,
    required this.message,
    this.onCreateMatch,
    this.onClearFilters,
  });

  final String message;
  final VoidCallback? onCreateMatch;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceXl,
        vertical: 48,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_cricket_outlined,
            size: 56,
            color: cf.textMuted.withValues(alpha: 0.45),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cf.textSecondary,
                ),
          ),
          if (onCreateMatch != null || onClearFilters != null) ...[
            const SizedBox(height: AppDimens.spaceLg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppDimens.spaceSm,
              runSpacing: AppDimens.spaceSm,
              children: [
                if (onCreateMatch != null)
                  FilledButton(
                    onPressed: onCreateMatch,
                    child: const Text('Create Match'),
                  ),
                if (onClearFilters != null)
                  OutlinedButton(
                    onPressed: onClearFilters,
                    child: const Text('Clear Filters'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
