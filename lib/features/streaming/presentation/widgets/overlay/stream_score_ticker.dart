import 'package:flutter/material.dart';

import '../../../../../core/utils/cricket_math.dart';
import '../../../../../core/utils/overs_formatter.dart';
import '../../../../../data/models/overlay_state_model.dart';

/// Scrolling score ticker shown above the scorebug during live streams.
class StreamScoreTicker extends StatefulWidget {
  const StreamScoreTicker({
    super.key,
    required this.overlay,
    this.sponsorLine,
  });

  final OverlayStateModel overlay;
  final String? sponsorLine;

  @override
  State<StreamScoreTicker> createState() => _StreamScoreTickerState();
}

class _StreamScoreTickerState extends State<StreamScoreTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _buildTickerText() {
    final o = widget.overlay;
    final overs = CricketMath.formatOvers(o.legalBalls, o.ballsPerOver);
    final bowlerOvers =
        OversFormatter.formatOvers(o.bowlerBalls, o.ballsPerOver);
    final parts = <String>[
      '${o.battingTeamName} ${o.totalRuns}/${o.totalWickets} (${overs} ov)',
      'CRR ${o.runRate.toStringAsFixed(2)}',
      if (o.target != null) 'Target ${o.target}',
      '${o.bowlerName} $bowlerOvers-${o.bowlerRuns}-${o.bowlerWickets}',
      if (widget.sponsorLine != null && widget.sponsorLine!.isNotEmpty)
        widget.sponsorLine!,
    ];
    return parts.join('   •   ');
  }

  @override
  Widget build(BuildContext context) {
    final text = _buildTickerText();
    return Container(
      height: 28,
      color: Colors.black87,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                -_controller.value * MediaQuery.sizeOf(context).width * 1.4,
                0,
              ),
              child: child,
            );
          },
          child: Row(
            children: [
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 48),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
