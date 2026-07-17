import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../core/navigation/tournament_join_navigation.dart';
import '../../../data/models/tournament_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import '../../../shared/providers/tournament_lifecycle_provider.dart';
import 'tournament_teams_screen.dart';
import 'tournament_matches_screen.dart';
import 'tournament_groups_screen.dart';
import 'tabs/tournament_dashboard_tabs.dart';
import 'tabs/tournament_officials_tab.dart';
import 'tabs/tournament_stats_tab.dart';
import 'tabs/tournament_heroes_tab.dart';
import 'tabs/tournament_leaderboard_tab.dart';
import 'tabs/tournament_summary_tab.dart';
import 'tournament_dashboard_sections.dart';
import 'tournament_overview_screen.dart';
import 'widgets/tournament_share_sheet.dart';

class TournamentDashboardScreen extends ConsumerStatefulWidget {
  const TournamentDashboardScreen({
    super.key,
    required this.tournamentId,
    this.initialSection = TournamentDashboardSection.overview,
  });

  final String tournamentId;
  final TournamentDashboardSection initialSection;

  @override
  ConsumerState<TournamentDashboardScreen> createState() =>
      _TournamentDashboardScreenState();
}

class _TournamentDashboardScreenState
    extends ConsumerState<TournamentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late ScrollController _scrollController;
  bool _showAppBarTitle = false;
  double _titleThreshold = 0;
  bool _isCompleted = false;

  static const _coverHeight = 168.0;

  List<String> get _labels =>
      TournamentDashboardSection.labelsForStatus(_isCompleted);

  List<TournamentDashboardSection> get _sections =>
      TournamentDashboardSection.tabOrderForStatus(_isCompleted);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: _labels.length,
      vsync: this,
      initialIndex: TournamentDashboardSection.tabOrder
          .indexOf(widget.initialSection),
    );
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
    final uid = ref.watch(authStateProvider).value?.uid;
    final tournamentAsync = ref.watch(tournamentProvider(widget.tournamentId));
    final role = ref.watch(
      tournamentMemberRoleProvider((widget.tournamentId, uid)),
    );

    // Trigger automatic lifecycle status sync.
    ref.watch(tournamentLifecycleAutoSyncProvider(widget.tournamentId));

    return tournamentAsync.when(
      data: (tournament) {
        if (tournament == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tournament')),
            body: const Center(child: Text('Tournament not found')),
          );
        }

        // Rebuild tab controller if completed state changes.
        final nowCompleted =
            tournament.status == TournamentStatus.completed;
        if (nowCompleted != _isCompleted) {
          _isCompleted = nowCompleted;
          final prevIndex = _tabs.index;
          _tabs.dispose();
          final newLabels =
              TournamentDashboardSection.labelsForStatus(_isCompleted);
          _tabs = TabController(
            length: newLabels.length,
            vsync: this,
            initialIndex: prevIndex.clamp(0, newLabels.length - 1),
          );
        }

        final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
        _titleThreshold = _coverHeight - topInset - 1;

        final appBarTheme = Theme.of(context).appBarTheme;
        final tabBar = TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: cf.accent,
          labelColor: cf.accent,
          unselectedLabelColor: cf.textSecondary,
          dividerColor: cf.border,
          tabs: _labels.map((l) => Tab(text: l)).toList(),
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: appBarTheme.systemOverlayStyle ??
              (cf.isLight
                  ? SystemUiOverlayStyle.dark
                  : SystemUiOverlayStyle.light),
          child: Scaffold(
            backgroundColor: cf.background,
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
                  scrolledUnderElevation: appBarTheme.scrolledUnderElevation ?? 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: overlayFg,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        goToMyCricketTournamentsTab(ref, context);
                      }
                    },
                  ),
                  title: _showAppBarTitle
                      ? Text(
                          tournament.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appBarTheme.titleTextStyle?.copyWith(
                                color: chromeFg,
                                fontWeight: FontWeight.w700,
                              ) ??
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: chromeFg,
                                    fontWeight: FontWeight.w700,
                                  ),
                        )
                      : null,
                  actions: [
                    IconButton(
                      tooltip: 'Share',
                      icon: Icon(Icons.share_outlined, color: overlayFg),
                      onPressed: () => showTournamentShareSheet(
                        context,
                        tournament: tournament,
                      ),
                    ),
                    if (role == TournamentRole.owner ||
                        role == TournamentRole.admin)
                      IconButton(
                        tooltip: 'Edit',
                        icon: Icon(Icons.edit_outlined, color: overlayFg),
                        onPressed: () => context.push(
                          '/tournaments/${widget.tournamentId}/edit',
                        ),
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: _TournamentHeaderBanner(tournament: tournament),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TournamentTabBarDelegate(tabBar, cf.surface),
                ),
              ];
              },
              body: TabBarView(
                controller: _tabs,
                children: [
                  TournamentOverviewScreen(
                    tournamentId: widget.tournamentId,
                    tournament: tournament,
                    role: role,
                    onNavigateToSection: (TournamentDashboardSection section) {
                      final index = _sections.indexOf(section);
                      if (index >= 0) _tabs.animateTo(index);
                    },
                  ),
                  TournamentMatchesTab(
                    tournament: tournament,
                    role: role,
                  ),
                  TournamentLeaderboardTab(tournamentId: widget.tournamentId),
                  TournamentPointsTab(tournament: tournament),
                  TournamentStatsTab(tournamentId: widget.tournamentId),
                  TournamentTeamsTab(tournament: tournament, role: role),
                  TournamentGroupsTab(tournament: tournament, role: role),
                  TournamentFixturesTab(tournament: tournament, role: role),
                  TournamentOfficialsTab(
                    tournamentId: widget.tournamentId,
                    role: role,
                  ),
                  TournamentSponsorsTab(
                    tournamentId: widget.tournamentId,
                    role: role,
                  ),
                  TournamentHeroesTab(tournamentId: widget.tournamentId),
                  TournamentRulesTab(
                    tournamentId: widget.tournamentId,
                    role: role,
                  ),
                  TournamentSettingsTab(tournament: tournament, role: role),
                  if (_isCompleted)
                    TournamentSummaryTab(
                      tournamentId: widget.tournamentId,
                      tournament: tournament,
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Tournament')),
        body: Center(child: Text('$e', style: TextStyle(color: cf.error))),
      ),
    );
  }
}

class _TournamentTabBarDelegate extends SliverPersistentHeaderDelegate {
  _TournamentTabBarDelegate(this.tabBar, this.bg);

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
  bool shouldRebuild(covariant _TournamentTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar || bg != oldDelegate.bg;
}

class _TournamentHeaderBanner extends StatelessWidget {
  const _TournamentHeaderBanner({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (tournament.bannerUrl != null)
          CachedNetworkImage(
            imageUrl: tournament.bannerUrl!,
            fit: BoxFit.cover,
          )
        else
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A2744), AppColors.primaryBlue],
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
        Positioned(
          left: AppDimens.spaceMd,
          right: AppDimens.spaceMd,
          bottom: AppDimens.spaceMd,
          child: Row(
            children: [
              if (tournament.logoUrl != null)
                CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      CachedNetworkImageProvider(tournament.logoUrl!),
                )
              else
                const CircleAvatar(
                  radius: 24,
                  child: Icon(Icons.emoji_events, color: AppColors.gold),
                ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tournament.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (tournament.location.displayLabel.isNotEmpty)
                      Text(
                        tournament.location.displayLabel,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    if (tournament.tournamentCode != null)
                      Text(
                        tournament.tournamentCode!,
                        style: const TextStyle(
                          color: AppColors.gold,
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
