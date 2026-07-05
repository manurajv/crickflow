import '../../../../../../../data/models/overlay_state_model.dart';
import 'landscape/landscape_scorebug_context.dart';

/// Detects when the banner scheduler should re-evaluate triggers.
bool shouldSyncScorebugBannerScheduler({
  required OverlayStateModel oldOverlay,
  required OverlayStateModel newOverlay,
  required LandscapeScorebugContext oldContext,
  required LandscapeScorebugContext newContext,
}) {
  return oldOverlay.version != newOverlay.version ||
      oldOverlay.legalBalls != newOverlay.legalBalls ||
      oldContext.partnershipRuns != newContext.partnershipRuns ||
      oldContext.currentOverNumber != newContext.currentOverNumber ||
      oldContext.ballsInCurrentOver != newContext.ballsInCurrentOver ||
      oldContext.isChase != newContext.isChase;
}
