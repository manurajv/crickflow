import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/cf_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/services/player_cricket_profile_models.dart';
import '../../../shared/providers/player_cricket_profile_provider.dart';
import '../../../shared/providers/player_social_provider.dart';
import '../../../shared/providers/providers.dart';
import 'tabs/profile_badges_tab.dart';
import 'tabs/profile_connections_tab.dart';
import 'tabs/profile_matches_tab.dart';
import 'tabs/profile_stats_tab.dart';
import 'tabs/profile_teams_tab.dart';
import 'tabs/profile_trophies_tab.dart';
import 'widgets/cricket_profile_header.dart';
import 'widgets/profile_match_filter_button.dart';

/// CricHeroes-style cricket profile hub: Matches · Stats · Trophies · Badges · Teams · Connections.
class MyCricketProfileScreen extends ConsumerStatefulWidget {
  const MyCricketProfileScreen({
    super.key,
    this.playerId,
    this.playerDocId,
  });

  /// Public CF player id (CF000001).
  final String? playerId;

  /// Firestore player doc id — used when opening from player repository.
  final String? playerDocId;

  @override
  ConsumerState<MyCricketProfileScreen> createState() =>
      _MyCricketProfileScreenState();
}

class _MyCricketProfileScreenState extends ConsumerState<MyCricketProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late ScrollController _scrollController;
  bool _showAppBarTitle = false;
  double _titleThreshold = 0;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = ref.read(profileInitialTabProvider);
      if (initial > 0 && initial < _tabs.length) {
        _tabs.animateTo(initial);
        ref.read(profileInitialTabProvider.notifier).state = 0;
      }
    });
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _scrollController.removeListener(_syncTitleVisibility);
    _scrollController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final viewerId = ref.watch(authStateProvider).value?.uid;
    final resolvedPlayerId = widget.playerId;

    if (resolvedPlayerId != null) {
      final userAsync = ref.watch(userByPlayerIdProvider(resolvedPlayerId));
      return userAsync.when(
        data: (user) => _buildScaffold(
          cf: cf,
          user: user,
          viewerId: viewerId,
          title: user?.effectiveName ?? 'Cricket Profile',
        ),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      );
    }

    final profileAsync = ref.watch(myCricketProfileProvider);
    final user = ref.watch(currentUserProfileProvider).valueOrNull;

    return profileAsync.when(
      data: (snapshot) => _buildScaffold(
        cf: cf,
        user: user,
        viewerId: viewerId,
        snapshot: snapshot,
        title: user?.effectiveName ?? 'My Cricket Profile',
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }

  Widget _buildScaffold({
    required CfColors cf,
    required UserModel? user,
    required String? viewerId,
    required String title,
    PlayerCricketProfileSnapshot? snapshot,
  }) {
    final isOwn = user != null && viewerId == user.id;
    final playerDocId =
        snapshot?.player.id ?? widget.playerDocId ?? user?.id;

    if (playerDocId == null && snapshot == null && user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('Player profile not found')),
      );
    }

    final profileAsync = snapshot != null
        ? AsyncValue.data(snapshot)
        : playerDocId != null
            ? ref.watch(playerCricketProfileByIdProvider(playerDocId))
            : const AsyncValue<PlayerCricketProfileSnapshot?>.loading();

    final barColor = CricketProfileHeader.heroBarColor(cf);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: cf.surface,
        body: profileAsync.when(
          data: (snap) {
            if (snap == null) {
              return const Center(child: Text('No cricket profile data'));
            }
            final expandedHeight =
                CricketProfileHeader.expandedHeight(context);
            final topInset =
                MediaQuery.paddingOf(context).top + kToolbarHeight;
            // Title appears once the flexible profile card has fully collapsed.
            _titleThreshold = expandedHeight - topInset - 1;

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
                    if (_tabs.index == 0 || _tabs.index == 1)
                      ProfileMatchFilterButton(
                        matches: snap.participatedMatches,
                        iconOnly: true,
                        iconColor: Colors.white,
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
                          child: CricketProfileHeader(
                            user: user,
                            player: snap.player,
                            clusters: snap.clusters,
                            isOwnProfile: isOwn,
                            viewerId: viewerId,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
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
                          Tab(text: 'Stats'),
                          Tab(text: 'Trophies'),
                          Tab(text: 'Badges'),
                          Tab(text: 'Teams'),
                          Tab(text: 'Connections'),
                        ],
                      ),
                      cf.surface,
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabs,
                  children: [
                    ProfileMatchesTab(matches: snap.participatedMatches),
                    ProfileStatsTab(
                      player: snap.player,
                      matches: snap.participatedMatches,
                    ),
                    ProfileTrophiesTab(trophies: snap.trophies),
                    ProfileBadgesTab(badges: snap.badges),
                    ProfileTeamsTab(teams: snap.teams),
                    ProfileConnectionsTab(
                      userId: user?.id ?? snap.player.userId ?? '',
                      playerId: user?.playerId ?? snap.player.playerId ?? '',
                      isOwnProfile: isOwn,
                      viewerId: viewerId,
                    ),
                  ],
                ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar, this.bg);

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
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar || bg != oldDelegate.bg;
}
