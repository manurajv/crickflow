import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/ball_event_model.dart';
import '../utils/scoring_display_utils.dart';

/// Shared delivery bubble — same visuals as live scoring over timeline.
class DeliveryBubble extends StatelessWidget {
  const DeliveryBubble({
    super.key,
    required this.event,
    this.size = 36,
    this.fontSize,
    this.marginRight = 8,
  });

  final BallEventModel event;
  final double size;
  final double? fontSize;
  final double marginRight;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final label = ScoringDisplayUtils.ballBubbleLabel(event);
    if (label.isEmpty) return const SizedBox.shrink();

    final style = DeliveryBubbleStyle.forEvent(event, cf);
    final textSize = fontSize ??
        (event.eventType == BallEventType.wide ||
                event.eventType == BallEventType.noBall ||
                label.contains('+')
            ? 9
            : 11);

    return Padding(
      padding: EdgeInsets.only(right: marginRight),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: style.background,
          border: Border.all(color: style.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: textSize,
            fontWeight: FontWeight.w700,
            color: style.text,
          ),
        ),
      ),
    );
  }
}

/// Live-scoring delivery bubble colors (from over timeline).
class DeliveryBubbleStyle {
  const DeliveryBubbleStyle({
    required this.background,
    required this.border,
    required this.text,
  });

  final Color background;
  final Color border;
  final Color text;

  static DeliveryBubbleStyle forEvent(BallEventModel event, CfColors cf) {
    final isWicket = event.eventType == BallEventType.wicket;
    final isSix = event.eventType == BallEventType.runs && event.runs >= 6;
    final isFour = event.eventType == BallEventType.runs && event.runs == 4;
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

    final text = isWicket
        ? Colors.white
        : isSix
            ? cf.statusUpcoming
            : isFour
                ? cf.success
                : cf.textPrimary;

    return DeliveryBubbleStyle(background: bg, border: border, text: text);
  }
}
