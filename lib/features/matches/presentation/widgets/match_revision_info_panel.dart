import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/overs_formatter.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/match_revision_model.dart';
import '../../../../domain/display/match_revision_display.dart';
import '../../../../shared/widgets/match_revision_badge.dart';

/// Match summary / scorecard sections for revisions, DLS, targets, penalties.
class MatchRevisionInfoPanel extends StatelessWidget {
  const MatchRevisionInfoPanel({
    super.key,
    required this.match,
    required this.revisions,
    this.showRevisionHistory = true,
    this.showInningsSummaries = true,
    this.showTargetInfo = true,
    this.showMatchRevisionsList = true,
    this.compact = false,
  });

  final MatchModel match;
  final List<MatchRevisionModel> revisions;
  final bool showRevisionHistory;
  final bool showInningsSummaries;
  final bool showTargetInfo;
  final bool showMatchRevisionsList;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!MatchRevisionDisplay.hasAnyRevisionContext(match, revisions)) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];

    if (showMatchRevisionsList) {
      children.add(
        _MatchRevisionsListSection(match: match, revisions: revisions),
      );
    }
    if (showInningsSummaries) {
      children.add(_FirstInningsSummarySection(match: match));
      children.add(
        _SecondInningsSummarySection(match: match, revisions: revisions),
      );
    }
    if (showTargetInfo) {
      children.add(_TargetInformationSection(match: match, revisions: revisions));
    }
    final penalties = MatchRevisionDisplay.penaltyEntries(match, revisions);
    if (penalties.isNotEmpty) {
      children.add(_PenaltyAdjustmentsSection(entries: penalties));
    }
    if (showRevisionHistory && revisions.isNotEmpty) {
      children.add(_RevisionHistorySection(revisions: revisions));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            SizedBox(height: compact ? AppDimens.spaceSm : AppDimens.spaceMd),
          children[i],
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            child,
          ],
        ),
      ),
    );
  }
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _MatchRevisionsListSection extends StatelessWidget {
  const _MatchRevisionsListSection({
    required this.match,
    required this.revisions,
  });

  final MatchModel match;
  final List<MatchRevisionModel> revisions;

  @override
  Widget build(BuildContext context) {
    final s = match.targetState;
    final bullets = <String>[];

    if (s.originalOvers != null && s.effectiveRevisedOvers != null) {
      bullets.add(
        'DLS Applied\n${s.originalOvers} overs → ${s.effectiveRevisedOvers} overs',
      );
    }
    if (s.originalTarget != null && s.effectiveRevisedTarget != null) {
      bullets.add(
        'Target Revised\n${s.originalTarget} → ${s.effectiveRevisedTarget}',
      );
    } else if (s.revisionMethod == 'manual' && s.revisedTarget != null) {
      bullets.add('Target Revised\nRevised Target: ${s.revisedTarget}');
    }

    for (final entry in MatchRevisionDisplay.penaltyEntries(match, revisions)) {
      final sign = entry.runs > 0 ? '+' : '';
      var line = 'Penalty Runs\n$sign${entry.runs} Runs';
      if (entry.reason.isNotEmpty) {
        line += '\nReason\n${entry.reason}';
      }
      bullets.add(line);
    }

    if (bullets.isEmpty && revisions.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SectionCard(
      title: 'Match Revisions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MatchRevisionBadgeRow(
            badges: MatchRevisionDisplay.badgesForMatch(match),
          ),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceSm),
            for (final bullet in bullets) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }
}

class _FirstInningsSummarySection extends StatelessWidget {
  const _FirstInningsSummarySection({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final first = MatchRevisionDisplay.firstRegularInnings(match);
    if (first == null || first.status != InningsStatus.completed) {
      return const SizedBox.shrink();
    }
    if (!MatchRevisionDisplay.hasTargetRevisionData(match)) {
      return const SizedBox.shrink();
    }

    final s = match.targetState;
    final overs = OversFormatter.formatOvers(
      first.legalBalls,
      match.rules.ballsPerOver,
    );

    return _SectionCard(
      title: 'First Innings Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Score', '${first.totalRuns}/${first.totalWickets}'),
          _infoRow('Overs', overs),
          if (s.originalOvers != null)
            _infoRow('Original Overs', '${s.originalOvers}'),
          if (s.effectiveRevisedOvers != null)
            _infoRow('Revised Overs', '${s.effectiveRevisedOvers}'),
          _infoRow('DLS Applied', s.dlsApplied ? 'Yes' : 'No'),
          if (s.effectiveRevisedTarget != null)
            _infoRow('Target Generated', '${s.effectiveRevisedTarget}'),
        ],
      ),
    );
  }
}

class _SecondInningsSummarySection extends StatelessWidget {
  const _SecondInningsSummarySection({
    required this.match,
    required this.revisions,
  });

  final MatchModel match;
  final List<MatchRevisionModel> revisions;

  @override
  Widget build(BuildContext context) {
    final second = MatchRevisionDisplay.secondRegularInnings(match);
    if (second == null) return const SizedBox.shrink();
    if (!MatchRevisionDisplay.hasTargetRevisionData(match)) {
      return const SizedBox.shrink();
    }

    final s = match.targetState;
    final finalTarget = second.targetRuns ?? s.effectiveRevisedTarget;
    final reason = _latestReason(revisions);

    return _SectionCard(
      title: 'Second Innings Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.originalTarget != null)
            _infoRow('Original Target', '${s.originalTarget}'),
          if (finalTarget != null) _infoRow('Final Target', '$finalTarget'),
          if (s.revisionMethod != null)
            _infoRow('Revision Method', s.revisionMethod!.toUpperCase()),
          if (reason.isNotEmpty) _infoRow('Reason', reason),
        ],
      ),
    );
  }

  static String _latestReason(List<MatchRevisionModel> revisions) {
    for (final rev in revisions.reversed) {
      if (rev.reason.isNotEmpty) return rev.reason;
    }
    return '';
  }
}

class _TargetInformationSection extends StatelessWidget {
  const _TargetInformationSection({
    required this.match,
    required this.revisions,
  });

  final MatchModel match;
  final List<MatchRevisionModel> revisions;

  @override
  Widget build(BuildContext context) {
    final s = match.targetState;
    final original = s.originalTarget;
    final current = s.effectiveRevisedTarget ?? s.pendingChaseTarget;
    if (original == null && current == null && !s.dlsApplied) {
      return const SizedBox.shrink();
    }

    final reason = _SecondInningsSummarySection._latestReason(revisions);

    return _SectionCard(
      title: 'Target Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (original != null) _infoRow('Original Target', '$original'),
          if (current != null) _infoRow('Current Target', '$current'),
          if (s.revisionMethod != null)
            _infoRow('Revision Method', s.revisionMethod!.toUpperCase()),
          if (reason.isNotEmpty) _infoRow('Reason', reason),
          if (original != null && current != null && original != current) ...[
            const SizedBox(height: 8),
            Text(
              'Target: $original',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            Text(
              'Revised Target: $current',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PenaltyAdjustmentsSection extends StatelessWidget {
  const _PenaltyAdjustmentsSection({required this.entries});

  final List<PenaltyAdjustmentEntry> entries;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Penalty Adjustments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in entries) ...[
            MatchRevisionBadgeChip(
              label: entry.runs > 0
                  ? 'PENALTY +${entry.runs}'
                  : 'PENALTY ${entry.runs}',
              kind: 'penalty',
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.runs > 0 ? '+' : ''}${entry.runs} Runs',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (entry.reason.isNotEmpty)
              Text(
                'Reason: ${entry.reason}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            Text(
              entry.source,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _RevisionHistorySection extends StatefulWidget {
  const _RevisionHistorySection({required this.revisions});

  final List<MatchRevisionModel> revisions;

  @override
  State<_RevisionHistorySection> createState() =>
      _RevisionHistorySectionState();
}

class _RevisionHistorySectionState extends State<_RevisionHistorySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Revision History',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final rev in widget.revisions) ...[
                    Text(
                      MatchRevisionDisplay.revisionTitle(rev),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      MatchRevisionDisplay.revisionBody(rev),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    if (MatchRevisionDisplay.revisionMeta(rev).isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        MatchRevisionDisplay.revisionMeta(rev),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    const Divider(height: 20),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
