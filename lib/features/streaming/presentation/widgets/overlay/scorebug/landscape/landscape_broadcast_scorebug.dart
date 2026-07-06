import 'package:flutter/material.dart';

import '../../../../../../../data/models/overlay_state_model.dart';
import '../../../../../data/models/stream_overlay_theme.dart';
import '../scorebug_banner_host.dart';
import '../scorebug_helpers.dart';
import '../scorebug_tokens.dart';
import 'landscape_banner_scheduler.dart';
import 'landscape_batting_panel.dart';
import 'landscape_batsmen_panel.dart';
import 'landscape_bowler_panel.dart';
import 'landscape_event_banner.dart';
import 'landscape_info_banners.dart';
import 'landscape_scorebug_context.dart';
import 'landscape_scorebug_layout.dart';
import 'landscape_this_over_widget.dart';

/// Professional TV-style landscape scorebug — bottom broadcast bar with modular panels.
class LandscapeBroadcastScorebug extends StatefulWidget {
  const LandscapeBroadcastScorebug({
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
  State<LandscapeBroadcastScorebug> createState() =>
      _LandscapeBroadcastScorebugState();
}

class _LandscapeBroadcastScorebugState extends State<LandscapeBroadcastScorebug> {
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
  void didUpdateWidget(covariant LandscapeBroadcastScorebug oldWidget) {
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
        final scale = LandscapeScorebugLayout.scaleForWidth(constraints.maxWidth);
        final barHeight = LandscapeScorebugLayout.barHeight(scale);
        final secondaryHeight = LandscapeScorebugLayout.secondaryRowHeight(scale);
        final gap = LandscapeScorebugLayout.panelGap(scale);
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
                  )
                : null);
        final topBannerWidth = activeBanner?.kind ==
                LandscapeTopBannerKind.projectedScore
            ? LandscapeScorebugLayout.bannerWidthThroughBatsmen(
                totalWidth: constraints.maxWidth,
                scale: scale,
              )
            : LandscapeBattingPanel.widthThroughScore(
                scale: scale,
                scoreDisplay: overlay.scoreDisplay,
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
              );

        final totalHeight = secondaryRowH + (2 * scale) + barHeight;
        final bowlerColumnWidth =
            (constraints.maxWidth * 0.26).clamp(148 * scale, 230 * scale);
        final edgeInset = LandscapeScorebugLayout.edgeInset(scale);
        final sectionGap = LandscapeScorebugLayout.batsmenBowlerGap(scale);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [LandscapeScorebugLayout.barShadow()],
              ),
              child: SizedBox(
                height: totalHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(width: edgeInset),
                    Expanded(
                      child: Column(
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
                                              duration: const Duration(
                                                milliseconds: 320,
                                              ),
                                              switchInCurve: Curves.easeOutCubic,
                                              switchOutCurve: Curves.easeInCubic,
                                              transitionBuilder:
                                                  (child, animation) =>
                                                      SlideTransition(
                                                position: Tween<Offset>(
                                                  begin: const Offset(-0.12, 0),
                                                  end: Offset.zero,
                                                ).animate(animation),
                                                child: FadeTransition(
                                                  opacity: animation,
                                                  child: child,
                                                ),
                                              ),
                                              child: KeyedSubtree(
                                                key: ValueKey(
                                                  _scheduler.active!.kind,
                                                ),
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
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                LandscapeBattingPanel(
                                  overlay: overlay,
                                  tokens: tokens,
                                  scale: scale,
                                  teamAbbr: teamAbbr,
                                  teamLogoUrl: ctx.battingTeamLogoUrl,
                                  powerplayBadge: ctx.powerplayBadge,
                                ),
                                SizedBox(width: gap),
                                Expanded(
                                  child: showEvent
                                      ? centerPanel
                                      : AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 360),
                                          switchInCurve: Curves.easeOutCubic,
                                          switchOutCurve: Curves.easeIn,
                                          transitionBuilder:
                                              (child, animation) {
                                            return FadeTransition(
                                              opacity: animation,
                                              child: SlideTransition(
                                                position: Tween<Offset>(
                                                  begin: const Offset(0.06, 0),
                                                  end: Offset.zero,
                                                ).animate(animation),
                                                child: child,
                                              ),
                                            );
                                          },
                                          child: centerPanel,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: sectionGap),
                    SizedBox(
                      width: bowlerColumnWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LandscapeThisOverWidget(
                            labels: ctx.thisOverLabels,
                            tokens: tokens,
                            scale: scale,
                          ),
                          SizedBox(height: 2 * scale),
                          SizedBox(
                            height: barHeight,
                            child: LandscapeBowlerPanel(
                              overlay: overlay,
                              tokens: tokens,
                              scale: scale,
                              bowlingTeamName: bowlingTeamName,
                              bowlingTeamLogoUrl: ctx.bowlingTeamLogoUrl,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: edgeInset),
                  ],
                ),
              ),
            ),
          ],
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
        ),
      LandscapeTopBannerKind.toWin => LandscapeToWinBanner(
          runsNeeded: ctx.runsNeeded ?? 0,
          ballsRemaining: ctx.ballsRemaining ?? 0,
          tokens: tokens,
          scale: scale,
        ),
      LandscapeTopBannerKind.currentRunRate => LandscapeRunRateBanner(
          runRate: overlay.runRate,
          tokens: tokens,
          scale: scale,
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
        ),
      LandscapeTopBannerKind.requiredRunRate => LandscapeRequiredRrBanner(
          requiredRunRate: overlay.requiredRunRate ?? 0,
          tokens: tokens,
          scale: scale,
        ),
    };
  }
}
