import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../core/utils/calendar_utils.dart';
import '../../../../../core/utils/match_share_utils.dart';
import '../../../../../core/utils/venue_maps_utils.dart';
import '../../../../../data/models/match_model.dart';
import '../../../../../domain/services/match_info_models.dart';
import '../../../../../domain/services/match_upcoming_models.dart';
import '../../../../../shared/widgets/cf_button.dart';
import '../../../../../shared/widgets/match_follow_button.dart';
import '../../../../../shared/widgets/match_quick_action_button.dart';
import '../../../../../shared/widgets/match_team_avatar.dart';
import '../../tabs/match_info_tab.dart';
import '../summary/match_summary_sections.dart';

class UpcomingStatusBadge extends StatelessWidget {
  const UpcomingStatusBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cf.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cf.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: cf.success),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cf.success,
            ),
          ),
        ],
      ),
    );
  }
}

class UpcomingPreviewCard extends StatelessWidget {
  const UpcomingPreviewCard({super.key, required this.preview});

  final UpcomingMatchPreview preview;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        decoration: cfCardDecoration(context),
        child: Column(
          children: [
            UpcomingStatusBadge(label: preview.statusBadge),
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: _TeamColumn(
                    name: preview.teamAName,
                    logoUrl: preview.teamALogoUrl,
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cf.surfaceElevated,
                    border: Border.all(color: cf.border),
                  ),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: cf.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: _TeamColumn(
                    name: preview.teamBName,
                    logoUrl: preview.teamBLogoUrl,
                  ),
                ),
              ],
            ),
            if (preview.formatLabel.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                preview.formatLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cf.textPrimary,
                ),
              ),
            ],
            if (preview.venueLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                preview.venueLabel,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cf.textSecondary),
              ),
            ],
            if (preview.dateLabel.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                preview.dateLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cf.textPrimary,
                ),
              ),
            ],
            if (preview.timeLabel.isNotEmpty)
              Text(
                preview.timeLabel,
                style: TextStyle(color: cf.textSecondary),
              ),
            if (preview.scheduledAt != null) ...[
              const SizedBox(height: AppDimens.spaceMd),
              UpcomingCountdown(start: preview.scheduledAt!),
            ],
          ],
        ),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.name,
    required this.logoUrl,
  });

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MatchTeamAvatar(name: name, logoUrl: logoUrl, size: 52),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: cf.textPrimary,
          ),
        ),
      ],
    );
  }
}

class UpcomingCountdown extends StatefulWidget {
  const UpcomingCountdown({super.key, required this.start});

  final DateTime start;

  @override
  State<UpcomingCountdown> createState() => _UpcomingCountdownState();
}

class _UpcomingCountdownState extends State<UpcomingCountdown> {
  Timer? _timer;
  late String _label;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _label = _formatCountdown(widget.start));
  }

  static String _formatCountdown(DateTime start) {
    final diff = start.difference(DateTime.now());
    if (diff.isNegative) return 'Scheduled — waiting for scorer to start';
    final days = diff.inDays;
    if (days >= 1) {
      final hours = diff.inHours % 24;
      return days == 1 && hours == 0
          ? 'Starts in 1 day'
          : 'Starts in $days days${hours > 0 ? ' $hours hours' : ''}';
    }
    if (diff.inHours >= 1) {
      final mins = diff.inMinutes % 60;
      return 'Starts in ${diff.inHours} hours${mins > 0 ? ' $mins minutes' : ''}';
    }
    if (diff.inMinutes >= 1) {
      return 'Starts in ${diff.inMinutes} minutes';
    }
    return 'Starting soon';
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      children: [
        Text(
          'Starts in:',
          style: TextStyle(fontSize: 12, color: cf.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          _label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: cf.accent,
          ),
        ),
      ],
    );
  }
}

class UpcomingHeadToHeadSection extends StatelessWidget {
  const UpcomingHeadToHeadSection({
    super.key,
    required this.matchId,
    required this.snapshot,
    required this.teamAName,
    required this.teamBName,
    this.teamALogoUrl,
    this.teamBLogoUrl,
  });

  final String matchId;
  final HeadToHeadSnapshot snapshot;
  final String teamAName;
  final String teamBName;
  final String? teamALogoUrl;
  final String? teamBLogoUrl;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Head to head'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: cfCardDecoration(context),
            child: snapshot.hasHistory
                ? Column(
                    children: [
                      Row(
                        children: [
                          MatchTeamAvatar(
                            name: teamAName,
                            logoUrl: teamALogoUrl,
                            size: 28,
                          ),
                          Expanded(
                            child: Text(
                              '${snapshot.matchesPlayed} Matches',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cf.textSecondary,
                              ),
                            ),
                          ),
                          MatchTeamAvatar(
                            name: teamBName,
                            logoUrl: teamBLogoUrl,
                            size: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      _H2HRow(
                        label: 'Won',
                        left: '${snapshot.teamAWins}',
                        right: '${snapshot.teamBWins}',
                        cf: cf,
                      ),
                      _H2HRow(
                        label: 'Won bat 1st',
                        left: '${snapshot.teamAWonBatFirst}',
                        right: '${snapshot.teamBWonBatFirst}',
                        cf: cf,
                      ),
                      _H2HRow(
                        label: 'Won bowl 1st',
                        left: '${snapshot.teamAWonBowlFirst}',
                        right: '${snapshot.teamBWonBowlFirst}',
                        cf: cf,
                      ),
                      _H2HRow(
                        label: 'Avg. Runs',
                        left: snapshot.teamAAvgScore.toStringAsFixed(0),
                        right: snapshot.teamBAvgScore.toStringAsFixed(0),
                        cf: cf,
                        highlight: true,
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      CfButton(
                        label: 'View more insights',
                        icon: Icons.insights_outlined,
                        onPressed: () =>
                            context.push('/match/$matchId/head-to-head'),
                      ),
                    ],
                  )
                : Text(
                    'No previous meetings',
                    style: TextStyle(color: cf.textSecondary),
                  ),
          ),
        ),
      ],
    );
  }
}

class _H2HRow extends StatelessWidget {
  const _H2HRow({
    required this.label,
    required this.left,
    required this.right,
    required this.cf,
    this.highlight = false,
  });

  final String label;
  final String left;
  final String right;
  final CfColors cf;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontWeight: FontWeight.w800,
      color: highlight ? cf.accent : cf.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(left, style: valueStyle)),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cf.textMuted),
            ),
          ),
          Expanded(
            child: Text(right, textAlign: TextAlign.end, style: valueStyle),
          ),
        ],
      ),
    );
  }
}

class UpcomingMilestonesSection extends StatefulWidget {
  const UpcomingMilestonesSection({super.key, required this.milestones});

  final List<UpcomingMilestoneCard> milestones;

  @override
  State<UpcomingMilestonesSection> createState() =>
      _UpcomingMilestonesSectionState();
}

class _UpcomingMilestonesSectionState extends State<UpcomingMilestonesSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.milestones.isEmpty) return const SizedBox.shrink();
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Milestones to be unlocked',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: cf.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: cf.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: AppDimens.spaceSm),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              itemCount: widget.milestones.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final m = widget.milestones[index];
                return _MilestoneCard(milestone: m, cf: cf);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.milestone, required this.cf});

  final UpcomingMilestoneCard milestone;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: cfCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(milestone.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            milestone.title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: cf.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              milestone.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: cf.textSecondary),
            ),
          ),
          Text(
            milestone.progressLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cf.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class UpcomingBannersSection extends StatelessWidget {
  const UpcomingBannersSection({super.key, required this.banners});

  final List<UpcomingMatchBanner> banners;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Match banners'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: banners.isEmpty
              ? OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Banner generator — coming soon')),
                    );
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Generate Banner'),
                )
              : Column(
                  children: [
                    for (final banner in banners)
                      Container(
                        width: double.infinity,
                        height: 120,
                        margin: const EdgeInsets.only(bottom: 10),
                        clipBehavior: Clip.antiAlias,
                        decoration: cfCardDecoration(context),
                        child: banner.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: banner.imageUrl!,
                                fit: BoxFit.cover,
                              )
                            : Center(
                                child: Text(
                                  banner.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: cf.textPrimary,
                                  ),
                                ),
                              ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class UpcomingQuickActions extends StatelessWidget {
  const UpcomingQuickActions({
    super.key,
    required this.match,
  });

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Quick Actions'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: MatchFollowButton(
                      matchId: match.id,
                      quickAction: true,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: MatchQuickActionButton(
                      icon: Icons.share_outlined,
                      label: 'Share Match',
                      onPressed: () => shareMatchLink(
                        matchId: match.id,
                        title: match.title,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: match.teamAId != null
                        ? MatchQuickActionButton(
                            icon: Icons.groups_outlined,
                            label: 'View Teams',
                            onPressed: () =>
                                context.push('/teams/${match.teamAId}'),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: match.tournamentId != null
                        ? MatchQuickActionButton(
                            icon: Icons.emoji_events_outlined,
                            label: 'View Tournament',
                            onPressed: () => context.push(
                              '/tournaments/${match.tournamentId}',
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: MatchQuickActionButton(
                      icon: Icons.place_outlined,
                      label: 'View Venue',
                      onPressed: () async {
                        final ok = await openVenueDirections(
                          destination: match.venue,
                        );
                        if (context.mounted && !ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open maps'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: MatchQuickActionButton(
                      icon: Icons.event_outlined,
                      label: 'Add To Calendar',
                      onPressed: () async {
                        final ok = await addMatchToCalendar(match);
                        if (context.mounted && !ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not add to calendar'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class UpcomingInsightsBanner extends StatelessWidget {
  const UpcomingInsightsBanner({
    super.key,
    required this.matchId,
  });

  final String matchId;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: cf.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: cf.info.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Preview team form before match day',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cf.textPrimary,
                ),
              ),
            ),
            CfButton(
              label: 'Insights',
              icon: Icons.bar_chart_outlined,
              compact: true,
              onPressed: () => context.push('/match/$matchId/head-to-head'),
            ),
          ],
        ),
      ),
    );
  }
}

class UpcomingInfoSection extends StatelessWidget {
  const UpcomingInfoSection({super.key, required this.rows});

  final List<MatchInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return InfoKeyValueSection(title: 'Match Information', rows: rows);
  }
}

class UpcomingOfficialsSection extends StatelessWidget {
  const UpcomingOfficialsSection({super.key, required this.officials});

  final List<MatchInfoOfficial> officials;

  @override
  Widget build(BuildContext context) {
    if (officials.isEmpty) return const SizedBox.shrink();
    return InfoOfficialsSection(officials: officials);
  }
}
