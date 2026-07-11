import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/services/match_mvp_models.dart';
import '../../../../shared/providers/match_mvp_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../widgets/mvp/mvp_filter_chips.dart';
import '../widgets/mvp/mvp_leaderboard_row.dart';

class MatchMvpTab extends ConsumerStatefulWidget {
  const MatchMvpTab({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<MatchMvpTab> createState() => _MatchMvpTabState();
}

class _MatchMvpTabState extends ConsumerState<MatchMvpTab> {
  MvpLeaderboardFilter _filter = MvpLeaderboardFilter.all;
  final Set<String> _expandedIds = {};

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final snapshot = ref.watch(matchMvpProvider(widget.matchId));
    final match = ref.watch(matchProvider(widget.matchId)).valueOrNull;
    final leaderboard = snapshot.leaderboardFor(_filter);
    final showBreakdown = _filter == MvpLeaderboardFilter.all ||
        _filter == MvpLeaderboardFilter.teamA ||
        _filter == MvpLeaderboardFilter.teamB;
    final matchComplete = match != null &&
        (match.status == MatchStatus.completed ||
            match.status == MatchStatus.abandoned);

    if (!snapshot.hasData) {
      return ListView(
        padding: AppDimens.listPadding,
        children: [
          _HowMvpLink(matchId: widget.matchId, cf: cf),
          const SizedBox(height: AppDimens.spaceLg),
          Center(
            child: Text(
              snapshot.isLive
                  ? 'MVP board builds as the match is scored.'
                  : 'No MVP data for this match yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cf.textSecondary),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Match MVP',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: cf.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            _HowMvpLink(matchId: widget.matchId, cf: cf),
          ],
        ),
        if (snapshot.isLive) ...[
          const SizedBox(height: AppDimens.spaceXs),
          _LiveChip(cf: cf),
        ],
        if (matchComplete && snapshot.playerOfTheMatch != null) ...[
          const SizedBox(height: AppDimens.spaceMd),
          _AwardBanner(
            emoji: '🏆',
            title: 'Player Of The Match',
            player: snapshot.playerOfTheMatch!,
            cf: cf,
          ),
        ],
        if (snapshot.fighterOfTheMatch != null) ...[
          const SizedBox(height: AppDimens.spaceSm),
          _AwardBanner(
            emoji: '🥊',
            title: 'Fighter Of The Match',
            player: snapshot.fighterOfTheMatch!,
            cf: cf,
          ),
        ],
        const SizedBox(height: AppDimens.spaceLg),
        MvpFilterChips(
          selected: _filter,
          teamAName: match?.teamAName ?? '',
          teamBName: match?.teamBName ?? '',
          onSelected: (f) => setState(() => _filter = f),
          cf: cf,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        if (leaderboard.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceLg),
            child: Text(
              'No players match this filter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cf.textSecondary),
            ),
          )
        else
          ...leaderboard.map(
            (entry) => MvpLeaderboardRow(
              entry: entry,
              cf: cf,
              showBreakdown: showBreakdown,
              showPotmBadge: matchComplete,
              expanded: _expandedIds.contains(entry.player.playerId),
              onToggle: showBreakdown
                  ? () {
                      setState(() {
                        final id = entry.player.playerId;
                        if (_expandedIds.contains(id)) {
                          _expandedIds.remove(id);
                        } else {
                          _expandedIds.add(id);
                        }
                      });
                    }
                  : null,
            ),
          ),
      ],
    );
  }
}

class _HowMvpLink extends StatelessWidget {
  const _HowMvpLink({required this.matchId, required this.cf});

  final String matchId;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.push('/match/$matchId/mvp/how'),
      style: TextButton.styleFrom(
        foregroundColor: cf.link,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
      ),
      child: const Text('How MVP is Calculated?'),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.cf});

  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: cf.statusLive.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cf.statusLive.withValues(alpha: 0.4)),
        ),
        child: Text(
          'LIVE',
          style: TextStyle(
            color: cf.statusLive,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _AwardBanner extends StatelessWidget {
  const _AwardBanner({
    required this.emoji,
    required this.title,
    required this.player,
    required this.cf,
  });

  final String emoji;
  final String title;
  final MvpPlayerScore player;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: cf.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: cf.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cf.accent,
                  ),
                ),
                Text(
                  '${player.playerName} · ${player.teamName}',
                  style: TextStyle(color: cf.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            player.totalMvp.toStringAsFixed(3),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: cf.scoreEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}
