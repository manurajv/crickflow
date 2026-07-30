import 'notification_enums.dart';

class NotificationListFilters {
  const NotificationListFilters({
    this.query = '',
    this.types = const {},
    this.statuses = const {},
    this.audiences = const {},
    this.platforms = const {},
    this.from,
    this.to,
    this.scheduledOnly = false,
    this.includeArchived = false,
  });

  static const empty = NotificationListFilters();

  final String query;
  final Set<ManagedNotificationType> types;
  final Set<ManagedNotificationStatus> statuses;
  final Set<ManagedNotificationAudience> audiences;
  final Set<ManagedPlatformTarget> platforms;
  final DateTime? from;
  final DateTime? to;
  final bool scheduledOnly;
  final bool includeArchived;

  bool get hasActiveFilters =>
      types.isNotEmpty ||
      statuses.isNotEmpty ||
      audiences.isNotEmpty ||
      platforms.isNotEmpty ||
      from != null ||
      to != null ||
      scheduledOnly ||
      includeArchived;

  NotificationListFilters copyWith({
    String? query,
    Set<ManagedNotificationType>? types,
    Set<ManagedNotificationStatus>? statuses,
    Set<ManagedNotificationAudience>? audiences,
    Set<ManagedPlatformTarget>? platforms,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    bool? scheduledOnly,
    bool? includeArchived,
  }) {
    return NotificationListFilters(
      query: query ?? this.query,
      types: types ?? this.types,
      statuses: statuses ?? this.statuses,
      audiences: audiences ?? this.audiences,
      platforms: platforms ?? this.platforms,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      scheduledOnly: scheduledOnly ?? this.scheduledOnly,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }
}
