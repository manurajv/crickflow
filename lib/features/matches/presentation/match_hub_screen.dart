import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/match_share_utils.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/match_model.dart';
import '../../../data/repositories/match_audience_repository.dart';
import '../../../shared/providers/match_audience_provider.dart';
import '../../../shared/providers/match_live_provider.dart';
import '../../../shared/providers/match_summary_provider.dart';
import '../../../shared/providers/match_upcoming_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import '../../../shared/widgets/cf_marquee_text.dart';
import 'match_hub_tabs.dart';
import 'tabs/match_commentary_tab.dart';
import 'tabs/match_highlights_tab.dart';
import 'tabs/match_info_tab.dart';
import 'tabs/upcoming_match_info_tab.dart';
import 'tabs/match_insights_tab.dart';
import 'tabs/match_live_tab.dart';
import 'tabs/match_mvp_tab.dart';
import 'tabs/match_scorecard_tab.dart';
import 'tabs/match_squads_tab.dart';
import 'tabs/match_summary_tab.dart';

/// Multi-tab match experience — Live tab while in progress, Summary after completion.
class MatchHubScreen extends ConsumerWidget {
  const MatchHubScreen({
    super.key,
    required this.matchId,
    this.initialTab = 'summary',
  });

  final String matchId;
  final String initialTab;

  static int tabIndexFor(String? tab, MatchModel match) =>
      MatchHubTabConfig.forMatch(match).resolveInitialIndex(match, tab);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchProvider(matchId));

    return matchAsync.when(
      data: (match) {
        if (match == null) {
          return Scaffold(
            appBar: const CfChromeAppBar(title: Text('Match')),
            body: const Center(child: Text('Match not found')),
          );
        }

        return _MatchHubBody(
          matchId: matchId,
          match: match,
          initialTab: initialTab,
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }
}

class _MatchHubBody extends ConsumerStatefulWidget {
  const _MatchHubBody({
    required this.matchId,
    required this.match,
    required this.initialTab,
  });

  final String matchId;
  final MatchModel match;
  final String initialTab;

  @override
  ConsumerState<_MatchHubBody> createState() => _MatchHubBodyState();
}

class _MatchHubBodyState extends ConsumerState<_MatchHubBody>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  MatchHubTabConfig? _config;
  bool _initialTabApplied = false;
  bool _viewRecorded = false;
  bool _liveAudienceJoined = false;
  String? _audienceUid;
  late final MatchAudienceRepository _audienceRepo;
  ProviderSubscription<AsyncValue<User?>>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _audienceRepo = ref.read(matchAudienceRepositoryProvider);
    _authSubscription = ref.listenManual(authStateProvider, (prev, next) {
      if (!mounted) return;
      if (prev?.value?.uid == null && next.value?.uid != null) {
        _trackAudience().catchError((_) {});
      }
    });
    _syncTabs(widget.match, applyInitialTab: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackAudience().catchError((_) {});
    });
  }

  Future<void> _trackAudience() async {
    if (!mounted) return;
    final matchId = widget.matchId;

    if (!_viewRecorded) {
      await _audienceRepo.recordView(matchId);
      _viewRecorded = true;
    }

    if (_liveAudienceJoined || !_isLiveMatch(widget.match)) return;

    var uid = ref.read(authStateProvider).value?.uid;
    uid ??= (await ref.read(authStateProvider.future))?.uid;
    if (uid == null || !mounted) return;

    await _audienceRepo.joinLiveAudience(matchId: matchId, userId: uid);
    _audienceUid = uid;
    _liveAudienceJoined = true;
  }

  @override
  void didUpdateWidget(covariant _MatchHubBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldConfig = MatchHubTabConfig.forMatch(oldWidget.match);
    final newConfig = MatchHubTabConfig.forMatch(widget.match);
    if (!listEquals(oldConfig.tabIds, newConfig.tabIds)) {
      _syncTabs(widget.match, previousConfig: oldConfig);
    } else {
      _config = newConfig;
    }

    if (!_isLiveMatch(oldWidget.match) && _isLiveMatch(widget.match)) {
      _liveAudienceJoined = false;
      _trackAudience().catchError((_) {});
    }
  }

  bool _isLiveMatch(MatchModel match) =>
      match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak;

  void _syncTabs(
    MatchModel match, {
    MatchHubTabConfig? previousConfig,
    bool applyInitialTab = false,
  }) {
    final config = MatchHubTabConfig.forMatch(match);
    final oldController = _tabController;
    final oldIndex = oldController?.index ?? 0;
    final oldId = previousConfig?.idAt(oldIndex) ?? _config?.idAt(oldIndex);

    oldController?.dispose();

    _config = config;

    var nextIndex = config.resolveInitialIndex(match, widget.initialTab);
    if (!applyInitialTab && !_initialTabApplied && oldId != null) {
      if (oldId == MatchHubTabId.live &&
          !config.contains(MatchHubTabId.live) &&
          config.contains(MatchHubTabId.summary)) {
        nextIndex = config.indexOf(MatchHubTabId.summary);
      } else if (config.contains(oldId)) {
        nextIndex = config.indexOf(oldId);
      }
    }

    final initialIndex = nextIndex.clamp(0, config.tabIds.length - 1);
    _tabController = TabController(
      length: config.tabIds.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    if (applyInitialTab) _initialTabApplied = true;
  }

  @override
  void dispose() {
    _authSubscription?.close();
    if (_liveAudienceJoined && _audienceUid != null) {
      _audienceRepo
          .leaveLiveAudience(
            matchId: widget.matchId,
            userId: _audienceUid!,
          )
          .catchError((_) {});
    }
    _tabController?.dispose();
    super.dispose();
  }

  void _exit(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _navigateTab(String tabName) {
    final config = _config;
    final controller = _tabController;
    if (config == null || controller == null) return;
    final id = MatchHubTabConfig.idFromName(tabName);
    if (id == null || !config.contains(id)) return;
    controller.animateTo(config.indexOf(id));
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final config = _config!;
    final controller = _tabController!;

    // Keep live feeds subscribed for the whole hub session — TabBarView
    // lazily builds tabs, so without this the Live tab streams may not start
    // until another tab (e.g. Scorecard) watches the same providers.
    if (config.contains(MatchHubTabId.live)) {
      ref.watch(matchLiveProvider(widget.matchId));
    } else if (MatchHubTabConfig.isUpcomingMatch(match)) {
      ref.watch(matchUpcomingProvider(widget.matchId));
    } else if (MatchHubTabConfig.showsSummaryTab(match)) {
      // Summary heroes/insights/fielders need ball events — subscribe early so
      // the first paint is not empty while TabBarView lazy-builds other tabs.
      ref.watch(ballEventsProvider(widget.matchId));
      ref.watch(matchSummaryProvider(widget.matchId));
    }

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && context.mounted) {
          context.go('/home');
        }
      },
      child: Scaffold(
        appBar: CfChromeAppBar(
          centerTitle: false,
          title: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: CfMarqueeText(
              text: match.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _exit(context),
          ),
          actions: [
            if (match.status != MatchStatus.completed)
              IconButton(
                icon: const Icon(Icons.videocam_outlined),
                tooltip: 'Go Live',
                onPressed: () => context.push('/match/${widget.matchId}/stream'),
              ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share match',
              onPressed: () => shareMatchLink(
                matchId: widget.matchId,
                title: match.title,
              ),
            ),
          ],
          bottom: TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: config.tabs,
          ),
        ),
        body: TabBarView(
          controller: controller,
          children: [
            for (final id in config.tabIds)
              _tabFor(id, match, _navigateTab),
          ],
        ),
      ),
    );
  }

  Widget _tabFor(
    MatchHubTabId id,
    MatchModel match,
    void Function(String tabName) onNavigateTab,
  ) {
    return switch (id) {
      MatchHubTabId.info => MatchHubTabConfig.isUpcomingMatch(match)
          ? UpcomingMatchInfoTab(matchId: widget.matchId)
          : MatchInfoTab(matchId: widget.matchId),
      MatchHubTabId.live => MatchLiveTab(matchId: widget.matchId),
      MatchHubTabId.summary => MatchSummaryTab(
          matchId: widget.matchId,
          onNavigateTab: onNavigateTab,
        ),
      MatchHubTabId.scorecard => MatchScorecardTab(matchId: widget.matchId),
      MatchHubTabId.insights => MatchInsightsTab(matchId: widget.matchId),
      MatchHubTabId.comms => MatchCommentaryTab(matchId: widget.matchId),
      MatchHubTabId.squads => MatchSquadsTab(matchId: widget.matchId),
      MatchHubTabId.mvp => MatchMvpTab(matchId: widget.matchId),
      MatchHubTabId.gallery => MatchHighlightsTab(matchId: widget.matchId),
    };
  }
}
