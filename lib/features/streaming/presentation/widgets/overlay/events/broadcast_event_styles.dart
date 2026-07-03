import 'package:flutter/material.dart';

import '../../../../domain/streaming_enums.dart';
import '../scorebug/scorebug_tokens.dart';

/// Visual config for broadcast event graphics.
class BroadcastEventStyle {
  const BroadcastEventStyle({
    required this.label,
    required this.color,
    required this.accent,
    this.patternChar,
  });

  final String label;
  final Color color;
  final Color accent;
  final String? patternChar;
}

/// Maps [StreamEventOverlayType] and custom titles to broadcast styling.
class BroadcastEventStyles {
  BroadcastEventStyles._();

  static BroadcastEventStyle forOverlay({
    required StreamEventOverlayType type,
    required String title,
  }) {
    final normalized = title.toUpperCase().replaceAll('!', '').trim();

    if (normalized.contains('NO BALL') || normalized == 'NO BALL') {
      return _noBall;
    }
    if (normalized.contains('WIDE') || normalized == 'WIDE') {
      return _wide;
    }
    if (normalized.contains('FREE HIT') || normalized == 'FREE HIT') {
      return _freeHit;
    }

    return switch (type) {
      StreamEventOverlayType.boundaryFour => _four,
      StreamEventOverlayType.hugeSix => _six,
      StreamEventOverlayType.wicket ||
      StreamEventOverlayType.hatTrick ||
      StreamEventOverlayType.lastWicket =>
        _wicket,
      StreamEventOverlayType.strategicTimeout => _timeout,
      StreamEventOverlayType.inningsBreak ||
      StreamEventOverlayType.drinksBreak =>
        _inningsBreak,
      StreamEventOverlayType.drsIndicator => _review,
      StreamEventOverlayType.matchFinished ||
      StreamEventOverlayType.victory ||
      StreamEventOverlayType.tournamentWinner ||
      StreamEventOverlayType.playerOfMatch =>
        _matchResult,
      _ => BroadcastEventStyle(
          label: _cleanLabel(title),
          color: ScorebugTokens.eventNeutral,
          accent: Colors.white,
        ),
    };
  }

  static String _cleanLabel(String title) {
    return title.toUpperCase().replaceAll('!', '').trim();
  }

  static const _four = BroadcastEventStyle(
    label: 'FOUR',
    color: ScorebugTokens.eventFour,
    accent: Color(0xFFBBDEFB),
    patternChar: '4',
  );

  static const _six = BroadcastEventStyle(
    label: 'SIX',
    color: ScorebugTokens.eventSix,
    accent: Color(0xFFFFE082),
    patternChar: '6',
  );

  static const _wicket = BroadcastEventStyle(
    label: 'WICKET',
    color: ScorebugTokens.eventWicket,
    accent: Color(0xFFEF9A9A),
    patternChar: 'W',
  );

  static const _noBall = BroadcastEventStyle(
    label: 'NO BALL',
    color: Color(0xFFE65100),
    accent: Color(0xFFFFCC80),
  );

  static const _wide = BroadcastEventStyle(
    label: 'WIDE',
    color: Color(0xFF00838F),
    accent: Color(0xFF80DEEA),
  );

  static const _freeHit = BroadcastEventStyle(
    label: 'FREE HIT',
    color: Color(0xFF2E7D32),
    accent: Color(0xFFA5D6A7),
  );

  static const _review = BroadcastEventStyle(
    label: 'REVIEW',
    color: ScorebugTokens.eventReview,
    accent: Color(0xFFCE93D8),
  );

  static const _timeout = BroadcastEventStyle(
    label: 'STRATEGIC TIMEOUT',
    color: ScorebugTokens.eventBreak,
    accent: Color(0xFFB0BEC5),
  );

  static const _inningsBreak = BroadcastEventStyle(
    label: 'INNINGS BREAK',
    color: ScorebugTokens.eventBreak,
    accent: Color(0xFFB0BEC5),
  );

  static const _matchResult = BroadcastEventStyle(
    label: 'MATCH RESULT',
    color: ScorebugTokens.eventResult,
    accent: Color(0xFFFFC107),
  );
}

/// Ghosted background pattern for event banners.
class EventPatternBackground extends StatelessWidget {
  const EventPatternBackground({
    super.key,
    required this.char,
    required this.color,
  });

  final String char;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 48).ceil().clamp(3, 20);
        final rows = (constraints.maxHeight / 40).ceil().clamp(1, 4);
        return OverflowBox(
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
          alignment: Alignment.center,
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: List.generate(
              cols * rows,
              (_) => Text(
                char,
                style: TextStyle(
                  color: color.withValues(alpha: 0.12),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shared event banner used by portrait and landscape graphics.
class BroadcastEventCard extends StatelessWidget {
  const BroadcastEventCard({
    super.key,
    required this.style,
    required this.title,
    required this.subtitle,
    required this.landscape,
  });

  final BroadcastEventStyle style;
  final String title;
  final String subtitle;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: landscape ? 420 : 0,
        maxWidth: landscape ? 720 : double.infinity,
      ),
      margin: EdgeInsets.symmetric(horizontal: landscape ? 48 : 20),
      padding: EdgeInsets.symmetric(
        horizontal: landscape ? 48 : 24,
        vertical: landscape ? 20 : 18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [style.color, Color.lerp(style.color, Colors.black, 0.25)!],
        ),
        borderRadius: BorderRadius.circular(landscape ? 2 : 8),
        border: Border(
          left: BorderSide(color: style.accent, width: landscape ? 6 : 5),
        ),
        boxShadow: [
          BoxShadow(
            color: style.color.withValues(alpha: 0.55),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (style.patternChar != null)
            Positioned.fill(
              child: EventPatternBackground(
                char: style.patternChar!,
                color: style.accent,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: landscape ? 44 : 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: landscape ? 8 : 4,
                  height: 1,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: landscape ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
