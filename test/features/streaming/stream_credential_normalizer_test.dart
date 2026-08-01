import 'package:crickflow/features/streaming/domain/stream_credential_normalizer.dart';
import 'package:crickflow/features/streaming/domain/streaming_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamCredentialNormalizer Facebook', () {
    test('preserves query string when splitting secure_stream_url', () {
      const full =
          'rtmps://live-api-s.facebook.com:443/rtmp/1234567890?s_bl=1&s_vt=api-s&s_sw=0';
      final result = StreamCredentialNormalizer.normalize(
        rtmpUrl: '',
        streamKey: full,
        platform: StreamPlatform.facebook,
      );
      expect(result.rtmpUrl, 'rtmps://live-api-s.facebook.com:443/rtmp');
      expect(result.streamKey, '1234567890?s_bl=1&s_vt=api-s&s_sw=0');
    });

    test('splits full URL pasted into key even when server preset is set', () {
      const full =
          'rtmps://live-api-s.facebook.com:443/rtmp/abcdefg?s_bl=1&s_vt=api-s';
      final result = StreamCredentialNormalizer.normalize(
        rtmpUrl: StreamPlatform.facebook.defaultRtmpUrl,
        streamKey: full,
        platform: StreamPlatform.facebook,
      );
      expect(result.rtmpUrl, 'rtmps://live-api-s.facebook.com:443/rtmp');
      expect(result.streamKey, 'abcdefg?s_bl=1&s_vt=api-s');
    });

    test('replaces stale YouTube ingest URL for Facebook platform', () {
      final result = StreamCredentialNormalizer.normalize(
        rtmpUrl: StreamPlatform.youtube.defaultRtmpUrl,
        streamKey: 'plain-fb-key?s_bl=1',
        platform: StreamPlatform.facebook,
      );
      expect(result.rtmpUrl, 'rtmps://live-api-s.facebook.com:443/rtmp');
      expect(result.streamKey, 'plain-fb-key?s_bl=1');
    });

    test('injects :443 when Facebook RTMPS URL omits the port', () {
      final result = StreamCredentialNormalizer.normalize(
        rtmpUrl: 'rtmps://live-api-s.facebook.com/rtmp/',
        streamKey: 'plain-key?s_bl=1',
        platform: StreamPlatform.facebook,
      );
      expect(result.rtmpUrl, 'rtmps://live-api-s.facebook.com:443/rtmp');
      expect(
        StreamCredentialNormalizer.buildEndpoint(
          result.rtmpUrl,
          result.streamKey,
        ),
        'rtmps://live-api-s.facebook.com:443/rtmp/plain-key?s_bl=1',
      );
    });

    test('clears key when server URL is pasted into the key field', () {
      final result = StreamCredentialNormalizer.normalize(
        rtmpUrl: StreamPlatform.facebook.defaultRtmpUrl,
        streamKey: 'rtmps://live-api-s.facebook.com:443/rtmp/',
        platform: StreamPlatform.facebook,
      );
      expect(result.rtmpUrl, 'rtmps://live-api-s.facebook.com:443/rtmp');
      expect(result.streamKey, isEmpty);
    });

    test('strips leading slash from stream key', () {
      final endpoint = StreamCredentialNormalizer.buildEndpoint(
        'rtmps://live-api-s.facebook.com:443/rtmp/',
        '/xyz?s_bl=1',
      );
      expect(
        endpoint,
        'rtmps://live-api-s.facebook.com:443/rtmp/xyz?s_bl=1',
      );
    });

    test('buildEndpoint keeps Facebook query on the key', () {
      final endpoint = StreamCredentialNormalizer.buildEndpoint(
        'rtmps://live-api-s.facebook.com:443/rtmp/',
        'xyz?s_bl=1&s_vt=api-s',
      );
      expect(
        endpoint,
        'rtmps://live-api-s.facebook.com:443/rtmp/xyz?s_bl=1&s_vt=api-s',
      );
    });
  });

  group('StreamCredentialNormalizer YouTube', () {
    test('keeps YouTube manual key + URL intact', () {
      final result = StreamCredentialNormalizer.normalize(
        rtmpUrl: 'rtmp://a.rtmp.youtube.com/live2',
        streamKey: 'xxxx-yyyy-zzzz',
        platform: StreamPlatform.youtube,
      );
      expect(result.rtmpUrl, 'rtmp://a.rtmp.youtube.com/live2');
      expect(result.streamKey, 'xxxx-yyyy-zzzz');
    });
  });
}
