import 'dart:async';

import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
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
  final _youtubeWatchUrlController = TextEditingController();
  final _secondaryYoutubeController = TextEditingController();
  StreamDestination _destination = StreamDestination.youtube;
  bool _cameraLoading = true;
  String? _cameraError;
  bool _webrtcBeta = false;
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
    _youtubeWatchUrlController.dispose();
    _secondaryYoutubeController.dispose();
    super.dispose();
  }

  Future<void> _persistStreamMeta(StreamStatus status) async {
    final match = ref.read(matchProvider(widget.matchId)).valueOrNull;
    if (match == null) return;

    final watchUrl = _youtubeWatchUrlController.text.trim();
    final secondaryUrl = _secondaryYoutubeController.text.trim();
    final stream = StreamMetadataModel(
      status: status,
      destination: _destination,
      rtmpUrl: _rtmpUrlController.text.trim(),
      streamKey: _streamKeyController.text.trim(),
      startedAt: status == StreamStatus.live ? DateTime.now() : match.stream.startedAt,
      youtubeWatchUrl: watchUrl.isEmpty ? match.stream.youtubeWatchUrl : watchUrl,
      secondaryYoutubeWatchUrl: secondaryUrl.isEmpty
          ? match.stream.secondaryYoutubeWatchUrl
          : secondaryUrl,
      cameraALabel: match.stream.cameraALabel,
      cameraBLabel: match.stream.cameraBLabel,
      webrtcEnabled: _webrtcBeta,
    );

    await ref.read(matchRepositoryProvider).updateMatch(
          match.copyWith(stream: stream),
        );
  }

  Future<void> _syncWebrtcRoom(StreamStatus status) async {
    final signaling = ref.read(webrtcSignalingProvider);
    if (status == StreamStatus.live && _webrtcBeta) {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid != null) {
        await signaling.openRoom(matchId: widget.matchId, publisherId: uid);
      }
    } else if (status == StreamStatus.ended) {
      await signaling.closeRoom(widget.matchId);
    }
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
      await _syncWebrtcRoom(StreamStatus.live);
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
    await _syncWebrtcRoom(StreamStatus.ended);
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
          if (_youtubeWatchUrlController.text.isEmpty &&
              match.stream.youtubeWatchUrl != null) {
            _youtubeWatchUrlController.text = match.stream.youtubeWatchUrl!;
          }
          if (_secondaryYoutubeController.text.isEmpty &&
              match.stream.secondaryYoutubeWatchUrl != null) {
            _secondaryYoutubeController.text =
                match.stream.secondaryYoutubeWatchUrl!;
          }
          _webrtcBeta = match.stream.webrtcEnabled;

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
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
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
                      const SizedBox(height: AppDimens.spaceMd),
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
                      const SizedBox(height: 12),
                      TextField(
                        controller: _youtubeWatchUrlController,
                        decoration: const InputDecoration(
                          labelText: 'YouTube watch link (main camera)',
                          hintText: 'https://youtube.com/watch?v=...',
                          helperText:
                              'Paste your live video URL from YouTube Studio',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _secondaryYoutubeController,
                        decoration: const InputDecoration(
                          labelText: '2nd camera YouTube link (optional)',
                          hintText: 'Drone / stump cam live URL',
                          helperText:
                              'Use a second YouTube live stream for another angle',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('WebRTC beta (signaling)'),
                        subtitle: const Text(
                          'Opens a low-latency room for viewers. Video peer next release.',
                        ),
                        value: _webrtcBeta,
                        onChanged: (v) => setState(() => _webrtcBeta = v),
                      ),
                      if (_cameraError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _cameraError!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                      const SizedBox(height: AppDimens.spaceLg),
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
