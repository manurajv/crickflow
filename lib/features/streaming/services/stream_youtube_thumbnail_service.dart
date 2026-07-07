import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/stream_studio_config.dart';

/// Resolves YouTube thumbnail bytes from an optional user upload only.
///
/// Match-intro capture off-screen is unreliable (network images, overlay timing),
/// so when no image is uploaded we omit thumbnail and YouTube uses its default.
class StreamYouTubeThumbnailService {
  const StreamYouTubeThumbnailService();

  static const _kMinThumbnailBytes = 1024;

  Future<Map<String, String>?> resolvePayload({
    required Ref ref,
    required String matchId,
    required StreamStudioConfig config,
  }) async {
    return _encodeFile(config.thumbnailPath);
  }

  Future<Map<String, String>?> _encodeFile(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length < _kMinThumbnailBytes || bytes.length > 2 * 1024 * 1024) {
      return null;
    }
    final lower = path.toLowerCase();
    final mimeType = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    return {
      'thumbnailBase64': base64Encode(bytes),
      'thumbnailMimeType': mimeType,
    };
  }
}

final streamYouTubeThumbnailServiceProvider =
    Provider((ref) => const StreamYouTubeThumbnailService());
