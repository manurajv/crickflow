import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'series_announcements_screen.dart';
import 'widgets/series_status_banner.dart';
import 'widgets/series_ui.dart';
import 'widgets/series_user_name.dart';

/// Org dashboard for the owner and admins: status, numbers, work queue,
/// recent activity and shortcuts.
class SeriesOrgDashboardScreen extends ConsumerWidget {
  const SeriesOrgDashboardScreen({super.key, required this.seriesId});
  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final role = ref.watch(mySeriesRoleProvider(seriesId));
    final isOwner = role == SeriesRole.superAdmin;
    final canAdmin = isOwner || role == SeriesRole.seriesAdmin;
    final seriesAsync = ref.watch(seriesByIdProvider(seriesId));

    if (!canAdmin) {
      return const Scaffold(
        appBar: CfChromeAppBar(title: Text('Dashboard')),
        body: Center(child: Text('Admin access required')),
      );
    }

    return Scaffold(
      backgroundColor: cf.background,
      appBar: const CfChromeAppBar(title: Text('Dashboard')),
      body: seriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (series) {
          if (series == null) {
            return const Center(child: Text('Organization not found'));
          }
          final pending =
              ref.watch(pendingSeriesApprovalsProvider(seriesId)).valueOrNull ??
                  const <SeriesApprovalModel>[];
          final admins =
              ref.watch(seriesAdminsListProvider(seriesId)).valueOrNull ??
                  const <SeriesAdminModel>[];
          final clubs =
              ref.watch(clubsForSeriesProvider(seriesId)).valueOrNull ??
                  const <SeriesClubModel>[];
          final audit =
              ref.watch(seriesAuditLogsProvider(seriesId)).valueOrNull ??
                  const <SeriesAuditLogModel>[];
          final announcements =
              ref.watch(seriesAnnouncementsProvider(seriesId)).valueOrNull ??
                  const <SeriesAnnouncementModel>[];
          final activeAdmins = admins.where((a) => a.status == 'active').length;
          final pendingClubs =
              clubs.where((c) => c.status == SeriesClubStatus.pending).length;

          return ListView(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            children: [
              Text(
                series.name,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${series.kind.label} · ${isOwner ? 'You are the owner' : 'You are an admin'}',
                style: TextStyle(color: cf.textSecondary),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              SeriesStatusBanner(series: series, showWhenActive: true),
              const SizedBox(height: AppDimens.spaceMd),
              Row(
                children: [
                  SeriesStat(series.clubCount, series.memberUnitsStatLabel),
                  const SizedBox(width: AppDimens.spaceSm),
                  SeriesStat(series.playerCount, 'Players'),
                ],
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Row(
                children: [
                  SeriesStat(series.matchCount, 'Matches'),
                  const SizedBox(width: AppDimens.spaceSm),
                  SeriesStat(activeAdmins, 'Admins'),
                ],
              ),
              const SizedBox(height: AppDimens.spaceLg),
              _SectionTitle('Needs attention'),
              _ActionTile(
                icon: Icons.fact_check_outlined,
                title: 'Pending approvals',
                subtitle: pending.isEmpty
                    ? 'All caught up'
                    : '${pending.length} waiting for review',
                badge: pending.length,
                onTap: () => context.push('/series/$seriesId/approvals'),
              ),
              if (pendingClubs > 0)
                _ActionTile(
                  icon: Icons.groups_outlined,
                  title: '${series.memberUnitsSingular}s awaiting approval',
                  subtitle: '$pendingClubs pending',
                  badge: pendingClubs,
                  onTap: () => context.push('/series/$seriesId/approvals'),
                ),
              const SizedBox(height: AppDimens.spaceMd),
              _SectionTitle('Manage'),
              _ActionTile(
                icon: Icons.campaign_outlined,
                title: 'Announcements',
                subtitle: 'Post news to clubs and players',
                onTap: () => context.push('/series/$seriesId/announcements'),
              ),
              _ActionTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admins',
                subtitle: '$activeAdmins active',
                onTap: () => context.push('/series/$seriesId/admins'),
              ),
              _ActionTile(
                icon: Icons.event_outlined,
                title: 'Fixtures',
                onTap: () => context.push('/series/$seriesId/fixtures'),
              ),
              _ActionTile(
                icon: Icons.leaderboard_outlined,
                title: 'Rankings',
                onTap: () => context.push('/series/$seriesId/rankings'),
              ),
              if (isOwner)
                _ActionTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings & ownership',
                  subtitle: 'Rules, registration, transfer, archive',
                  onTap: () => context.push('/series/$seriesId/settings'),
                ),
              if (announcements.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceMd),
                _SectionTitle('Latest announcement'),
                SeriesAnnouncementCard(
                  announcement: announcements.first,
                  showAudience: true,
                ),
              ],
              const SizedBox(height: AppDimens.spaceMd),
              Row(
                children: [
                  Expanded(child: _SectionTitle('Recent activity')),
                  TextButton(
                    onPressed: () => context.push('/series/$seriesId/audit'),
                    child: const Text('See all'),
                  ),
                ],
              ),
              if (audit.isEmpty)
                Text(
                  'No activity yet',
                  style: TextStyle(color: cf.textSecondary),
                )
              else
                for (final log in audit.take(5))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.receipt_long_outlined, color: cf.accent),
                    title: Text(seriesAuditActionLabel(log.action)),
                    subtitle: Row(
                      children: [
                        Flexible(
                          child: SeriesUserName(
                            log.actorUserId,
                            fallback: 'Someone',
                            style: TextStyle(
                              color: cf.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          ' · ${seriesShortDate(log.timestamp)}',
                          style: TextStyle(
                            color: cf.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge = 0,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: ListTile(
        tileColor: cf.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        leading: Icon(icon, color: cf.accent),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge > 0)
              Badge(
                label: Text('$badge'),
                backgroundColor: cf.accent,
                textColor: cf.onAccent,
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
