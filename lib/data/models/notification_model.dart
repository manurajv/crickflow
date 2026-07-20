import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.matchId,
    this.matchTitle,
    this.teamId,
    this.playerId,
    this.type,
    this.category,
    this.tab,
    this.actionStatus,
    this.addedByUserId,
    this.reportId,
    this.tournamentId,
    this.requestId,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String? matchId;
  /// Display header for match-related notifications (e.g. "Falcons vs Lions").
  final String? matchTitle;
  final String? teamId;
  final String? playerId;
  final String? type;
  final String? category;
  /// Deep-link tab hint (live, summary, badges, …).
  final String? tab;
  /// Post-action status for actionable invites (accepted, rejected, …).
  final String? actionStatus;
  final String? addedByUserId;
  final String? reportId;
  final String? tournamentId;
  final String? requestId;
  final bool read;
  final DateTime? createdAt;

  bool get isRead => read;

  bool get hasActionStatus =>
      actionStatus != null && actionStatus!.trim().isNotEmpty;

  /// First non-empty body line (event detail).
  String get detailPrimary {
    final lines = body
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return '';
    return lines.first;
  }

  /// Second detail line when present.
  String? get detailSecondary {
    final lines = body
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 2) return null;
    return lines[1];
  }

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? map['message'] as String? ?? '',
      matchId: map['matchId'] as String?,
      matchTitle: map['matchTitle'] as String?,
      teamId: map['teamId'] as String?,
      playerId: map['playerId'] as String?,
      type: map['type'] as String?,
      category: map['category'] as String?,
      tab: map['tab'] as String?,
      actionStatus: map['actionStatus'] as String?,
      addedByUserId: map['addedByUserId'] as String?,
      reportId: map['reportId'] as String?,
      tournamentId: map['tournamentId'] as String?,
      requestId: map['requestId'] as String?,
      read: map['read'] as bool? ?? map['isRead'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [id, title, read, actionStatus];
}
