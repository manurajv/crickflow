import 'package:equatable/equatable.dart';

import '../../../core/constants/enums.dart';
import '../../../data/models/location_model.dart';

enum PlayerRankingsSection { batting, bowling, fielding }

enum PlayerRankingsCategory {
  // Batting
  mostRuns,
  highestScore,
  bestAverage,
  strikeRate,
  mostFifties,
  mostHundreds,
  mostSixes,
  mostFours,
  fastestFifty,
  fastestHundred,
  // Bowling
  mostWickets,
  bestBowlingFigures,
  economy,
  bowlingStrikeRate,
  maidens,
  dotBalls,
  fiveWicketHauls,
  // Fielding
  mostCatches,
  mostRunOuts,
  mostStumpings,
  mostDirectHits,
}

enum PlayerRankingsOversFilter {
  all,
  overs1to12,
  overs13to20,
  overs21to99,
  testMatch,
}

/// Years shown in the rankings year dropdown (newest first).
/// Published from 2026; new years appear automatically when the calendar rolls.
List<int> playerRankingsYearOptions({
  DateTime? now,
  int earliestYear = 2026,
}) {
  final current = (now ?? DateTime.now()).year;
  final start = earliestYear > current ? current : earliestYear;
  return [for (var y = current; y >= start; y--) y];
}

extension PlayerRankingsCategoryX on PlayerRankingsCategory {
  PlayerRankingsSection get section => switch (this) {
        PlayerRankingsCategory.mostRuns ||
        PlayerRankingsCategory.highestScore ||
        PlayerRankingsCategory.bestAverage ||
        PlayerRankingsCategory.strikeRate ||
        PlayerRankingsCategory.mostFifties ||
        PlayerRankingsCategory.mostHundreds ||
        PlayerRankingsCategory.mostSixes ||
        PlayerRankingsCategory.mostFours ||
        PlayerRankingsCategory.fastestFifty ||
        PlayerRankingsCategory.fastestHundred =>
          PlayerRankingsSection.batting,
        PlayerRankingsCategory.mostWickets ||
        PlayerRankingsCategory.bestBowlingFigures ||
        PlayerRankingsCategory.economy ||
        PlayerRankingsCategory.bowlingStrikeRate ||
        PlayerRankingsCategory.maidens ||
        PlayerRankingsCategory.dotBalls ||
        PlayerRankingsCategory.fiveWicketHauls =>
          PlayerRankingsSection.bowling,
        PlayerRankingsCategory.mostCatches ||
        PlayerRankingsCategory.mostRunOuts ||
        PlayerRankingsCategory.mostStumpings ||
        PlayerRankingsCategory.mostDirectHits =>
          PlayerRankingsSection.fielding,
      };

  String get title => switch (this) {
        PlayerRankingsCategory.mostRuns => 'Most Runs',
        PlayerRankingsCategory.highestScore => 'Highest Score',
        PlayerRankingsCategory.bestAverage => 'Best Average',
        PlayerRankingsCategory.strikeRate => 'Strike Rate',
        PlayerRankingsCategory.mostFifties => 'Most Fifties',
        PlayerRankingsCategory.mostHundreds => 'Most Hundreds',
        PlayerRankingsCategory.mostSixes => 'Most Sixes',
        PlayerRankingsCategory.mostFours => 'Most Fours',
        PlayerRankingsCategory.fastestFifty => 'Fastest Fifty',
        PlayerRankingsCategory.fastestHundred => 'Fastest Hundred',
        PlayerRankingsCategory.mostWickets => 'Most Wickets',
        PlayerRankingsCategory.bestBowlingFigures => 'Best Bowling Figures',
        PlayerRankingsCategory.economy => 'Economy',
        PlayerRankingsCategory.bowlingStrikeRate => 'Strike Rate',
        PlayerRankingsCategory.maidens => 'Maidens',
        PlayerRankingsCategory.dotBalls => 'Dot Balls',
        PlayerRankingsCategory.fiveWicketHauls => 'Five Wicket Hauls',
        PlayerRankingsCategory.mostCatches => 'Most Catches',
        PlayerRankingsCategory.mostRunOuts => 'Most Run Outs',
        PlayerRankingsCategory.mostStumpings => 'Most Stumpings',
        PlayerRankingsCategory.mostDirectHits => 'Most Direct Hits',
      };

  /// Categories that need match/ball-event replay and are not on career docs.
  bool get requiresMatchReplay => switch (this) {
        PlayerRankingsCategory.fastestFifty ||
        PlayerRankingsCategory.fastestHundred ||
        PlayerRankingsCategory.bestBowlingFigures ||
        PlayerRankingsCategory.maidens ||
        PlayerRankingsCategory.dotBalls =>
          true,
        _ => false,
      };
}

extension PlayerRankingsSectionX on PlayerRankingsSection {
  String get title => switch (this) {
        PlayerRankingsSection.batting => 'Batting',
        PlayerRankingsSection.bowling => 'Bowling',
        PlayerRankingsSection.fielding => 'Fielding',
      };

  List<PlayerRankingsCategory> get categories => switch (this) {
        PlayerRankingsSection.batting => kPlayerRankingsBattingCategories,
        PlayerRankingsSection.bowling => kPlayerRankingsBowlingCategories,
        PlayerRankingsSection.fielding => kPlayerRankingsFieldingCategories,
      };
}

extension PlayerRankingsOversFilterX on PlayerRankingsOversFilter {
  String get title => switch (this) {
        PlayerRankingsOversFilter.all => 'All',
        PlayerRankingsOversFilter.overs1to12 => '1–12 Overs',
        PlayerRankingsOversFilter.overs13to20 => '13–20 Overs',
        PlayerRankingsOversFilter.overs21to99 => '21–99 Overs',
        PlayerRankingsOversFilter.testMatch => 'Test Match',
      };

  /// Compact label for the rankings subtitle (e.g. "1–12 overs", "All overs").
  String get summaryLabel => switch (this) {
        PlayerRankingsOversFilter.all => 'All overs',
        PlayerRankingsOversFilter.overs1to12 => '1–12 overs',
        PlayerRankingsOversFilter.overs13to20 => '13–20 overs',
        PlayerRankingsOversFilter.overs21to99 => '21–99 overs',
        PlayerRankingsOversFilter.testMatch => 'Test Match',
      };
}

const kPlayerRankingsBattingCategories = [
  PlayerRankingsCategory.mostRuns,
  PlayerRankingsCategory.highestScore,
  PlayerRankingsCategory.bestAverage,
  PlayerRankingsCategory.strikeRate,
  PlayerRankingsCategory.mostFifties,
  PlayerRankingsCategory.mostHundreds,
  PlayerRankingsCategory.mostSixes,
  PlayerRankingsCategory.mostFours,
  PlayerRankingsCategory.fastestFifty,
  PlayerRankingsCategory.fastestHundred,
];

const kPlayerRankingsBowlingCategories = [
  PlayerRankingsCategory.mostWickets,
  PlayerRankingsCategory.bestBowlingFigures,
  PlayerRankingsCategory.economy,
  PlayerRankingsCategory.bowlingStrikeRate,
  PlayerRankingsCategory.maidens,
  PlayerRankingsCategory.dotBalls,
  PlayerRankingsCategory.fiveWicketHauls,
];

const kPlayerRankingsFieldingCategories = [
  PlayerRankingsCategory.mostCatches,
  PlayerRankingsCategory.mostRunOuts,
  PlayerRankingsCategory.mostStumpings,
  PlayerRankingsCategory.mostDirectHits,
];

class PlayerRankingsFilter extends Equatable {
  const PlayerRankingsFilter({
    this.ballType = CricketBallType.leather,
    this.indoorBallMaterial,
    this.section = PlayerRankingsSection.batting,
    this.category = PlayerRankingsCategory.mostRuns,
    this.year,
    this.overs = PlayerRankingsOversFilter.all,
    this.location = const LocationModel(),
    this.searchQuery = '',
  });

  final CricketBallType ballType;

  /// Rankings-only: when [ballType] is indoor, optionally restrict to indoor
  /// matches played with leather or tennis. `null` = all indoor.
  final CricketBallType? indoorBallMaterial;

  final PlayerRankingsSection section;
  final PlayerRankingsCategory category;

  /// `null` = All Time; otherwise a calendar year (e.g. 2026).
  final int? year;
  final PlayerRankingsOversFilter overs;
  final LocationModel location;
  final String searchQuery;

  bool get hasLocationFilter =>
      location.country.isNotEmpty ||
      location.stateProvince.isNotEmpty ||
      location.city.isNotEmpty;

  /// Rankings always aggregate from completed matches so Leather / Tennis /
  /// Indoor filters stay accurate (career overall stats are not ball-specific).
  bool get usesCareerAggregates => false;

  /// Year, overs, location, or indoor leather/tennis sub-filter is active.
  bool get hasAdvancedFilters =>
      year != null ||
      overs != PlayerRankingsOversFilter.all ||
      hasLocationFilter ||
      indoorBallMaterial != null;

  /// e.g. "Most Runs in Colombo (in 2026, 1–12 overs)"
  /// or "Most Runs worldwide (All time, All overs)".
  String get advancedFilterSummary {
    final place = _locationSummaryLabel;
    final yearPart = year != null ? 'in $year' : 'All time';
    final ballPart = _ballSummaryLabel;
    return '${category.title} · $ballPart in $place ($yearPart, ${overs.summaryLabel})';
  }

  String get _ballSummaryLabel {
    if (ballType != CricketBallType.indoor) {
      return switch (ballType) {
        CricketBallType.leather => 'Leather',
        CricketBallType.tennis => 'Tennis',
        CricketBallType.indoor => 'Indoor',
      };
    }
    return switch (indoorBallMaterial) {
      CricketBallType.leather => 'Indoor · Leather',
      CricketBallType.tennis => 'Indoor · Tennis',
      _ => 'Indoor',
    };
  }

  String get _locationSummaryLabel {
    final city = location.city.trim();
    if (city.isNotEmpty) return city;
    final state = location.stateProvince.trim();
    if (state.isNotEmpty) return state;
    final country = location.country.trim();
    if (country.isNotEmpty) return country;
    return 'worldwide';
  }

  PlayerRankingsFilter copyWith({
    CricketBallType? ballType,
    CricketBallType? indoorBallMaterial,
    bool clearIndoorBallMaterial = false,
    PlayerRankingsSection? section,
    PlayerRankingsCategory? category,
    int? year,
    bool clearYear = false,
    PlayerRankingsOversFilter? overs,
    LocationModel? location,
    String? searchQuery,
    bool clearLocation = false,
  }) {
    var nextCategory = category ?? this.category;
    final nextSection = section ?? this.section;
    if (section != null && category == null) {
      nextCategory = nextSection.categories.first;
    } else if (category != null && category.section != nextSection) {
      nextCategory = nextSection.categories.first;
    }

    final nextBall = ballType ?? this.ballType;
    final nextIndoorMaterial = nextBall != CricketBallType.indoor
        ? null
        : (clearIndoorBallMaterial
            ? null
            : (indoorBallMaterial ?? this.indoorBallMaterial));

    return PlayerRankingsFilter(
      ballType: nextBall,
      indoorBallMaterial: nextIndoorMaterial,
      section: nextSection,
      category: nextCategory,
      year: clearYear ? null : (year ?? this.year),
      overs: overs ?? this.overs,
      location: clearLocation ? const LocationModel() : (location ?? this.location),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        ballType,
        indoorBallMaterial,
        section,
        category,
        year,
        overs,
        location,
        searchQuery,
      ];
}

class PlayerRankingStat extends Equatable {
  const PlayerRankingStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  List<Object?> get props => [label, value];
}

class PlayerRankingEntry extends Equatable {
  const PlayerRankingEntry({
    required this.rank,
    required this.playerDocId,
    required this.playerName,
    required this.value,
    required this.valueLabel,
    required this.section,
    required this.detailStats,
    this.publicPlayerId,
    this.photoUrl,
    this.role = '',
    this.teamName = '',
    this.teamId,
    this.verified = false,
  });

  final int rank;
  final String playerDocId;
  final String? publicPlayerId;
  final String playerName;
  final String? photoUrl;
  final String role;
  final String teamName;
  final String? teamId;
  final bool verified;
  final num value;
  final String valueLabel;
  final PlayerRankingsSection section;
  final List<PlayerRankingStat> detailStats;

  @override
  List<Object?> get props => [rank, playerDocId, valueLabel, detailStats];
}
