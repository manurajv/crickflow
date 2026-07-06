import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../../../../../../../data/models/overlay_state_model.dart';
import 'landscape_scorebug_context.dart';

enum LandscapeTopBannerKind {
  partnership(1),
  projectedScore(3),
  toWin(4),
  currentRunRate(5),
  requiredRunRate(7);

  const LandscapeTopBannerKind(this.priority);
  final int priority;
}

class LandscapeTopBannerRequest {
  const LandscapeTopBannerRequest({
    required this.kind,
    required this.duration,
  });

  final LandscapeTopBannerKind kind;
  final Duration duration;
}

/// Priority queue for top-left informational banners (never shown together).
class LandscapeBannerScheduler {
  LandscapeBannerScheduler({required this.onChanged});

  final VoidCallback onChanged;

  final Queue<LandscapeTopBannerRequest> _queue = Queue();
  LandscapeTopBannerRequest? _active;
  Timer? _timer;

  int _lastPartnershipMilestone = 0;
  int _lastOverForCrr = -1;
  int _lastOverForProjection = -1;
  int _lastOverForRrr = -1;
  int _lastOverForToWin = -1;
  int _prevLegalBalls = -1;
  int _prevOverNumber = -1;
  int _latestLegalBalls = 0;
  int? _projectionStartLegalBalls;
  DateTime? _projectionStartedAt;

  static const _projectionMinDuration = Duration(seconds: 10);
  static const _projectionMinDeliveries = 2;
  static const _projectionMaxDuration = Duration(seconds: 15);

  LandscapeTopBannerRequest? get active => _active;

  void dispose() {
    _timer?.cancel();
  }

  void reset() {
    _timer?.cancel();
    _queue.clear();
    _active = null;
    _lastPartnershipMilestone = 0;
    _lastOverForCrr = -1;
    _lastOverForProjection = -1;
    _lastOverForRrr = -1;
    _lastOverForToWin = -1;
    _prevLegalBalls = -1;
    _prevOverNumber = -1;
    _latestLegalBalls = 0;
    _projectionStartLegalBalls = null;
    _projectionStartedAt = null;
  }

  void onOverlayUpdate({
    required OverlayStateModel overlay,
    required LandscapeScorebugContext context,
    required bool centerEventActive,
    required bool forBurnInCapture,
  }) {
    _latestLegalBalls = overlay.legalBalls;
    _maybeEnqueuePartnership(context);
    _maybeEnqueueOverTriggers(overlay, context);

    _prevLegalBalls = overlay.legalBalls;
    _prevOverNumber = context.currentOverNumber;

    if (_active?.kind == LandscapeTopBannerKind.projectedScore) {
      _maybeCompleteProjection(overlay);
    }

    if (centerEventActive) return;
    _pumpQueue();
  }

  void _maybeEnqueuePartnership(LandscapeScorebugContext context) {
    final runs = context.partnershipRuns;
    if (runs < 50) return;

    final milestone = (runs ~/ 50) * 50;
    if (milestone <= _lastPartnershipMilestone) return;

    _lastPartnershipMilestone = milestone;
    _enqueue(
      LandscapeTopBannerRequest(
        kind: LandscapeTopBannerKind.partnership,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _maybeEnqueueOverTriggers(
    OverlayStateModel overlay,
    LandscapeScorebugContext context,
  ) {
    if (_prevLegalBalls < 0) return;

    final overNumber = context.currentOverNumber;
    final overChanged = overNumber != _prevOverNumber;
    final inningsStarted = _prevLegalBalls == 0 && overlay.legalBalls > 0;
    final overBoundaryCompleted = overlay.legalBalls > _prevLegalBalls &&
        overlay.ballsPerOver > 0 &&
        overlay.legalBalls % overlay.ballsPerOver == 0;

    final showOverStartBanner =
        overChanged || inningsStarted || overBoundaryCompleted;

    if (showOverStartBanner) {
      final crrOver = overChanged
          ? overNumber
          : (overBoundaryCompleted && !overChanged
              ? overNumber + 1
              : overNumber);

      if (_lastOverForCrr != crrOver) {
        _lastOverForCrr = crrOver;
        _enqueue(
          const LandscapeTopBannerRequest(
            kind: LandscapeTopBannerKind.currentRunRate,
            duration: Duration(seconds: 4),
          ),
        );
      }

      if (context.isChase &&
          crrOver % 4 == 0 &&
          _lastOverForToWin != crrOver) {
        _lastOverForToWin = crrOver;
        _enqueue(
          const LandscapeTopBannerRequest(
            kind: LandscapeTopBannerKind.toWin,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }

    if (overBoundaryCompleted &&
        context.showProjectionPhase &&
        _lastOverForProjection != overNumber) {
      _lastOverForProjection = overNumber;
      _enqueue(
        const LandscapeTopBannerRequest(
          kind: LandscapeTopBannerKind.projectedScore,
          duration: _projectionMinDuration,
        ),
      );
    }

    if ((overChanged || overBoundaryCompleted) &&
        context.isChase &&
        overlay.requiredRunRate != null &&
        _lastOverForRrr != overNumber) {
      _lastOverForRrr = overNumber;
      _enqueue(
        const LandscapeTopBannerRequest(
          kind: LandscapeTopBannerKind.requiredRunRate,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _maybeCompleteProjection(OverlayStateModel overlay) {
    final startedAt = _projectionStartedAt;
    final startBalls = _projectionStartLegalBalls;
    if (startedAt == null || startBalls == null) return;

    final elapsed =
        DateTime.now().difference(startedAt) >= _projectionMinDuration;
    final deliveries = overlay.legalBalls - startBalls;
    if (elapsed && deliveries >= _projectionMinDeliveries) {
      _finishActiveBanner();
    }
  }

  void _finishActiveBanner() {
    _timer?.cancel();
    _projectionStartLegalBalls = null;
    _projectionStartedAt = null;
    _active = null;
    onChanged();
    _pumpQueue();
  }

  void _startProjectionBanner() {
    _projectionStartLegalBalls = _latestLegalBalls;
    _projectionStartedAt = DateTime.now();
    _timer?.cancel();
    _timer = Timer(_projectionMaxDuration, _finishActiveBanner);
  }

  void _enqueue(LandscapeTopBannerRequest request) {
    if (_active?.kind == request.kind) return;
    if (_queue.any((r) => r.kind == request.kind)) return;
    final items = [..._queue, request]
      ..sort((a, b) => a.kind.priority.compareTo(b.kind.priority));
    _queue
      ..clear()
      ..addAll(items);
  }

  void _pumpQueue() {
    if (_active != null) return;
    if (_queue.isEmpty) return;

    _active = _queue.removeFirst();
    _timer?.cancel();
    if (_active!.kind == LandscapeTopBannerKind.projectedScore) {
      _startProjectionBanner();
    } else {
      _timer = Timer(_active!.duration, _finishActiveBanner);
    }
    onChanged();
  }

  void resumeAfterCenterEvent() {
    _pumpQueue();
  }
}
