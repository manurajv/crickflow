import 'deep_link_utils.dart';
import 'match_display_id.dart';

/// Encodes/decodes scorer takeover QR payloads.
class ScorerQrUtils {
  ScorerQrUtils._();

  static String buildTakeoverUri({
    required String matchDocumentId,
    required String ownershipToken,
  }) {
    final displayId = MatchDisplayId.of(matchDocumentId);
    return Uri(
      scheme: DeepLinkUtils.customScheme,
      host: 'match',
      path: '/$matchDocumentId/takeover',
      queryParameters: {
        'token': ownershipToken,
        'mid': displayId,
      },
    ).toString();
  }

  static ScorerTakeoverPayload? parseUri(Uri uri) {
    final path = DeepLinkUtils.pathFromUri(uri) ??
        DeepLinkUtils.normalizeLocation(uri.toString());
    if (path == null) return null;

    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length < 3 ||
        segments[0] != 'match' ||
        segments[2] != 'takeover') {
      return null;
    }

    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return null;

    return ScorerTakeoverPayload(
      matchDocumentId: segments[1],
      ownershipToken: token,
      displayMatchId: uri.queryParameters['mid'] ?? '',
    );
  }
}

class ScorerTakeoverPayload {
  const ScorerTakeoverPayload({
    required this.matchDocumentId,
    required this.ownershipToken,
    this.displayMatchId = '',
  });

  final String matchDocumentId;
  final String ownershipToken;
  final String displayMatchId;
}
