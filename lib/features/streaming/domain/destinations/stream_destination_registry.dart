import '../streaming_enums.dart';
import 'stream_destination_provider.dart';
import '../../facebook/facebook_destination_provider.dart';
import '../../rtmp/custom_rtmp_destination_provider.dart';
import '../../services/stream_platform_service.dart';
import '../../twitch/twitch_destination_provider.dart';
import '../../youtube/youtube_destination_provider.dart';

/// Resolves the correct [StreamDestinationProvider] for each [StreamPlatform].
class StreamDestinationRegistry {
  StreamDestinationRegistry({
    required StreamPlatformService platformService,
  }) : _providers = {
          StreamPlatform.youtube:
              YouTubeDestinationProvider(platformService),
          StreamPlatform.facebook:
              FacebookDestinationProvider(platformService),
          StreamPlatform.twitch: TwitchDestinationProvider(platformService),
          StreamPlatform.customRtmp: CustomRtmpDestinationProvider(),
        };

  final Map<StreamPlatform, StreamDestinationProvider> _providers;

  StreamDestinationProvider forPlatform(StreamPlatform platform) {
    return _providers[platform] ?? _providers[StreamPlatform.customRtmp]!;
  }

  List<StreamDestinationProvider> get all => _providers.values.toList();
}
