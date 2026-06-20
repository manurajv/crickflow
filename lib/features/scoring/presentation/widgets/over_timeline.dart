import 'package:flutter/material.dart';

import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/ball_event_model.dart';
import '../utils/scoring_display_utils.dart';
import 'delivery_bubble.dart';

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
                children: deliveries
                    .map((e) => DeliveryBubble(event: e))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }
}
