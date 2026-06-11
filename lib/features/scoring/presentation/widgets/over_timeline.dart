import 'package:flutter/material.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/ball_event_model.dart';
import '../utils/scoring_display_utils.dart';

/// Ball-by-ball delivery bubbles for the current or completed over.
class OverTimeline extends StatelessWidget {
  const OverTimeline({
    super.key,
    required this.events,
    this.overExtras = 0,
    this.title = 'This over',
    this.showExtrasLabel = true,
  });

  final List<BallEventModel> events;
  final int overExtras;
  final String title;
  final bool showExtrasLabel;

  static const _ballSize = 36.0;
  static const _ballGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final deliveries = events
        .where((e) => ScoringDisplayUtils.ballBubbleLabel(e).isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            if (overExtras > 0 && showExtrasLabel) ...[
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
        if (deliveries.isEmpty)
          const Text(
            'No deliveries recorded',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          )
        else
          SizedBox(
            height: _ballSize + 4,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: deliveries.map(_DeliveryBubble.new).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _DeliveryBubble extends StatelessWidget {
  const _DeliveryBubble(this.event);

  final BallEventModel event;

  @override
  Widget build(BuildContext context) {
    final isWicket = event.eventType == BallEventType.wicket;
    final isBoundary = event.runs >= 4 && event.eventType == BallEventType.runs;
    final isExtra = event.eventType == BallEventType.wide ||
        event.eventType == BallEventType.noBall ||
        event.eventType == BallEventType.bye ||
        event.eventType == BallEventType.legBye ||
        (event.eventType == BallEventType.wicket &&
            event.runOutDeliveryKind != null &&
            event.runOutDeliveryKind != RunOutDeliveryKind.normal);

    return Padding(
      padding: const EdgeInsets.only(right: OverTimeline._ballGap),
      child: Container(
        width: OverTimeline._ballSize,
        height: OverTimeline._ballSize,
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
          ScoringDisplayUtils.ballBubbleLabel(event),
          style: TextStyle(
            fontSize: event.eventType == BallEventType.wide ||
                    event.eventType == BallEventType.noBall ||
                    ScoringDisplayUtils.ballBubbleLabel(event).contains('+')
                ? 9
                : 11,
            fontWeight: FontWeight.w700,
            color: isWicket ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
