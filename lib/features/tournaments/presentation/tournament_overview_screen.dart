import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/deep_link_utils.dart';
import '../../../core/utils/venue_maps_utils.dart';
import '../../../data/models/tournament/tournament_activity_model.dart';
import '../../../data/models/tournament/tournament_setup_meta.dart';
import '../../../data/models/tournament_model.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import '../../../shared/widgets/cf_button.dart';
import 'tournament_dashboard_sections.dart';
import 'utils/tournament_display_utils.dart';
import 'widgets/overview/tournament_overview_widgets.dart';
import 'widgets/tournament_join_banner.dart';
import 'widgets/tournament_qr_view.dart';

typedef TournamentSectionNavigator = void Function(
  TournamentDashboardSection section,
);

/// Tournament dashboard landing tab — summary and key tournament details.
class TournamentOverviewScreen extends ConsumerWidget {
  const TournamentOverviewScreen({
    super.key,
    required this.tournamentId,
    required this.tournament,
    required this.role,
    this.onNavigateToSection,
  });

  final String tournamentId;
  final TournamentModel tournament;
  final TournamentRole role;
  final TournamentSectionNavigator? onNavigateToSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(tournamentPermissionServiceProvider);
    final canManage = permissions.canManageTournament(role);

    final tournamentAsync = ref.watch(tournamentProvider(tournamentId));
    final groupsAsync = ref.watch(tournamentGroupsProvider(tournamentId));
    final matchesAsync = ref.watch(tournamentMatchesProvider(tournamentId));
    final officialsAsync = ref.watch(tournamentOfficialsProvider(tournamentId));
    final sponsorsAsync = ref.watch(tournamentSponsorsProvider(tournamentId));

    final isLoading = tournamentAsync.isLoading ||
        groupsAsync.isLoading ||
        matchesAsync.isLoading ||
        officialsAsync.isLoading ||
        sponsorsAsync.isLoading;

    if (isLoading && tournamentAsync.valueOrNull == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tournamentAsync.hasError && tournamentAsync.valueOrNull == null) {
      return Center(
        child: Padding(
          padding: AppDimens.screenPadding,
          child: Text(
            '${tournamentAsync.error}',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.cf.error),
          ),
        ),
      );
    }

    final current = tournamentAsync.valueOrNull ?? tournament;
    final stats = ref.watch(tournamentOverviewStatsProvider(tournamentId));
    final activity = ref.watch(tournamentRecentActivityProvider(tournamentId));
    final organizerId = current.effectiveOrganizerId;
    final organizerAsync = organizerId.isEmpty
        ? const AsyncValue<UserModel?>.data(null)
        : ref.watch(userProfileByIdProvider(organizerId));

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView(
        padding: AppDimens.screenPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          TournamentJoinBanner(tournament: current, role: role),
          TournamentOverviewSectionCard(
            title: 'Quick statistics',
            child: TournamentOverviewStatGrid(
              stats: [
                TournamentOverviewStatItem(
                  label: 'Teams',
                  value: '${stats.teamCount}',
                  icon: Icons.groups_outlined,
                ),
                TournamentOverviewStatItem(
                  label: 'Matches',
                  value: '${stats.matchCount}',
                  icon: Icons.sports_cricket_outlined,
                ),
                TournamentOverviewStatItem(
                  label: 'Groups',
                  value: '${stats.groupCount}',
                  icon: Icons.view_module_outlined,
                ),
                TournamentOverviewStatItem(
                  label: 'Officials',
                  value: '${stats.officialCount}',
                  icon: Icons.verified_user_outlined,
                ),
                TournamentOverviewStatItem(
                  label: 'Sponsors',
                  value: '${stats.sponsorCount}',
                  icon: Icons.handshake_outlined,
                ),
              ],
            ),
          ),
          _OrganizerSection(
            tournament: current,
            organizerAsync: organizerAsync,
            canViewContact: canManage,
          ),
          _TournamentInfoSection(tournament: current),
          _TeamInfoSection(
            tournament: current,
            registeredCount: stats.teamCount,
            onViewTeams: () => onNavigateToSection?.call(
              TournamentDashboardSection.teams,
            ),
          ),
          _OfficialsInfoSection(
            tournament: current,
            stats: stats,
            onManageOfficials: () => onNavigateToSection?.call(
              TournamentDashboardSection.officials,
            ),
          ),
          _QrSharingSection(tournament: current),
          _RecentActivitySection(activity: activity),
          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(tournamentProvider(tournamentId));
    ref.invalidate(tournamentGroupsProvider(tournamentId));
    ref.invalidate(tournamentMatchesProvider(tournamentId));
    ref.invalidate(tournamentOfficialsProvider(tournamentId));
    ref.invalidate(tournamentSponsorsProvider(tournamentId));
  }
}

class _OrganizerSection extends StatelessWidget {
  const _OrganizerSection({
    required this.tournament,
    required this.organizerAsync,
    required this.canViewContact,
  });

  final TournamentModel tournament;
  final AsyncValue<UserModel?> organizerAsync;
  final bool canViewContact;

  @override
  Widget build(BuildContext context) {
    final meta = tournament.setupMeta;
    final profile = organizerAsync.valueOrNull;
    final name = _organizerName(profile, meta);
    final location = profile?.location.displayLabel.isNotEmpty == true
        ? profile!.location.displayLabel
        : tournament.location.displayLabel;

    return TournamentOverviewSectionCard(
      title: 'Organizer',
      child: organizerAsync.isLoading
          ? const Padding(
              padding: EdgeInsets.all(AppDimens.spaceMd),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: profile?.photoUrl != null
                        ? CachedNetworkImageProvider(profile!.photoUrl!)
                        : null,
                    child: profile?.photoUrl == null
                        ? const Icon(Icons.person_outline)
                        : null,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('Tournament organizer'),
                  trailing: profile?.playerId != null
                      ? IconButton(
                          tooltip: 'View profile',
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => context.push(
                            '/player/${profile!.playerId}',
                          ),
                        )
                      : null,
                  onTap: profile?.playerId != null
                      ? () => context.push('/player/${profile!.playerId}')
                      : null,
                ),
                if (location.isNotEmpty)
                  TournamentOverviewDetailRow(label: 'Location', value: location),
                if (canViewContact) ...[
                  if (meta.organizerPhone.trim().isNotEmpty)
                    TournamentOverviewDetailRow(
                      label: 'Phone',
                      value: meta.organizerPhone.trim(),
                    ),
                  if (meta.organizerEmail.trim().isNotEmpty)
                    TournamentOverviewDetailRow(
                      label: 'Email',
                      value: meta.organizerEmail.trim(),
                    ),
                ],
                if (profile?.playerId != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          context.push('/player/${profile!.playerId}'),
                      icon: const Icon(Icons.person_search_outlined, size: 18),
                      label: const Text('View profile'),
                    ),
                  ),
              ],
            ),
    );
  }

  String _organizerName(UserModel? profile, TournamentSetupMeta meta) {
    if (profile != null) {
      final display = profile.displayName.trim();
      if (display.isNotEmpty) return display;
      final legal = profile.name.trim();
      if (legal.isNotEmpty) return legal;
    }
    final metaName = meta.organizerName.trim();
    if (metaName.isNotEmpty) return metaName;
    return 'Organizer';
  }
}

class _TournamentInfoSection extends StatelessWidget {
  const _TournamentInfoSection({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final meta = tournament.setupMeta;
    final grounds = tournament.grounds
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toList();

    return TournamentOverviewSectionCard(
      title: 'Tournament information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TournamentOverviewDetailRow(
            label: 'Type',
            value: tournamentCricketMatchTypeLabel(meta.cricketMatchType),
          ),
          TournamentOverviewDetailRow(
            label: 'Category',
            value: tournamentCategoryLabel(meta.category),
          ),
          if (tournament.ballType != null)
            TournamentOverviewDetailRow(
              label: 'Ball type',
              value: cricketBallTypeLabel(tournament.ballType!),
            ),
          if (tournament.pitchType != null)
            TournamentOverviewDetailRow(
              label: 'Pitch type',
              value: pitchTypeLabel(tournament.pitchType!),
            ),
          TournamentOverviewDetailRow(
            label: 'Entry fee',
            value: formatEntryFee(tournament.entryFee),
          ),
          TournamentOverviewDetailRow(
            label: 'Prize pool',
            value: formatPrizePool(tournament),
          ),
          if (grounds.isNotEmpty)
            _GroundsRows(
              grounds: grounds,
              cityLabel: tournament.location.displayLabel,
            ),
          if (tournament.tournamentCode != null &&
              tournament.tournamentCode!.trim().isNotEmpty)
            TournamentOverviewDetailRow(
              label: 'Tournament code',
              value: tournament.tournamentCode!,
            ),
          if (tournament.description.trim().isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Description',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.cf.textMuted,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              tournament.description.trim(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.cf.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroundsRows extends StatelessWidget {
  const _GroundsRows({
    required this.grounds,
    required this.cityLabel,
  });

  final List<String> grounds;
  final String cityLabel;

  String _queryFor(String ground) {
    final city = cityLabel.trim();
    return city.isEmpty ? ground : '$ground, $city';
  }

  Future<void> _openMaps(BuildContext context, String query) async {
    final ok = await openVenueInGoogleMaps(query: query);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final label = grounds.length == 1 ? 'Ground' : 'Grounds';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textMuted,
                  ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < grounds.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                    child: InkWell(
                      onTap: () => _openMaps(context, _queryFor(grounds[i])),
                      child: Text(
                        grounds[i],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cf.accent,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamInfoSection extends StatelessWidget {
  const _TeamInfoSection({
    required this.tournament,
    required this.registeredCount,
    this.onViewTeams,
  });

  final TournamentModel tournament;
  final int registeredCount;
  final VoidCallback? onViewTeams;

  @override
  Widget build(BuildContext context) {
    final meta = tournament.setupMeta;
    final totalTeams = meta.totalTeams;
    final requiredTeams = meta.teamsRequired;

    return TournamentOverviewSectionCard(
      title: 'Team information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalTeams != null)
            TournamentOverviewDetailRow(
              label: 'Total teams',
              value: '$totalTeams',
            ),
          if (requiredTeams != null)
            TournamentOverviewDetailRow(
              label: 'Required teams',
              value: '$requiredTeams',
            ),
          TournamentOverviewDetailRow(
            label: 'Registered teams',
            value: '$registeredCount',
          ),
          TournamentOverviewDetailRow(
            label: 'Format',
            value: tournamentFormatLabel(tournament.format),
          ),
          if (registeredCount == 0)
            const TournamentOverviewEmptyInline(
              message: 'No teams added yet.',
              icon: Icons.groups_outlined,
            ),
          if (onViewTeams != null) ...[
            const SizedBox(height: AppDimens.spaceSm),
            CfButton(
              label: 'View teams',
              isOutlined: true,
              compact: true,
              onPressed: onViewTeams,
            ),
          ],
        ],
      ),
    );
  }
}

class _OfficialsInfoSection extends StatelessWidget {
  const _OfficialsInfoSection({
    required this.tournament,
    required this.stats,
    this.onManageOfficials,
  });

  final TournamentModel tournament;
  final TournamentOverviewStats stats;
  final VoidCallback? onManageOfficials;

  @override
  Widget build(BuildContext context) {
    final permissions = tournament.setupMeta.requiredOfficialRoles;

    return TournamentOverviewSectionCard(
      title: 'Officials',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final role in TournamentOfficialRole.values)
            TournamentOverviewDetailRow(
              label: tournamentOfficialRoleLabel(role),
              value: '${stats.officialsByRole[role] ?? 0}',
            ),
          if (stats.officialCount == 0 && permissions.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Needed: ${permissions.map(tournamentOfficialRoleSingular).join(', ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.cf.textSecondary,
                  ),
            ),
          ],
          if (stats.officialCount == 0)
            const TournamentOverviewEmptyInline(
              message: 'No officials added yet.',
              icon: Icons.verified_user_outlined,
            ),
          if (onManageOfficials != null) ...[
            const SizedBox(height: AppDimens.spaceSm),
            CfButton(
              label: 'Manage officials',
              isOutlined: true,
              compact: true,
              onPressed: onManageOfficials,
            ),
          ],
        ],
      ),
    );
  }
}

class _QrSharingSection extends ConsumerStatefulWidget {
  const _QrSharingSection({required this.tournament});

  final TournamentModel tournament;

  @override
  ConsumerState<_QrSharingSection> createState() => _QrSharingSectionState();
}

class _QrSharingSectionState extends ConsumerState<_QrSharingSection> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final tournament = widget.tournament;
    final joinLink =
        DeepLinkUtils.hostedTournamentJoinUri(tournament.id).toString();

    return TournamentOverviewSectionCard(
      title: 'QR & sharing',
      child: Column(
        children: [
          TournamentQrView(tournament: tournament, showCode: false),
          const SizedBox(height: AppDimens.spaceSm),
          SelectableText(
            joinLink,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Let cricketers find this tournament easily with this QR code.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Row(
            children: [
              Expanded(
                child: _QrActionButton(
                  icon: Icons.copy_outlined,
                  label: 'Copy link',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: joinLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite link copied')),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: _QrActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onPressed: () => Share.share(
                    'Join ${tournament.name} on CrickFlow\n$joinLink',
                    subject: tournament.name,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: _QrActionButton(
                  icon: Icons.download_outlined,
                  label: 'Download',
                  isLoading: _downloading,
                  onPressed: _downloading ? null : () => _downloadQr(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadQr(BuildContext context) async {
    final accent = context.cf.accent;
    setState(() => _downloading = true);
    try {
      final bytes = await ref
          .read(tournamentQrExportServiceProvider)
          .renderShareCard(
            tournament: widget.tournament,
            accentColor: accent,
          );
      final safeName = widget.tournament.name
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final fileName = '${safeName.isEmpty ? 'tournament' : safeName}_qr.png';

      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: 'image/png',
          ),
        ],
        subject: widget.tournament.name,
        text:
            'Join ${widget.tournament.name} on CrickFlow\n${DeepLinkUtils.hostedTournamentJoinUri(widget.tournament.id)}',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not prepare QR: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }
}

class _QrActionButton extends StatelessWidget {
  const _QrActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        minimumSize: const Size(0, 52),
      ),
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({required this.activity});

  final List<TournamentActivityItem> activity;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return TournamentOverviewSectionCard(
      title: 'Recent activity',
      child: activity.isEmpty
          ? const TournamentOverviewEmptyInline(
              message: 'No recent activity yet.',
              icon: Icons.timeline_outlined,
            )
          : Column(
              children: [
                for (var i = 0; i < activity.length; i++) ...[
                  if (i > 0)
                    Divider(height: 20, color: cf.border.withValues(alpha: 0.6)),
                  _ActivityTile(item: activity[i]),
                ],
              ],
            ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final TournamentActivityItem item;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cf.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_iconFor(item.type), size: 18, color: cf.accent),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cf.textPrimary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cf.textSecondary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                AppDateUtils.timeAgo(item.timestamp),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cf.textMuted,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconFor(TournamentActivityType type) => switch (type) {
        TournamentActivityType.teamRegistered => Icons.groups_outlined,
        TournamentActivityType.fixtureGenerated => Icons.event_note_outlined,
        TournamentActivityType.matchScheduled => Icons.sports_cricket_outlined,
        TournamentActivityType.sponsorAdded => Icons.handshake_outlined,
        TournamentActivityType.officialAdded => Icons.verified_user_outlined,
        TournamentActivityType.groupCreated => Icons.view_module_outlined,
        TournamentActivityType.tournamentUpdated => Icons.update_outlined,
      };
}

/// Backward-compatible alias used by the dashboard tab bar.
typedef TournamentOverviewTab = TournamentOverviewScreen;
