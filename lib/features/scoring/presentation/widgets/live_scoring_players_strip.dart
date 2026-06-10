import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/constants/enums.dart';
import '../../../../data/models/ball_event_model.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_rules_model.dart';
import '../utils/scoring_display_utils.dart';

enum BowlingSide { over, between, round }

/// Batsmen, bowler figures, bowling side, and current-over timeline.
class LiveScoringPlayersStrip extends StatelessWidget {
  const LiveScoringPlayersStrip({
    super.key,
    required this.innings,
    required this.rules,
    required this.overEvents,
    this.bowlingSide = BowlingSide.over,
    this.onBowlingSideChanged,
    this.onReplaceStriker,
    this.onReplaceNonStriker,
    this.onReplaceBowler,
  });

  final InningsModel innings;
  final MatchRulesModel rules;
  final List<BallEventModel> overEvents;
  final BowlingSide bowlingSide;
  final ValueChanged<BowlingSide>? onBowlingSideChanged;
  final VoidCallback? onReplaceStriker;
  final VoidCallback? onReplaceNonStriker;
  final VoidCallback? onReplaceBowler;

  @override
  Widget build(BuildContext context) {
    final striker = ScoringDisplayUtils.batsman(innings, innings.strikerId);
    final nonStriker =
        ScoringDisplayUtils.batsman(innings, innings.nonStrikerId);
    final bowler = ScoringDisplayUtils.bowler(innings, innings.currentBowlerId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: AppDimens.spaceSm,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceElevated,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _BatsmanCell(
                  name: striker?.playerName ?? 'Striker',
                  score: ScoringDisplayUtils.batsmanScoreLine(striker),
                  isOnStrike: true,
                  onReplace: onReplaceStriker != null &&
                          !ScoringDisplayUtils.batsmanHasFacedBall(
                            innings,
                            innings.strikerId,
                          )
                      ? onReplaceStriker
                      : null,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: AppColors.border,
              ),
              Expanded(
                child: _BatsmanCell(
                  name: nonStriker?.playerName ?? 'Non-striker',
                  score: ScoringDisplayUtils.batsmanScoreLine(nonStriker),
                  isOnStrike: false,
                  onReplace: onReplaceNonStriker != null &&
                          !ScoringDisplayUtils.batsmanHasFacedBall(
                            innings,
                            innings.nonStrikerId,
                          )
                      ? onReplaceNonStriker
                      : null,
                ),
              ),
            ],
          ),
        ),
        Container(
          color: AppColors.card,
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            0,
          ),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      bowler?.playerName ?? 'Select bowler',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    ScoringDisplayUtils.bowlerFigures(
                      bowler,
                      rules.ballsPerOver,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (onReplaceBowler != null &&
                      !ScoringDisplayUtils.bowlerHasBowledBall(
                        innings,
                        innings.currentBowlerId,
                      )) ...[
                    const SizedBox(width: 8),
                    _ReplaceLink(label: 'Change', onTap: onReplaceBowler!),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _BowlingSideOption(
                      label: 'Over the wicket',
                      selected: bowlingSide == BowlingSide.over,
                      activeLineIndex: 0,
                      onTap: () =>
                          onBowlingSideChanged?.call(BowlingSide.over),
                    ),
                  ),
                  Expanded(
                    child: _BowlingSideOption(
                      label: 'Between the wicket',
                      selected: bowlingSide == BowlingSide.between,
                      activeLineIndex: 1,
                      onTap: () =>
                          onBowlingSideChanged?.call(BowlingSide.between),
                    ),
                  ),
                  Expanded(
                    child: _BowlingSideOption(
                      label: 'Round the wicket',
                      selected: bowlingSide == BowlingSide.round,
                      activeLineIndex: 2,
                      onTap: () =>
                          onBowlingSideChanged?.call(BowlingSide.round),
                    ),
                  ),
                ],
              ),
              if (overEvents.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceSm),
                _OverTimeline(
                  events: overEvents,
                  overExtras: ScoringDisplayUtils.currentOverExtras(overEvents),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BatsmanCell extends StatelessWidget {
  const _BatsmanCell({
    required this.name,
    required this.score,
    required this.isOnStrike,
    this.onReplace,
  });

  final String name;
  final String score;
  final bool isOnStrike;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    final accent =
        isOnStrike ? AppColors.gold : AppColors.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.sports_cricket, size: 15, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      score,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (onReplace != null) ...[
                      Text(
                        ' · ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      _ReplaceLink(label: 'Replace', onTap: onReplace!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplaceLink extends StatelessWidget {
  const _ReplaceLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.gold,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.gold,
        ),
      ),
    );
  }
}

class _BowlingSideOption extends StatelessWidget {
  const _BowlingSideOption({
    required this.label,
    required this.selected,
    required this.activeLineIndex,
    required this.onTap,
  });

  final String label;
  final bool selected;
  /// 0 = left line, 1 = middle, 2 = right.
  final int activeLineIndex;
  final VoidCallback onTap;

  static const _iconH = 40.0;
  static const _lineGap = 2.0;
  static const _lineW = 2.0;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        selected ? AppColors.gold : AppColors.textMuted.withValues(alpha: 0.5);
    final idleColor = AppColors.textMuted.withValues(alpha: 0.22);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _iconH,
                width: double.infinity,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: _lineGap),
                        Container(
                          width: _lineW,
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: i == activeLineIndex
                                ? activeColor
                                : idleColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                softWrap: true,
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.15,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverTimeline extends StatelessWidget {
  const _OverTimeline({
    required this.events,
    required this.overExtras,
  });

  final List<BallEventModel> events;
  final int overExtras;

  static const _ballSize = 36.0;
  static const _ballGap = 8.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'This over',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            if (overExtras > 0) ...[
              const Spacer(),
              Text(
                'Extras $overExtras',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: _ballSize + 4,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: events
                  .where((e) => ScoringDisplayUtils.ballBubbleLabel(e).isNotEmpty)
                  .map((e) {
                final isWicket = e.eventType == BallEventType.wicket;
                final isBoundary =
                    e.runs >= 4 && e.eventType == BallEventType.runs;
                final isExtra = e.eventType == BallEventType.wide ||
                    e.eventType == BallEventType.noBall ||
                    e.eventType == BallEventType.bye ||
                    e.eventType == BallEventType.legBye;
                return Padding(
                  padding: const EdgeInsets.only(right: _ballGap),
                  child: Container(
                    width: _ballSize,
                    height: _ballSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isWicket
                          ? AppColors.accentRed
                          : isBoundary
                              ? AppColors.gold.withValues(alpha: 0.35)
                              : isExtra
                                  ? AppColors.primaryBlue.withValues(alpha: 0.25)
                                  : AppColors.surfaceElevated,
                      border: Border.all(
                        color: isWicket
                            ? AppColors.accentRed
                            : isBoundary
                                ? AppColors.gold
                                : isExtra
                                    ? AppColors.primaryBlue
                                    : AppColors.border,
                      ),
                    ),
                    child: Text(
                      ScoringDisplayUtils.ballBubbleLabel(e),
                      style: TextStyle(
                        fontSize: e.eventType == BallEventType.wide ||
                                e.eventType == BallEventType.noBall
                            ? 9
                            : 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
