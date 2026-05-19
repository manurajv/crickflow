import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/youtube_utils.dart';

/// In-app YouTube live / VOD player (Phase 3.2).
class YoutubeEmbedCard extends StatefulWidget {
  const YoutubeEmbedCard({
    super.key,
    required this.youtubeWatchUrl,
    this.height = 180,
  });

  final String? youtubeWatchUrl;
  final double height;

  @override
  State<YoutubeEmbedCard> createState() => _YoutubeEmbedCardState();
}

class _YoutubeEmbedCardState extends State<YoutubeEmbedCard> {
  WebViewController? _controller;
  String? _videoId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant YoutubeEmbedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.youtubeWatchUrl != widget.youtubeWatchUrl) {
      _initPlayer();
    }
  }

  void _initPlayer() {
    final id = YoutubeUtils.videoIdFromUrl(widget.youtubeWatchUrl);
    _videoId = id;
    if (id == null) {
      setState(() {
        _controller = null;
        _loading = false;
      });
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(YoutubeUtils.embedUrl(id)));

    setState(() {
      _controller = controller;
      _loading = true;
    });
  }

  Future<void> _openExternal() async {
    final url = widget.youtubeWatchUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open YouTube')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_videoId == null) {
      return Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        child: ListTile(
          leading: const Icon(Icons.live_tv, color: AppColors.gold),
          title: const Text('Live on YouTube'),
          subtitle: const Text(
            'Broadcaster: add your YouTube live link in Go Live settings.',
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.live_tv, color: Colors.redAccent),
            title: const Text('Watch live'),
            trailing: TextButton(
              onPressed: _openExternal,
              child: const Text('YouTube app'),
            ),
          ),
          SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                if (_controller != null)
                  WebViewWidget(controller: _controller!),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
