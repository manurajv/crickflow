import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';
import '../../domain/streaming/replay_marker_session_utils.dart';
import '../../features/streaming/domain/streaming_enums.dart';

/// Collapsible seek-bar timeline for stream replay markers across live sessions.
class StreamReplayMarkerBar extends StatefulWidget {
  const StreamReplayMarkerBar({
    super.key,
    required this.resolvedMarkers,
    required this.totalDurationMs,
    required this.sessions,
    required this.onMarkerTap,
    this.horizontalPadding = AppDimens.spaceMd,
    this.activeSourceIndex,
  });

  final List<ResolvedReplayMarker> resolvedMarkers;
  final int totalDurationMs;
  final List<ReplayMarkerSession> sessions;
  final ValueChanged<ResolvedReplayMarker> onMarkerTap;
  final double horizontalPadding;
  final int? activeSourceIndex;

  @override
  State<StreamReplayMarkerBar> createState() => _StreamReplayMarkerBarState();
}

class _StreamReplayMarkerBarState extends State<StreamReplayMarkerBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.resolvedMarkers.isEmpty || widget.totalDurationMs <= 0) {
      return const SizedBox.shrink();
    }

    final cf = context.cf;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding,
        4,
        widget.horizontalPadding,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: AppColors.gold.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Special moments',
                      style: TextStyle(
                        color: cf.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.resolvedMarkers.length}',
                      style: TextStyle(
                        color: cf.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: cf.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            _MarkerTrack(
              resolvedMarkers: widget.resolvedMarkers,
              totalDurationMs: widget.totalDurationMs,
              sessions: widget.sessions,
              onMarkerTap: widget.onMarkerTap,
              activeSourceIndex: widget.activeSourceIndex,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.resolvedMarkers.length,
                separatorBuilder: (_, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final resolved = widget.resolvedMarkers[index];
                  return _MarkerChip(
                    resolved: resolved,
                    isActive: resolved.sourceIndex == widget.activeSourceIndex,
                    onTap: () => widget.onMarkerTap(resolved),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MarkerTrack extends StatelessWidget {
  const _MarkerTrack({
    required this.resolvedMarkers,
    required this.totalDurationMs,
    required this.sessions,
    required this.onMarkerTap,
    this.activeSourceIndex,
  });

  final List<ResolvedReplayMarker> resolvedMarkers;
  final int totalDurationMs;
  final List<ReplayMarkerSession> sessions;
  final ValueChanged<ResolvedReplayMarker> onMarkerTap;
  final int? activeSourceIndex;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 24,
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 10,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: cf.border.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (sessions.length > 1)
                for (final session in sessions.skip(1))
                  Positioned(
                    left: _positionLeft(session.timelineStartMs, width) - 0.5,
                    top: 6,
                    child: Container(
                      width: 1,
                      height: 12,
                      color: cf.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
              for (final resolved in resolvedMarkers)
                _MarkerDot(
                  resolved: resolved,
                  left: _positionLeft(resolved.timelinePositionMs, width),
                  dimmed: activeSourceIndex != null &&
                      resolved.sourceIndex != activeSourceIndex,
                  onTap: () => onMarkerTap(resolved),
                ),
            ],
          ),
        );
      },
    );
  }

  double _positionLeft(int positionMs, double width) {
    final fraction = (positionMs / totalDurationMs).clamp(0.0, 1.0);
    const dotSize = 12.0;
    return (fraction * width - dotSize / 2).clamp(0.0, width - dotSize);
  }
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({
    required this.resolved,
    required this.left,
    required this.onTap,
    this.dimmed = false,
  });

  final ResolvedReplayMarker resolved;
  final double left;
  final VoidCallback onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final marker = resolved.marker;
    final color = _ReplayMarkerColors.forKind(marker.kind);

    return Positioned(
      left: left,
      top: 6,
      child: Tooltip(
        message: resolved.commentary,
        preferBelow: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Opacity(
              opacity: dimmed ? 0.55 : 1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkerChip extends StatelessWidget {
  const _MarkerChip({
    required this.resolved,
    required this.onTap,
    this.isActive = false,
  });

  final ResolvedReplayMarker resolved;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final marker = resolved.marker;
    final color = _ReplayMarkerColors.forKind(marker.kind);

    return Material(
      color: isActive ? cf.surfaceElevated : cf.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? AppColors.gold.withValues(alpha: 0.6) : cf.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  resolved.commentary,
                  style: TextStyle(
                    color: cf.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplayMarkerColors {
  _ReplayMarkerColors._();

  static Color forKind(ReplayMarkerKind kind) => switch (kind) {
        ReplayMarkerKind.wicket => AppColors.accentRed,
        ReplayMarkerKind.six => AppColors.gold,
        ReplayMarkerKind.four => AppColors.primaryBlue,
        ReplayMarkerKind.century => const Color(0xFFAB47BC),
        ReplayMarkerKind.milestone => const Color(0xFF26A69A),
        ReplayMarkerKind.custom => AppColors.textSecondary,
      };
}
