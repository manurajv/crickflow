import 'package:flutter/material.dart';

import '../../../../../../../data/models/overlay_state_model.dart';
import '../../../../../data/models/stream_overlay_theme.dart';
import '../landscape/landscape_banner_scheduler.dart';
import '../landscape/landscape_batting_panel.dart';
import '../landscape/landscape_batsmen_panel.dart';
import '../landscape/landscape_bowler_panel.dart';
import '../landscape/landscape_event_banner.dart';
import '../landscape/landscape_info_banners.dart';
import '../landscape/landscape_scorebug_context.dart';
import '../scorebug_banner_host.dart';
import '../scorebug_helpers.dart';
import '../scorebug_tokens.dart';
import 'portrait_scorebug_layout.dart';

/// Professional TV-style portrait scorebug — stacked panels matching landscape features.
class PortraitBroadcastScorebug extends StatefulWidget {
  const PortraitBroadcastScorebug({
    super.key,
    required this.overlay,
    required this.theme,
    required this.context,
    this.eventOverlay,
    this.onEventFinished,
    this.forBurnInCapture = false,
  });

  final OverlayStateModel overlay;
  final StreamOverlayTheme theme;
  final LandscapeScorebugContext context;
  final StreamEventOverlay? eventOverlay;
  final VoidCallback? onEventFinished;
  final bool forBurnInCapture;

  @override
  State<PortraitBroadcastScorebug> createState() =>
      _PortraitBroadcastScorebugState();
}

class _PortraitBroadcastScorebugState extends State<PortraitBroadcastScorebug> {
  late final LandscapeBannerScheduler _scheduler;

  @override
  void initState() {
    super.initState();
    _scheduler = LandscapeBannerScheduler(onChanged: () {
      if (mounted) setState(() {});
    });
    _syncScheduler();
  }

  @override
  void didUpdateWidget(covariant PortraitBroadcastScorebug oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (shouldSyncScorebugBannerScheduler(
      oldOverlay: oldWidget.overlay,
      newOverlay: widget.overlay,
      oldContext: oldWidget.context,
      newContext: widget.context,
    )) {
      _syncScheduler();
    }
    if (oldWidget.eventOverlay != null && widget.eventOverlay == null) {
      _scheduler.resumeAfterCenterEvent();
    }
  }

  void _syncScheduler() {
    _scheduler.onOverlayUpdate(
      overlay: widget.overlay,
      context: widget.context,
      centerEventActive:
          ScorebugHelpers.isCenterScorebugEvent(widget.eventOverlay),
      forBurnInCapture: widget.forBurnInCapture,
    );
  }

  @override
  void dispose() {
    _scheduler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ScorebugTokens.fromTheme(widget.theme);
    final ctx = widget.context;
    final overlay = widget.overlay;
    final teamAbbr = ScorebugHelpers.teamAbbrev(overlay.battingTeamName);
    final bowlingTeamName = ScorebugHelpers.bowlingTeamName(
      teamAName: overlay.teamAName,
      teamBName: overlay.teamBName,
      battingTeamName: overlay.battingTeamName,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = PortraitScorebugLayout.scaleForWidth(constraints.maxWidth);
        final barHeight = PortraitScorebugLayout.barHeight(scale);
        final secondaryHeight = PortraitScorebugLayout.secondaryRowHeight(scale);
        final centerEvent =
            ScorebugHelpers.centerScorebugEvent(widget.eventOverlay);
        final showEvent = centerEvent != null;
        final beforeBall = ctx.beforeFirstBall && !showEvent;
        final activeBanner = _scheduler.active;
        final showChaseNeedChip = !showEvent &&
            activeBanner == null &&
            ctx.shouldShowChaseNeedChip(
              totalRuns: overlay.totalRuns,
              target: overlay.target,
            );
        final topBanner = !showEvent && activeBanner != null
            ? _buildTopBanner(
                request: activeBanner,
                tokens: tokens,
                scale: scale,
                overlay: overlay,
                ctx: ctx,
              )
            : null;
        final topSecondary = topBanner ??
            (showChaseNeedChip
                ? LandscapeChaseNeedChip(
                    runsNeeded: ctx.runsNeeded!,
                    ballsRemaining: ctx.ballsRemaining!,
                    tokens: tokens,
                    scale: scale,
                    portrait: true,
                  )
                : null);
        final topBannerWidth = activeBanner?.kind ==
                LandscapeTopBannerKind.projectedScore
            ? constraints.maxWidth
            : LandscapeBattingPanel.widthThroughScore(
                scale: scale,
                scoreDisplay: overlay.scoreDisplay,
                portrait: true,
              );
        final secondaryRowH = topBanner != null
            ? secondaryHeight
            : (showChaseNeedChip ? barHeight : secondaryHeight);

        final centerPanel = showEvent
            ? LandscapeEventBanner(
                key: ValueKey(
                  '${centerEvent.type.name}-'
                  '${centerEvent.createdAt?.millisecondsSinceEpoch ?? centerEvent.title}',
                ),
                event: centerEvent,
                tokens: tokens,
                scale: scale,
                forBurnInCapture: widget.forBurnInCapture,
                onFinished: widget.onEventFinished,
              )
            : LandscapeBatsmenPanel(
                key: const ValueKey('batsmen'),
                overlay: overlay,
                tokens: tokens,
                scale: scale,
                centerTitle: beforeBall ? ctx.preBallCenterTitle : null,
                showTarget: ctx.isChase,
                compact: true,
                portrait: true,
              );

        return DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [PortraitScorebugLayout.barShadow()],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: secondaryRowH,
                width: double.infinity,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: topSecondary != null
                      ? SizedBox(
                          width: topBannerWidth,
                          child: topBanner != null
                              ? AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 320),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) =>
                                      SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(-0.1, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  ),
                                  child: KeyedSubtree(
                                    key: ValueKey(_scheduler.active!.kind),
                                    child: topBanner,
                                  ),
                                )
                              : topSecondary,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              SizedBox(height: 2 * scale),
              SizedBox(
                height: barHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LandscapeBattingPanel(
                    overlay: overlay,
                    tokens: tokens,
                    scale: scale,
                    teamAbbr: teamAbbr,
                    teamLogoUrl: ctx.battingTeamLogoUrl,
                    powerplayBadge: ctx.powerplayBadge,
                    portrait: true,
                  ),
                ),
              ),
              SizedBox(
                height: barHeight,
                child: showEvent
                    ? centerPanel
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 360),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.05, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: centerPanel,
                      ),
              ),
              LandscapeBowlerPanel(
                overlay: overlay,
                tokens: tokens,
                scale: scale,
                bowlingTeamName: bowlingTeamName,
                bowlingTeamLogoUrl: ctx.bowlingTeamLogoUrl,
                thisOverLabels: ctx.thisOverLabels,
                inlineThisOver: true,
                portrait: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBanner({
    required LandscapeTopBannerRequest request,
    required ScorebugTokens tokens,
    required double scale,
    required OverlayStateModel overlay,
    required LandscapeScorebugContext ctx,
  }) {
    return switch (request.kind) {
      LandscapeTopBannerKind.partnership => LandscapePartnershipBanner(
          runs: ctx.partnershipRuns,
          balls: ctx.partnershipBalls,
          tokens: tokens,
          scale: scale,
          portrait: true,
        ),
      LandscapeTopBannerKind.toWin => LandscapeToWinBanner(
          runsNeeded: ctx.runsNeeded ?? 0,
          ballsRemaining: ctx.ballsRemaining ?? 0,
          tokens: tokens,
          scale: scale,
          portrait: true,
        ),
      LandscapeTopBannerKind.currentRunRate => LandscapeRunRateBanner(
          runRate: overlay.runRate,
          tokens: tokens,
          scale: scale,
          portrait: true,
        ),
      LandscapeTopBannerKind.projectedScore => LandscapeProjectionBanner(
          projections: ScorebugHelpers.projectedScores(
            totalRuns: overlay.totalRuns,
            legalBalls: overlay.legalBalls,
            totalOvers: ctx.totalOvers,
            ballsPerOver: overlay.ballsPerOver,
            currentRunRate: overlay.runRate,
          ),
          tokens: tokens,
          scale: scale,
          portrait: true,
        ),
      LandscapeTopBannerKind.requiredRunRate => LandscapeRequiredRrBanner(
          requiredRunRate: overlay.requiredRunRate ?? 0,
          tokens: tokens,
          scale: scale,
          portrait: true,
        ),
    };
  }
}
