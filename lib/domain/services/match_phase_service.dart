import '../../data/models/match_rules_model.dart';
import 'match_analytics_models.dart';

/// Centralized limited-overs phase calculation.
class MatchPhaseService {
  const MatchPhaseService._();

  static MatchPhaseRanges forRules(MatchRulesModel rules) {
    final totalOvers = rules.totalOvers.clamp(1, 999);
    final lastNOversCount = _min(5, totalOvers);
    final lastNOversStart = _max(1, totalOvers - lastNOversCount + 1);
    final momentumWindowSize = totalOvers <= 1 ? 1 : _min(4, totalOvers);

    if (_hasCustomSlots(rules)) {
      return _rangesFromCustomSlots(
        rules: rules,
        totalOvers: totalOvers,
        lastNOversCount: lastNOversCount,
        lastNOversStart: lastNOversStart,
        momentumWindowSize: momentumWindowSize,
      );
    }

    final dynamic = _dynamicRanges(totalOvers, rules.powerplayOvers);
    return MatchPhaseRanges(
      totalOvers: totalOvers,
      powerplayLabel: dynamic.powerplayLabel,
      middleLabel: dynamic.middleLabel,
      deathLabel: dynamic.deathLabel,
      lastNOversCount: lastNOversCount,
      lastNOversStart: lastNOversStart,
      momentumWindowSize: momentumWindowSize,
    );
  }

  static OverPhaseKind classifyOver(int overNumber, MatchRulesModel rules) {
    if (rules.isTestMatch) return OverPhaseKind.normal;
    if (overNumber < 1 || overNumber > rules.totalOvers) {
      return OverPhaseKind.normal;
    }

    if (_hasCustomSlots(rules)) {
      for (final o in rules.powerplaySlots[0]) {
        if (o == overNumber) return OverPhaseKind.powerplay;
      }
      for (final o in rules.powerplaySlots[1]) {
        if (o == overNumber) return OverPhaseKind.powerplay;
      }
      for (final o in rules.powerplaySlots[2]) {
        if (o == overNumber) return OverPhaseKind.death;
      }
    }

    if (rules.powerplayOvers != null && overNumber <= rules.powerplayOvers!) {
      return OverPhaseKind.powerplay;
    }

    final ranges = _dynamicRanges(
      rules.totalOvers.clamp(1, 999),
      rules.powerplayOvers,
    );
    if (overNumber >= ranges.powerplayStart &&
        overNumber <= ranges.powerplayEnd) {
      return OverPhaseKind.powerplay;
    }
    if (overNumber >= ranges.deathStart && overNumber <= ranges.deathEnd) {
      return OverPhaseKind.death;
    }
    if (ranges.hasMiddle &&
        overNumber >= ranges.middleStart &&
        overNumber <= ranges.middleEnd) {
      return OverPhaseKind.middle;
    }
    return OverPhaseKind.normal;
  }

  static bool _hasCustomSlots(MatchRulesModel rules) =>
      rules.powerplaySlots.any((slot) => slot.isNotEmpty);

  static _DynamicRanges _dynamicRanges(int totalOvers, int? legacyPowerplay) {
    final powerplayEnd = legacyPowerplay != null
        ? legacyPowerplay.clamp(1, totalOvers)
        : _max(1, (totalOvers * 0.30).round());

    final deathLength = _max(1, (totalOvers * 0.25).round());
    var deathStart = _max(1, totalOvers - deathLength + 1);
    if (deathStart <= powerplayEnd) {
      deathStart = powerplayEnd + 1;
    }
    final deathEnd = totalOvers;

    final middleStart = powerplayEnd + 1;
    final middleEnd = deathStart - 1;

    return _DynamicRanges(
      powerplayStart: 1,
      powerplayEnd: powerplayEnd,
      middleStart: middleStart,
      middleEnd: middleEnd,
      deathStart: deathStart <= deathEnd ? deathStart : deathEnd,
      deathEnd: deathEnd,
    );
  }

  static MatchPhaseRanges _rangesFromCustomSlots({
    required MatchRulesModel rules,
    required int totalOvers,
    required int lastNOversCount,
    required int lastNOversStart,
    required int momentumWindowSize,
  }) {
    final ppOvers = <int>{
      ...rules.powerplaySlots[0],
      ...rules.powerplaySlots[1],
    };
    if (rules.powerplayOvers != null) {
      for (var o = 1; o <= rules.powerplayOvers!.clamp(1, totalOvers); o++) {
        ppOvers.add(o);
      }
    }
    final deathOvers = {...rules.powerplaySlots[2]};
    final dynamic = _dynamicRanges(totalOvers, null);

    return MatchPhaseRanges(
      totalOvers: totalOvers,
      powerplayLabel: ppOvers.isEmpty
          ? dynamic.powerplayLabel
          : _labelForOvers('Powerplay', ppOvers),
      middleLabel: dynamic.middleLabel,
      deathLabel: deathOvers.isEmpty
          ? dynamic.deathLabel
          : _labelForOvers('Death Overs', deathOvers),
      lastNOversCount: lastNOversCount,
      lastNOversStart: lastNOversStart,
      momentumWindowSize: momentumWindowSize,
    );
  }

  static String _labelForOvers(String name, Set<int> overs) {
    final sorted = overs.toList()..sort();
    if (sorted.isEmpty) return name;
    if (sorted.length == 1) return '$name (${sorted.first})';

    var contiguous = true;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] != sorted[i - 1] + 1) {
        contiguous = false;
        break;
      }
    }
    if (contiguous) return '$name (${sorted.first}-${sorted.last})';
    return '$name (${sorted.join(', ')})';
  }
}

class _DynamicRanges {
  const _DynamicRanges({
    required this.powerplayStart,
    required this.powerplayEnd,
    required this.middleStart,
    required this.middleEnd,
    required this.deathStart,
    required this.deathEnd,
  });

  final int powerplayStart;
  final int powerplayEnd;
  final int middleStart;
  final int middleEnd;
  final int deathStart;
  final int deathEnd;

  bool get hasMiddle => middleStart <= middleEnd;

  String get powerplayLabel =>
      _rangeLabel('Powerplay', powerplayStart, powerplayEnd);

  String get middleLabel => hasMiddle
      ? _rangeLabel('Middle Overs', middleStart, middleEnd)
      : 'Middle Overs';

  String get deathLabel => _rangeLabel('Death Overs', deathStart, deathEnd);

  static String _rangeLabel(String name, int start, int end) {
    if (start <= 0 || end <= 0) return name;
    if (start == end) return '$name ($start)';
    return '$name ($start-$end)';
  }
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;
