import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../../../../../../../data/models/overlay_state_model.dart';
import 'landscape_scorebug_context.dart';

enum LandscapeTopBannerKind {
  partnership(1),
  toWin(4),
  currentRunRate(5),
  projectedScore(6),
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
  }

  void onOverlayUpdate({
    required OverlayStateModel overlay,
    required LandscapeScorebugContext context,
    required bool centerEventActive,
    required bool forBurnInCapture,
  }) {
    if (forBurnInCapture) return;

    _maybeEnqueuePartnership(context);
    _maybeEnqueueOverTriggers(overlay, context);

    _prevLegalBalls = overlay.legalBalls;
    _prevOverNumber = context.currentOverNumber;

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
    if (_prevLegalBalls < 0) {
      return;
    }

    final overChanged = context.currentOverNumber != _prevOverNumber;
    final overJustStarted =
        context.ballsInCurrentOver == 0 && overlay.legalBalls > _prevLegalBalls;
    final overJustCompleted =
        context.ballsInCurrentOver == 0 &&
            overlay.legalBalls > _prevLegalBalls &&
            _prevLegalBalls > 0;

    if (overJustStarted || (overChanged && context.ballsInCurrentOver == 0)) {
      if (_lastOverForCrr != context.currentOverNumber) {
        _lastOverForCrr = context.currentOverNumber;
        _enqueue(
          const LandscapeTopBannerRequest(
            kind: LandscapeTopBannerKind.currentRunRate,
            duration: Duration(seconds: 4),
          ),
        );
      }

      if (context.showProjectionPhase &&
          _lastOverForProjection != context.currentOverNumber) {
        _lastOverForProjection = context.currentOverNumber;
        _enqueue(
          const LandscapeTopBannerRequest(
            kind: LandscapeTopBannerKind.projectedScore,
            duration: Duration(seconds: 5),
          ),
        );
      }

      if (context.isChase &&
          context.currentOverNumber % 4 == 0 &&
          _lastOverForToWin != context.currentOverNumber) {
        _lastOverForToWin = context.currentOverNumber;
        _enqueue(
          const LandscapeTopBannerRequest(
            kind: LandscapeTopBannerKind.toWin,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }

    if (overJustCompleted &&
        context.isChase &&
        overlay.requiredRunRate != null &&
        _lastOverForRrr != context.currentOverNumber) {
      _lastOverForRrr = context.currentOverNumber;
      _enqueue(
        const LandscapeTopBannerRequest(
          kind: LandscapeTopBannerKind.requiredRunRate,
          duration: Duration(seconds: 4),
        ),
      );
    }
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
    _timer = Timer(_active!.duration, () {
      _active = null;
      onChanged();
      _pumpQueue();
    });
    onChanged();
  }

  void resumeAfterCenterEvent() {
    _pumpQueue();
  }
}
