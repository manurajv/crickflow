import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';
import '../../core/utils/facebook_utils.dart';
import '../../core/utils/youtube_utils.dart';
import '../../domain/streaming/match_stream_playback.dart';

/// In-app social stream player — edge-to-edge 16:9 video, no title chrome.
class MatchStreamPlayer extends StatefulWidget {
  const MatchStreamPlayer({
    super.key,
    required this.source,
    this.edgeToEdge = false,
  });

  final MatchStreamSource source;
  final bool edgeToEdge;

  @override
  State<MatchStreamPlayer> createState() => _MatchStreamPlayerState();
}

class _MatchStreamPlayerState extends State<MatchStreamPlayer> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;
  bool _usingWatchPageFallback = false;
  bool _usingFacebookPluginFallback = false;
  String? _youtubeVideoId;
  String? _facebookWatchUrl;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant MatchStreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.url != widget.source.url) {
      _usingWatchPageFallback = false;
      _usingFacebookPluginFallback = false;
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    final payload = _resolveEmbedPayload(widget.source);
    _error = payload == null ? 'Could not play this link in-app' : null;
    _youtubeVideoId = payload is _YoutubeEmbed ? payload.videoId : null;
    _facebookWatchUrl =
        payload is _FacebookEmbed ? payload.watchUrl : null;

    if (payload == null) {
      setState(() {
        _controller = null;
        _loading = false;
      });
      return;
    }

    final controller = WebViewController();
    final platform = widget.source.platform;
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _onPageFinished(controller),
          onWebResourceError: (err) {
            if (!mounted) return;
            if (err.isForMainFrame != true) return;
            if (payload is _YoutubeEmbed && !_usingWatchPageFallback) {
              unawaited(_loadWatchPageFallback(controller, payload.videoId));
              return;
            }
            if (payload is _FacebookEmbed && !_usingFacebookPluginFallback) {
              unawaited(_loadFacebookPluginFallback(controller, payload.watchUrl));
              return;
            }
            setState(() {
              _loading = false;
              _error ??= _playbackErrorMessage(platform);
            });
          },
          onNavigationRequest: (request) =>
              _allowStreamNavigation(request, platform),
        ),
      );

    await _configurePlatform(controller, platform);

    switch (payload) {
      case _YoutubeEmbed(:final videoId):
        if (_usingWatchPageFallback) {
          await _loadWatchPageFallback(controller, videoId);
        } else {
          await controller.loadHtmlString(
            YoutubeUtils.embedHtml(videoId, fullControls: true),
            baseUrl: YoutubeUtils.embedRefererOrigin,
          );
        }
      case _FacebookEmbed(:final watchUrl):
        if (_usingFacebookPluginFallback) {
          await _loadFacebookPluginFallback(controller, watchUrl);
        } else {
          await controller.loadHtmlString(
            FacebookUtils.embedHtml(watchUrl),
            baseUrl: FacebookUtils.embedRefererOrigin,
          );
        }
      case _DirectUrlEmbed(:final url, :final headers):
        await controller.loadRequest(Uri.parse(url), headers: headers);
    }

    if (!mounted) return;
    setState(() {
      _controller = controller;
      _loading = true;
      _error = null;
    });
  }

  String _playbackErrorMessage(StreamPlaybackPlatform platform) {
    return switch (platform) {
      StreamPlaybackPlatform.youtube =>
        'Playback failed — try opening in YouTube',
      StreamPlaybackPlatform.facebook =>
        'Playback failed — try opening in Facebook',
      StreamPlaybackPlatform.twitch =>
        'Playback failed — try opening in Twitch',
      StreamPlaybackPlatform.unknown =>
        'Playback failed — try opening in browser',
    };
  }

  Future<void> _onPageFinished(WebViewController controller) async {
    if (!mounted) return;
    if (_usingWatchPageFallback) {
      try {
        await controller.runJavaScript(YoutubeUtils.minimizeMobileWatchPageJs);
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadWatchPageFallback(
    WebViewController controller,
    String videoId,
  ) async {
    _usingWatchPageFallback = true;
    await controller.loadRequest(
      Uri.parse(YoutubeUtils.watchPageUrl(videoId)),
      headers: const {
        'Referer': '${YoutubeUtils.embedRefererOrigin}/',
      },
    );
  }

  Future<void> _loadFacebookPluginFallback(
    WebViewController controller,
    String watchUrl,
  ) async {
    _usingFacebookPluginFallback = true;
    await controller.loadRequest(
      Uri.parse(FacebookUtils.pluginEmbedUrl(watchUrl)),
      headers: const {
        'Referer': '${FacebookUtils.embedRefererOrigin}/',
      },
    );
  }

  NavigationDecision _allowStreamNavigation(
    NavigationRequest request,
    StreamPlaybackPlatform platform,
  ) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    final host = uri.host.toLowerCase();

    final allowed = switch (platform) {
      StreamPlaybackPlatform.facebook =>
        FacebookUtils.isAllowedEmbedHost(host) ||
            host.contains('google.com') ||
            host.contains('gstatic.com'),
      StreamPlaybackPlatform.youtube =>
        host.contains('youtube.com') ||
            host.contains('youtu.be') ||
            host.contains('youtube-nocookie.com') ||
            host.contains('google.com') ||
            host.contains('gstatic.com') ||
            host.contains('googlevideo.com') ||
            host.contains('ytimg.com'),
      StreamPlaybackPlatform.twitch =>
        host.contains('twitch.tv') ||
            host.contains('ttvnw.net') ||
            host.contains('jtvnw.net'),
      StreamPlaybackPlatform.unknown => true,
    };
    return allowed ? NavigationDecision.navigate : NavigationDecision.prevent;
  }

  Future<void> _configurePlatform(
    WebViewController controller,
    StreamPlaybackPlatform platform,
  ) async {
    final native = controller.platform;
    if (native is AndroidWebViewController) {
      await native.setMediaPlaybackRequiresUserGesture(false);
      final ua = switch (platform) {
        StreamPlaybackPlatform.facebook => FacebookUtils.desktopChromeUserAgent,
        StreamPlaybackPlatform.youtube => YoutubeUtils.mobileChromeUserAgent,
        _ => null,
      };
      if (ua != null) {
        await native.setUserAgent(ua);
      }
    }
  }

  _EmbedPayload? _resolveEmbedPayload(MatchStreamSource source) {
    switch (source.platform) {
      case StreamPlaybackPlatform.youtube:
        final id = YoutubeUtils.videoIdFromUrl(source.url);
        if (id == null) return null;
        return _YoutubeEmbed(videoId: id);
      case StreamPlaybackPlatform.facebook:
        final watchUrl = FacebookUtils.normalizeWatchUrl(source.url);
        if (watchUrl == null) return null;
        return _FacebookEmbed(watchUrl: watchUrl);
      case StreamPlaybackPlatform.twitch:
      case StreamPlaybackPlatform.unknown:
        return _DirectUrlEmbed(url: source.url, headers: const {});
    }
  }

  Future<void> _openExternal() async {
    final url = widget.source.url;
    if (widget.source.platform == StreamPlaybackPlatform.youtube) {
      final id = YoutubeUtils.videoIdFromUrl(url) ?? _youtubeVideoId;
      if (id != null) {
        final appUri = Uri.parse('vnd.youtube:$id');
        if (await canLaunchUrl(appUri)) {
          await launchUrl(appUri);
          return;
        }
      }
    }
    if (widget.source.platform == StreamPlaybackPlatform.facebook) {
      final fb = _facebookWatchUrl ?? FacebookUtils.normalizeWatchUrl(url) ?? url;
      final uri = Uri.tryParse(fb);
      if (uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open stream link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final openLabel = MatchStreamPlayback.openInLabel(widget.source.platform);
    final video = AspectRatio(
      aspectRatio: 16 / 9,
      child: _buildPlayerBody(cf, openLabel),
    );

    if (widget.edgeToEdge) {
      return video;
    }

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      clipBehavior: Clip.antiAlias,
      color: cf.surface,
      child: video,
    );
  }

  Widget _buildPlayerBody(CfColors cf, String openLabel) {
    if (_error != null && _controller == null) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.live_tv, color: cf.textSecondary, size: 40),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cf.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_new, size: 16),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              label: Text(openLabel, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_controller != null) WebViewWidget(controller: _controller!),
        if (_loading)
          const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: _openExternal,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.open_in_new, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      openLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

sealed class _EmbedPayload {}

class _YoutubeEmbed implements _EmbedPayload {
  const _YoutubeEmbed({required this.videoId});
  final String videoId;
}

class _FacebookEmbed implements _EmbedPayload {
  const _FacebookEmbed({required this.watchUrl});
  final String watchUrl;
}

class _DirectUrlEmbed implements _EmbedPayload {
  const _DirectUrlEmbed({required this.url, required this.headers});
  final String url;
  final Map<String, String> headers;
}
