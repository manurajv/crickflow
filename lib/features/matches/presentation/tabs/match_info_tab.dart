import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/venue_maps_utils.dart';
import '../../../../domain/services/match_info_models.dart';
import '../../../../shared/providers/match_info_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_match_repair.dart';
import '../../../../shared/widgets/lineup_player_avatar.dart';
import '../widgets/info/match_tournament_info_card.dart';
import '../widgets/summary/match_summary_sections.dart';

class MatchInfoTab extends ConsumerWidget {
  const MatchInfoTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(matchProvider(matchId)).valueOrNull;
    final displayMatch = ref.watch(matchDisplayProvider(matchId)) ?? match;
    final info = ref.watch(matchInfoProvider(matchId));

    return ListView(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
      children: [
        if (displayMatch != null) MatchTournamentInfoCard(match: displayMatch),
        if (info.abandoned != null)
          InfoAbandonedBanner(section: info.abandoned!),
        if (info.hasOverview)
          InfoKeyValueSection(title: 'Match Overview', rows: info.overview),
        if (info.hasConfiguration)
          InfoKeyValueSection(
            title: 'Match Configuration',
            rows: info.configuration,
          ),
        if (info.hasOfficials)
          InfoOfficialsSection(officials: info.officials),
        if (info.hasNotes)
          InfoTimelineSection(title: 'Match Notes', entries: info.notes),
        if (info.hasAdminEvents)
          InfoTimelineSection(
            title: 'Match Events',
            entries: info.adminEvents,
          ),
        if (info.hasDls)
          for (final section in info.dlsSections)
            InfoKeyValueSection(title: section.title, rows: section.rows),
        if (info.hasPenalties)
          InfoPenaltiesSection(penalties: info.penalties),
        if (info.hasConditions)
          InfoKeyValueSection(title: 'Match Conditions', rows: info.conditions),
        if (info.hasQuickLinks)
          InfoQuickLinksSection(links: info.quickLinks),
      ],
    );
  }
}

class InfoAbandonedBanner extends StatelessWidget {
  const InfoAbandonedBanner({super.key, required this.section});

  final MatchInfoAbandonedSection section;

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
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: cf.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: cf.error.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match Abandoned',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: cf.error,
              ),
            ),
            if (section.reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(section.reason, style: TextStyle(color: cf.textPrimary)),
            ],
            if (section.timeLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(section.timeLabel, style: TextStyle(color: cf.textSecondary)),
            ],
            if (section.resultStatus.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                section.resultStatus,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cf.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InfoKeyValueSection extends StatelessWidget {
  const InfoKeyValueSection({
    super.key,
    required this.title,
    required this.rows,
  });

  final String title;
  final List<MatchInfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SummarySectionHeader(title: title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: cfCardDecoration(context),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  _InfoRow(row: rows[i], cf: cf),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.row, required this.cf});

  final MatchInfoRow row;
  final CfColors cf;

  Future<void> _openMaps(BuildContext context) async {
    final ok = await openVenueDirections(destination: row.value);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTappable = row.openDirectionsInMaps ||
        (row.route != null && row.route!.isNotEmpty);
    final valueStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: row.highlight ? cf.accent : cf.textPrimary,
      decoration: isTappable ? TextDecoration.underline : null,
    );

    Widget valueWidget = Text(row.value, style: valueStyle);
    if (isTappable) {
      valueWidget = InkWell(
        onTap: () {
          if (row.openDirectionsInMaps) {
            _openMaps(context);
          } else if (row.route != null && row.route!.isNotEmpty) {
            context.push(row.route!);
          }
        },
        child: Row(
          children: [
            Expanded(child: Text(row.value, style: valueStyle)),
            Icon(Icons.chevron_right, size: 16, color: cf.accent),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            row.label,
            style: TextStyle(fontSize: 12, color: cf.textMuted),
          ),
        ),
        Expanded(child: valueWidget),
      ],
    );
  }
}

class InfoOfficialsSection extends StatelessWidget {
  const InfoOfficialsSection({super.key, required this.officials});

  final List<MatchInfoOfficial> officials;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Match Officials'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Container(
            decoration: cfCardDecoration(context),
            child: Column(
              children: [
                for (var i = 0; i < officials.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    child: Row(
                      children: [
                        LineupPlayerAvatar(
                          name: officials[i].name,
                          photoUrl: officials[i].photoUrl,
                          radius: 22,
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                officials[i].name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cf.accent,
                                ),
                              ),
                              Text(
                                '(${officials[i].role})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cf.textSecondary,
                                ),
                              ),
                              if (officials[i].playerId != null &&
                                  officials[i].playerId!.isNotEmpty)
                                Text(
                                  'ID ${officials[i].playerId}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cf.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class InfoTimelineSection extends StatelessWidget {
  const InfoTimelineSection({
    super.key,
    required this.title,
    required this.entries,
  });

  final String title;
  final List<MatchInfoTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SummarySectionHeader(title: title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Container(
            decoration: cfCardDecoration(context),
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: entries[i].isAdminEvent ? cf.info : cf.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entries[i].title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cf.textPrimary,
                                ),
                              ),
                              if (entries[i].subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  entries[i].subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cf.textSecondary,
                                  ),
                                ),
                              ],
                              if (entries[i].timestamp != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimestamp(entries[i].timestamp!),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cf.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatTimestamp(DateTime dt) {
    return DateFormat('d MMM yyyy · h:mm a').format(dt);
  }
}

class InfoPenaltiesSection extends StatelessWidget {
  const InfoPenaltiesSection({super.key, required this.penalties});

  final List<MatchInfoPenalty> penalties;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Penalty Runs'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Container(
            decoration: cfCardDecoration(context),
            child: Column(
              children: [
                for (var i = 0; i < penalties.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${penalties[i].teamName} · +${penalties[i].runs}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cf.textPrimary,
                          ),
                        ),
                        if (penalties[i].reason.isNotEmpty)
                          Text(
                            penalties[i].reason,
                            style: TextStyle(color: cf.textSecondary),
                          ),
                        if (penalties[i].timestamp != null)
                          Text(
                            InfoTimelineSection._formatTimestamp(
                              penalties[i].timestamp!,
                            ),
                            style: TextStyle(fontSize: 11, color: cf.textMuted),
                          ),
                      ],
                    ),
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

class InfoQuickLinksSection extends StatelessWidget {
  const InfoQuickLinksSection({super.key, required this.links});

  final List<MatchInfoQuickLink> links;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Quick Links'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Wrap(
            spacing: AppDimens.spaceSm,
            runSpacing: AppDimens.spaceSm,
            children: [
              for (final link in links)
                _QuickLinkChip(link: link, cf: cf),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickLinkChip extends StatelessWidget {
  const _QuickLinkChip({required this.link, required this.cf});

  final MatchInfoQuickLink link;
  final CfColors cf;

  IconData get _icon => switch (link.iconName) {
        'leaderboard' => Icons.leaderboard_outlined,
        'emoji_events' => Icons.emoji_events_outlined,
        'trophy' => Icons.emoji_events_outlined,
        'groups' => Icons.groups_outlined,
        'place' => Icons.place_outlined,
        _ => Icons.open_in_new,
      };

  @override
  Widget build(BuildContext context) {
    final tappable = link.route.isNotEmpty;
    return Material(
      color: cf.card,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: InkWell(
        onTap: tappable ? () => context.push(link.route) : null,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(color: cf.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, color: cf.accent, size: 20),
              const SizedBox(height: 8),
              Text(
                link.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: cf.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
