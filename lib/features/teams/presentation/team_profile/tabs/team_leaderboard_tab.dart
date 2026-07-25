import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../domain/services/team_profile/team_profile_models.dart';
import '../../../../../shared/providers/team_profile_provider.dart';
import '../../../../../shared/widgets/lineup_player_avatar.dart';

class TeamLeaderboardTab extends ConsumerStatefulWidget {
  const TeamLeaderboardTab({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamLeaderboardTab> createState() => _TeamLeaderboardTabState();
}

class _TeamLeaderboardTabState extends ConsumerState<TeamLeaderboardTab> {
  TeamLeaderboardSection _section = TeamLeaderboardSection.batting;
  TeamLeaderboardCategory _category = TeamLeaderboardCategory.mostRuns;

  List<TeamLeaderboardCategory> get _options => switch (_section) {
        TeamLeaderboardSection.batting => kTeamBattingLeaderboardCategories,
        TeamLeaderboardSection.bowling => kTeamBowlingLeaderboardCategories,
        TeamLeaderboardSection.fielding => kTeamFieldingLeaderboardCategories,
        TeamLeaderboardSection.partnerships =>
          kTeamPartnershipLeaderboardCategories,
      };

  void _selectSection(TeamLeaderboardSection section) {
    setState(() {
      _section = section;
      _category = _options.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final key = (teamId: widget.teamId, category: _category);
    final isPartnerships = _section == TeamLeaderboardSection.partnerships;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(teamProfileSnapshotProvider(widget.teamId));
        ref.invalidate(teamProfileBallEventsProvider(widget.teamId));
        ref.invalidate(teamLeaderboardProvider(key));
        ref.invalidate(teamPartnershipLeaderboardProvider(key));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppDimens.listPadding,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in TeamLeaderboardSection.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: AppDimens.spaceXs),
                    child: FilterChip(
                      label: Text(_sectionLabel(s)),
                      selected: _section == s,
                      onSelected: (_) => _selectSection(s),
                      selectedColor: cf.accent.withValues(alpha: 0.15),
                      checkmarkColor: cf.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          DropdownButtonFormField<TeamLeaderboardCategory>(
            key: ValueKey(_category),
            initialValue: _category,
            decoration: InputDecoration(
              filled: true,
              fillColor: cf.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cf.border),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
            ),
            items: [
              for (final c in _options)
                DropdownMenuItem(value: c, child: Text(c.title)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: AppDimens.spaceMd),
          if (isPartnerships)
            ..._partnershipBody(context, cf, key)
          else
            ..._playerBody(context, cf, key),
        ],
      ),
    );
  }

  List<Widget> _playerBody(
    BuildContext context,
    CfColors cf,
    TeamLeaderboardKey key,
  ) {
    final entriesAsync = ref.watch(teamLeaderboardProvider(key));
    return entriesAsync.when(
      loading: () => [
        const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (e, _) => [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Text(
            'Unable to load leaderboard: $e',
            textAlign: TextAlign.center,
            style: TextStyle(color: cf.textSecondary),
          ),
        ),
      ],
      data: (entries) {
        if (entries.isEmpty) return [_empty(context, cf)];
        return [
          for (final e in entries) ...[
            _LeaderboardCard(entry: e),
            const SizedBox(height: AppDimens.spaceSm),
          ],
        ];
      },
    );
  }

  List<Widget> _partnershipBody(
    BuildContext context,
    CfColors cf,
    TeamLeaderboardKey key,
  ) {
    final entriesAsync = ref.watch(teamPartnershipLeaderboardProvider(key));
    return entriesAsync.when(
      loading: () => [
        const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (e, _) => [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Text(
            'Unable to load partnerships: $e',
            textAlign: TextAlign.center,
            style: TextStyle(color: cf.textSecondary),
          ),
        ),
      ],
      data: (entries) {
        if (entries.isEmpty) return [_empty(context, cf)];
        final maxRuns = entries.first.runs.clamp(1, 999999);
        return [
          for (final e in entries) ...[
            _TeamPartnershipCard(
              entry: e,
              maxRuns: maxRuns,
              cf: cf,
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],
        ];
      },
    );
  }

  Widget _empty(BuildContext context, CfColors cf) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.leaderboard_outlined, size: 48, color: cf.textMuted),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'No ${_category.title.toLowerCase()} data yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'Rankings appear once this team has scored matches.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cf.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _sectionLabel(TeamLeaderboardSection s) => switch (s) {
        TeamLeaderboardSection.batting => 'Batting',
        TeamLeaderboardSection.bowling => 'Bowling',
        TeamLeaderboardSection.fielding => 'Fielding',
        TeamLeaderboardSection.partnerships => 'Partnerships',
      };
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.entry});

  final TeamLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final rankColor = switch (entry.rank) {
      1 => const Color(0xFFFFD54F),
      2 => const Color(0xFFB0BEC5),
      3 => const Color(0xFFFFAB91),
      _ => cf.accent,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        onTap: () => context.push('/players/${entry.playerId}'),
        child: Container(
          decoration: cfCardDecoration(context),
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#${entry.rank}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: rankColor,
                      ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              CircleAvatar(
                radius: 22,
                backgroundColor: cf.border,
                backgroundImage: entry.photoUrl != null &&
                        entry.photoUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(entry.photoUrl!)
                    : null,
                child: entry.photoUrl == null || entry.photoUrl!.isEmpty
                    ? Text(
                        entry.playerName.isNotEmpty
                            ? entry.playerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (entry.role.isNotEmpty) entry.role,
                        '${entry.matches} matches',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                entry.valueLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cf.accent,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Insights-style partnership card with both batters.
class _TeamPartnershipCard extends StatelessWidget {
  const _TeamPartnershipCard({
    required this.entry,
    required this.maxRuns,
    required this.cf,
  });

  final TeamPartnershipLeaderboardEntry entry;
  final int maxRuns;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final p = entry;
    final barScale = (p.runs / maxRuns).clamp(0.15, 1.0);
    final rankColor = switch (p.rank) {
      1 => const Color(0xFFFFD54F),
      2 => const Color(0xFFB0BEC5),
      3 => const Color(0xFFFFAB91),
      _ => cf.accent,
    };

    return Container(
      padding: AppDimens.cardPadding,
      decoration: cfCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${p.rank}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: rankColor,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_ordinal(p.wicketNumber)} Wicket Partnership',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cf.textSecondary,
                  ),
                ),
              ),
              if (p.isHighest)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cf.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: cf.success.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 14, color: cf.success),
                      const SizedBox(width: 4),
                      Text(
                        'Highest',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cf.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (p.matchLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              p.matchLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cf.textMuted,
              ),
            ),
          ],
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BatterColumn(
                  name: p.batterAName,
                  runs: p.batterARuns,
                  balls: p.batterABalls,
                  photoUrl: p.batterAPhotoUrl,
                  alignEnd: false,
                  cf: cf,
                  onTap: p.batterAId.isEmpty
                      ? null
                      : () => context.push('/players/${p.batterAId}'),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Text(
                      '${p.runs} (${p.balls})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cf.textPrimary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: barScale,
                      child: _ContributionBar(
                        leftFraction: p.batterAShare,
                        rightFraction: p.batterBShare,
                        cf: cf,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _BatterColumn(
                  name: p.batterBName,
                  runs: p.batterBRuns,
                  balls: p.batterBBalls,
                  photoUrl: p.batterBPhotoUrl,
                  alignEnd: true,
                  cf: cf,
                  onTap: p.batterBId.isEmpty
                      ? null
                      : () => context.push('/players/${p.batterBId}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}

class _BatterColumn extends StatelessWidget {
  const _BatterColumn({
    required this.name,
    required this.runs,
    required this.balls,
    required this.photoUrl,
    required this.alignEnd,
    required this.cf,
    this.onTap,
  });

  final String name;
  final int runs;
  final int balls;
  final String? photoUrl;
  final bool alignEnd;
  final CfColors cf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cross =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: cross,
        children: [
          LineupPlayerAvatar(
            name: name.isNotEmpty ? name : '?',
            photoUrl: photoUrl,
            radius: 22,
          ),
          const SizedBox(height: 6),
          Text(
            name.isNotEmpty ? name : '—',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cf.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
          ),
          const SizedBox(height: 2),
          Text(
            '$runs ($balls)',
            style: TextStyle(
              fontSize: 11,
              color: cf.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: textAlign,
          ),
        ],
      ),
    );
  }
}

class _ContributionBar extends StatelessWidget {
  const _ContributionBar({
    required this.leftFraction,
    required this.rightFraction,
    required this.cf,
  });

  final double leftFraction;
  final double rightFraction;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final leftFlex = (leftFraction * 1000).round().clamp(1, 1000);
    final rightFlex = (rightFraction * 1000).round().clamp(1, 1000);

    return SizedBox(
      height: 8,
      child: Row(
        children: [
          Expanded(
            flex: leftFlex,
            child: Container(
              decoration: BoxDecoration(
                color: cf.accent,
                borderRadius: BorderRadius.horizontal(
                  left: const Radius.circular(4),
                  right:
                      rightFlex <= 0 ? const Radius.circular(4) : Radius.zero,
                ),
              ),
            ),
          ),
          if (leftFlex > 0 && rightFlex > 0) const SizedBox(width: 2),
          Expanded(
            flex: rightFlex,
            child: Container(
              decoration: BoxDecoration(
                color: cf.accent.withValues(alpha: 0.35),
                borderRadius: BorderRadius.horizontal(
                  left: leftFlex <= 0 ? const Radius.circular(4) : Radius.zero,
                  right: const Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
