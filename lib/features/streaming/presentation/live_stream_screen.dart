import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rtmp_broadcaster/camera.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/overlay_state_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../data/services/stream_service.dart';

class LiveStreamScreen extends ConsumerStatefulWidget {
  const LiveStreamScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen> {
  final _rtmpUrlController = TextEditingController(
    text: 'rtmp://a.rtmp.youtube.com/live2',
  );
  final _streamKeyController = TextEditingController();
  StreamDestination _destination = StreamDestination.youtube;
  bool _cameraLoading = true;
  String? _cameraError;
  Timer? _streamHeartbeatTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera();
      _resumeHeartbeatIfLive();
    });
  }

  void _resumeHeartbeatIfLive() {
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    final service = ref.read(streamServiceProvider);
    if (match?.stream.status == StreamStatus.live ||
        service.status == StreamStatus.live) {
      _startStreamHeartbeat();
    }
  }

  Future<void> _initCamera() async {
    if (!StreamService.isPlatformSupported) {
      setState(() {
        _cameraLoading = false;
        _cameraError = 'Use an Android or iOS device to stream.';
      });
      return;
    }
    try {
      await ref.read(streamServiceProvider).initCamera();
      if (mounted) {
        setState(() {
          _cameraLoading = false;
          _cameraError = ref.read(streamServiceProvider).lastError;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraLoading = false;
          _cameraError = '$e';
        });
      }
    }
  }

  void _startStreamHeartbeat() {
    _streamHeartbeatTimer?.cancel();
    _streamHeartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(matchRepositoryProvider).touchStreamHeartbeat(widget.matchId);
    });
  }

  void _stopStreamHeartbeat() {
    _streamHeartbeatTimer?.cancel();
    _streamHeartbeatTimer = null;
  }

  @override
  void dispose() {
    _stopStreamHeartbeat();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _rtmpUrlController.dispose();
    _streamKeyController.dispose();
    super.dispose();
  }

  Future<void> _persistStreamMeta(StreamStatus status) async {
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    if (match == null) return;

    final stream = StreamMetadataModel(
      status: status,
      destination: _destination,
      rtmpUrl: _rtmpUrlController.text.trim(),
      streamKey: _streamKeyController.text.trim(),
      startedAt: status == StreamStatus.live ? DateTime.now() : match.stream.startedAt,
    );

    await ref.read(matchRepositoryProvider).updateMatch(
          match.copyWith(stream: stream),
        );
  }

  Future<void> _goLive() async {
    final key = _streamKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your YouTube stream key')),
      );
      return;
    }

    setState(() => _cameraError = null);
    try {
      await ref.read(streamServiceProvider).startStream(
            rtmpUrl: _rtmpUrlController.text.trim(),
            streamKey: key,
          );
      await _persistStreamMeta(StreamStatus.live);
      _startStreamHeartbeat();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = '$e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stream failed: $e')),
        );
      }
    }
  }

  Future<void> _endStream() async {
    _stopStreamHeartbeat();
    await ref.read(streamServiceProvider).stopStream();
    await _persistStreamMeta(StreamStatus.ended);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchProvider(widget.matchId));
    final overlayAsync = ref.watch(overlayProvider(widget.matchId));
    final streamService = ref.watch(streamServiceProvider);
    final status = streamService.status;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live Stream'),
        backgroundColor: Colors.black87,
      ),
      body: matchAsync.when(
        data: (match) {
          if (match == null) return const Center(child: Text('Match not found'));

          if (_streamKeyController.text.isEmpty &&
              match.stream.streamKey != null) {
            _streamKeyController.text = match.stream.streamKey!;
          }

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _cameraPreview(streamService),
                    overlayAsync.when(
                      data: (overlay) => overlay != null
                          ? _overlayPreview(overlay, match)
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    Positioned(top: 16, left: 16, child: _statusChip(status)),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      const Text(
                        'Stream Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'YouTube Studio → Go live → Stream settings → copy Stream URL + Stream key.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<StreamDestination>(
                        initialValue: _destination,
                        decoration:
                            const InputDecoration(labelText: 'Destination'),
                        items: const [
                          DropdownMenuItem(
                            value: StreamDestination.youtube,
                            child: Text('YouTube Live'),
                          ),
                          DropdownMenuItem(
                            value: StreamDestination.customRtmp,
                            child: Text('Custom RTMP'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _destination = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _rtmpUrlController,
                        decoration: const InputDecoration(labelText: 'RTMP URL'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _streamKeyController,
                        decoration: const InputDecoration(
                          labelText: 'Stream Key',
                        ),
                        obscureText: true,
                      ),
                      if (_cameraError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _cameraError!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (status != StreamStatus.live)
                        CfButton(
                          label: 'Go Live',
                          icon: Icons.play_circle,
                          isGold: true,
                          onPressed:
                              _cameraLoading ? null : () => _goLive(),
                        )
                      else
                        CfButton(
                          label: 'End Stream',
                          icon: Icons.stop,
                          onPressed: _endStream,
                        ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _cameraLoading ? null : _initCamera,
                        icon: const Icon(Icons.cameraswitch),
                        label: const Text('Retry camera'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _cameraPreview(StreamService streamService) {
    if (_cameraLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final controller = streamService.cameraController;
    if (controller != null && controller.value.isInitialized == true) {
      return CameraPreview(controller);
    }
    return Container(
      color: const Color(0xFF1a1a1a),
      child: Center(
        child: Text(
          _cameraError ?? 'Camera unavailable',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38),
        ),
      ),
    );
  }

  Widget _statusChip(StreamStatus status) {
    final color = switch (status) {
      StreamStatus.live => AppColors.liveIndicator,
      StreamStatus.connecting => AppColors.gold,
      StreamStatus.error => Colors.redAccent,
      _ => AppColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _overlayPreview(OverlayStateModel overlay, MatchModel match) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.scoreboardBg.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${overlay.battingTeamName} ${overlay.scoreDisplay} (${overlay.oversDisplay})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              'RR ${overlay.runRate.toStringAsFixed(2)}',
              style: const TextStyle(color: AppColors.gold),
            ),
          ],
        ),
      ),
    );
  }
}
