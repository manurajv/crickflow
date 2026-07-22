import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../data/models/player_model.dart';

/// Batting pattern percentages used for cluster classification.
class BattingPatternStats {
  const BattingPatternStats({
    this.balls = 0,
    this.runs = 0,
    this.strikeRate = 0,
    this.dotPct = 0,
    this.singlesPct = 0,
    this.doublesPct = 0,
    this.triplesPct = 0,
    this.boundaryPct = 0,
    this.sixPct = 0,
    this.inningsCount = 0,
    this.matchCount = 0,
  });

  final int balls;
  final int runs;
  final double strikeRate;
  final double dotPct;
  final double singlesPct;
  final double doublesPct;
  final double triplesPct;
  final double boundaryPct;
  final double sixPct;
  final int inningsCount;
  final int matchCount;

  static const empty = BattingPatternStats();
}

/// Bowling pattern stats used for cluster classification.
class BowlingPatternStats {
  const BowlingPatternStats({
    this.wickets = 0,
    this.economy = 0,
    this.average = 0,
    this.strikeRate = 0,
    this.dotPct = 0,
    this.oversBowled = 0,
    this.matchCount = 0,
  });

  final int wickets;
  final double economy;
  final double average;
  final double strikeRate;
  final double dotPct;
  final double oversBowled;
  final int matchCount;

  static const empty = BowlingPatternStats();
}

class PlayerClusters {
  const PlayerClusters({
    this.batting,
    this.bowling,
    this.battingPattern = BattingPatternStats.empty,
    this.bowlingPattern = BowlingPatternStats.empty,
  });

  final BattingClusterType? batting;
  final BowlingClusterType? bowling;
  final BattingPatternStats battingPattern;
  final BowlingPatternStats bowlingPattern;

  List<String> get topTagLabels {
    final tags = <String>[];
    if (batting != null) tags.add(_battingLabel(batting!));
    if (bowling != null) tags.add(_bowlingLabel(bowling!));
    return tags;
  }

  static String _battingLabel(BattingClusterType type) => switch (type) {
        BattingClusterType.steadyBatter => 'Steady Batter',
        BattingClusterType.classicist => 'Classicist',
        BattingClusterType.accumulator => 'Accumulator',
        BattingClusterType.hardHitter => 'Hard Hitter',
        BattingClusterType.destroyer => 'Destroyer',
      };

  static String _bowlingLabel(BowlingClusterType type) => switch (type) {
        BowlingClusterType.aspirant => 'Aspirant',
        BowlingClusterType.wildcard => 'Wildcard',
        BowlingClusterType.economist => 'Economist',
        BowlingClusterType.spearhead => 'Spearhead',
      };
}

class CaptainYearStats {
  const CaptainYearStats({
    required this.year,
    this.matches = 0,
    this.wins = 0,
    this.losses = 0,
  });

  final int year;
  final int matches;
  final int wins;
  final int losses;

  double get winPct => matches == 0 ? 0 : (wins / matches) * 100;
}

class CaptainFormatStats {
  const CaptainFormatStats({
    required this.label,
    this.matches = 0,
    this.wins = 0,
    this.losses = 0,
  });

  final String label;
  final int matches;
  final int wins;
  final int losses;

  double get winPct => matches == 0 ? 0 : (wins / matches) * 100;
}

class CaptainTimelinePoint {
  const CaptainTimelinePoint({
    required this.date,
    required this.result,
    required this.matchTitle,
    this.teamScore = 0,
    this.opponentScore = 0,
  });

  final DateTime date;
  final String result;
  final String matchTitle;
  final int teamScore;
  final int opponentScore;
}

class CaptainStatsSnapshot {
  const CaptainStatsSnapshot({
    this.matchesAsCaptain = 0,
    this.wins = 0,
    this.losses = 0,
    this.ties = 0,
    this.tossesWon = 0,
    this.tossesTotal = 0,
    this.highestTeamScore = 0,
    this.lowestDefendedScore = 0,
    this.successfulChases = 0,
    this.chaseAttempts = 0,
    this.avgTeamScore = 0,
    this.avgConcededScore = 0,
    this.byYear = const [],
    this.byFormat = const [],
    this.timeline = const [],
  });

  final int matchesAsCaptain;
  final int wins;
  final int losses;
  final int ties;
  final int tossesWon;
  final int tossesTotal;
  final int highestTeamScore;
  final int lowestDefendedScore;
  final int successfulChases;
  final int chaseAttempts;
  final double avgTeamScore;
  final double avgConcededScore;
  final List<CaptainYearStats> byYear;
  final List<CaptainFormatStats> byFormat;
  final List<CaptainTimelinePoint> timeline;

  double get winPct =>
      matchesAsCaptain == 0 ? 0 : (wins / matchesAsCaptain) * 100;

  double get tossPct => tossesTotal == 0 ? 0 : (tossesWon / tossesTotal) * 100;

  static const empty = CaptainStatsSnapshot();
}

class PlayerTrophy {
  const PlayerTrophy({
    required this.id,
    required this.kind,
    required this.title,
    required this.tier,
    required this.category,
    required this.date,
    this.matchId,
    this.tournamentId,
    this.matchTitle = '',
    this.tournamentName = '',
    this.performance = '',
    this.teamName = '',
    this.emoji = '🏆',
  });

  final String id;
  final PlayerTrophyKind kind;
  final String title;
  final TrophyTier tier;
  final TrophyCategory category;
  final DateTime date;
  final String? matchId;
  final String? tournamentId;
  final String matchTitle;
  final String tournamentName;
  final String performance;
  final String teamName;
  final String emoji;
}

class PlayerBadgeDefinition {
  const PlayerBadgeDefinition({
    required this.id,
    required this.title,
    required this.category,
    required this.tier,
    required this.requirement,
    this.repeatability = BadgeRepeatability.repeatable,
    this.iconName = 'star',
    this.progressionGroup,
    this.groupOrder = 0,
  });

  final String id;
  final String title;
  final BadgeType category;
  final BadgeTier tier;
  final String requirement;
  final BadgeRepeatability repeatability;
  final String iconName;
  /// Badges in the same group award highest eligible only (no cascade).
  final String? progressionGroup;
  /// Sort order within a progression group (lower = easier).
  final int groupOrder;

  bool get isRepeatable => repeatability == BadgeRepeatability.repeatable;
  bool get isOneTime => repeatability == BadgeRepeatability.oneTime;
}

/// A badge unlocked during one match (summary / awards UI).
class MatchBadgeUnlock {
  const MatchBadgeUnlock({
    required this.badgeId,
    required this.playerId,
    required this.playerName,
    required this.performanceSnapshot,
  });

  final String badgeId;
  final String playerId;
  final String playerName;
  final String performanceSnapshot;
}

/// One time a badge was earned in a match.
class BadgeAchievementEntry {
  const BadgeAchievementEntry({
    required this.matchId,
    required this.achievedAt,
    required this.performanceSnapshot,
    this.matchTitle = '',
  });

  final String matchId;
  final DateTime achievedAt;
  final String performanceSnapshot;
  final String matchTitle;

  Map<String, dynamic> toMap() => {
        'matchId': matchId,
        'achievedAt': achievedAt.toIso8601String(),
        'performanceSnapshot': performanceSnapshot,
        if (matchTitle.isNotEmpty) 'matchTitle': matchTitle,
      };

  factory BadgeAchievementEntry.fromMap(Map<String, dynamic> map) {
    return BadgeAchievementEntry(
      matchId: map['matchId'] as String? ?? '',
      achievedAt: DateTime.tryParse(map['achievedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      performanceSnapshot: map['performanceSnapshot'] as String? ?? '',
      matchTitle: map['matchTitle'] as String? ?? '',
    );
  }
}

/// Persisted badge progression (Firestore: players/{id}/badge_progress/{badgeId}).
class PlayerBadgeRecord {
  const PlayerBadgeRecord({
    required this.badgeId,
    required this.repeatability,
    this.unlockCount = 0,
    this.firstAchievedAt,
    this.lastAchievedAt,
    this.achievementHistory = const [],
    this.oneTimeUnlocked = false,
    this.unlockedAt,
    this.unlockedMatchId,
    this.unlockPerformanceSnapshot,
    this.unlockMatchTitle,
  });

  final String badgeId;
  final BadgeRepeatability repeatability;
  final int unlockCount;
  final DateTime? firstAchievedAt;
  final DateTime? lastAchievedAt;
  final List<BadgeAchievementEntry> achievementHistory;
  final bool oneTimeUnlocked;
  final DateTime? unlockedAt;
  final String? unlockedMatchId;
  final String? unlockPerformanceSnapshot;
  final String? unlockMatchTitle;

  bool get unlocked =>
      repeatability == BadgeRepeatability.repeatable
          ? unlockCount > 0
          : oneTimeUnlocked;

  Map<String, dynamic> toMap() {
    if (repeatability == BadgeRepeatability.oneTime) {
      return {
        'badgeId': badgeId,
        'repeatability': repeatability.name,
        'unlocked': oneTimeUnlocked,
        if (unlockedAt != null) 'unlockedAt': unlockedAt!.toIso8601String(),
        if (unlockedMatchId != null && unlockedMatchId!.isNotEmpty)
          'unlockedMatchId': unlockedMatchId,
        if (unlockPerformanceSnapshot != null)
          'performanceSnapshot': unlockPerformanceSnapshot,
        if (unlockMatchTitle != null && unlockMatchTitle!.isNotEmpty)
          'unlockMatchTitle': unlockMatchTitle,
      };
    }
    return {
      'badgeId': badgeId,
      'repeatability': repeatability.name,
      'unlockCount': unlockCount,
      if (firstAchievedAt != null)
        'firstAchievedAt': firstAchievedAt!.toIso8601String(),
      if (lastAchievedAt != null)
        'lastAchievedAt': lastAchievedAt!.toIso8601String(),
      'achievementHistory':
          achievementHistory.map((e) => e.toMap()).toList(),
    };
  }

  factory PlayerBadgeRecord.fromMap(
    String badgeId,
    Map<String, dynamic> map, {
    BadgeRepeatability repeatability = BadgeRepeatability.repeatable,
  }) {
    final kind = map['repeatability'] as String?;
    final resolved = kind != null
        ? BadgeRepeatability.values.firstWhere(
            (e) => e.name == kind,
            orElse: () => repeatability,
          )
        : repeatability;

    if (resolved == BadgeRepeatability.oneTime) {
      return PlayerBadgeRecord(
        badgeId: badgeId,
        repeatability: BadgeRepeatability.oneTime,
        oneTimeUnlocked: map['unlocked'] as bool? ?? false,
        unlockedAt: DateTime.tryParse(map['unlockedAt'] as String? ?? ''),
        unlockedMatchId: map['unlockedMatchId'] as String?,
        unlockPerformanceSnapshot: map['performanceSnapshot'] as String?,
        unlockMatchTitle: map['unlockMatchTitle'] as String?,
      );
    }

    final historyRaw = map['achievementHistory'] as List? ?? [];
    return PlayerBadgeRecord(
      badgeId: badgeId,
      repeatability: BadgeRepeatability.repeatable,
      unlockCount: (map['unlockCount'] as num?)?.toInt() ?? 0,
      firstAchievedAt:
          DateTime.tryParse(map['firstAchievedAt'] as String? ?? ''),
      lastAchievedAt: DateTime.tryParse(map['lastAchievedAt'] as String? ?? ''),
      achievementHistory: historyRaw
          .whereType<Map>()
          .map((e) => BadgeAchievementEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class PlayerBadgeProgress {
  const PlayerBadgeProgress({
    required this.definition,
    this.unlocked = false,
    this.unlockCount = 0,
    this.progress = 0,
    this.target = 1,
    this.earnedAt,
    this.firstAchievedAt,
    this.matchId,
    this.achievementHistory = const [],
    this.progressToNextTier,
    this.nextTierTitle,
    this.unlockedAt,
    this.unlockPerformanceSnapshot,
    this.unlockMatchTitle,
  });

  final PlayerBadgeDefinition definition;
  final bool unlocked;
  final int unlockCount;
  final double progress;
  final double target;
  final DateTime? earnedAt;
  final DateTime? firstAchievedAt;
  final String? matchId;
  final List<BadgeAchievementEntry> achievementHistory;
  final String? progressToNextTier;
  final String? nextTierTitle;
  final DateTime? unlockedAt;
  final String? unlockPerformanceSnapshot;
  final String? unlockMatchTitle;

  bool get isRepeatable => definition.isRepeatable;
  bool get isOneTime => definition.isOneTime;

  DateTime? get lastAchievedAt =>
      isRepeatable ? earnedAt : unlockedAt;

  double get completionPct =>
      target <= 0 ? 0 : ((progress / target).clamp(0, 1) * 100);
}

class PlayerTeamProfile {
  const PlayerTeamProfile({
    required this.teamId,
    required this.teamName,
    this.logoUrl,
    this.since,
    this.matches = 0,
    this.wins = 0,
    this.losses = 0,
    this.runs = 0,
    this.wickets = 0,
    this.captainMatches = 0,
    this.teamRole = '',
    this.avgScore = 0,
    this.strikeRate = 0,
    this.winPct = 0,
  });

  final String teamId;
  final String teamName;
  final String? logoUrl;
  final DateTime? since;
  final int matches;
  final int wins;
  final int losses;
  final int runs;
  final int wickets;
  final int captainMatches;
  final String teamRole;
  final double avgScore;
  final double strikeRate;
  final double winPct;
}

class ProfileMatchFilters {
  const ProfileMatchFilters({
    this.overs,
    this.ballType,
    this.matchType,
    this.year,
    this.teamId,
    this.tournamentId,
  });

  final int? overs;
  final CricketBallType? ballType;
  final CricketMatchType? matchType;
  final int? year;
  final String? teamId;
  final String? tournamentId;

  ProfileMatchFilters copyWith({
    int? Function()? overs,
    CricketBallType? Function()? ballType,
    CricketMatchType? Function()? matchType,
    int? Function()? year,
    String? Function()? teamId,
    String? Function()? tournamentId,
  }) {
    return ProfileMatchFilters(
      overs: overs != null ? overs() : this.overs,
      ballType: ballType != null ? ballType() : this.ballType,
      matchType: matchType != null ? matchType() : this.matchType,
      year: year != null ? year() : this.year,
      teamId: teamId != null ? teamId() : this.teamId,
      tournamentId: tournamentId != null ? tournamentId() : this.tournamentId,
    );
  }

  bool get hasActiveFilters =>
      overs != null ||
      ballType != null ||
      matchType != null ||
      year != null ||
      (tournamentId != null && tournamentId!.isNotEmpty);

  int get activeFilterCount =>
      (overs != null ? 1 : 0) +
      (ballType != null ? 1 : 0) +
      (matchType != null ? 1 : 0) +
      (year != null ? 1 : 0) +
      (tournamentId != null && tournamentId!.isNotEmpty ? 1 : 0);
}

class PlayerCricketProfileSnapshot {
  const PlayerCricketProfileSnapshot({
    required this.player,
    this.clusters = const PlayerClusters(),
    this.captainStats = CaptainStatsSnapshot.empty,
    this.trophies = const [],
    this.badges = const [],
    this.teams = const [],
    this.participatedMatches = const [],
  });

  final PlayerModel player;
  final PlayerClusters clusters;
  final CaptainStatsSnapshot captainStats;
  final List<PlayerTrophy> trophies;
  final List<PlayerBadgeProgress> badges;
  final List<PlayerTeamProfile> teams;
  final List<MatchModel> participatedMatches;
}

/// Supported overs filter options.
const profileOversFilterOptions = [5, 10, 15, 20, 25, 30, 40, 50];
