import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.pendingSeek,
    this.onPendingSeekApplied,
    this.awaitingWatchUrl = false,
    this.landscapeFullscreen = false,
  });

  final MatchStreamSource source;
  final bool edgeToEdge;
  final Duration? pendingSeek;
  final VoidCallback? onPendingSeekApplied;
  /// Show the go-live placeholder only while an active broadcast awaits a URL.
  final bool awaitingWatchUrl;
  /// When true, entering fullscreen locks the device to landscape.
  final bool landscapeFullscreen;

  @override
  State<MatchStreamPlayer> createState() => MatchStreamPlayerState();
}

class MatchStreamPlayerState extends State<MatchStreamPlayer> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;
  bool _usingWatchPageFallback = false;
  bool _usingFacebookPluginFallback = false;
  bool _usingFacebookWatchFallback = false;
  String? _youtubeVideoId;
  String? _facebookWatchUrl;
  OverlayEntry? _fullscreenEntry;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant MatchStreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.url != widget.source.url ||
        oldWidget.source.sessionKey != widget.source.sessionKey ||
        oldWidget.awaitingWatchUrl != widget.awaitingWatchUrl) {
      unawaited(_exitFullscreen(restoreOrientation: true));
      _usingWatchPageFallback = false;
      _usingFacebookPluginFallback = false;
      _usingFacebookWatchFallback = false;
      unawaited(_initPlayer());
      return;
    }
    if (widget.pendingSeek != null &&
        widget.pendingSeek != oldWidget.pendingSeek) {
      unawaited(_seekWhenReady(widget.pendingSeek!));
    }
  }

  @override
  void dispose() {
    _exitFullscreen(restoreOrientation: true);
    super.dispose();
  }

  Future<void> _enterFullscreen() async {
    if (_isFullscreen || _controller == null || !mounted) return;
    final overlay = Overlay.of(context);
    final controller = _controller!;

    if (widget.landscapeFullscreen) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;

    _fullscreenEntry = OverlayEntry(
      builder: (ctx) => _StreamFullscreenOverlay(
        openLabel: MatchStreamPlayback.openInLabel(widget.source.platform),
        onClose: _exitFullscreen,
        onOpenExternal: _openExternal,
        showLoading: _loading,
        child: WebViewWidget(controller: controller),
      ),
    );
    overlay.insert(_fullscreenEntry!);
    if (mounted) setState(() => _isFullscreen = true);
  }

  Future<void> _exitFullscreen({bool restoreOrientation = false}) async {
    _fullscreenEntry?.remove();
    _fullscreenEntry = null;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (widget.landscapeFullscreen || restoreOrientation) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
    if (mounted) setState(() => _isFullscreen = false);
  }

  Future<void> _seekWhenReady(Duration offset) async {
    for (var attempt = 0; attempt < 30; attempt++) {
      if (!mounted) return;
      final controller = _controller;
      if (controller != null && !_loading && _error == null) {
        await _seekToOffset(offset);
        widget.onPendingSeekApplied?.call();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<void> _initPlayer() async {
    if (widget.awaitingWatchUrl &&
        MatchStreamPlayback.isPendingWatchUrl(widget.source.url)) {
      setState(() {
        _controller = null;
        _loading = true;
        _error = null;
      });
      return;
    }

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
            if (payload is _FacebookEmbed && !_usingFacebookWatchFallback) {
              if (!_usingFacebookPluginFallback) {
                unawaited(_loadFacebookPluginFallback(controller, payload.watchUrl));
              } else {
                unawaited(_loadFacebookWatchFallback(controller, payload.watchUrl));
              }
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
        if (_usingFacebookWatchFallback) {
          await _loadFacebookWatchFallback(controller, watchUrl);
        } else if (_usingFacebookPluginFallback) {
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
    _syncFullscreenOverlay();
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
    final platform = widget.source.platform;
    if (platform == StreamPlaybackPlatform.facebook &&
        !_usingFacebookWatchFallback) {
      final unavailable = await _facebookEmbedShowsUnavailable(controller);
      if (!mounted) return;
      if (unavailable) {
        final watchUrl = _facebookWatchUrl ?? widget.source.url;
        if (!_usingFacebookPluginFallback) {
          unawaited(_loadFacebookPluginFallback(controller, watchUrl));
          return;
        }
        if (!_usingFacebookWatchFallback) {
          unawaited(_loadFacebookWatchFallback(controller, watchUrl));
          return;
        }
      }
    }
    if (mounted) setState(() => _loading = false);
    _syncFullscreenOverlay();
    await _applyPendingSeekIfNeeded();
  }

  void _syncFullscreenOverlay() {
    _fullscreenEntry?.markNeedsBuild();
  }

  Future<void> _applyPendingSeekIfNeeded() async {
    final pending = widget.pendingSeek;
    if (pending == null) return;
    await _seekWhenReady(pending);
  }

  /// Seek the in-app player to [offset] (YouTube iframe API or `t=` fallback).
  Future<void> seekToOffset(
    Duration offset, {
    String? seekLabel,
  }) async {
    await _seekToOffset(offset, seekLabel: seekLabel);
  }

  Future<void> _seekToOffset(
    Duration offset, {
    String? seekLabel,
  }) async {
    final controller = _controller;
    if (controller == null) return;

    if (widget.source.platform == StreamPlaybackPlatform.youtube) {
      final seconds = offset.inSeconds;
      if (_usingWatchPageFallback) {
        final id = _youtubeVideoId;
        if (id != null) {
          final at = YoutubeUtils.watchUrlAtOffset(
            'https://www.youtube.com/watch?v=$id',
            offset,
          );
          if (at != null) {
            await controller.loadRequest(
              Uri.parse(at),
              headers: const {
                'Referer': '${YoutubeUtils.embedRefererOrigin}/',
              },
            );
            if (mounted) setState(() => _loading = true);
          }
        }
      } else {
        try {
          await controller.runJavaScript(YoutubeUtils.seekIframeJs(seconds));
        } catch (_) {
          final id = _youtubeVideoId;
          if (id != null) {
            await controller.loadHtmlString(
              YoutubeUtils.embedHtml(
                id,
                fullControls: true,
                startSeconds: seconds,
              ),
              baseUrl: YoutubeUtils.embedRefererOrigin,
            );
            if (mounted) setState(() => _loading = true);
          }
        }
      }
      if (mounted && seekLabel != null && seekLabel.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Jumped to $seekLabel'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (widget.source.platform == StreamPlaybackPlatform.facebook) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Facebook in-app seek is limited — opening externally'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _openExternal(atOffset: offset);
    }
  }

  Future<bool> _facebookEmbedShowsUnavailable(WebViewController controller) async {
    try {
      final result = await controller.runJavaScriptReturningResult(
        FacebookUtils.embedUnavailableProbeJs,
      );
      return result == true || result.toString() == 'true';
    } catch (_) {
      return false;
    }
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

  Future<void> _loadFacebookWatchFallback(
    WebViewController controller,
    String watchUrl,
  ) async {
    final fallback = FacebookUtils.inAppFallbackUrl(watchUrl);
    if (fallback == null) return;
    _usingFacebookWatchFallback = true;
    final native = controller.platform;
    if (native is AndroidWebViewController) {
      await native.setUserAgent(FacebookUtils.mobileChromeUserAgent);
    }
    await controller.loadRequest(
      Uri.parse(fallback),
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

  Future<void> _openExternal({Duration? atOffset}) async {
    final url = widget.source.url;
    if (widget.source.platform == StreamPlaybackPlatform.youtube) {
      final id = YoutubeUtils.videoIdFromUrl(url) ?? _youtubeVideoId;
      if (id != null) {
        if (atOffset != null && atOffset.inSeconds > 0) {
          final at = YoutubeUtils.watchUrlAtOffset(
            'https://www.youtube.com/watch?v=$id',
            atOffset,
          );
          if (at != null &&
              await launchUrl(
                Uri.parse(at),
                mode: LaunchMode.externalApplication,
              )) {
            return;
          }
        }
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
    if (_controller == null &&
        widget.awaitingWatchUrl &&
        MatchStreamPlayback.isPendingWatchUrl(widget.source.url)) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading) const CircularProgressIndicator(),
              if (_loading) const SizedBox(height: 12),
              Text(
                'Stream link loading…',
                style: TextStyle(color: cf.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

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
        if (_controller != null && !_isFullscreen)
          WebViewWidget(controller: _controller!),
        if (_isFullscreen)
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: Icon(Icons.fullscreen, color: Colors.white38, size: 40),
            ),
          ),
        if (_loading && !_isFullscreen)
          const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          ),
        Positioned(
          top: 6,
          right: 6,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller != null && _error == null && !_isFullscreen)
                Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: _enterFullscreen,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(Icons.fullscreen, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              if (_controller != null && _error == null && !_isFullscreen)
                const SizedBox(width: 6),
              Material(
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
            ],
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

class _StreamFullscreenOverlay extends StatelessWidget {
  const _StreamFullscreenOverlay({
    required this.child,
    required this.onClose,
    required this.onOpenExternal,
    required this.openLabel,
    required this.showLoading,
  });

  final Widget child;
  final VoidCallback onClose;
  final VoidCallback onOpenExternal;
  final String openLabel;
  final bool showLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) onClose();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(child: child),
            if (showLoading)
              const ColoredBox(
                color: Colors.black54,
                child: Center(child: CircularProgressIndicator()),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: onClose,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.fullscreen_exit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: onOpenExternal,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.open_in_new,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              openLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
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
