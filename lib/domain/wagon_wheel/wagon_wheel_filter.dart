import 'package:equatable/equatable.dart';

enum WagonWheelRunFilter {
  all,
  singles,
  doubles,
  triples,
  fours,
  sixes,
  boundaries;

  String get label => switch (this) {
        WagonWheelRunFilter.all => 'All shots',
        WagonWheelRunFilter.singles => 'Singles',
        WagonWheelRunFilter.doubles => 'Doubles',
        WagonWheelRunFilter.triples => 'Triples',
        WagonWheelRunFilter.fours => 'Fours',
        WagonWheelRunFilter.sixes => 'Sixes',
        WagonWheelRunFilter.boundaries => 'Boundaries',
      };

  bool matches(int batsmanRuns) => switch (this) {
        WagonWheelRunFilter.all => true,
        WagonWheelRunFilter.singles => batsmanRuns == 1,
        WagonWheelRunFilter.doubles => batsmanRuns == 2,
        WagonWheelRunFilter.triples => batsmanRuns == 3,
        WagonWheelRunFilter.fours => batsmanRuns == 4,
        WagonWheelRunFilter.sixes => batsmanRuns == 6,
        WagonWheelRunFilter.boundaries =>
          batsmanRuns == 4 || batsmanRuns == 6,
      };
}

enum WagonWheelViewMode {
  lines,
  scatter,
  heatmap,
}

/// Filters for wagon wheel analytics queries.
class WagonWheelFilter extends Equatable {
  const WagonWheelFilter({
    this.batterId,
    this.bowlerId,
    this.teamId,
    this.matchId,
    this.tournamentId,
    this.inningsNumber,
    this.runFilter = WagonWheelRunFilter.all,
    this.fromDate,
    this.toDate,
    this.viewMode = WagonWheelViewMode.lines,
    this.batterCareerMode = false,
    this.opponentTeamFilter = false,
    this.bowlerNameKey,
  });

  final String? batterId;
  final String? bowlerId;
  final String? teamId;
  final String? matchId;
  final String? tournamentId;
  final int? inningsNumber;
  final WagonWheelRunFilter runFilter;
  final DateTime? fromDate;
  final DateTime? toDate;
  final WagonWheelViewMode viewMode;

  /// Player analytics: career wagon wheel for a locked batter.
  final bool batterCareerMode;

  /// When true, [teamId] matches the bowling (opponent) team in the innings.
  final bool opponentTeamFilter;

  /// Career batter view: filter by name + bowling type identity (dedupes ids).
  final String? bowlerNameKey;

  WagonWheelFilter copyWith({
    String? batterId,
    String? bowlerId,
    String? teamId,
    String? matchId,
    String? tournamentId,
    int? inningsNumber,
    WagonWheelRunFilter? runFilter,
    DateTime? fromDate,
    DateTime? toDate,
    WagonWheelViewMode? viewMode,
    bool? batterCareerMode,
    bool? opponentTeamFilter,
    String? bowlerNameKey,
    bool clearBatterId = false,
    bool clearBowlerId = false,
    bool clearBowlerNameKey = false,
    bool clearTeamId = false,
    bool clearMatchId = false,
    bool clearTournamentId = false,
    bool clearInnings = false,
    bool clearFromDate = false,
    bool clearToDate = false,
  }) {
    return WagonWheelFilter(
      batterId: clearBatterId ? null : (batterId ?? this.batterId),
      bowlerId: clearBowlerId ? null : (bowlerId ?? this.bowlerId),
      teamId: clearTeamId ? null : (teamId ?? this.teamId),
      matchId: clearMatchId ? null : (matchId ?? this.matchId),
      tournamentId:
          clearTournamentId ? null : (tournamentId ?? this.tournamentId),
      inningsNumber:
          clearInnings ? null : (inningsNumber ?? this.inningsNumber),
      runFilter: runFilter ?? this.runFilter,
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      viewMode: viewMode ?? this.viewMode,
      batterCareerMode: batterCareerMode ?? this.batterCareerMode,
      opponentTeamFilter: opponentTeamFilter ?? this.opponentTeamFilter,
      bowlerNameKey:
          clearBowlerNameKey ? null : (bowlerNameKey ?? this.bowlerNameKey),
    );
  }

  @override
  List<Object?> get props => [
        batterId,
        bowlerId,
        teamId,
        matchId,
        tournamentId,
        inningsNumber,
        runFilter,
        fromDate,
        toDate,
        viewMode,
        batterCareerMode,
        opponentTeamFilter,
        bowlerNameKey,
      ];
}
