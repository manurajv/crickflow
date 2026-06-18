import 'package:equatable/equatable.dart';

/// Match timeline entry under `matchTimeline/`.
class MatchTimelineEventModel extends Equatable {
  const MatchTimelineEventModel({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.createdBy = '',
    this.createdAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String createdBy;
  final DateTime? createdAt;

  factory MatchTimelineEventModel.fromMap(String id, Map<String, dynamic> map) {
    return MatchTimelineEventModel(
      id: id,
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        if (subtitle.isNotEmpty) 'subtitle': subtitle,
        if (createdBy.isNotEmpty) 'createdBy': createdBy,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  @override
  List<Object?> get props => [id, title];
}
