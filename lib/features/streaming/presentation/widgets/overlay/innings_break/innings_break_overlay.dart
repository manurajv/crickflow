import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../data/models/innings_break_snapshot.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import 'innings_break_screens.dart';

/// Looped innings break slideshow — centered cards, 15 seconds per screen.
class InningsBreakOverlay extends StatefulWidget {
  const InningsBreakOverlay({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
    this.onVisualChange,
  });

  final InningsBreakSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;
  final VoidCallback? onVisualChange;

  static const slideDuration = Duration(seconds: 15);

  @override
  State<InningsBreakOverlay> createState() => _InningsBreakOverlayState();
}

class _InningsBreakOverlayState extends State<InningsBreakOverlay> {
  Timer? _timer;
  int _index = 0;

  List<InningsBreakScreenKind> get _screens => widget.snapshot.screens;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant InningsBreakOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= _screens.length) {
      _index = 0;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(InningsBreakOverlay.slideDuration, (_) => _next());
  }

  void _next() {
    if (!mounted || _screens.isEmpty) return;
    setState(() => _index = (_index + 1) % _screens.length);
    widget.onVisualChange?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_screens.isEmpty) return const SizedBox.shrink();

    final kind = _screens[_index];

    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: [
              ...previousChildren,
              ?currentChild,
            ],
          );
        },
        child: KeyedSubtree(
          key: ValueKey(kind),
          child: _screenFor(kind),
        ),
      ),
    );
  }

  Widget _screenFor(InningsBreakScreenKind kind) {
    final snapshot = widget.snapshot;
    final theme = widget.theme;
    final landscape = widget.landscape;

    return switch (kind) {
      InningsBreakScreenKind.battingScorecard => BattingScorecardScreen(
          snapshot: snapshot,
          theme: theme,
          landscape: landscape,
        ),
      InningsBreakScreenKind.bowlingFigures => BowlingScorecardScreen(
          snapshot: snapshot,
          theme: theme,
          landscape: landscape,
        ),
      InningsBreakScreenKind.inningsSummary => MatchSummaryScreen(
          snapshot: snapshot,
          theme: theme,
          landscape: landscape,
        ),
      InningsBreakScreenKind.battingHighlights => BattingHighlightsScreen(
          snapshot: snapshot,
          theme: theme,
          landscape: landscape,
        ),
      InningsBreakScreenKind.bowlingHighlights => BowlingHighlightsScreen(
          snapshot: snapshot,
          theme: theme,
          landscape: landscape,
        ),
      InningsBreakScreenKind.matchSituation => MatchSituationScreen(
          snapshot: snapshot,
          theme: theme,
          landscape: landscape,
        ),
      InningsBreakScreenKind.partnerships => PartnershipScreen(
          snapshot: snapshot,
          theme: theme,
          landscape: landscape,
        ),
      InningsBreakScreenKind.fallOfWickets => FallOfWicketsScreen(
          snapshot: snapshot,
          theme: theme,
          landscape: landscape,
        ),
      InningsBreakScreenKind.analytics => AnalyticsScreen(
          snapshot: snapshot,
          theme: theme,
          landscape: landscape,
        ),
      InningsBreakScreenKind.thankYou => ThankYouScreen(
          snapshot: snapshot,
          theme: theme,
          landscape: landscape,
        ),
    };
  }
}
