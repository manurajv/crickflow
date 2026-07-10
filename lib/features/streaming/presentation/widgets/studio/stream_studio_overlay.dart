import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/match_model.dart';
import '../../../../../data/services/stream_service.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../data/models/stream_studio_config.dart';
import '../../../domain/streaming_enums.dart';
import '../../providers/streaming_studio_providers.dart';
import 'stream_platform_setup_info_sheet.dart';
import 'stream_studio_quick_settings_sheet.dart';
import '../health/stream_health_overlay.dart';
import 'studio_landscape_rotation.dart';

const _kTopBarH = 48.0;
const _kQuickRowH = 40.0;
const _kDestinationStackGap = 6.0;
const _kPreLiveRowH = 44.0;
const _kBroadcastBtnH = 50.0;
const _kBottomLiveH = 44.0;
const _kEdge = 12.0;
const _kLensChipH = 34.0;
const _kIconSize = 18.0;
const _kControlSize = 38.0;

/// Dark base + tint for outdoor readability on bright camera preview.
Color _outdoorFill(Color tint, {required bool selected, required bool enabled}) {
  if (!enabled) {
    return Colors.black.withValues(alpha: 0.45);
  }
  return Color.alphaBlend(
    tint.withValues(alpha: selected ? 0.72 : 0.48),
    Colors.black.withValues(alpha: 0.68),
  );
}

Color _outdoorBorder(Color tint, {required bool selected, required bool enabled}) {
  if (!enabled) return Colors.white.withValues(alpha: 0.22);
  return tint.withValues(alpha: selected ? 0.95 : 0.65);
}

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
    this.isStartingLive = false,
    this.isEndingLive = false,
    this.isObsMode = false,
    this.onNavigateBack,
    this.onEndStream,
    this.onMarkReplay,
    this.onBatterySaver,
    this.onAddStreamLink,
    this.showStreamLinkDot = false,
  });

  final String matchId;
  final MatchModel match;
  final bool canStart;
  final Future<void> Function(int lensIndex) onLensSelected;
  final VoidCallback onGoLive;
  final VoidCallback onOpenBroadcastSetup;
  final bool cameraReady;
  final bool isLive;
  final bool isStartingLive;
  final bool isEndingLive;
  final bool isObsMode;
  final Future<void> Function()? onNavigateBack;
  final VoidCallback? onEndStream;
  final VoidCallback? onMarkReplay;
  final VoidCallback? onBatterySaver;
  final VoidCallback? onAddStreamLink;
  final bool showStreamLinkDot;

  @override
  ConsumerState<StreamStudioOverlay> createState() => _StreamStudioOverlayState();
}

class _StreamStudioOverlayState extends ConsumerState<StreamStudioOverlay>
    with TickerProviderStateMixin {
  bool _chromeHidden = false;
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
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.isObsMode || _chromeHidden) return;
      final config = ref.read(streamStudioConfigProvider(widget.matchId));
      if (config.platform == StreamPlatform.youtube &&
          config.broadcastSetupMode == StreamBroadcastSetupMode.manual) {
        unawaited(
          showStreamPlatformSetupInfoSheet(
            context,
            matchId: widget.matchId,
          ),
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant StreamStudioOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && !oldWidget.isLive) {
      _liveStartedAt = DateTime.now();
      _startDurationTicker();
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

  bool _showNetworkWarning(StreamService service, StreamHealthMetrics? health) {
    if (service.isReconnecting) return true;
    if (health == null) return false;
    return health.isReconnecting ||
        health.connectionQuality == StreamConnectionQuality.poor;
  }

  _BroadcastButtonState _buttonState(
    StreamService service,
    StreamHealthMetrics? health,
    bool configured,
    bool isStartingLive,
  ) {
    if (widget.isLive) {
      if (service.isReconnecting || !service.isRtmpLive) {
        return _BroadcastButtonState.reconnecting;
      }
      return _BroadcastButtonState.live;
    }
    if (isStartingLive || service.status == StreamStatus.connecting) {
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
    final isLandscapeUi = widget.isLive
        ? service.orientation == StreamOrientationMode.landscape
        : config.orientation == StreamOrientationMode.landscape;
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
    final topInset = isLandscapeUi ? 0.0 : pad.top;
    final sideInset = isLandscapeUi ? pad.left + _kEdge : _kEdge;
    final subBarTop = topInset + _kTopBarH + (isLandscapeUi ? 2 : 6);
    final bottomSafe = pad.bottom + _kEdge;
    final liveBarH = widget.isLive ? _kBottomLiveH + 8 : 0.0;
    final readyBottom = bottomSafe + liveBarH;
    final showPreLiveEssentials = !widget.isLive && !widget.isObsMode;
    final preLiveRowBottom = readyBottom + _kBroadcastBtnH + 6;
    final zoomBottom = widget.isLive
        ? readyBottom
        : showPreLiveEssentials
            ? preLiveRowBottom + _kPreLiveRowH + 8
            : readyBottom + _kBroadcastBtnH + 6;

    ref.listen(
      streamStudioConfigProvider(widget.matchId),
      (prev, next) {
        if (widget.isObsMode) return;
        final switchedToManual = prev != null &&
            next.platform == StreamPlatform.youtube &&
            next.broadcastSetupMode == StreamBroadcastSetupMode.manual &&
            prev.broadcastSetupMode != StreamBroadcastSetupMode.manual;
        if (!switchedToManual) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _chromeHidden) return;
          unawaited(
            showStreamPlatformSetupInfoSheet(
              context,
              matchId: widget.matchId,
            ),
          );
        });
      },
    );

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
                if (widget.isLive && _showNetworkWarning(service, health))
                  Positioned(
                    top: pad.top + 6,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _NetworkWarning(
                        cf: cf,
                        text: service.isReconnecting ||
                                (health?.isReconnecting == true)
                            ? 'Reconnecting…'
                            : 'Poor network',
                      ),
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
          height: topInset + _kTopBarH + _kQuickRowH + (isLandscapeUi ? 8 : 20),
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
          height: bottomSafe +
              liveBarH +
              _kBroadcastBtnH +
              (showLens ? _kLensChipH + 14 : 0) +
              (showPreLiveEssentials ? _kPreLiveRowH + 12 : 0) +
              24,
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
          child: isLandscapeUi
              ? Padding(
                  padding: EdgeInsets.fromLTRB(
                    sideInset,
                    0,
                    pad.right + _kEdge,
                    0,
                  ),
                  child: _StudioTopBar(
                    cf: cf,
                    title: config.title.trim().isNotEmpty
                        ? config.title.trim()
                        : 'Stream Studio',
                    isLive: widget.isLive,
                    duration: widget.isLive ? _liveDuration() : null,
                    micOn: config.micEnabled,
                    connectionQuality: health?.connectionQuality,
                    isReconnecting:
                        service.isReconnecting || (health?.isReconnecting ?? false),
                    orientation: config.orientation,
                    onBack: widget.isLive
                        ? null
                        : () => unawaited(widget.onNavigateBack?.call()),
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
                    onOrientation: widget.isObsMode || widget.isLive
                        ? null
                        : _toggleOrientation,
                    onSettings: widget.isLive
                        ? () => showStreamStudioQuickSettingsSheet(
                              context,
                              matchId: widget.matchId,
                              match: widget.match,
                              canStart: widget.canStart,
                              cameraReady: widget.cameraReady,
                              onOpenBroadcastSetup:
                                  widget.onOpenBroadcastSetup,
                            )
                        : null,
                    showHealthOverlay: false,
                  ),
                )
              : SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      sideInset,
                      4,
                      pad.right + _kEdge,
                      0,
                    ),
                    child: _StudioTopBar(
                      cf: cf,
                      title: config.title.trim().isNotEmpty
                          ? config.title.trim()
                          : 'Stream Studio',
                      isLive: widget.isLive,
                      duration: widget.isLive ? _liveDuration() : null,
                      micOn: config.micEnabled,
                      connectionQuality: health?.connectionQuality,
                      isReconnecting:
                        service.isReconnecting || (health?.isReconnecting ?? false),
                      orientation: config.orientation,
                      onBack: widget.isLive
                          ? null
                          : () => unawaited(widget.onNavigateBack?.call()),
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
                      onOrientation: widget.isObsMode || widget.isLive
                          ? null
                          : _toggleOrientation,
                      onSettings: widget.isLive
                          ? () => showStreamStudioQuickSettingsSheet(
                                context,
                                matchId: widget.matchId,
                                match: widget.match,
                                canStart: widget.canStart,
                                cameraReady: widget.cameraReady,
                                onOpenBroadcastSetup:
                                    widget.onOpenBroadcastSetup,
                              )
                          : null,
                      showHealthOverlay: false,
                    ),
                  ),
                ),
        ),
        if (widget.isLive && _showNetworkWarning(service, health))
          Positioned(
            top: topInset + _kTopBarH + 6,
            left: 0,
            right: 0,
            child: Center(
              child: _NetworkWarning(
                cf: cf,
                text: service.isReconnecting ||
                        (health?.isReconnecting == true)
                    ? 'Reconnecting…'
                    : 'Poor network',
              ),
            ),
          ),
        Positioned(
          top: subBarTop,
          right: pad.right + _kEdge,
          child: _StudioDestinationPanel(
            cf: cf,
            matchId: widget.matchId,
            config: config,
            isObs: widget.isObsMode,
            onHideUi: () {
              setState(() => _chromeHidden = true);
              _autoHideTimer?.cancel();
            },
          ),
        ),
        if (!widget.isObsMode)
          Positioned(
            top: subBarTop,
            left: sideInset,
            child: const StreamLiveStatsPill(),
          ),
        if (showPreLiveEssentials)
          Positioned(
            left: sideInset,
            right: pad.right + _kEdge,
            bottom: preLiveRowBottom,
            child: _PreLiveEssentialsRow(
              cf: cf,
              onSetup: widget.onOpenBroadcastSetup,
              onStreamSettings: () => showStreamStudioQuickSettingsSheet(
                context,
                matchId: widget.matchId,
                match: widget.match,
                canStart: widget.canStart,
                cameraReady: widget.cameraReady,
                onOpenBroadcastSetup: widget.onOpenBroadcastSetup,
              ),
            ),
          ),
        if (showLens)
          Positioned(
            left: sideInset,
            right: pad.right + _kEdge,
            bottom: zoomBottom,
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
            bottom: readyBottom,
            child: _BroadcastStatusButton(
              cf: cf,
              state: _buttonState(service, health, configured, widget.isStartingLive),
              canStart: widget.canStart && widget.cameraReady,
              connectPulse: _connectPulse,
              onSetup: widget.onOpenBroadcastSetup,
              onGoLive: widget.onGoLive,
            ),
          ),
        if (widget.isLive)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  sideInset,
                  0,
                  pad.right + _kEdge,
                  _kEdge,
                ),
                child: _StudioLiveActionsBar(
                  cf: cf,
                  onMarkReplay: widget.onMarkReplay,
                  onEndLive: widget.onEndStream,
                  onBatterySaver: widget.onBatterySaver,
                  onAddStreamLink: widget.onAddStreamLink,
                  showStreamLinkDot: widget.showStreamLinkDot,
                  isEndingLive: widget.isEndingLive,
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
    this.onSettings,
    this.duration,
    this.onBack,
    this.onMic,
    this.onFlip,
    this.onOrientation,
    this.connectionQuality,
    this.isReconnecting = false,
    this.orientation = StreamOrientationMode.portrait,
    this.showHealthOverlay = false,
  });

  final CfColors cf;
  final String title;
  final bool isLive;
  final String? duration;
  final bool micOn;
  final StreamConnectionQuality? connectionQuality;
  final bool isReconnecting;
  final StreamOrientationMode orientation;
  final bool showHealthOverlay;
  final VoidCallback? onBack;
  final VoidCallback? onMic;
  final VoidCallback? onFlip;
  final VoidCallback? onOrientation;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      cf: cf,
      height: showHealthOverlay ? null : _kTopBarH,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: showHealthOverlay ? 4 : 0),
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
                if (showHealthOverlay) const StreamHealthOverlay(),
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
          if (onSettings != null)
            _RoundIcon(
              cf: cf,
              icon: Icons.tune_rounded,
              onTap: onSettings,
              tooltip: 'Stream settings',
            ),
        ],
        ),
      ),
    );
  }
}

class _StudioDestinationPanel extends StatelessWidget {
  const _StudioDestinationPanel({
    required this.cf,
    required this.matchId,
    required this.config,
    required this.isObs,
    required this.onHideUi,
  });

  final CfColors cf;
  final String matchId;
  final StreamStudioConfig config;
  final bool isObs;
  final VoidCallback onHideUi;

  bool get _showSetupInfo => !isObs;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = streamPlatformBadgeLabel(config, isObs: isObs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StudioQuickActions(
          cf: cf,
          onHideUi: onHideUi,
        ),
        const SizedBox(height: _kDestinationStackGap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PlatformChip(cf: cf, label: badgeLabel),
            if (_showSetupInfo) ...[
              const SizedBox(width: 6),
              _SetupInfoButton(
                cf: cf,
                onTap: () => showStreamPlatformSetupInfoSheet(
                  context,
                  matchId: matchId,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SetupInfoButton extends StatelessWidget {
  const _SetupInfoButton({required this.cf, required this.onTap});

  final CfColors cf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _outdoorFill(cf.accent, selected: false, enabled: true),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _kQuickRowH,
          height: _kQuickRowH,
          child: Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _StudioQuickActions extends StatelessWidget {
  const _StudioQuickActions({
    required this.cf,
    required this.onHideUi,
  });

  final CfColors cf;
  final VoidCallback onHideUi;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kQuickRowH,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _UtilityBtn(
            cf: cf,
            icon: Icons.open_in_full_rounded,
            label: 'Hide',
            onTap: onHideUi,
          ),
        ],
      ),
    );
  }
}

class _PreLiveEssentialsRow extends StatelessWidget {
  const _PreLiveEssentialsRow({
    required this.cf,
    required this.onSetup,
    required this.onStreamSettings,
  });

  final CfColors cf;
  final VoidCallback onSetup;
  final VoidCallback onStreamSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: _PrimaryActionBtn(
            cf: cf,
            icon: Icons.settings_outlined,
            label: 'Setup',
            onTap: onSetup,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PrimaryActionBtn(
            cf: cf,
            icon: Icons.tune_rounded,
            label: 'Stream settings',
            onTap: onStreamSettings,
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionBtn extends StatelessWidget {
  const _PrimaryActionBtn({
    required this.cf,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final CfColors cf;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = _outdoorFill(cf.accent, selected: true, enabled: true);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: _kPreLiveRowH,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _outdoorBorder(cf.accent, selected: true, enabled: true),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UtilityBtn extends StatelessWidget {
  const _UtilityBtn({
    required this.cf,
    required this.icon,
    required this.label,
    this.onTap,
    this.showDot = false,
  });

  final CfColors cf;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return _StudioMiniCard(
      cf: cf,
      tintColor: Colors.white,
      selected: false,
      onTap: onTap,
      height: _kQuickRowH,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                size: 16,
                color: onTap == null ? cf.textDisabled : Colors.white,
              ),
              if (showDot)
                Positioned(
                  right: -3,
                  top: -2,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: cf.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black54, width: 1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: onTap == null ? cf.textDisabled : Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioLiveActionsBar extends StatelessWidget {
  const _StudioLiveActionsBar({
    required this.cf,
    this.onMarkReplay,
    this.onEndLive,
    this.onBatterySaver,
    this.onAddStreamLink,
    this.showStreamLinkDot = false,
    this.isEndingLive = false,
  });

  final CfColors cf;
  final VoidCallback? onMarkReplay;
  final VoidCallback? onEndLive;
  final VoidCallback? onBatterySaver;
  final VoidCallback? onAddStreamLink;
  final bool showStreamLinkDot;
  final bool isEndingLive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kBottomLiveH,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isEndingLive) ...[
            _UtilityBtn(
              cf: cf,
              icon: Icons.link_rounded,
              label: 'Link',
              showDot: showStreamLinkDot,
              onTap: onAddStreamLink,
            ),
            const SizedBox(width: 8),
            _UtilityBtn(
              cf: cf,
              icon: Icons.flag_outlined,
              label: 'Mark',
              onTap: onMarkReplay,
            ),
            const SizedBox(width: 8),
            _UtilityBtn(
              cf: cf,
              icon: Icons.dark_mode_outlined,
              label: 'Dim',
              onTap: onBatterySaver,
            ),
            const SizedBox(width: 8),
          ],
          _StudioActionButton(
            cf: cf,
            label: isEndingLive ? 'Ending live…' : 'Stop',
            icon: Icons.stop_rounded,
            color: cf.error,
            busy: isEndingLive,
            onTap: isEndingLive ? null : onEndLive,
          ),
        ],
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
    final (label, icon, tint, fg, onTap, enabled, isPrimary) = switch (state) {
      _BroadcastButtonState.setup => (
          'Ready',
          Icons.radio_button_unchecked_rounded,
          cf.accent,
          Colors.white,
          onSetup,
          true,
          true,
        ),
      _BroadcastButtonState.ready => (
          'Go Live',
          Icons.sensors_rounded,
          cf.accent,
          Colors.white,
          onGoLive,
          canStart,
          true,
        ),
      _BroadcastButtonState.connecting => (
          'Connecting…',
          Icons.sync_rounded,
          cf.info,
          Colors.white,
          null,
          false,
          false,
        ),
      _BroadcastButtonState.live => (
          'Live',
          Icons.fiber_manual_record_rounded,
          cf.statusLive,
          Colors.white,
          null,
          false,
          false,
        ),
      _BroadcastButtonState.reconnecting => (
          'Reconnecting…',
          Icons.sync_problem_rounded,
          cf.error,
          Colors.white,
          null,
          false,
          false,
        ),
    };

    final fill = isPrimary
        ? _outdoorFill(tint, selected: true, enabled: enabled)
        : _outdoorFill(tint, selected: false, enabled: enabled);

    final child = AnimatedBuilder(
      animation: connectPulse,
      builder: (context, _) {
        final pulse = state == _BroadcastButtonState.connecting ||
                state == _BroadcastButtonState.reconnecting
            ? 0.96 + connectPulse.value * 0.04
            : 1.0;
        return Transform.scale(
          scale: pulse,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                height: _kBroadcastBtnH,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _outdoorBorder(tint, selected: isPrimary, enabled: enabled),
                    width: isPrimary ? 2 : 1.5,
                  ),
                  boxShadow: isPrimary
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: enabled ? fg : fg.withValues(alpha: 0.5), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        color: enabled ? fg : fg.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.3,
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

    return child;
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
    final tint = selected ? cf.accent : Colors.white;
    return _StudioMiniCard(
      cf: cf,
      selected: selected,
      tintColor: enabled ? tint : cf.textDisabled,
      onTap: enabled ? onTap : null,
      minWidth: 44,
      height: _kLensChipH,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: !enabled
                ? Colors.white.withValues(alpha: 0.4)
                : selected
                    ? cf.accent
                    : Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
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
    this.tintColor,
    this.onTap,
    this.minWidth,
    this.height,
  });

  final CfColors cf;
  final Widget child;
  final bool selected;
  final Color? tintColor;
  final VoidCallback? onTap;
  final double? minWidth;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final tint = tintColor ?? (selected ? cf.accent : Colors.white);
    final enabled = onTap != null;
    final fill = _outdoorFill(tint, selected: selected, enabled: enabled);
    final border = _outdoorBorder(tint, selected: selected, enabled: enabled);

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
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
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
    this.busy = false,
  });

  final CfColors cf;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
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
      color: _outdoorFill(
        selected ? cf.accent : Colors.white,
        selected: selected,
        enabled: onTap != null,
      ),
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
                ? Colors.white.withValues(alpha: 0.35)
                : selected
                    ? cf.accent
                    : Colors.white,
          ),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({
    required this.cf,
    required this.label,
  });

  final CfColors cf;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168),
      child: _StudioMiniCard(
        cf: cf,
        tintColor: cf.accent,
        selected: true,
        height: _kQuickRowH,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cf.error.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
