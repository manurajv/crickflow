import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/batter_intro_profile.dart';
import '../../../../data/models/innings_break_snapshot.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import '../../../providers/player_intro_lookup.dart';
import '../../../providers/streaming_studio_providers.dart';
import '../batter_intro/batter_intro_career_card.dart';
import '../events/broadcast_event_anim.dart';
import '../scorebug/broadcast_live_branding.dart';
import '../scorebug/broadcast_match_title_chip.dart';
import '../scorebug/scorebug_tokens.dart';
import 'innings_break_side_panels.dart';

/// Chase opening pair intro with target and first-innings context.
class ChaseOpeningBatsmenIntro extends ConsumerStatefulWidget {
  const ChaseOpeningBatsmenIntro({
    super.key,
    required this.matchId,
    required this.snapshot,
    required this.theme,
    required this.landscape,
    this.onFinished,
    this.onVisualChange,
  });

  final String matchId;
  final ChaseOpeningBatsmenSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;
  final VoidCallback? onFinished;
  final VoidCallback? onVisualChange;

  static const holdDuration = Duration(seconds: 8);

  @override
  ConsumerState<ChaseOpeningBatsmenIntro> createState() =>
      _ChaseOpeningBatsmenIntroState();
}

class _ChaseOpeningBatsmenIntroState
    extends ConsumerState<ChaseOpeningBatsmenIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: BroadcastEventAnim.defaultEnter,
      reverseDuration: BroadcastEventAnim.defaultExit,
    )..addListener(() => widget.onVisualChange?.call());

    unawaited(
      BroadcastEventAnim.runSequence(
        controller: _controller,
        hold: ChaseOpeningBatsmenIntro.holdDuration,
        isMounted: () => mounted,
        onFinished: _finish,
      ),
    );
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ScorebugTokens.fromTheme(widget.theme);
    final snapshot = widget.snapshot;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = widget.landscape
            ? (constraints.maxWidth / 1280).clamp(0.65, 1.35).toDouble()
            : (constraints.maxWidth / 360).clamp(0.78, 1.1).toDouble();

        final strikerLookup = PlayerIntroLookup(
          matchId: widget.matchId,
          playerId: snapshot.strikerId,
          fallbackName: snapshot.strikerName,
        );
        final nonStrikerLookup = PlayerIntroLookup(
          matchId: widget.matchId,
          playerId: snapshot.nonStrikerId,
          fallbackName: snapshot.nonStrikerName,
        );

        final strikerProfile =
            ref.watch(batterIntroProfileProvider(strikerLookup)).valueOrNull ??
                BatterIntroProfile(playerName: snapshot.strikerName);
        final nonStrikerProfile = ref
                .watch(batterIntroProfileProvider(nonStrikerLookup))
                .valueOrNull ??
            BatterIntroProfile(playerName: snapshot.nonStrikerName);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: BroadcastEventAnim.exitAwareOpacity(_controller),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(12 * scale),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: BroadcastMatchTitleChip(
                                  title: snapshot.matchTitle,
                                  tokens: tokens,
                                  scale: scale,
                                  landscape: widget.landscape,
                                ),
                              ),
                              SizedBox(width: 10 * scale),
                              BroadcastLiveBranding(
                                tokens: tokens,
                                scale: scale,
                                landscape: widget.landscape,
                                logoUrl: snapshot.crickflowLogoUrl.isNotEmpty
                                    ? snapshot.crickflowLogoUrl
                                    : null,
                              ),
                            ],
                          ),
                          SizedBox(height: 10 * scale),
                          _ChaseContextBand(
                            snapshot: snapshot,
                            tokens: tokens,
                            scale: scale,
                          ),
                          Expanded(
                            child: Align(
                              alignment: const Alignment(0, -0.2),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    BatterIntroCareerCard(
                                      profile: strikerProfile,
                                      tokens: tokens,
                                      scale: scale * 0.88,
                                      landscape: widget.landscape,
                                    ),
                                    SizedBox(width: 28 * scale),
                                    BatterIntroCareerCard(
                                      profile: nonStrikerProfile,
                                      tokens: tokens,
                                      scale: scale * 0.88,
                                      landscape: widget.landscape,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ChaseContextBand extends StatelessWidget {
  const _ChaseContextBand({
    required this.snapshot,
    required this.tokens,
    required this.scale,
  });

  final ChaseOpeningBatsmenSnapshot snapshot;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 10 * scale),
      decoration: BoxDecoration(
        color: tokens.panelBg.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border(
          left: BorderSide(
            color: InningsBreakVisuals.highlightBlue,
            width: 3 * scale,
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18 * scale,
        runSpacing: 6 * scale,
        children: [
          _chip('1ST INNINGS', snapshot.firstInningsScore, tokens, scale),
          _chip('TARGET', '${snapshot.target}', tokens, scale),
          _chip(
            'REQ RR',
            snapshot.requiredRunRate.toStringAsFixed(2),
            tokens,
            scale,
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String label,
    String value,
    ScorebugTokens tokens,
    double scale,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tokens.white.withValues(alpha: 0.72),
            fontSize: 9 * scale,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(width: 6 * scale),
        Text(
          value,
          style: TextStyle(
            color: tokens.white,
            fontSize: 14 * scale,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
