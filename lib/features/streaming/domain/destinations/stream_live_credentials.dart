import 'package:equatable/equatable.dart';

/// RTMP ingest credentials returned by a destination provider (YouTube, Facebook, etc.).
class StreamLiveCredentials extends Equatable {
  const StreamLiveCredentials({
    required this.rtmpUrl,
    required this.streamKey,
    this.watchUrl = '',
    this.broadcastId = '',
    this.providerLabel = '',
  });

  final String rtmpUrl;
  final String streamKey;
  final String watchUrl;
  final String broadcastId;
  final String providerLabel;

  String get fullRtmpEndpoint {
    final base = rtmpUrl.endsWith('/') ? rtmpUrl : '$rtmpUrl/';
    return '$base$streamKey';
  }

  @override
  List<Object?> get props => [rtmpUrl, streamKey, watchUrl, broadcastId];
}
