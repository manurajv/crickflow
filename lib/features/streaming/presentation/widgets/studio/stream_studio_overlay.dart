import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/match_model.dart';
import '../../../../../data/services/stream_service.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../domain/streaming_enums.dart';
import '../../providers/streaming_studio_providers.dart';
import 'stream_studio_quick_settings_sheet.dart';
import 'stream_camera_settings_sheet.dart';
import 'studio_landscape_rotation.dart';

const _kTopBarH = 48.0;
const _kBottomDockH = 52.0;
const _kEdge = 12.0;
const _kLensChipH = 32.0;
const _kIconSize = 18.0;
const _kControlSize = 38.0;

enum _BroadcastButtonState { setup, ready, connecting, live, reconnecting }

/// Professional studio chrome over the full-screen camera preview.
class StreamStudioOverlay extends ConsumerStatefulWidget {
  const StreamStudioOverlay({
    super.key,
    required this.matchId,
    required this.match,
    required this.canStart,
    required this.onLensSelected,
    required this.onGoLive,
    required this.onOpenBroadcastSetup,
    required this.cameraReady,
    this.isLive = false,
    this.isObsMode = false,
    this.onEndStream,
    this.onMarkReplay,
  });

  final String matchId;
  final MatchModel match;
  final bool canStart;
  final Future<void> Function(int lensIndex) onLensSelected;
  final VoidCallback onGoLive;
  final VoidCallback onOpenBroadcastSetup;
  final bool cameraReady;
  final bool isLive;
  final bool isObsMode;
  final VoidCallback? onEndStream;
  final VoidCallback? onMarkReplay;

  @override
  ConsumerState<StreamStudioOverlay> createState() => _StreamStudioOverlayState();
}

class _StreamStudioOverlayState extends ConsumerState<StreamStudioOverlay>
    with TickerProviderStateMixin {
  bool _chromeHidden = false;
  bool _statsVisible = false;
  Timer? _autoHideTimer;
  Timer? _durationTimer;
  DateTime? _liveStartedAt;
  late AnimationController _livePulse;
  late AnimationController _connectPulse;

  @override
  void initState() {
    super.initState();
    _livePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.85,
      upperBound: 1,
    );
    _connectPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    if (widget.isLive) {
      _liveStartedAt = DateTime.now();
      _startDurationTicker();
      _statsVisible = true;
    }
  }

  @override
  void didUpdateWidget(covariant StreamStudioOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && !oldWidget.isLive) {
      _liveStartedAt = DateTime.now();
      _startDurationTicker();
      _statsVisible = true;
      _scheduleAutoHide();
      _livePulse.repeat(reverse: true);
    } else if (!widget.isLive && oldWidget.isLive) {
      _durationTimer?.cancel();
      _livePulse.stop();
    }
  }

  void _startDurationTicker() {
    _durationTimer?.cancel();
    if (!widget.isLive) return;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.isLive) setState(() {});
    });
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    if (!widget.isLive || _chromeHidden) return;
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && widget.isLive) setState(() => _chromeHidden = true);
    });
  }

  void _showChrome() {
    setState(() => _chromeHidden = false);
    _scheduleAutoHide();
  }

  String _liveDuration() {
    final start = _liveStartedAt;
    if (start == null) return '00:00';
    final d = DateTime.now().difference(start);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _durationTimer?.cancel();
    _livePulse.dispose();
    _connectPulse.dispose();
    super.dispose();
  }

  bool _showNetworkWarning(StreamHealthMetrics? health) {
    if (health == null) return false;
    return health.isReconnecting ||
        health.connectionQuality == StreamConnectionQuality.poor;
  }

  _BroadcastButtonState _buttonState(
    StreamService service,
    StreamHealthMetrics? health,
    bool configured,
  ) {
    if (widget.isLive) {
      if (service.status == StreamStatus.connecting ||
          health?.isReconnecting == true) {
        return _BroadcastButtonState.reconnecting;
      }
      return _BroadcastButtonState.live;
    }
    if (service.status == StreamStatus.connecting) {
      return _BroadcastButtonState.connecting;
    }
    if (configured) return _BroadcastButtonState.ready;
    return _BroadcastButtonState.setup;
  }

  Future<void> _toggleOrientation() async {
    final service = ref.read(streamServiceProvider);
    final notifier =
        ref.read(streamStudioConfigProvider(widget.matchId).notifier);
    await service.toggleOrientation();
    notifier.update(
      (c) => c.copyWith(
        orientation: service.orientation,
        orientationLocked: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final pad = MediaQuery.paddingOf(context);
    final health = ref.watch(streamHealthProvider).valueOrNull;
    final service = ref.watch(streamServiceProvider);
    final config = ref.watch(streamStudioConfigProvider(widget.matchId));
    final isLandscapeUi = config.orientation == StreamOrientationMode.landscape;
    final notifier =
        ref.read(streamStudioConfigProvider(widget.matchId).notifier);
    final configured = config.isBroadcastConfigured;
    final lenses = service.lenses;
    final selectedIdx = lenses.isEmpty
        ? 0
        : service.selectedLensIndex.clamp(0, lenses.length - 1);
    final canSwitch = widget.cameraReady &&
        !service.isSwitchingLens &&
        !widget.isObsMode &&
        (widget.isLive
            ? service.canAdjustZoomWhileLive
            : !service.isStreaming);
    final backLenses = lenses.where((l) => !l.isFront).toList(growable: false);
    final showLens = !widget.isObsMode &&
        backLenses.length > 1 &&
        (canSwitch || !widget.isLive);
    final bottomReserve = pad.bottom + _kBottomDockH + _kEdge;
    final lensReserve = showLens ? _kLensChipH + 14 : 0;
    final broadcastReserve =
        !widget.isLive && !widget.isObsMode ? 56.0 : 0;
    final sideInset = isLandscapeUi ? pad.left + _kEdge : _kEdge;

    if (_chromeHidden) {
      return Positioned.fill(
        child: StudioLandscapeRotation(
          landscape: isLandscapeUi,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _showChrome,
            child: Stack(
              children: [
                if (widget.isLive)
                  Positioned(
                    top: pad.top + 6,
                    left: pad.left + _kEdge,
                    child: _LiveBadge(
                      cf: cf,
                      duration: _liveDuration(),
                      pulse: _livePulse,
                    ),
                  ),
                if (widget.isLive && _showNetworkWarning(health))
                  Positioned(
                    left: pad.left + _kEdge,
                    right: pad.right + _kEdge,
                    bottom: pad.bottom + _kEdge,
                    child: _NetworkWarning(
                      cf: cf,
                      text: health?.isReconnecting == true
                          ? 'Reconnecting…'
                          : 'Poor network',
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final chrome = Stack(
      fit: StackFit.expand,
      children: [
        // Subtle edge scrims — keeps controls readable without hiding preview.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: pad.top + _kTopBarH + 24,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: bottomReserve + lensReserve + broadcastReserve + 32,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.62),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(sideInset, 4, pad.right + _kEdge, 0),
              child: _StudioTopBar(
                cf: cf,
                title: config.title.trim().isNotEmpty
                    ? config.title.trim()
                    : 'Stream Studio',
                isLive: widget.isLive,
                duration: widget.isLive ? _liveDuration() : null,
                micOn: config.micEnabled,
                connectionQuality: health?.connectionQuality,
                isReconnecting: health?.isReconnecting ?? false,
                orientation: config.orientation,
                onBack: widget.isLive
                    ? null
                    : () => Navigator.maybePop(context),
                onMic: () async {
                  final next = !config.micEnabled;
                  notifier.update((c) => c.copyWith(micEnabled: next));
                  await service.setMicEnabled(next);
                },
                onFlip: canSwitch && !widget.isLive
                    ? () {
                        final frontIdx =
                            lenses.indexWhere((l) => l.isFront);
                        final backIdx =
                            lenses.indexWhere((l) => !l.isFront);
                        final isFront = lenses.isNotEmpty &&
                            lenses[selectedIdx].isFront;
                        if (isFront && backIdx >= 0) {
                          widget.onLensSelected(backIdx);
                        } else if (!isFront && frontIdx >= 0) {
                          widget.onLensSelected(frontIdx);
                        }
                      }
                    : null,
                onOrientation: widget.isObsMode ? null : _toggleOrientation,
                onSettings: () => showStreamStudioQuickSettingsSheet(
                  context,
                  matchId: widget.matchId,
                  match: widget.match,
                  canStart: widget.canStart,
                  cameraReady: widget.cameraReady,
                  onOpenBroadcastSetup: widget.onOpenBroadcastSetup,
                ),
                onToggleStats: widget.isLive
                    ? () => setState(() => _statsVisible = !_statsVisible)
                    : null,
                statsVisible: _statsVisible,
              ),
            ),
          ),
        ),
        if (_statsVisible && widget.isLive)
          Positioned(
            top: pad.top + _kTopBarH + 4,
            right: pad.right + _kEdge,
            child: _StatsCard(
              cf: cf,
              fps: health?.fps,
              kbps: health?.bitrateKbps,
              dropped: health?.droppedVideoFrames,
              uploadKbps: health?.uploadSpeedKbps,
              connectionQuality: health?.connectionQuality,
              isReconnecting: health?.isReconnecting ?? false,
              onClose: () => setState(() => _statsVisible = false),
            ),
          ),
        if (showLens)
          Positioned(
            left: sideInset,
            right: pad.right + _kEdge,
            bottom: bottomReserve + lensReserve + broadcastReserve,
            child: _LensStrip(
              cf: cf,
              lenses: backLenses,
              allLenses: lenses,
              selectedIndex: selectedIdx,
              canSwitch: canSwitch,
              onSelect: widget.onLensSelected,
            ),
          ),
        if (!widget.isLive && !widget.isObsMode)
          Positioned(
            left: sideInset,
            right: pad.right + _kEdge,
            bottom: bottomReserve + lensReserve + 6,
            child: _BroadcastStatusButton(
              cf: cf,
              state: _buttonState(service, health, configured),
              canStart: widget.canStart && widget.cameraReady,
              connectPulse: _connectPulse,
              onSetup: widget.onOpenBroadcastSetup,
              onGoLive: widget.onGoLive,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(sideInset, 0, pad.right + _kEdge, _kEdge),
              child: _StudioBottomDock(
                cf: cf,
                platform: config.platform,
                isObsMode: widget.isObsMode,
                isLive: widget.isLive,
                onHideUi: () {
                  setState(() => _chromeHidden = true);
                  _autoHideTimer?.cancel();
                },
                onSetup: widget.onOpenBroadcastSetup,
                onCameraSettings: widget.isObsMode || !widget.cameraReady
                    ? null
                    : () => showStreamCameraSettingsSheet(
                          context,
                          matchId: widget.matchId,
                          cameraReady: widget.cameraReady,
                        ),
                onMarkReplay: widget.onMarkReplay,
                onEndLive: widget.onEndStream,
                onGoLive: configured && widget.canStart && widget.cameraReady
                    ? widget.onGoLive
                    : null,
              ),
            ),
          ),
        ),
      ],
    );

    return Positioned.fill(
      child: StudioLandscapeRotation(
        landscape: isLandscapeUi,
        child: chrome,
      ),
    );
  }
}

class _StudioTopBar extends StatelessWidget {
  const _StudioTopBar({
    required this.cf,
    required this.title,
    required this.isLive,
    required this.micOn,
    required this.onSettings,
    this.duration,
    this.onBack,
    this.onMic,
    this.onFlip,
    this.onOrientation,
    this.onToggleStats,
    this.connectionQuality,
    this.isReconnecting = false,
    this.orientation = StreamOrientationMode.portrait,
    this.statsVisible = false,
  });

  final CfColors cf;
  final String title;
  final bool isLive;
  final String? duration;
  final bool micOn;
  final StreamConnectionQuality? connectionQuality;
  final bool isReconnecting;
  final StreamOrientationMode orientation;
  final bool statsVisible;
  final VoidCallback? onBack;
  final VoidCallback? onMic;
  final VoidCallback? onFlip;
  final VoidCallback? onOrientation;
  final VoidCallback onSettings;
  final VoidCallback? onToggleStats;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      cf: cf,
      height: _kTopBarH,
      child: Row(
        children: [
          if (onBack != null)
            _RoundIcon(cf: cf, icon: Icons.arrow_back_rounded, onTap: onBack)
          else
            const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cf.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
                if (isLive && duration != null)
                  Text(
                    duration!,
                    style: TextStyle(
                      color: cf.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (isLive) ...[
            _LivePill(duration: null),
            const SizedBox(width: 4),
          ],
          if (connectionQuality != null)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                isReconnecting
                    ? Icons.sync_rounded
                    : _connectionIcon(connectionQuality!),
                size: 16,
                color: _connectionColor(cf, connectionQuality!, isReconnecting),
              ),
            ),
          if (onMic != null)
            _RoundIcon(
              cf: cf,
              icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
              selected: micOn,
              onTap: onMic,
            ),
          if (onFlip != null)
            _RoundIcon(
              cf: cf,
              icon: Icons.cameraswitch_rounded,
              onTap: onFlip,
            ),
          if (onOrientation != null)
            _RoundIcon(
              cf: cf,
              icon: orientation == StreamOrientationMode.portrait
                  ? Icons.stay_current_portrait_rounded
                  : Icons.stay_current_landscape_rounded,
              onTap: onOrientation,
              tooltip: orientation.studioLabel,
            ),
          if (onToggleStats != null)
            _RoundIcon(
              cf: cf,
              icon: statsVisible
                  ? Icons.insights_rounded
                  : Icons.insights_outlined,
              selected: statsVisible,
              onTap: onToggleStats,
            ),
          _RoundIcon(cf: cf, icon: Icons.tune_rounded, onTap: onSettings),
        ],
      ),
    );
  }
}

class _StudioBottomDock extends StatelessWidget {
  const _StudioBottomDock({
    required this.cf,
    required this.platform,
    required this.isObsMode,
    required this.isLive,
    required this.onHideUi,
    required this.onSetup,
    this.onCameraSettings,
    this.onMarkReplay,
    this.onEndLive,
    this.onGoLive,
  });

  final CfColors cf;
  final StreamPlatform platform;
  final bool isObsMode;
  final bool isLive;
  final VoidCallback onHideUi;
  final VoidCallback onSetup;
  final VoidCallback? onCameraSettings;
  final VoidCallback? onMarkReplay;
  final VoidCallback? onEndLive;
  final VoidCallback? onGoLive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kBottomDockH,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          Expanded(
            child: Row(
              children: [
                _DockBtn(
                  cf: cf,
                  icon: Icons.open_in_full_rounded,
                  label: 'Hide',
                  onTap: onHideUi,
                ),
                const SizedBox(width: 6),
                _DockBtn(
                  cf: cf,
                  icon: Icons.settings_outlined,
                  label: 'Setup',
                  onTap: onSetup,
                ),
                if (onCameraSettings != null) ...[
                  const SizedBox(width: 6),
                  _DockBtn(
                    cf: cf,
                    icon: Icons.videocam_outlined,
                    label: 'Camera',
                    onTap: onCameraSettings,
                  ),
                ],
                const SizedBox(width: 8),
                _PlatformChip(cf: cf, platform: platform, isObs: isObsMode),
              ],
            ),
          ),
          if (isLive) ...[
            _DockBtn(
              cf: cf,
              icon: Icons.flag_outlined,
              label: 'Mark',
              onTap: onMarkReplay,
            ),
            const SizedBox(width: 8),
            _StudioActionButton(
              cf: cf,
              label: 'Stop',
              icon: Icons.stop_rounded,
              color: cf.error,
              onTap: onEndLive,
            ),
          ] else if (onGoLive != null)
            _StudioActionButton(
              cf: cf,
              label: 'Go Live',
              icon: Icons.sensors_rounded,
              color: cf.accent,
              foreground: cf.onAccent,
              onTap: onGoLive,
            ),
        ],
        ),
      ),
    );
  }
}

class _BroadcastStatusButton extends StatelessWidget {
  const _BroadcastStatusButton({
    required this.cf,
    required this.state,
    required this.canStart,
    required this.connectPulse,
    required this.onSetup,
    required this.onGoLive,
  });

  final CfColors cf;
  final _BroadcastButtonState state;
  final bool canStart;
  final AnimationController connectPulse;
  final VoidCallback onSetup;
  final VoidCallback onGoLive;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color, onTap, enabled) = switch (state) {
      _BroadcastButtonState.setup => (
          'Ready',
          Icons.radio_button_unchecked_rounded,
          cf.textSecondary,
          onSetup,
          true,
        ),
      _BroadcastButtonState.ready => (
          'Go Live',
          Icons.sensors_rounded,
          cf.accent,
          onGoLive,
          canStart,
        ),
      _BroadcastButtonState.connecting => (
          'Connecting…',
          Icons.sync_rounded,
          cf.info,
          null,
          false,
        ),
      _BroadcastButtonState.live => (
          'Live',
          Icons.fiber_manual_record_rounded,
          cf.statusLive,
          null,
          false,
        ),
      _BroadcastButtonState.reconnecting => (
          'Reconnecting…',
          Icons.sync_problem_rounded,
          cf.error,
          null,
          false,
        ),
    };

    final child = AnimatedBuilder(
      animation: connectPulse,
      builder: (context, _) {
        final pulse = state == _BroadcastButtonState.connecting ||
                state == _BroadcastButtonState.reconnecting
            ? 0.92 + connectPulse.value * 0.08
            : 1.0;
        return Transform.scale(
          scale: pulse,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(26),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: color.withValues(alpha: enabled ? 0.92 : 0.35),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return Center(child: child);
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.cf,
    this.fps,
    this.kbps,
    this.dropped,
    this.uploadKbps,
    this.connectionQuality,
    this.isReconnecting = false,
    required this.onClose,
  });

  final CfColors cf;
  final int? fps;
  final int? kbps;
  final int? dropped;
  final double? uploadKbps;
  final StreamConnectionQuality? connectionQuality;
  final bool isReconnecting;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      cf: cf,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isReconnecting ? 'Reconnecting' : 'Stream health',
                  style: TextStyle(
                    color: isReconnecting ? cf.error : cf.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(Icons.close, size: 14, color: cf.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (fps != null) '$fps fps',
                if (kbps != null) '$kbps kbps',
                if (dropped != null && dropped! > 0) '$dropped drop',
                if (uploadKbps != null) '↑${uploadKbps!.round()}k',
                if (connectionQuality != null)
                  _connectionLabel(connectionQuality!),
              ].join(' · '),
              style: TextStyle(color: cf.textPrimary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _LensStrip extends StatelessWidget {
  const _LensStrip({
    required this.cf,
    required this.lenses,
    required this.allLenses,
    required this.selectedIndex,
    required this.canSwitch,
    required this.onSelect,
  });

  final CfColors cf;
  final List<CameraLensInfo> lenses;
  final List<CameraLensInfo> allLenses;
  final int selectedIndex;
  final bool canSwitch;
  final Future<void> Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lens in lenses) ...[
              _ZoomChip(
                cf: cf,
                label: formatLensZoom(lens.zoomFactor),
                selected: allLenses.indexOf(lens) == selectedIndex,
                enabled: canSwitch,
                onTap: canSwitch
                    ? () => onSelect(allLenses.indexOf(lens))
                    : null,
              ),
              if (lens != lenses.last) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _ZoomChip extends StatelessWidget {
  const _ZoomChip({
    required this.cf,
    required this.label,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final CfColors cf;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _StudioMiniCard(
      cf: cf,
      selected: selected,
      onTap: enabled ? onTap : null,
      minWidth: 44,
      height: _kLensChipH,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: !enabled
                ? cf.textDisabled
                : selected
                    ? cf.accent
                    : cf.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _StudioMiniCard extends StatelessWidget {
  const _StudioMiniCard({
    required this.cf,
    required this.child,
    this.selected = false,
    this.onTap,
    this.minWidth,
    this.height,
  });

  final CfColors cf;
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final double? minWidth;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth ?? 0, minHeight: height ?? 0),
          height: height,
          padding: height == null
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
              : const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? cf.accent.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: cf.isLight ? 0.06 : 0.42),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? cf.accent.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: cf.isLight ? 0.14 : 0.1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StudioActionButton extends StatelessWidget {
  const _StudioActionButton({
    required this.cf,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.foreground,
  });

  final CfColors cf;
  final String label;
  final IconData icon;
  final Color color;
  final Color? foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? cf.onPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
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

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.cf,
    required this.child,
    this.height,
  });

  final CfColors cf;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: cf.isLight
                ? cf.surface.withValues(alpha: 0.82)
                : Colors.black.withValues(alpha: 0.42),
            borderRadius: radius,
            border: Border.all(
              color: cf.isLight
                  ? cf.border.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: cf.isLight ? 0.1 : 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.cf,
    required this.icon,
    this.onTap,
    this.selected = false,
    this.tooltip,
  });

  final CfColors cf;
  final IconData icon;
  final VoidCallback? onTap;
  final bool selected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: selected
          ? cf.accent.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: cf.isLight ? 0.08 : 0.06),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _kControlSize,
          height: _kControlSize,
          child: Icon(
            icon,
            size: _kIconSize,
            color: onTap == null
                ? cf.textDisabled
                : selected
                    ? cf.accent
                    : cf.textPrimary,
          ),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

class _DockBtn extends StatelessWidget {
  const _DockBtn({
    required this.cf,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final CfColors cf;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _StudioMiniCard(
      cf: cf,
      onTap: onTap,
      height: 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: onTap == null ? cf.textDisabled : cf.textPrimary,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: onTap == null ? cf.textDisabled : cf.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({
    required this.cf,
    required this.platform,
    required this.isObs,
  });

  final CfColors cf;
  final StreamPlatform platform;
  final bool isObs;

  @override
  Widget build(BuildContext context) {
    final label = isObs ? 'OBS' : platform.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cf.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cf.accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cf.accent,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({this.duration});

  final String? duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            duration != null ? 'LIVE $duration' : 'LIVE',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({
    required this.cf,
    required this.duration,
    required this.pulse,
  });

  final CfColors cf;
  final String duration;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: pulse,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'LIVE $duration',
              style: TextStyle(
                color: cf.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkWarning extends StatelessWidget {
  const _NetworkWarning({required this.cf, required this.text});

  final CfColors cf;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cf.error.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _connectionIcon(StreamConnectionQuality q) => switch (q) {
      StreamConnectionQuality.excellent => Icons.signal_cellular_4_bar,
      StreamConnectionQuality.good => Icons.signal_cellular_alt,
      StreamConnectionQuality.fair => Icons.signal_cellular_alt_2_bar,
      StreamConnectionQuality.poor =>
        Icons.signal_cellular_connected_no_internet_0_bar,
      StreamConnectionQuality.unknown => Icons.signal_cellular_null,
    };

Color _connectionColor(
  CfColors cf,
  StreamConnectionQuality q,
  bool reconnecting,
) {
  if (reconnecting) return cf.error;
  return switch (q) {
    StreamConnectionQuality.excellent => cf.success,
    StreamConnectionQuality.good => cf.accent,
    StreamConnectionQuality.fair => Colors.orange,
    StreamConnectionQuality.poor => cf.error,
    StreamConnectionQuality.unknown => cf.textMuted,
  };
}

String _connectionLabel(StreamConnectionQuality q) => switch (q) {
      StreamConnectionQuality.excellent => 'Excellent',
      StreamConnectionQuality.good => 'Good',
      StreamConnectionQuality.fair => 'Fair',
      StreamConnectionQuality.poor => 'Poor',
      StreamConnectionQuality.unknown => 'Unknown',
    };
