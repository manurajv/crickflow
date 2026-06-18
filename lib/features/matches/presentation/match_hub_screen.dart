import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/deep_link_utils.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/match_follow_button.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'tabs/match_commentary_tab.dart';
import 'tabs/match_highlights_tab.dart';
import 'tabs/match_insights_tab.dart';
import 'tabs/match_mvp_tab.dart';
import 'tabs/match_scorecard_tab.dart';
import 'tabs/match_squads_tab.dart';
import 'tabs/match_summary_tab.dart';

/// Multi-tab match experience inspired by broadcast apps — unique CrickFlow UX.
class MatchHubScreen extends ConsumerStatefulWidget {
  const MatchHubScreen({
    super.key,
    required this.matchId,
    this.initialTab = 'summary',
  });

  final String matchId;
  final String initialTab;

  static const _tabs = [
    Tab(text: 'Summary'),
    Tab(text: 'Scorecard'),
    Tab(text: 'Comms'),
    Tab(text: 'Insights'),
    Tab(text: 'Squads'),
    Tab(text: 'MVP'),
    Tab(text: 'Highlights'),
  ];

  static int tabIndexFor(String? tab) {
    return switch (tab?.toLowerCase()) {
      'scorecard' => 1,
      'comms' || 'commentary' => 2,
      'insights' => 3,
      'squads' => 4,
      'mvp' => 5,
      'highlights' => 6,
      _ => 0,
    };
  }

  @override
  ConsumerState<MatchHubScreen> createState() => _MatchHubScreenState();
}

class _MatchHubScreenState extends ConsumerState<MatchHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: MatchHubScreen._tabs.length,
      vsync: this,
      initialIndex: MatchHubScreen.tabIndexFor(widget.initialTab),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _exit(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchProvider(widget.matchId));

    return matchAsync.when(
      data: (match) {
        if (match == null) {
          return Scaffold(
            appBar: const CfChromeAppBar(title: Text('Match')),
            body: const Center(child: Text('Match not found')),
          );
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
              title: Text(
                match.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _exit(context),
              ),
              actions: [
                MatchFollowButton(matchId: widget.matchId, compact: true),
                IconButton(
                  icon: const Icon(Icons.link),
                  tooltip: 'Copy web scorecard',
                  onPressed: () {
                    final url = DeepLinkUtils.publicLiveScorecardUri(
                      widget.matchId,
                    ).toString();
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied: $url')),
                    );
                  },
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: MatchHubScreen._tabs,
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                MatchSummaryTab(matchId: widget.matchId),
                MatchScorecardTab(matchId: widget.matchId),
                MatchCommentaryTab(matchId: widget.matchId),
                MatchInsightsTab(matchId: widget.matchId),
                MatchSquadsTab(matchId: widget.matchId),
                MatchMvpTab(matchId: widget.matchId),
                MatchHighlightsTab(matchId: widget.matchId),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }
}
