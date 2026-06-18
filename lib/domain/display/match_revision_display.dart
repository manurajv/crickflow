import '../../core/constants/enums.dart';
import '../../core/utils/overs_formatter.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_revision_model.dart';
import '../../domain/scoring/innings_completion_policy.dart';

/// Display-only helpers for DLS, target revisions, and penalties.
class MatchRevisionDisplay {
  MatchRevisionDisplay._();

  static bool hasTargetRevisionData(MatchModel match) {
    final s = match.targetState;
    return s.dlsApplied ||
        s.revisedTarget != null ||
        s.originalTarget != null ||
        s.effectiveRevisedOvers != null ||
        s.originalOvers != null ||
        s.revisionMethod != null;
  }

  static bool hasAnyRevisionContext(
    MatchModel match,
    List<MatchRevisionModel> revisions,
  ) {
    if (hasTargetRevisionData(match)) return true;
    if (revisions.isNotEmpty) return true;
    return match.innings.any((inn) => inn.penaltyRuns != 0);
  }

  /// One-line notices shown above the scorecard (DLS, declarations).
  static List<String> scorecardTopNotices(MatchModel match) {
    final lines = <String>[];
    final s = match.targetState;
    if (s.dlsApplied) {
      final parts = <String>['DLS applied'];
      if (s.originalOvers != null && s.effectiveRevisedOvers != null) {
        parts.add('${s.originalOvers} overs → ${s.effectiveRevisedOvers} overs');
      }
      if (s.originalTarget != null &&
          s.effectiveRevisedTarget != null &&
          s.originalTarget != s.effectiveRevisedTarget) {
        parts.add(
          'target ${s.originalTarget} → ${s.effectiveRevisedTarget}',
        );
      }
      lines.add(parts.join(' · '));
    }

    for (final inn in match.innings) {
      if (inn.status != InningsStatus.completed) continue;
      final raw = inn.endReason?.trim().toLowerCase();
      if (raw != 'declared' && raw != 'declare') continue;
      final team = _battingTeamName(match, inn);
      lines.add(
        team.isNotEmpty
            ? '$team declared their innings'
            : 'Innings ${inn.inningsNumber} declared',
      );
    }
    return lines;
  }

  static String _battingTeamName(MatchModel match, InningsModel inn) {
    if (inn.battingTeamId == match.teamAId) return match.teamAName;
    if (inn.battingTeamId == match.teamBId) return match.teamBName;
    return '';
  }

  static List<MatchRevisionBadge> badgesForMatch(MatchModel match) {
    final s = match.targetState;
    final badges = <MatchRevisionBadge>[];

    if (s.dlsApplied) {
      badges.add(const MatchRevisionBadge(label: 'DLS APPLIED', kind: 'dls'));
      if (s.effectiveRevisedTarget != null) {
        badges.add(const MatchRevisionBadge(label: 'DLS TARGET', kind: 'dls'));
      }
    }
    if (s.revisionMethod == 'manual' && s.revisedTarget != null) {
      badges.add(
        const MatchRevisionBadge(label: 'TARGET REVISED', kind: 'target'),
      );
    }
    if (s.matchOutcome == 'draw') {
      badges.add(const MatchRevisionBadge(label: 'DRAW', kind: 'result'));
    }
    if (s.matchOutcome == 'abandoned') {
      badges.add(const MatchRevisionBadge(label: 'ABANDONED', kind: 'result'));
    }
    return badges;
  }

  static List<MatchRevisionBadge> badgesForInnings(
    MatchModel match,
    InningsModel inn,
  ) {
    final badges = <MatchRevisionBadge>[];
    if (inn.inningsNumber == 1 && !inn.isSuperOver) {
      badges.addAll(badgesForMatch(match));
    } else if (inn.inningsNumber >= 2 && !inn.isSuperOver) {
      final s = match.targetState;
      if (s.dlsApplied) {
        badges.add(const MatchRevisionBadge(label: 'DLS APPLIED', kind: 'dls'));
      }
      if (s.revisionMethod == 'manual' && s.revisedTarget != null) {
        badges.add(
          const MatchRevisionBadge(label: 'TARGET REVISED', kind: 'target'),
        );
      }
    }

    if (inn.penaltyRuns != 0) {
      final sign = inn.penaltyRuns > 0 ? '+' : '';
      badges.add(
        MatchRevisionBadge(
          label: 'PENALTY $sign${inn.penaltyRuns}',
          kind: 'penalty',
        ),
      );
    }

    final end = inn.endReason?.toLowerCase();
    if (inn.status == InningsStatus.completed) {
      if (end == 'declared') {
        badges.add(const MatchRevisionBadge(label: 'DECLARED', kind: 'end'));
      } else if (end == 'all_out') {
        badges.add(const MatchRevisionBadge(label: 'ALL OUT', kind: 'end'));
      }
    }
    return badges;
  }

  static String? completedResultWithDlsNote(MatchModel match, String base) {
    final s = match.targetState;
    if (s.dlsApplied && s.effectiveRevisedTarget != null) {
      return '$base\n(DLS Revised Target: ${s.effectiveRevisedTarget})';
    }
    return base;
  }

  static InningsModel? firstRegularInnings(MatchModel match) =>
      InningsCompletionPolicy.firstInnings(match);

  static InningsModel? secondRegularInnings(MatchModel match) {
    for (final inn in match.innings) {
      if (inn.inningsNumber == 2 && !inn.isSuperOver) return inn;
    }
    return null;
  }

  static String revisionTitle(MatchRevisionModel rev) {
    final type = rev.type.toLowerCase();
    return switch (type) {
      'dls' => 'DLS Applied',
      'manual' => 'Target Revised',
      'penalty_added' => 'Penalty Runs Added',
      'penalty_removed' => 'Penalty Runs Removed',
      _ => rev.type.isNotEmpty ? rev.type : 'Revision',
    };
  }

  static String revisionBody(MatchRevisionModel rev) {
    final parts = <String>[];
    if (rev.originalOvers != null && rev.revisedOvers != null) {
      parts.add('${rev.originalOvers} overs → ${rev.revisedOvers} overs');
    }
    if (rev.oldTarget != null && rev.newTarget != null) {
      parts.add('Target: ${rev.oldTarget} → ${rev.newTarget}');
    } else if (rev.newTarget != null) {
      parts.add('Target: ${rev.newTarget}');
    }
    if (rev.penaltyRuns != null && rev.penaltyRuns != 0) {
      final sign = rev.penaltyRuns! > 0 ? '+' : '';
      parts.add('$sign${rev.penaltyRuns} Runs');
    }
    if (rev.reason.isNotEmpty) {
      parts.add('Reason: ${rev.reason}');
    }
    return parts.isEmpty ? 'Revision recorded' : parts.join('\n');
  }

  static String revisionMeta(MatchRevisionModel rev) {
    final parts = <String>[];
    if (rev.createdAt != null) {
      final dt = rev.createdAt!;
      parts.add(
        '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}',
      );
    }
    if (rev.createdBy.isNotEmpty) {
      parts.add('Scorer: ${rev.createdBy.length > 8 ? '${rev.createdBy.substring(0, 8)}…' : rev.createdBy}');
    }
    return parts.join(' · ');
  }

  static List<PenaltyAdjustmentEntry> penaltyEntries(
    MatchModel match,
    List<MatchRevisionModel> revisions,
  ) {
    final entries = <PenaltyAdjustmentEntry>[];
    for (final rev in revisions) {
      if (rev.penaltyRuns == null || rev.penaltyRuns == 0) continue;
      entries.add(
        PenaltyAdjustmentEntry(
          runs: rev.penaltyRuns!,
          reason: rev.reason,
          source: revisionTitle(rev),
        ),
      );
    }
    for (final inn in match.innings) {
      if (inn.penaltyRuns == 0) continue;
      entries.add(
        PenaltyAdjustmentEntry(
          runs: inn.penaltyRuns,
          reason: inn.penaltyReason,
          source: 'Innings ${inn.inningsNumber}',
        ),
      );
    }
    return entries;
  }

  static String buildExportSection(
    MatchModel match,
    List<MatchRevisionModel> revisions,
  ) {
    if (!hasAnyRevisionContext(match, revisions)) return '';

    final buffer = StringBuffer();
    buffer.writeln('Match Revisions');
    buffer.writeln();

    final s = match.targetState;
    if (s.originalOvers != null && s.effectiveRevisedOvers != null) {
      buffer.writeln('• DLS Applied');
      buffer.writeln('  ${s.originalOvers} overs → ${s.effectiveRevisedOvers} overs');
    }
    if (s.originalTarget != null && s.effectiveRevisedTarget != null) {
      buffer.writeln('• Target Revised');
      buffer.writeln('  ${s.originalTarget} → ${s.effectiveRevisedTarget}');
    } else if (s.effectiveRevisedTarget != null) {
      buffer.writeln('• Final Target: ${s.effectiveRevisedTarget}');
    }
    if (s.dlsApplied) {
      buffer.writeln('• DLS Applied: Yes');
    }

    for (final entry in penaltyEntries(match, revisions)) {
      final sign = entry.runs > 0 ? '+' : '';
      buffer.writeln('• Penalty Runs');
      buffer.writeln('  $sign${entry.runs} Runs');
      if (entry.reason.isNotEmpty) {
        buffer.writeln('  Reason: ${entry.reason}');
      }
    }

    if (revisions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Revision History');
      for (final rev in revisions) {
        buffer.writeln('• ${revisionTitle(rev)}');
        buffer.writeln('  ${revisionBody(rev).replaceAll('\n', '\n  ')}');
        final meta = revisionMeta(rev);
        if (meta.isNotEmpty) buffer.writeln('  $meta');
      }
    }

    final first = firstRegularInnings(match);
    if (first != null && first.status == InningsStatus.completed) {
      buffer.writeln();
      buffer.writeln('First Innings Summary');
      buffer.writeln(
        'Score: ${first.totalRuns}/${first.totalWickets}',
      );
      buffer.writeln(
        'Overs: ${OversFormatter.formatOvers(first.legalBalls, match.rules.ballsPerOver)}',
      );
      if (s.originalOvers != null) {
        buffer.writeln('Original Overs: ${s.originalOvers}');
      }
      if (s.effectiveRevisedOvers != null) {
        buffer.writeln('Revised Overs: ${s.effectiveRevisedOvers}');
      }
      buffer.writeln('DLS Applied: ${s.dlsApplied ? 'Yes' : 'No'}');
      if (s.effectiveRevisedTarget != null) {
        buffer.writeln('Target Generated: ${s.effectiveRevisedTarget}');
      }
    }

    final second = secondRegularInnings(match);
    if (second != null) {
      buffer.writeln();
      buffer.writeln('Second Innings Summary');
      if (s.originalTarget != null) {
        buffer.writeln('Original Target: ${s.originalTarget}');
      }
      final finalTarget = second.targetRuns ?? s.effectiveRevisedTarget;
      if (finalTarget != null) {
        buffer.writeln('Final Target: $finalTarget');
      }
      if (s.revisionMethod != null) {
        buffer.writeln('Revision Method: ${s.revisionMethod!.toUpperCase()}');
      }
    }

    if (match.status == MatchStatus.completed && s.dlsApplied) {
      buffer.writeln();
      buffer.writeln('Result generated after DLS revision.');
    }

    return buffer.toString().trimRight();
  }
}

class MatchRevisionBadge {
  const MatchRevisionBadge({required this.label, required this.kind});

  final String label;
  final String kind;
}

class PenaltyAdjustmentEntry {
  const PenaltyAdjustmentEntry({
    required this.runs,
    required this.reason,
    required this.source,
  });

  final int runs;
  final String reason;
  final String source;
}
