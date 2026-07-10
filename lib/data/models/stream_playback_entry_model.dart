import 'package:equatable/equatable.dart';

/// One public watch link for a match (YouTube / Facebook / etc.).
class StreamPlaybackEntryModel extends Equatable {
  const StreamPlaybackEntryModel({
    required this.url,
    this.label = '',
    this.addedAt,
    this.isLive = false,
    this.addedByUserId,
    this.addedByName,
  });

  final String url;
  final String label;
  final DateTime? addedAt;
  final bool isLive;
  final String? addedByUserId;
  final String? addedByName;

  factory StreamPlaybackEntryModel.fromMap(Map<String, dynamic> map) {
    return StreamPlaybackEntryModel(
      url: map['url'] as String? ?? '',
      label: map['label'] as String? ?? '',
      addedAt: DateTime.tryParse(map['addedAt']?.toString() ?? ''),
      isLive: map['isLive'] as bool? ?? false,
      addedByUserId: map['addedByUserId'] as String?,
      addedByName: map['addedByName'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'url': url,
        if (label.isNotEmpty) 'label': label,
        if (addedAt != null) 'addedAt': addedAt!.toIso8601String(),
        'isLive': isLive,
        if (addedByUserId != null) 'addedByUserId': addedByUserId,
        if (addedByName != null) 'addedByName': addedByName,
      };

  StreamPlaybackEntryModel copyWith({
    String? url,
    String? label,
    DateTime? addedAt,
    bool? isLive,
    String? addedByUserId,
    String? addedByName,
  }) {
    return StreamPlaybackEntryModel(
      url: url ?? this.url,
      label: label ?? this.label,
      addedAt: addedAt ?? this.addedAt,
      isLive: isLive ?? this.isLive,
      addedByUserId: addedByUserId ?? this.addedByUserId,
      addedByName: addedByName ?? this.addedByName,
    );
  }

  @override
  List<Object?> get props => [url, addedAt, isLive];
}

List<StreamPlaybackEntryModel> parseStreamPlaybackEntries(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => StreamPlaybackEntryModel.fromMap(Map<String, dynamic>.from(e)))
      .where((e) => e.url.trim().isNotEmpty)
      .toList();
}
