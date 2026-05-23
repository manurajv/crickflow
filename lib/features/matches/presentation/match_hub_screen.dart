import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/deep_link_utils.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'tabs/match_commentary_tab.dart';
import 'tabs/match_highlights_tab.dart';
import 'tabs/match_insights_tab.dart';
import 'tabs/match_mvp_tab.dart';
import 'tabs/match_scorecard_tab.dart';
import 'tabs/match_squads_tab.dart';
import 'tabs/match_summary_tab.dart';

/// Multi-tab match experience inspired by broadcast apps — unique CrickFlow UX.
class MatchHubScreen extends ConsumerWidget {
  const MatchHubScreen({super.key, required this.matchId});

  final String matchId;

  static const _tabs = [
    Tab(text: 'Summary'),
    Tab(text: 'Scorecard'),
    Tab(text: 'Comms'),
    Tab(text: 'Insights'),
    Tab(text: 'Squads'),
    Tab(text: 'MVP'),
    Tab(text: 'Highlights'),
  ];

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

        return PopScope(
          canPop: context.canPop(),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && context.mounted) {
              context.go('/home');
            }
          },
          child: DefaultTabController(
          length: _tabs.length,
          child: Scaffold(
            appBar: CfChromeAppBar(
              title: Text(
                match.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.link),
                  tooltip: 'Copy web scorecard',
                  onPressed: () {
                    final url =
                        DeepLinkUtils.publicLiveScorecardUri(matchId).toString();
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied: $url')),
                    );
                  },
                ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _tabs,
              ),
            ),
            body: TabBarView(
              children: [
                MatchSummaryTab(matchId: matchId),
                MatchScorecardTab(matchId: matchId),
                MatchCommentaryTab(matchId: matchId),
                MatchInsightsTab(matchId: matchId),
                MatchSquadsTab(matchId: matchId),
                MatchMvpTab(matchId: matchId),
                MatchHighlightsTab(matchId: matchId),
              ],
            ),
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
