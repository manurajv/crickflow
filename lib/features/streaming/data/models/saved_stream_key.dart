import 'package:equatable/equatable.dart';

import '../../domain/streaming_enums.dart';

/// A previously used stream key for quick reuse in manual RTMP setup.
class SavedStreamKey extends Equatable {
  const SavedStreamKey({
    required this.id,
    required this.streamKey,
    required this.platform,
    this.rtmpUrl = '',
    this.label = '',
    this.lastUsedAt,
  });

  final String id;
  final String streamKey;
  final StreamPlatform platform;
  final String rtmpUrl;
  final String label;
  final DateTime? lastUsedAt;

  /// Last 8 characters of the stream key — the primary identifier shown in the UI.
  String get keyPreview {
    final key = streamKey.trim();
    if (key.length <= 8) return key;
    return '…${key.substring(key.length - 8)}';
  }

  /// Prefers a user-set label, otherwise the last-8 key preview (never the platform name).
  String get displayLabel {
    if (label.trim().isNotEmpty) return label.trim();
    return keyPreview;
  }

  factory SavedStreamKey.fromMap(Map<String, dynamic> map) {
    final platformName = map['platform'] as String? ?? 'youtube';
    return SavedStreamKey(
      id: map['id'] as String? ?? '',
      streamKey: map['streamKey'] as String? ?? '',
      platform: StreamPlatform.values.firstWhere(
        (p) => p.name == platformName,
        orElse: () => StreamPlatform.youtube,
      ),
      rtmpUrl: map['rtmpUrl'] as String? ?? '',
      label: map['label'] as String? ?? '',
      lastUsedAt: map['lastUsedAt'] != null
          ? DateTime.tryParse(map['lastUsedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'streamKey': streamKey,
        'platform': platform.name,
        'rtmpUrl': rtmpUrl,
        'label': label,
        'lastUsedAt': lastUsedAt?.toIso8601String(),
      };

  SavedStreamKey copyWithLastUsed(DateTime when) => SavedStreamKey(
        id: id,
        streamKey: streamKey,
        platform: platform,
        rtmpUrl: rtmpUrl,
        label: label,
        lastUsedAt: when,
      );

  @override
  List<Object?> get props => [id, streamKey, platform, rtmpUrl];
}
