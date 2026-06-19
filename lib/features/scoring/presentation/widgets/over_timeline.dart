import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/cf_colors.dart';
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
    final cf = context.cf;
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
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cf.textMuted,
              ),
            ),
            if (overExtras > 0 && showExtrasLabel) ...[
              const Spacer(),
              Text(
                'Extras $overExtras',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cf.accent,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (deliveries.isEmpty)
          Text(
            'No deliveries recorded',
            style: TextStyle(
              fontSize: 12,
              color: cf.textMuted,
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
    final cf = context.cf;
    final isWicket = event.eventType == BallEventType.wicket;
    final isSix =
        event.eventType == BallEventType.runs && event.runs >= 6;
    final isFour =
        event.eventType == BallEventType.runs && event.runs == 4;
    final isExtra = event.eventType == BallEventType.wide ||
        event.eventType == BallEventType.noBall ||
        event.eventType == BallEventType.bye ||
        event.eventType == BallEventType.legBye ||
        (event.eventType == BallEventType.wicket &&
            event.runOutDeliveryKind != null &&
            event.runOutDeliveryKind != RunOutDeliveryKind.normal);

    final bg = isWicket
        ? cf.error
        : isSix
            ? cf.statusUpcoming.withValues(alpha: 0.18)
            : isFour
                ? cf.success.withValues(alpha: 0.15)
                : isExtra
                    ? cf.accent.withValues(alpha: 0.12)
                    : cf.sectionBackground;

    final border = isWicket
        ? cf.error
        : isSix
            ? cf.statusUpcoming.withValues(alpha: 0.65)
            : isFour
                ? cf.success.withValues(alpha: 0.55)
                : isExtra
                    ? cf.accent.withValues(alpha: 0.45)
                    : cf.border;

    final textColor = isWicket
        ? Colors.white
        : isSix
            ? cf.statusUpcoming
            : isFour
                ? cf.success
                : cf.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(right: OverTimeline._ballGap),
      child: Container(
        width: OverTimeline._ballSize,
        height: OverTimeline._ballSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: border),
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
            color: textColor,
          ),
        ),
      ),
    );
  }
}
