import 'package:flutter/material.dart';

import '../../../core/constants/enums.dart';
import '../../../data/models/match_model.dart';
import '../../../domain/scoring/match_lifecycle.dart';

/// Identifiers for match hub tabs (order varies by match status).
enum MatchHubTabId {
  info,
  live,
  summary,
  scorecard,
  insights,
  comms,
  squads,
  mvp,
  gallery,
}

/// Tab layout for a match hub — Live vs Summary visibility depends on status.
class MatchHubTabConfig {
  const MatchHubTabConfig({required this.tabIds});

  final List<MatchHubTabId> tabIds;

  static bool showsLiveTab(MatchModel match) =>
      !isUpcomingMatch(match) && MatchLifecycle.isEffectivelyLive(match);

  static bool showsSummaryTab(MatchModel match) =>
      !isUpcomingMatch(match) &&
      (MatchLifecycle.isCompleted(match) ||
          match.status == MatchStatus.abandoned);

  static bool isUpcomingMatch(MatchModel match) =>
      MatchLifecycle.isUpcoming(match);

  static MatchHubTabConfig forMatch(MatchModel match) {
    if (isUpcomingMatch(match)) {
      return const MatchHubTabConfig(
        tabIds: [MatchHubTabId.info, MatchHubTabId.squads],
      );
    }

    final ids = <MatchHubTabId>[
      MatchHubTabId.info,
      if (showsLiveTab(match)) MatchHubTabId.live,
      if (showsSummaryTab(match)) MatchHubTabId.summary,
      MatchHubTabId.scorecard,
      MatchHubTabId.insights,
      MatchHubTabId.comms,
      MatchHubTabId.squads,
      MatchHubTabId.mvp,
      MatchHubTabId.gallery,
    ];
    return MatchHubTabConfig(tabIds: ids);
  }

  int indexOf(MatchHubTabId id) => tabIds.indexOf(id);

  bool contains(MatchHubTabId id) => tabIds.contains(id);

  MatchHubTabId? idAt(int index) {
    if (index < 0 || index >= tabIds.length) return null;
    return tabIds[index];
  }

  List<Tab> get tabs => tabIds
      .map((id) => Tab(text: _label(id, upcoming: tabIds.length <= 2)))
      .toList(growable: false);

  static MatchHubTabId? idFromName(String? name) {
    return switch (name?.toLowerCase()) {
      'info' => MatchHubTabId.info,
      'live' => MatchHubTabId.live,
      'summary' => MatchHubTabId.summary,
      'scorecard' => MatchHubTabId.scorecard,
      'insights' => MatchHubTabId.insights,
      'comms' || 'commentary' => MatchHubTabId.comms,
      'squads' => MatchHubTabId.squads,
      'mvp' => MatchHubTabId.mvp,
      'gallery' || 'highlights' => MatchHubTabId.gallery,
      _ => null,
    };
  }

  static String nameFor(MatchHubTabId id) {
    return switch (id) {
      MatchHubTabId.info => 'info',
      MatchHubTabId.live => 'live',
      MatchHubTabId.summary => 'summary',
      MatchHubTabId.scorecard => 'scorecard',
      MatchHubTabId.insights => 'insights',
      MatchHubTabId.comms => 'comms',
      MatchHubTabId.squads => 'squads',
      MatchHubTabId.mvp => 'mvp',
      MatchHubTabId.gallery => 'highlights',
    };
  }

  static MatchHubTabId defaultTab(MatchModel match) {
    if (isUpcomingMatch(match)) return MatchHubTabId.info;
    if (showsLiveTab(match)) return MatchHubTabId.live;
    if (showsSummaryTab(match)) return MatchHubTabId.summary;
    return MatchHubTabId.info;
  }

  int resolveInitialIndex(MatchModel match, String? requestedTab) {
    final requested = idFromName(requestedTab);
    if (requested != null && contains(requested)) {
      return indexOf(requested);
    }
    return indexOf(defaultTab(match));
  }

  static String _label(MatchHubTabId id, {bool upcoming = false}) {
    return switch (id) {
      MatchHubTabId.info => upcoming ? 'Match Info' : 'Info',
      MatchHubTabId.live => 'Live',
      MatchHubTabId.summary => 'Summary',
      MatchHubTabId.scorecard => 'Scorecard',
      MatchHubTabId.insights => 'Insights',
      MatchHubTabId.comms => 'Comms',
      MatchHubTabId.squads => 'Squads',
      MatchHubTabId.mvp => 'MVP',
      MatchHubTabId.gallery => 'Highlights',
    };
  }
}

/// Legacy helpers — prefer [MatchHubTabConfig] with a [MatchModel].
class MatchHubTabs {
  MatchHubTabs._();

  static int indexFor(String? tab, MatchModel match) =>
      MatchHubTabConfig.forMatch(match).resolveInitialIndex(match, tab);

  static String nameForIndex(int index, MatchModel match) {
    final id = MatchHubTabConfig.forMatch(match).idAt(index);
    if (id == null) return 'info';
    return MatchHubTabConfig.nameFor(id);
  }
}
