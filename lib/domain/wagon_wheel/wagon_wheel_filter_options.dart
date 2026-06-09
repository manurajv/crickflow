import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';

/// Selectable id + display label for filter dropdowns.
class WagonWheelFilterOption {
  const WagonWheelFilterOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Available filter choices derived from match data and wagon wheel events.
class WagonWheelFilterOptions {
  const WagonWheelFilterOptions({
    this.batters = const [],
    this.bowlers = const [],
    this.teams = const [],
    this.inningsNumbers = const [],
    this.minDate,
    this.maxDate,
  });

  final List<WagonWheelFilterOption> batters;
  final List<WagonWheelFilterOption> bowlers;
  final List<WagonWheelFilterOption> teams;
  final List<int> inningsNumbers;
  final DateTime? minDate;
  final DateTime? maxDate;

  bool get hasData =>
      batters.isNotEmpty ||
      bowlers.isNotEmpty ||
      teams.isNotEmpty ||
      inningsNumbers.isNotEmpty;
}

class WagonWheelFilterOptionsService {
  WagonWheelFilterOptions build({
    required List<MatchModel> matches,
    required List<BallEventModel> events,
  }) {
    final batters = <String, String>{};
    final bowlers = <String, String>{};
    final teams = <String, String>{};
    final innings = <int>{};
    DateTime? minDate;
    DateTime? maxDate;

    final matchById = {for (final m in matches) m.id: m};

    for (final match in matches) {
      _collectTeams(match, teams);
      for (final inn in match.innings) {
        innings.add(inn.inningsNumber);
        _collectInningsPlayers(inn, batters, bowlers);
      }
    }

    for (final event in events) {
      if (event.wagonWheel == null) continue;

      innings.add(event.inningsNumber);
      final match = matchById[event.matchId];

      if (event.strikerId != null && event.strikerId!.isNotEmpty) {
        batters[event.strikerId!] =
            _batterName(match, event.inningsNumber, event.strikerId!) ??
                batters[event.strikerId!] ??
                'Batter';
      }
      if (event.bowlerId != null && event.bowlerId!.isNotEmpty) {
        bowlers[event.bowlerId!] =
            _bowlerName(match, event.inningsNumber, event.bowlerId!) ??
                bowlers[event.bowlerId!] ??
                'Bowler';
      }

      final inn = match != null
          ? _inningsFor(match, event.inningsNumber)
          : null;
      if (inn != null && inn.battingTeamId.isNotEmpty) {
        teams[inn.battingTeamId] =
            _teamName(match, inn.battingTeamId) ??
                teams[inn.battingTeamId] ??
                'Team';
      }

      final ts = event.timestamp;
      if (ts != null) {
        if (minDate == null || ts.isBefore(minDate)) minDate = ts;
        if (maxDate == null || ts.isAfter(maxDate)) maxDate = ts;
      }
    }

    return WagonWheelFilterOptions(
      batters: _sortedOptions(batters),
      bowlers: _sortedOptions(bowlers),
      teams: _sortedOptions(teams),
      inningsNumbers: innings.toList()..sort(),
      minDate: minDate,
      maxDate: maxDate,
    );
  }

  void _collectTeams(MatchModel match, Map<String, String> teams) {
    if (match.teamAId != null && match.teamAId!.isNotEmpty) {
      teams[match.teamAId!] = match.teamAName.isNotEmpty
          ? match.teamAName
          : 'Team A';
    }
    if (match.teamBId != null && match.teamBId!.isNotEmpty) {
      teams[match.teamBId!] = match.teamBName.isNotEmpty
          ? match.teamBName
          : 'Team B';
    }
    for (final inn in match.innings) {
      if (inn.battingTeamId.isNotEmpty) {
        teams[inn.battingTeamId] =
            _teamName(match, inn.battingTeamId) ??
                teams[inn.battingTeamId] ??
                'Team';
      }
      if (inn.bowlingTeamId.isNotEmpty) {
        teams[inn.bowlingTeamId] =
            _teamName(match, inn.bowlingTeamId) ??
                teams[inn.bowlingTeamId] ??
                'Team';
      }
    }
  }

  void _collectInningsPlayers(
    InningsModel inn,
    Map<String, String> batters,
    Map<String, String> bowlers,
  ) {
    for (final b in inn.batsmen) {
      if (b.playerId.isNotEmpty) {
        batters[b.playerId] =
            b.playerName.isNotEmpty ? b.playerName : b.playerId;
      }
    }
    for (final b in inn.bowlers) {
      if (b.playerId.isNotEmpty) {
        bowlers[b.playerId] =
            b.playerName.isNotEmpty ? b.playerName : b.playerId;
      }
    }
  }

  InningsModel? _inningsFor(MatchModel match, int inningsNumber) {
    for (final inn in match.innings) {
      if (inn.inningsNumber == inningsNumber) return inn;
    }
    return null;
  }

  String? _batterName(MatchModel? match, int inningsNumber, String id) {
    final inn = match != null ? _inningsFor(match, inningsNumber) : null;
    if (inn == null) return null;
    for (final b in inn.batsmen) {
      if (b.playerId == id && b.playerName.isNotEmpty) return b.playerName;
    }
    return null;
  }

  String? _bowlerName(MatchModel? match, int inningsNumber, String id) {
    final inn = match != null ? _inningsFor(match, inningsNumber) : null;
    if (inn == null) return null;
    for (final b in inn.bowlers) {
      if (b.playerId == id && b.playerName.isNotEmpty) return b.playerName;
    }
    return null;
  }

  String? _teamName(MatchModel? match, String teamId) {
    if (match == null) return null;
    if (match.teamAId == teamId) return match.teamAName;
    if (match.teamBId == teamId) return match.teamBName;
    return null;
  }

  List<WagonWheelFilterOption> _sortedOptions(Map<String, String> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return entries
        .map((e) => WagonWheelFilterOption(id: e.key, label: e.value))
        .toList();
  }
}
