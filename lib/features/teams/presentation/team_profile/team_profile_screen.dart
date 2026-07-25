import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/cf_colors.dart';
import '../../../../features/my_cricket_profile/presentation/widgets/profile_match_filter_button.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/team_profile_provider.dart';
import '../utils/team_squad_utils.dart';
import 'tabs/team_info_tab.dart';
import 'tabs/team_leaderboard_tab.dart';
import 'tabs/team_matches_tab.dart';
import 'tabs/team_members_tab.dart';
import 'tabs/team_stats_tab.dart';
import 'tabs/team_trophies_tab.dart';
import 'widgets/team_profile_empty_state.dart';
import 'widgets/team_profile_header.dart';

/// CricHeroes-style team profile hub:
/// Matches · Leaderboard · Stats · Members · Trophies · Profile.
class TeamProfileScreen extends ConsumerStatefulWidget {
  const TeamProfileScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends ConsumerState<TeamProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late ScrollController _scrollController;
  bool _showAppBarTitle = false;
  double _titleThreshold = 0;
  var _recordedView = false;

  void _syncTitleVisibility() {
    if (_tabs.indexIsChanging || !_scrollController.hasClients) return;
    final show = _scrollController.offset >= _titleThreshold;
    if (show == _showAppBarTitle) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tabs.indexIsChanging || !_scrollController.hasClients) {
        return;
      }
      final nextShow = _scrollController.offset >= _titleThreshold;
      if (nextShow != _showAppBarTitle) {
        setState(() => _showAppBarTitle = nextShow);
      }
    });
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    setState(() {});
    _syncTitleVisibility();
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _scrollController = ScrollController()..addListener(_syncTitleVisibility);
    _tabs.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _scrollController.removeListener(_syncTitleVisibility);
    _scrollController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _showMoreMenu(BuildContext context) {
    final uid = ref.read(authStateProvider).value?.uid;
    final team = ref.read(teamByIdProvider(widget.teamId)).valueOrNull;
    final isOwner = team != null && TeamSquadUtils.isTeamOwner(uid, team);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit team'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/teams/${widget.teamId}/edit');
                },
              ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('View squad'),
              onTap: () {
                Navigator.pop(ctx);
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _trackView({
    required String? ownerId,
  }) async {
    if (_recordedView) return;
    final viewerId = ref.read(authStateProvider).value?.uid;
    if (viewerId == null || viewerId.isEmpty) return;
    _recordedView = true;
    try {
      await ref.read(teamFollowRepositoryProvider).recordProfileView(
            teamId: widget.teamId,
            viewerUserId: viewerId,
            teamOwnerUserId: ownerId,
          );
    } catch (_) {
      _recordedView = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final snapAsync = ref.watch(teamProfileSnapshotProvider(widget.teamId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: cf.surface,
        body: snapAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => TeamProfileEmptyState(
            icon: Icons.error_outline,
            title: 'Unable to load team',
            subtitle: '$e',
          ),
          data: (snap) {
            final title = snap.team.name;
            final expandedHeight = TeamProfileHeader.expandedHeight(context);
            final topInset =
                MediaQuery.paddingOf(context).top + kToolbarHeight;
            _titleThreshold = expandedHeight - topInset - 1;
            final barColor = TeamProfileHeader.heroBarColor(cf);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _trackView(ownerId: snap.team.createdBy);
            });

            return NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  expandedHeight: expandedHeight,
                  pinned: true,
                  stretch: false,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  backgroundColor: barColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.white,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  title: _showAppBarTitle
                      ? Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        )
                      : null,
                  actions: [
                    if (_tabs.index == 0 ||
                        _tabs.index == 1 ||
                        _tabs.index == 2)
                      ProfileMatchFilterButton(
                        matches: snap.matches,
                        iconOnly: true,
                        iconColor: Colors.white,
                        filtersProvider: teamProfileMatchFiltersProvider,
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration:
                              BoxDecoration(gradient: cf.heroGradient),
                        ),
                        Positioned(
                          top: topInset,
                          left: 0,
                          right: 0,
                          child: TeamProfileHeader(
                            snapshot: snap,
                            onMore: () => _showMoreMenu(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TeamTabBarDelegate(
                    TabBar(
                      controller: _tabs,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: cf.accent,
                      labelColor: cf.accent,
                      unselectedLabelColor: cf.textSecondary,
                      dividerColor: cf.border,
                      tabs: const [
                        Tab(text: 'Matches'),
                        Tab(text: 'Leaderboard'),
                        Tab(text: 'Stats'),
                        Tab(text: 'Members'),
                        Tab(text: 'Trophies'),
                        Tab(text: 'Profile'),
                      ],
                    ),
                    cf.surface,
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabs,
                children: [
                  TeamMatchesTab(teamId: widget.teamId),
                  TeamLeaderboardTab(teamId: widget.teamId),
                  TeamStatsTab(teamId: widget.teamId),
                  TeamMembersTab(teamId: widget.teamId),
                  TeamTrophiesTab(teamId: widget.teamId),
                  TeamInfoTab(teamId: widget.teamId),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TeamTabBarDelegate extends SliverPersistentHeaderDelegate {
  _TeamTabBarDelegate(this.tabBar, this.bg);

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
  bool shouldRebuild(covariant _TeamTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar || bg != oldDelegate.bg;
}
