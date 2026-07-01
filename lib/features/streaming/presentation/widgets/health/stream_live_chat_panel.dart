import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/youtube_utils.dart';
import '../../../services/stream_platform_service.dart';
import '../../providers/streaming_studio_providers.dart';

/// Read-only YouTube live chat panel (polls Cloud Function every 8s).
class StreamLiveChatPanel extends ConsumerStatefulWidget {
  const StreamLiveChatPanel({
    super.key,
    required this.matchId,
    this.maxHeight = 160,
  });

  final String matchId;
  final double maxHeight;

  @override
  ConsumerState<StreamLiveChatPanel> createState() =>
      _StreamLiveChatPanelState();
}

class _StreamLiveChatPanelState extends ConsumerState<StreamLiveChatPanel> {
  Timer? _timer;
  List<YouTubeChatMessage> _messages = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    final videoId = config.youtubeBroadcastId.isNotEmpty
        ? config.youtubeBroadcastId
        : YoutubeUtils.videoIdFromUrl(config.youtubeWatchUrl);
    if (videoId == null || videoId.isEmpty) return;

    try {
      final messages = await ref
          .read(streamPlatformServiceProvider)
          .fetchLiveChat(videoId: videoId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_messages.isEmpty && _error == null) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live chat',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.orange, fontSize: 10))
          else
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final m = _messages[_messages.length - 1 - index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                        children: [
                          TextSpan(
                            text: '${m.author}: ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: m.text),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
