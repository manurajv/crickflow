import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';

/// Commentary timeline filter options.
enum CommentaryFilter {
  full('Full'),
  wickets('Wickets'),
  boundaries('Boundaries'),
  overs('Overs'),
  powerplays('Powerplays');

  const CommentaryFilter(this.label);
  final String label;
}

enum CommentaryFeedKind {
  ball,
  overSummary,
  nextBatter,
  matchEvent,
}

enum CommentaryMatchEventKind {
  powerplayStarted,
  powerplayEnded,
}

/// Batter line at end of an over.
class CommentaryBatterLine {
  const CommentaryBatterLine({
    required this.name,
    required this.runs,
    required this.balls,
  });

  final String name;
  final int runs;
  final int balls;

  String get scoreLine => '$runs($balls)';
}

/// Bowler figures at end of an over.
class CommentaryBowlerLine {
  const CommentaryBowlerLine({
    required this.name,
    required this.oversText,
    required this.maidens,
    required this.runs,
    required this.wickets,
  });

  final String name;
  final String oversText;
  final int maidens;
  final int runs;
  final int wickets;

  String get figuresLine => '$oversText-$maidens-$runs-$wickets';
}

sealed class CommentaryFeedItem {
  const CommentaryFeedItem({
    required this.kind,
    required this.sortKey,
    required this.inningsNumber,
    required this.filters,
  });

  final CommentaryFeedKind kind;
  final int sortKey;
  final int inningsNumber;
  final Set<CommentaryFilter> filters;
}

class BallCommentaryItem extends CommentaryFeedItem {
  const BallCommentaryItem({
    required super.sortKey,
    required super.inningsNumber,
    required super.filters,
    required this.event,
    required this.strikerName,
    required this.bowlerName,
    required this.headline,
    required this.description,
    required this.teamRuns,
    required this.teamWickets,
    required this.legalBalls,
    this.fielderLine,
    this.dismissedName,
    this.dismissalShort,
    this.wicketDetailLine,
    this.batterRuns,
    this.batterBalls,
  }) : super(kind: CommentaryFeedKind.ball);

  final BallEventModel event;
  final String strikerName;
  final String bowlerName;
  final String headline;
  final String description;
  final int teamRuns;
  final int teamWickets;
  final int legalBalls;
  final String? fielderLine;
  final String? dismissedName;
  final String? dismissalShort;
  final String? wicketDetailLine;
  final int? batterRuns;
  final int? batterBalls;

  String get ballLabel => '${event.overNumber}.${event.ballInOver}';

  bool get isWicket =>
      event.eventType == BallEventType.wicket && event.isWicket;

  bool get isBoundary =>
      event.isBoundary || event.runs == 4 || event.runs >= 6;
}

class OverSummaryCommentaryItem extends CommentaryFeedItem {
  const OverSummaryCommentaryItem({
    required super.sortKey,
    required super.inningsNumber,
    required super.filters,
    required this.overNumber,
    required this.ballSymbols,
    required this.ballEvents,
    required this.runsInOver,
    required this.wicketsInOver,
    required this.teamRuns,
    required this.teamWickets,
    required this.batters,
    required this.bowler,
    this.bowlerToLine = '',
  }) : super(kind: CommentaryFeedKind.overSummary);

  final int overNumber;
  final List<String> ballSymbols;
  final List<BallEventModel> ballEvents;
  final int runsInOver;
  final int wicketsInOver;
  final int teamRuns;
  final int teamWickets;
  final List<CommentaryBatterLine> batters;
  final CommentaryBowlerLine bowler;
  final String bowlerToLine;

  bool get hasBoundary =>
      ballSymbols.any((s) => s == '4' || s == '6');
}

class NextBatterCommentaryItem extends CommentaryFeedItem {
  const NextBatterCommentaryItem({
    required super.sortKey,
    required super.inningsNumber,
    required super.filters,
    required this.playerId,
    required this.playerName,
    this.battingStyle,
    this.photoUrl,
  }) : super(kind: CommentaryFeedKind.nextBatter);

  final String playerId;
  final String playerName;
  final String? battingStyle;
  final String? photoUrl;
}

class MatchEventCommentaryItem extends CommentaryFeedItem {
  const MatchEventCommentaryItem({
    required super.sortKey,
    required super.inningsNumber,
    required super.filters,
    required this.eventKind,
    required this.title,
    this.subtitle,
    this.detail,
    this.runsScored,
    this.wicketsLost,
    this.crr,
  }) : super(kind: CommentaryFeedKind.matchEvent);

  final CommentaryMatchEventKind eventKind;
  final String title;
  final String? subtitle;
  final String? detail;
  final int? runsScored;
  final int? wicketsLost;
  final double? crr;
}

/// Built commentary feed for one match.
class CommentaryFeed {
  const CommentaryFeed({
    required this.itemsByInnings,
    required this.inningsOptions,
  });

  final Map<int, List<CommentaryFeedItem>> itemsByInnings;
  final List<CommentaryInningsOption> inningsOptions;

  static const empty = CommentaryFeed(
    itemsByInnings: {},
    inningsOptions: [],
  );

  List<CommentaryFeedItem> itemsForInnings(int inningsNumber) =>
      itemsByInnings[inningsNumber] ?? const [];

  List<CommentaryFeedItem> filtered({
    required int inningsNumber,
    required CommentaryFilter filter,
  }) {
    final items = itemsForInnings(inningsNumber);
    switch (filter) {
      case CommentaryFilter.full:
        return items
            .where(
              (i) =>
                  i.kind == CommentaryFeedKind.ball ||
                  i.kind == CommentaryFeedKind.overSummary ||
                  i.kind == CommentaryFeedKind.nextBatter ||
                  i.kind == CommentaryFeedKind.matchEvent,
            )
            .toList();
      case CommentaryFilter.wickets:
        return items.where((i) {
          if (i is BallCommentaryItem && i.isWicket) return true;
          if (i is NextBatterCommentaryItem) return true;
          if (i is OverSummaryCommentaryItem && i.wicketsInOver > 0) {
            return true;
          }
          return false;
        }).toList();
      case CommentaryFilter.boundaries:
        return items.where((i) {
          if (i is BallCommentaryItem && i.isBoundary) return true;
          if (i is OverSummaryCommentaryItem && i.hasBoundary) return true;
          return false;
        }).toList();
      case CommentaryFilter.overs:
        return items
            .where((i) => i.kind == CommentaryFeedKind.overSummary)
            .toList();
      case CommentaryFilter.powerplays:
        return items
            .where(
              (i) =>
                  i is MatchEventCommentaryItem &&
                  (i.eventKind == CommentaryMatchEventKind.powerplayStarted ||
                      i.eventKind == CommentaryMatchEventKind.powerplayEnded),
            )
            .toList();
    }
  }
}

class CommentaryInningsOption {
  const CommentaryInningsOption({
    required this.inningsNumber,
    required this.teamName,
    required this.battingTeamId,
  });

  final int inningsNumber;
  final String teamName;
  final String? battingTeamId;
}
