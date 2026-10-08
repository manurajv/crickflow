import 'package:equatable/equatable.dart';

/// Who receives an org announcement (mirrors `sendSeriesAnnouncement`).
enum SeriesAnnouncementAudience {
  all,
  admins,
  clubAdmins,
  members;

  String get label => switch (this) {
        SeriesAnnouncementAudience.all => 'Everyone',
        SeriesAnnouncementAudience.admins => 'Admins',
        SeriesAnnouncementAudience.clubAdmins => 'Club admins',
        SeriesAnnouncementAudience.members => 'Players',
      };

  static SeriesAnnouncementAudience parse(String? raw) =>
      SeriesAnnouncementAudience.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => SeriesAnnouncementAudience.all,
      );
}

/// `series/{seriesId}/announcements/{id}` — written by Cloud Functions only.
class SeriesAnnouncementModel extends Equatable {
  const SeriesAnnouncementModel({
    required this.id,
    required this.seriesId,
    required this.title,
    required this.body,
    this.audience = SeriesAnnouncementAudience.all,
    this.createdBy = '',
    this.createdByName = '',
    this.recipientCount = 0,
    this.createdAt,
  });

  final String id;
  final String seriesId;
  final String title;
  final String body;
  final SeriesAnnouncementAudience audience;
  final String createdBy;
  final String createdByName;
  final int recipientCount;
  final DateTime? createdAt;

  factory SeriesAnnouncementModel.fromMap(String id, Map<String, dynamic> map) {
    return SeriesAnnouncementModel(
      id: id,
      seriesId: map['seriesId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      audience: SeriesAnnouncementAudience.parse(map['audience'] as String?),
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      recipientCount: (map['recipientCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [id, seriesId, title, body, audience, createdAt];
}
