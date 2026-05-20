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
      children: [
        Container(
          color: const Color(0xFF2A3142),
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.spaceMd,
            horizontal: AppDimens.spaceLg,
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _BatsmanCell(
                    name: striker?.playerName ?? 'Striker',
                    score: ScoringDisplayUtils.batsmanScoreLine(striker),
                    isOnStrike: true,
                    onReplace: onReplaceStriker,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                Expanded(
                  child: _BatsmanCell(
                    name: nonStriker?.playerName ?? 'Non-striker',
                    score: ScoringDisplayUtils.batsmanScoreLine(nonStriker),
                    isOnStrike: false,
                    onReplace: onReplaceNonStriker,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          color: const Color(0xFF232B3A),
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sports_cricket,
                    size: 20,
                    color: AppColors.primaryBlue.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bowler?.playerName ?? 'Select bowler',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    ScoringDisplayUtils.bowlerFigures(bowler, rules.ballsPerOver),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB0BEC5),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (onReplaceBowler != null) ...[
                    const SizedBox(width: 8),
                    _ReplaceLink(label: 'Change', onTap: onReplaceBowler!),
                  ],
                ],
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BowlingSideOption(
                    label: 'Over the\nwicket',
                    selected: bowlingSide == BowlingSide.over,
                    lineAlign: Alignment.centerLeft,
                    onTap: () => onBowlingSideChanged?.call(BowlingSide.over),
                  ),
                  _BowlingSideOption(
                    label: 'Between\nthe wicket',
                    selected: bowlingSide == BowlingSide.between,
                    lineAlign: Alignment.center,
                    onTap: () =>
                        onBowlingSideChanged?.call(BowlingSide.between),
                  ),
                  _BowlingSideOption(
                    label: 'Round the\nwicket',
                    selected: bowlingSide == BowlingSide.round,
                    lineAlign: Alignment.centerRight,
                    onTap: () => onBowlingSideChanged?.call(BowlingSide.round),
                  ),
                ],
              ),
              if (overEvents.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceSm),
                _OverTimeline(events: overEvents),
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
        isOnStrike ? AppColors.primaryBlue : const Color(0xFF90A4AE);

    return Column(
      children: [
        Icon(
          Icons.sports_cricket,
          size: 18,
          color: accent,
        ),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          score,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        if (onReplace != null) ...[
          const SizedBox(height: 4),
          _ReplaceLink(label: 'Replace', onTap: onReplace!),
        ],
      ],
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
          color: AppColors.primaryBlue,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primaryBlue,
        ),
      ),
    );
  }
}

class _BowlingSideOption extends StatelessWidget {
  const _BowlingSideOption({
    required this.label,
    required this.selected,
    required this.lineAlign,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Alignment lineAlign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: 56,
            height: 40,
            child: CustomPaint(
              painter: _StumpsLinePainter(
                align: lineAlign,
                color: selected
                    ? AppColors.primaryBlue
                    : Colors.white.withValues(alpha: 0.25),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              height: 1.15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF78909C),
            ),
          ),
        ],
      ),
    );
  }
}

class _StumpsLinePainter extends CustomPainter {
  _StumpsLinePainter({required this.align, required this.color});

  final Alignment align;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final stumpW = 4.0;
    for (var i = -1; i <= 1; i++) {
      final x = cx + i * stumpW * 2.5;
      canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), paint);
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final dx = switch (align) {
      Alignment.centerLeft => size.width * 0.15,
      Alignment.centerRight => size.width * 0.85,
      _ => size.width / 2,
    };
    canvas.drawLine(
      Offset(dx, size.height * 0.35),
      Offset(dx, size.height * 0.9),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StumpsLinePainter old) =>
      old.color != color || old.align != align;
}

class _OverTimeline extends StatelessWidget {
  const _OverTimeline({required this.events});

  final List<BallEventModel> events;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: events.map((e) {
          final isWicket = e.eventType == BallEventType.wicket;
          final isBoundary =
              e.runs >= 4 && e.eventType == BallEventType.runs;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isWicket
                    ? AppColors.accentRed
                    : isBoundary
                        ? AppColors.gold.withValues(alpha: 0.35)
                        : const Color(0xFF3A4556),
                border: Border.all(
                  color: isBoundary ? AppColors.gold : const Color(0xFF4A5568),
                ),
              ),
              child: Text(
                ScoringDisplayUtils.ballBubbleLabel(e),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isWicket ? Colors.white : Colors.white,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
