import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/match_model.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../data/models/camera_lens_info.dart';
import '../../providers/streaming_studio_providers.dart';
import 'stream_studio_quick_settings_sheet.dart';
import 'stream_camera_settings_sheet.dart';

/// Themed studio chrome over the camera preview — light/dark via [CfColors].
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
    with SingleTickerProviderStateMixin {
  bool _chromeHidden = false;
  bool _healthVisible = true;
  late AnimationController _micPulse;

  @override
  void initState() {
    super.initState();
    _micPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _micPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    if (_chromeHidden) {
      return Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => setState(() => _chromeHidden = false),
          child: Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _StudioPill(
                  cf: cf,
                  child: Text(
                    'Tap to show controls',
                    style: TextStyle(color: cf.textSecondary, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final service = ref.watch(streamServiceProvider);
    final config = ref.watch(streamStudioConfigProvider(widget.matchId));
    final notifier = ref.read(streamStudioConfigProvider(widget.matchId).notifier);
    final health = ref.watch(streamHealthProvider).valueOrNull;
    final configured = config.isBroadcastConfigured;
    final lenses = service.lenses;
    final selectedIdx = lenses.isEmpty
        ? 0
        : service.selectedLensIndex.clamp(0, lenses.length - 1);
    final canSwitch = widget.cameraReady &&
        !service.isStreaming &&
        !service.isSwitchingLens &&
        !widget.isObsMode;
    final backLenses = lenses.where((l) => !l.isFront).toList(growable: false);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: _TopBar(
                cf: cf,
                title: widget.isLive ? 'Live' : 'Stream studio',
                onBack: widget.isLive ? null : () => Navigator.maybePop(context),
                onSettings: () => showStreamStudioQuickSettingsSheet(
                  context,
                  matchId: widget.matchId,
                  match: widget.match,
                  canStart: widget.canStart,
                  cameraReady: widget.cameraReady,
                  onOpenBroadcastSetup: widget.onOpenBroadcastSetup,
                ),
                onCameraSettings: widget.isObsMode || !widget.cameraReady
                    ? null
                    : () => showStreamCameraSettingsSheet(
                          context,
                          matchId: widget.matchId,
                          cameraReady: widget.cameraReady,
                        ),
                onShowStats: !_healthVisible && (widget.isLive || widget.cameraReady)
                    ? () => setState(() => _healthVisible = true)
                    : null,
                onTorch: widget.isObsMode
                    ? null
                    : () async {
                        final next = !config.torchEnabled;
                        notifier.update((c) => c.copyWith(torchEnabled: next));
                        try {
                          await ref.read(streamServiceProvider).setTorch(next);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Torch failed: $e')),
                            );
                          }
                        }
                      },
                torchOn: config.torchEnabled,
                onMic: () => notifier.update(
                  (c) => c.copyWith(micEnabled: !c.micEnabled),
                ),
                micOn: config.micEnabled,
                onFlip: canSwitch
                    ? () {
                        final frontIdx = lenses.indexWhere((l) => l.isFront);
                        final backIdx = lenses.indexWhere((l) => !l.isFront);
                        final isFront =
                            lenses.isNotEmpty && lenses[selectedIdx].isFront;
                        if (isFront && backIdx >= 0) {
                          widget.onLensSelected(backIdx);
                        } else if (!isFront && frontIdx >= 0) {
                          widget.onLensSelected(frontIdx);
                        }
                      }
                    : null,
              ),
            ),
          ),
        ),
        if (_healthVisible && (widget.isLive || widget.cameraReady))
          Positioned(
            top: MediaQuery.paddingOf(context).top + 52,
            left: 16,
            right: 16,
            child: _HealthStrip(
              cf: cf,
              fps: widget.isLive ? health?.fps : null,
              kbps: widget.isLive ? health?.bitrateKbps : null,
              micEnabled: config.micEnabled,
              micGain: config.micGain,
              micActive: widget.isLive && config.micEnabled,
              micPulse: _micPulse,
              onClose: () => setState(() => _healthVisible = false),
            ),
          ),
        if (!widget.isObsMode && backLenses.length > 1)
          Positioned(
            left: 16,
            right: 16,
            bottom: 168,
            child: SafeArea(
              top: false,
              child: _LensPill(
                cf: cf,
                lenses: backLenses,
                allLenses: lenses,
                selectedIndex: selectedIdx,
                canSwitch: canSwitch,
                onSelect: widget.onLensSelected,
              ),
            ),
          ),
        if (!widget.isLive && !widget.isObsMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 96,
            child: SafeArea(
              top: false,
              child: Center(
                child: _CenterBroadcastButton(
                  cf: cf,
                  configured: configured,
                  canStart: widget.canStart && widget.cameraReady,
                  onReady: widget.onOpenBroadcastSetup,
                  onGoLive: widget.onGoLive,
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _BottomBar(
                cf: cf,
                hideCamera: widget.isObsMode,
                onHideChrome: () => setState(() => _chromeHidden = true),
                onSetup: widget.onOpenBroadcastSetup,
                isLive: widget.isLive,
                onEndLive: widget.onEndStream,
                onMarkReplay: widget.onMarkReplay,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CenterBroadcastButton extends StatelessWidget {
  const _CenterBroadcastButton({
    required this.cf,
    required this.configured,
    required this.canStart,
    required this.onReady,
    required this.onGoLive,
  });

  final CfColors cf;
  final bool configured;
  final bool canStart;
  final VoidCallback onReady;
  final VoidCallback onGoLive;

  @override
  Widget build(BuildContext context) {
    if (configured) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: canStart ? cf.accent : cf.textDisabled,
          foregroundColor: canStart ? cf.onAccent : cf.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          elevation: 4,
        ),
        onPressed: canStart ? onGoLive : null,
        icon: const Icon(Icons.play_circle_fill, size: 22),
        label: const Text(
          'Go Live',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: cf.accent,
        side: BorderSide(color: cf.accent, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        backgroundColor: cf.surface.withValues(alpha: 0.85),
      ),
      onPressed: onReady,
      icon: Icon(Icons.radio_button_checked, color: cf.accent, size: 20),
      label: Text(
        'Ready',
        style: TextStyle(
          color: cf.accent,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.cf,
    required this.title,
    this.onBack,
    required this.onSettings,
    this.onCameraSettings,
    this.onShowStats,
    this.onTorch,
    this.onMic,
    this.onFlip,
    this.torchOn = false,
    this.micOn = true,
  });

  final CfColors cf;
  final String title;
  final VoidCallback? onBack;
  final VoidCallback onSettings;
  final VoidCallback? onCameraSettings;
  final VoidCallback? onShowStats;
  final VoidCallback? onTorch;
  final VoidCallback? onMic;
  final VoidCallback? onFlip;
  final bool torchOn;
  final bool micOn;

  @override
  Widget build(BuildContext context) {
    return _StudioPill(
      cf: cf,
      child: Row(
        children: [
          if (onBack != null)
            _IconBtn(cf: cf, icon: Icons.arrow_back_rounded, onTap: onBack)
          else
            const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: cf.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onShowStats != null)
            _IconBtn(
              cf: cf,
              icon: Icons.insights_outlined,
              onTap: onShowStats,
              tooltip: 'Show stats',
            ),
          if (onTorch != null)
            _IconBtn(
              cf: cf,
              icon: torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
              selected: torchOn,
              onTap: onTorch,
            ),
          _IconBtn(
            cf: cf,
            icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            selected: micOn,
            onTap: onMic,
          ),
          if (onFlip != null)
            _IconBtn(cf: cf, icon: Icons.cameraswitch_rounded, onTap: onFlip),
          if (onCameraSettings != null)
            _IconBtn(
              cf: cf,
              icon: Icons.exposure_outlined,
              onTap: onCameraSettings,
              tooltip: 'Camera settings',
            ),
          _IconBtn(cf: cf, icon: Icons.tune_rounded, onTap: onSettings),
        ],
      ),
    );
  }
}

class _HealthStrip extends StatelessWidget {
  const _HealthStrip({
    required this.cf,
    this.fps,
    this.kbps,
    required this.micEnabled,
    required this.micGain,
    required this.micActive,
    required this.micPulse,
    required this.onClose,
  });

  final CfColors cf;
  final int? fps;
  final int? kbps;
  final bool micEnabled;
  final double micGain;
  final bool micActive;
  final Animation<double> micPulse;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: micPulse,
      builder: (context, _) {
        final baseLevel =
            micEnabled ? ((micGain - 0.5) / 1.5).clamp(0.15, 1.0) : 0.0;
        final liveBoost = micActive ? micPulse.value * 0.25 : 0.0;
        final level = (baseLevel + liveBoost).clamp(0.0, 1.0);

        return _StudioPill(
          cf: cf,
          child: Row(
            children: [
              Text(
                fps != null ? '$fps fps' : '— fps',
                style: TextStyle(color: cf.textSecondary, fontSize: 11),
              ),
              const SizedBox(width: 12),
              Text(
                kbps != null ? '$kbps kbps' : '— kbps',
                style: TextStyle(color: cf.textSecondary, fontSize: 11),
              ),
              const SizedBox(width: 12),
              Icon(
                micEnabled ? Icons.mic : Icons.mic_off,
                size: 14,
                color: micEnabled ? cf.accent : cf.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: micEnabled ? level : 0,
                    minHeight: 6,
                    backgroundColor: cf.border,
                    valueColor: AlwaysStoppedAnimation(
                      micEnabled ? cf.accent : cf.textMuted,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close, size: 18, color: cf.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LensPill extends StatelessWidget {
  const _LensPill({
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
      child: _StudioPill(
        cf: cf,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lens in lenses)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: allLenses.indexOf(lens) == selectedIndex
                      ? cf.accent.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: canSwitch
                        ? () => onSelect(allLenses.indexOf(lens))
                        : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: allLenses.indexOf(lens) == selectedIndex
                            ? Border.all(color: cf.accent, width: 1.2)
                            : null,
                      ),
                      child: Text(
                        formatLensZoom(lens.zoomFactor),
                        style: TextStyle(
                          color: canSwitch
                              ? (allLenses.indexOf(lens) == selectedIndex
                                  ? cf.accent
                                  : cf.textSecondary)
                              : cf.textDisabled,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.cf,
    required this.onSetup,
    required this.onHideChrome,
    required this.isLive,
    this.onEndLive,
    this.onMarkReplay,
    this.hideCamera = false,
  });

  final CfColors cf;
  final VoidCallback onSetup;
  final VoidCallback onHideChrome;
  final bool isLive;
  final VoidCallback? onEndLive;
  final VoidCallback? onMarkReplay;
  final bool hideCamera;

  @override
  Widget build(BuildContext context) {
    return _StudioPill(
      cf: cf,
      child: Row(
        children: [
          if (!hideCamera)
            _TextBtn(cf: cf, label: 'Hide UI', icon: Icons.open_in_full, onTap: onHideChrome),
          _TextBtn(cf: cf, label: 'Setup', icon: Icons.settings_outlined, onTap: onSetup),
          const Spacer(),
          if (isLive) ...[
            _TextBtn(
              cf: cf,
              label: 'Mark',
              icon: Icons.flag_outlined,
              onTap: onMarkReplay,
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: cf.error,
                foregroundColor: cf.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: onEndLive,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('End'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudioPill extends StatelessWidget {
  const _StudioPill({required this.cf, required this.child});

  final CfColors cf;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cf.surface.withValues(alpha: cf.isLight ? 0.92 : 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cf.border.withValues(alpha: 0.65)),
        boxShadow: cf.isLight
            ? [
                BoxShadow(
                  color: cf.cardShadow.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: child,
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
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
      color: selected ? cf.accent.withValues(alpha: 0.18) : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
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

class _TextBtn extends StatelessWidget {
  const _TextBtn({
    required this.cf,
    required this.label,
    required this.icon,
    this.onTap,
  });

  final CfColors cf;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: cf.textSecondary),
      label: Text(label, style: TextStyle(color: cf.textSecondary, fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

String formatLensZoom(double factor) {
  if (factor == 0.5) return '0.5x';
  if (factor == factor.roundToDouble() && factor >= 1) {
    return '${factor.toInt()}x';
  }
  return '${factor.toStringAsFixed(1)}x';
}
