import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/models/stream_studio_config.dart';
import '../domain/streaming_enums.dart';

/// Platform OAuth + automatic RTMP credential fetch.
///
/// YouTube live creation requires Cloud Function [createYouTubeLiveStream]
/// with YouTube Data API v3 credentials on the backend.
class StreamPlatformService {
  StreamPlatformService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<void> storeYouTubeOAuthToken({
    required String refreshToken,
    String? accessToken,
    String? channelId,
    DateTime? expiresAt,
  }) async {
    if (_auth.currentUser == null) return;
    final callable = _functions.httpsCallable('storeStreamingOAuthToken');
    await callable.call<Map<String, dynamic>>({
      'provider': 'youtube',
      'refreshToken': refreshToken,
      if (accessToken != null) 'accessToken': accessToken,
      if (channelId != null) 'channelId': channelId,
      if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
    });
  }

  Future<void> linkYouTubeAccount({required String serverAuthCode}) async {
    if (_auth.currentUser == null) {
      throw StreamPlatformException(
        'Sign in to CrickFlow first, then connect your YouTube account.',
      );
    }
    try {
      final callable = _functions.httpsCallable('linkYouTubeAccount');
      await callable.call<Map<String, dynamic>>({
        'serverAuthCode': serverAuthCode,
      });
    } on FirebaseFunctionsException catch (e) {
      throw StreamPlatformException(e.message ?? e.code);
    }
  }

  Future<YouTubeLiveCredentials?> createYouTubeLive({
    required StreamStudioConfig config,
    Map<String, String>? thumbnailPayload,
  }) async {
    if (_auth.currentUser == null) return null;
    try {
      final callable = _functions.httpsCallable('createYouTubeLiveStream');
      final result = await callable.call<Map<String, dynamic>>({
        'title': config.title,
        'description': config.description,
        'visibility': config.visibility.name,
        'channelId': config.youtubeChannelId,
        'language': config.language,
        'tags': config.tags,
        'goLiveImmediately': true,
        if (config.scheduledAt != null)
          'scheduledAt': config.scheduledAt!.toIso8601String(),
        if (thumbnailPayload != null) ...thumbnailPayload,
      });
      final data = result.data;
      return YouTubeLiveCredentials(
        rtmpUrl: data['rtmpUrl'] as String? ?? StreamPlatform.youtube.defaultRtmpUrl,
        streamKey: data['streamKey'] as String? ?? '',
        watchUrl: data['watchUrl'] as String? ?? '',
        broadcastId: data['broadcastId'] as String? ?? '',
        streamId: data['streamId'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      throw StreamPlatformException(e.message ?? e.code);
    } catch (e) {
      throw StreamPlatformException('$e');
    }
  }

  Future<PlatformLiveCredentials?> createFacebookLive({
    required StreamStudioConfig config,
  }) async {
    if (_auth.currentUser == null) return null;
    try {
      final callable = _functions.httpsCallable('createFacebookLiveStream');
      final result = await callable.call<Map<String, dynamic>>({
        'title': config.title,
        'pageId': config.facebookPageId,
      });
      final data = result.data;
      return PlatformLiveCredentials(
        rtmpUrl: data['rtmpUrl'] as String? ?? StreamPlatform.facebook.defaultRtmpUrl,
        streamKey: data['streamKey'] as String? ?? '',
        watchUrl: data['watchUrl'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      throw StreamPlatformException(e.message ?? e.code);
    }
  }

  Future<PlatformLiveCredentials?> createTwitchLive({
    required StreamStudioConfig config,
  }) async {
    if (_auth.currentUser == null) return null;
    try {
      final callable = _functions.httpsCallable('createTwitchLiveStream');
      final result = await callable.call<Map<String, dynamic>>({
        'title': config.title,
        'channel': config.twitchChannel,
      });
      final data = result.data;
      return PlatformLiveCredentials(
        rtmpUrl: data['rtmpUrl'] as String? ?? StreamPlatform.twitch.defaultRtmpUrl,
        streamKey: data['streamKey'] as String? ?? '',
        watchUrl: data['watchUrl'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      throw StreamPlatformException(e.message ?? e.code);
    }
  }

  Future<List<YouTubeChannel>> fetchYouTubeChannels() async {
    if (_auth.currentUser == null) {
      throw StreamPlatformException(
        'Sign in to CrickFlow to load YouTube channels.',
      );
    }
    try {
      final callable = _functions.httpsCallable('listYouTubeChannels');
      final result = await callable.call<Map<String, dynamic>>();
      final list = result.data['channels'] as List<dynamic>? ?? const [];
      return list
          .map((e) => YouTubeChannel(
                id: (e as Map)['id'] as String? ?? '',
                title: e['title'] as String? ?? '',
              ))
          .where((c) => c.id.isNotEmpty)
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw StreamPlatformException(e.message ?? e.code);
    }
  }

  Future<void> endYouTubeLive({required String broadcastId}) async {
    if (_auth.currentUser == null) return;
    try {
      final callable = _functions.httpsCallable('endYouTubeLiveStream');
      await callable.call<Map<String, dynamic>>({
        'broadcastId': broadcastId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw StreamPlatformException(e.message ?? e.code);
    }
  }

  /// Transitions an API-created broadcast to public live after RTMP ingest starts.
  Future<void> startYouTubeLiveBroadcast({
    required String broadcastId,
    String streamId = '',
  }) async {
    if (_auth.currentUser == null) {
      throw StreamPlatformException('Sign in required');
    }
    if (broadcastId.isEmpty) {
      throw StreamPlatformException('YouTube broadcast id missing');
    }
    try {
      final callable = _functions.httpsCallable('startYouTubeLiveBroadcast');
      await callable.call<Map<String, dynamic>>({
        'broadcastId': broadcastId,
        if (streamId.isNotEmpty) 'streamId': streamId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw StreamPlatformException(e.message ?? e.code);
    }
  }

  /// Poll YouTube broadcast lifecycle — `complete` / `revoked` means stream ended.
  Future<YouTubeBroadcastStatus?> fetchYouTubeBroadcastStatus({
    required String broadcastId,
  }) async {
    if (_auth.currentUser == null || broadcastId.isEmpty) return null;
    try {
      final callable = _functions.httpsCallable('getYouTubeBroadcastStatus');
      final result = await callable.call<Map<String, dynamic>>({
        'broadcastId': broadcastId,
      });
      final data = result.data;
      return YouTubeBroadcastStatus(
        broadcastId: data['broadcastId'] as String? ?? broadcastId,
        lifeCycleStatus: data['lifeCycleStatus'] as String? ?? 'unknown',
        streamStatus: data['streamStatus'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<YouTubeChatMessage>> fetchLiveChat({required String videoId}) async {
    if (_auth.currentUser == null) return const [];
    try {
      final callable = _functions.httpsCallable('getYouTubeLiveChat');
      final result = await callable.call<Map<String, dynamic>>({
        'videoId': videoId,
      });
      final list = result.data['messages'] as List<dynamic>? ?? const [];
      return list
          .map((e) => YouTubeChatMessage(
                id: (e as Map)['id'] as String? ?? '',
                author: e['author'] as String? ?? 'Viewer',
                text: e['text'] as String? ?? '',
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<YouTubeChaptersExport?> exportYouTubeChapters(String matchId) async {
    if (_auth.currentUser == null) return null;
    try {
      final callable = _functions.httpsCallable('exportYouTubeChapters');
      final result = await callable.call<Map<String, dynamic>>({'matchId': matchId});
      final data = result.data;
      return YouTubeChaptersExport(
        chaptersText: data['chaptersText'] as String? ?? '',
        descriptionBlock: data['descriptionBlock'] as String? ?? '',
        count: data['count'] as int? ?? 0,
      );
    } on FirebaseFunctionsException catch (e) {
      throw StreamPlatformException(e.message ?? e.code);
    }
  }
}

class StreamPlatformException implements Exception {
  StreamPlatformException(this.message);
  final String message;

  @override
  String toString() => message;
}

class YouTubeLiveCredentials {
  const YouTubeLiveCredentials({
    required this.rtmpUrl,
    required this.streamKey,
    required this.watchUrl,
    required this.broadcastId,
    this.streamId = '',
  });

  final String rtmpUrl;
  final String streamKey;
  final String watchUrl;
  final String broadcastId;
  final String streamId;
}

class PlatformLiveCredentials {
  const PlatformLiveCredentials({
    required this.rtmpUrl,
    required this.streamKey,
    required this.watchUrl,
  });

  final String rtmpUrl;
  final String streamKey;
  final String watchUrl;
}

class YouTubeChannel {
  const YouTubeChannel({required this.id, required this.title});

  final String id;
  final String title;
}

class YouTubeBroadcastStatus {
  const YouTubeBroadcastStatus({
    required this.broadcastId,
    required this.lifeCycleStatus,
    this.streamStatus,
  });

  final String broadcastId;
  final String lifeCycleStatus;
  final String? streamStatus;

  bool get isEnded =>
      lifeCycleStatus == 'complete' ||
      lifeCycleStatus == 'revoked' ||
      lifeCycleStatus == 'not_found';
}

class YouTubeChatMessage {
  const YouTubeChatMessage({
    required this.id,
    required this.author,
    required this.text,
  });

  final String id;
  final String author;
  final String text;
}

class YouTubeChaptersExport {
  const YouTubeChaptersExport({
    required this.chaptersText,
    required this.descriptionBlock,
    required this.count,
  });

  final String chaptersText;
  final String descriptionBlock;
  final int count;
}
