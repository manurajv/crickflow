import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_gate.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../domain/services/series/org_competition_access.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import '../../../shared/widgets/removed_content_view.dart';
import 'tabs/org_leaderboard_tab.dart';
import 'tabs/org_matches_tab.dart';
import 'tabs/org_tournaments_tab.dart';
import 'series_announcements_screen.dart';
import 'widgets/series_status_banner.dart';
import 'widgets/series_user_name.dart';
import 'widgets/org_welcome_sheet.dart';
import 'widgets/series_ui.dart';

/// Orgs profile hub — Associations / Clubs / Series share this screen.
/// Tournament-style collapsing cover + logo + pinned tabs.
class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({
    super.key,
    required this.seriesId,
    this.initialTab,
  });
  final String seriesId;

  /// overview · matches · tournaments · leaderboard · teams · about
  final String? initialTab;

  static const tabSlugs = [
    'overview',
    'matches',
    'tournaments',
    'leaderboard',
    'teams',
    'about',
  ];

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final ScrollController _scrollController;
  bool _showAppBarTitle = false;
  double _titleThreshold = 0;

  static const _coverHeight = 168.0;

  bool _welcomeChecked = false;

  @override
  void initState() {
    super.initState();
    final initial = SeriesDetailScreen.tabSlugs.indexOf(
      widget.initialTab ?? '',
    );
    _tabs =
        TabController(
          length: SeriesDetailScreen.tabSlugs.length,
          vsync: this,
          initialIndex: initial < 0 ? 0 : initial,
        )..addListener(() {
          if (mounted) setState(() {});
        });
    _scrollController = ScrollController()..addListener(_syncTitleVisibility);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncTitleVisibility);
    _scrollController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _syncTitleVisibility() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset >= _titleThreshold;
    if (show == _showAppBarTitle) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final nextShow = _scrollController.offset >= _titleThreshold;
      if (nextShow != _showAppBarTitle) {
        setState(() => _showAppBarTitle = nextShow);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final seriesId = widget.seriesId;
    final series = ref.watch(seriesByIdProvider(seriesId));
    final role = ref.watch(mySeriesRoleProvider(seriesId));
    final canAdmin = role.isFullOrgAdmin;
    final canStaff = role.isOrgStaff;
    final access = ref.watch(orgCompetitionAccessProvider(seriesId));
    if (canAdmin) ref.watch(orgTeamLinkMigrationProvider(seriesId));

    return series.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: const CfChromeAppBar(title: Text('Organization')),
        body: Center(child: Text('$e')),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: const CfChromeAppBar(title: Text('Organization')),
            body: const RemovedContentView(kind: 'organization'),
          );
        }

        final membersTab = item.memberUnitsTabLabel;
        final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
        _titleThreshold = _coverHeight - topInset - 1;
        _scheduleWelcomeIfNeeded(item, canAdmin);

        final appBarTheme = Theme.of(context).appBarTheme;
        final tabBar = TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: cf.accent,
          labelColor: cf.accent,
          unselectedLabelColor: cf.textSecondary,
          dividerColor: cf.border,
          tabs: [
            const Tab(text: 'Overview'),
            const Tab(text: 'Matches'),
            const Tab(text: 'Tournaments'),
            const Tab(text: 'Leaderboard'),
            Tab(text: membersTab),
            const Tab(text: 'About'),
          ],
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value:
              appBarTheme.systemOverlayStyle ??
              (cf.isLight
                  ? SystemUiOverlayStyle.dark
                  : SystemUiOverlayStyle.light),
          child: Scaffold(
            backgroundColor: cf.background,
            floatingActionButton: _orgFab(
              context: context,
              seriesId: seriesId,
              item: item,
              access: access,
              cf: cf,
            ),
            body: NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                final collapsed = innerBoxIsScrolled || _showAppBarTitle;
                final chromeFg = cf.chromeForeground;
                final overlayFg = collapsed ? chromeFg : Colors.white;

                return [
                  SliverAppBar(
                    expandedHeight: _coverHeight,
                    pinned: true,
                    stretch: false,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    backgroundColor: cf.chromeBackground,
                    foregroundColor: overlayFg,
                    iconTheme: IconThemeData(color: overlayFg),
                    actionsIconTheme: IconThemeData(color: overlayFg),
                    elevation: appBarTheme.elevation ?? 0,
                    scrolledUnderElevation:
                        appBarTheme.scrolledUnderElevation ?? 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: overlayFg,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(OrgFamily.forKind(item.kind).routePath);
                        }
                      },
                    ),
                    title: _showAppBarTitle
                        ? Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                appBarTheme.titleTextStyle?.copyWith(
                                  color: chromeFg,
                                  fontWeight: FontWeight.w700,
                                ) ??
                                Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  color: chromeFg,
                                  fontWeight: FontWeight.w700,
                                ),
                          )
                        : null,
                    actions: [
                      if (canStaff)
                        IconButton(
                          tooltip: 'Approvals',
                          onPressed: () =>
                              context.push('/series/$seriesId/approvals'),
                          icon: Icon(
                            Icons.fact_check_outlined,
                            color: overlayFg,
                          ),
                        ),
                      if (canAdmin)
                        IconButton(
                          tooltip: 'Settings',
                          onPressed: () =>
                              context.push('/series/$seriesId/settings'),
                          icon: Icon(Icons.settings_outlined, color: overlayFg),
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      background: _OrgHeaderBanner(series: item),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _OrgTabBarDelegate(tabBar, cf.surface),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabs,
                children: [
                  _Overview(series: item, canAdmin: canAdmin),
                  OrgMatchesTab(seriesId: seriesId),
                  OrgTournamentsTab(seriesId: seriesId),
                  OrgLeaderboardTab(seriesId: seriesId, series: item),
                  _MemberUnits(seriesId: seriesId, series: item),
                  _About(series: item),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _scheduleWelcomeIfNeeded(SeriesModel item, bool canAdmin) {
    if (_welcomeChecked || !canAdmin) return;
    _welcomeChecked = true;
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    if (uid.isEmpty) return;
    final force =
        GoRouterState.of(context).uri.queryParameters['welcome'] == '1';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      maybeShowOrgWelcome(
        context,
        seriesId: item.id,
        uid: uid,
        orgLabel: item.kind.label,
        forceFromCreate: force,
      );
    });
  }

  Widget? _orgFab({
    required BuildContext context,
    required String seriesId,
    required SeriesModel item,
    required OrgCompetitionAccess access,
    required CfColors cf,
  }) {
    final index = _tabs.index;
    Widget? fab;
    if (index == 1) {
      // Matches
      if (access.match == OrgStartMode.none) {
        fab = null;
      } else {
        final label = OrgCompetitionAccess.actionLabel(
          access.match,
          tournament: false,
        );
        fab = FloatingActionButton.extended(
          key: const ValueKey('org_fab_match'),
          heroTag: 'org_fab_match',
          backgroundColor: cf.fabBackground,
          foregroundColor: cf.fabForeground,
          onPressed: () => requireLogin(
            context: context,
            ref: ref,
            prompt: SignInPrompt.proposeMatch,
            returnPath: '/series/$seriesId/propose-match',
            action: () async {
              if (context.mounted) {
                context.push('/series/$seriesId/propose-match');
              }
            },
          ),
          icon: const Icon(Icons.sports_cricket_outlined),
          label: Text(label),
        );
      }
    } else if (index == 2) {
      // Tournaments
      if (access.tournament == OrgStartMode.none) {
        fab = null;
      } else {
        final label = OrgCompetitionAccess.actionLabel(
          access.tournament,
          tournament: true,
        );
        fab = FloatingActionButton.extended(
          key: const ValueKey('org_fab_tournament'),
          heroTag: 'org_fab_tournament',
          backgroundColor: cf.fabBackground,
          foregroundColor: cf.fabForeground,
          onPressed: () => requireLogin(
            context: context,
            ref: ref,
            prompt: SignInPrompt.proposeTournament,
            returnPath: '/series/$seriesId/propose-tournament',
            action: () async {
              if (context.mounted) {
                context.push('/series/$seriesId/propose-tournament');
              }
            },
          ),
          icon: const Icon(Icons.emoji_events_outlined),
          label: Text(label),
        );
      }
    } else if (index == 4) {
      // Teams / member units
      fab = FloatingActionButton.extended(
        key: const ValueKey('org_fab_team'),
        heroTag: 'org_fab_team',
        backgroundColor: cf.fabBackground,
        foregroundColor: cf.fabForeground,
        onPressed: () => requireLogin(
          context: context,
          ref: ref,
          prompt: SignInPrompt.createOrgTeam,
          returnPath: '/series/$seriesId/clubs/create',
          action: () async {
            if (context.mounted) {
              context.push('/series/$seriesId/clubs/create');
            }
          },
        ),
        icon: const Icon(Icons.add),
        label: Text(item.memberUnitsSingular),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: anim,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: fab ?? const SizedBox.shrink(key: ValueKey('org_fab_none')),
    );
  }
}

class _OrgTabBarDelegate extends SliverPersistentHeaderDelegate {
  _OrgTabBarDelegate(this.tabBar, this.bg);

  final TabBar tabBar;
  final Color bg;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(color: bg, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _OrgTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar || bg != oldDelegate.bg;
}

class _OrgHeaderBanner extends StatelessWidget {
  const _OrgHeaderBanner({required this.series});

  final SeriesModel series;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final hasCover =
        series.coverImageUrl != null && series.coverImageUrl!.isNotEmpty;
    final hasLogo = series.logoUrl != null && series.logoUrl!.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasCover)
          CachedNetworkImage(imageUrl: series.coverImageUrl!, fit: BoxFit.cover)
        else
          DecoratedBox(decoration: BoxDecoration(gradient: cf.heroGradient)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.15), cf.bannerScrimEnd],
            ),
          ),
        ),
        Positioned(
          left: AppDimens.spaceMd,
          right: AppDimens.spaceMd,
          bottom: AppDimens.spaceMd,
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: hasLogo
                    ? CachedNetworkImageProvider(series.logoUrl!)
                    : null,
                child: hasLogo
                    ? null
                    : Text(
                        series.name.isNotEmpty
                            ? series.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      series.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      series.subtitleMeta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      series.kind.label,
                      style: TextStyle(
                        color: cf.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.series, required this.canAdmin});
  final SeriesModel series;
  final bool canAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final pending = canAdmin
        ? (ref.watch(pendingSeriesApprovalsProvider(series.id)).valueOrNull ??
              const <SeriesApprovalModel>[])
        : const <SeriesApprovalModel>[];
    final announcements =
        ref.watch(seriesAnnouncementsProvider(series.id)).valueOrNull ??
        const <SeriesAnnouncementModel>[];
    final audit = canAdmin
        ? (ref.watch(seriesAuditLogsProvider(series.id)).valueOrNull ??
              const <SeriesAuditLogModel>[])
        : const <SeriesAuditLogModel>[];

    return ListView(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      children: [
        if (series.status != SeriesStatus.active || series.platformHold) ...[
          SeriesStatusBanner(series: series),
          const SizedBox(height: AppDimens.spaceMd),
        ],
        if (canAdmin) ...[
          ListTile(
            tileColor: cf.accent.withValues(alpha: cf.isLight ? 0.08 : 0.14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Icon(Icons.fact_check_outlined, color: cf.accent),
            title: const Text('Pending approvals'),
            subtitle: Text(
              pending.isEmpty
                  ? 'All caught up'
                  : '${pending.length} waiting for review',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pending.isNotEmpty)
                  Badge(
                    label: Text('${pending.length}'),
                    backgroundColor: cf.accent,
                    textColor: cf.onAccent,
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.push('/series/${series.id}/approvals'),
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
        Text(
          series.description.isEmpty
              ? 'Official CrickFlow ${series.kind.label.toLowerCase()}'
              : series.description,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppDimens.spaceLg),
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
            SeriesStat(series.tournamentCount, 'Tournaments'),
          ],
        ),
        const SizedBox(height: AppDimens.spaceLg),
        Row(
          children: [
            Expanded(
              child: Text(
                'Latest announcements',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () =>
                  context.push('/series/${series.id}/announcements'),
              child: const Text('See all'),
            ),
          ],
        ),
        if (announcements.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
            child: Text(
              'No announcements yet',
              style: TextStyle(color: cf.textSecondary),
            ),
          )
        else ...[
          for (final a in announcements.take(2)) ...[
            SeriesAnnouncementCard(announcement: a),
            const SizedBox(height: AppDimens.spaceSm),
          ],
          const SizedBox(height: AppDimens.spaceSm),
        ],
        ListTile(
          tileColor: cf.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(Icons.inbox_outlined, color: cf.accent),
          title: const Text('My requests'),
          subtitle: const Text('Track join and registration status'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/series/${series.id}/my-requests'),
        ),
        if (canAdmin) ...[
          const SizedBox(height: AppDimens.spaceSm),
          ListTile(
            tileColor: cf.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Icon(
              Icons.admin_panel_settings_outlined,
              color: cf.accent,
            ),
            title: const Text('Admins'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/series/${series.id}/admins'),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/series/${series.id}/audit'),
                child: const Text('See all'),
              ),
            ],
          ),
          if (audit.isEmpty)
            Text('No activity yet', style: TextStyle(color: cf.textSecondary))
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
                        style: TextStyle(color: cf.textSecondary, fontSize: 12),
                      ),
                    ),
                    Text(
                      ' · ${seriesShortDate(log.timestamp)}',
                      style: TextStyle(color: cf.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
        ],
      ],
    );
  }
}

class _About extends StatelessWidget {
  const _About({required this.series});
  final SeriesModel series;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return ListView(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      children: [
        Text('About', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          series.description.isEmpty
              ? 'No description yet.'
              : series.description,
        ),
        if (series.country.isNotEmpty ||
            series.region.isNotEmpty ||
            series.location.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceLg),
          Text('Location', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(series.subtitleMeta),
        ],
        if (series.rulesText.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceLg),
          Text(
            'Rules / playing conditions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(series.rulesText),
        ],
        const SizedBox(height: AppDimens.spaceLg),
        Text(
          'Max team squad: ${series.settings.maxSquadSize}',
          style: TextStyle(color: cf.textSecondary),
        ),
      ],
    );
  }
}

class _MemberUnits extends ConsumerWidget {
  const _MemberUnits({required this.seriesId, required this.series});
  final String seriesId;
  final SeriesModel series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(clubsForSeriesProvider(seriesId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (clubs) {
            final qController = TextEditingController();
            return _MemberUnitsSearchableList(
              seriesId: seriesId,
              series: series,
              clubs: clubs,
              searchController: qController,
            );
          },
        );
  }
}

class _MemberUnitsSearchableList extends StatefulWidget {
  const _MemberUnitsSearchableList({
    required this.seriesId,
    required this.series,
    required this.clubs,
    required this.searchController,
  });

  final String seriesId;
  final SeriesModel series;
  final List<SeriesClubModel> clubs;
  final TextEditingController searchController;

  @override
  State<_MemberUnitsSearchableList> createState() =>
      _MemberUnitsSearchableListState();
}

class _MemberUnitsSearchableListState
    extends State<_MemberUnitsSearchableList> {
  String _q = '';

  @override
  void dispose() {
    widget.searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final unit = widget.series.memberUnitsSingular.toLowerCase();
    final filtered = _q.isEmpty
        ? widget.clubs
        : widget.clubs
              .where((c) => c.name.toLowerCase().contains(_q.toLowerCase()))
              .toList();
    if (widget.clubs.isEmpty) {
      return SeriesEmptyState(
        icon: Icons.shield_outlined,
        title: 'No ${widget.series.memberUnitsStatLabel.toLowerCase()} yet',
        message: 'Create a $unit to request membership.',
        action: FilledButton.icon(
          onPressed: () =>
              context.push('/series/${widget.seriesId}/clubs/create'),
          icon: const Icon(Icons.add),
          label: Text('Create $unit'),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: TextField(
            controller: widget.searchController,
            onChanged: (v) => setState(() => _q = v),
            decoration: orgSearchDecoration(context),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: cf.border),
            itemBuilder: (_, i) {
              final club = filtered[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: cf.accent.withValues(
                    alpha: cf.isLight ? 0.1 : 0.15,
                  ),
                  backgroundImage: club.logoUrl == null
                      ? null
                      : NetworkImage(club.logoUrl!),
                  child: club.logoUrl == null
                      ? Text(
                          club.name.isNotEmpty
                              ? club.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(color: cf.accent),
                        )
                      : null,
                ),
                title: Text(club.name),
                subtitle: Text(club.status.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push('/series/${widget.seriesId}/clubs/${club.id}'),
              );
            },
          ),
        ),
      ],
    );
  }
}
