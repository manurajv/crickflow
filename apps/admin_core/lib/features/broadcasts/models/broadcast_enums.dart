/// Admin-facing broadcast lifecycle (mapped from `matches.stream` + heartbeat).
enum ManagedBroadcastStatus {
  scheduled,
  waiting,
  connecting,
  live,
  reconnecting,
  completed,
  failed,
  cancelled,
  idle;

  String get label => switch (this) {
        ManagedBroadcastStatus.scheduled => 'Scheduled',
        ManagedBroadcastStatus.waiting => 'Waiting',
        ManagedBroadcastStatus.connecting => 'Connecting',
        ManagedBroadcastStatus.live => 'Live',
        ManagedBroadcastStatus.reconnecting => 'Reconnecting',
        ManagedBroadcastStatus.completed => 'Completed',
        ManagedBroadcastStatus.failed => 'Failed',
        ManagedBroadcastStatus.cancelled => 'Cancelled',
        ManagedBroadcastStatus.idle => 'Idle',
      };

  String get wireValue => name;
}

enum ManagedBroadcastHealth {
  healthy,
  poor,
  offline,
  unknown;

  String get label => switch (this) {
        ManagedBroadcastHealth.healthy => 'Healthy',
        ManagedBroadcastHealth.poor => 'Poor',
        ManagedBroadcastHealth.offline => 'Offline',
        ManagedBroadcastHealth.unknown => 'Unknown',
      };
}

enum ManagedBroadcastVisibility {
  public,
  unlisted,
  private,
  unknown;

  String get label => switch (this) {
        ManagedBroadcastVisibility.public => 'Public',
        ManagedBroadcastVisibility.unlisted => 'Unlisted',
        ManagedBroadcastVisibility.private => 'Private',
        ManagedBroadcastVisibility.unknown => 'Unknown',
      };
}

enum BroadcastSortField {
  matchTitle,
  startedAt,
  status,
  platform,
  createdAt,
}

class BroadcastSort {
  const BroadcastSort({
    this.field = BroadcastSortField.startedAt,
    this.descending = true,
  });

  final BroadcastSortField field;
  final bool descending;

  BroadcastSort toggle(BroadcastSortField next) {
    if (field == next) {
      return BroadcastSort(field: field, descending: !descending);
    }
    return BroadcastSort(field: next, descending: true);
  }
}
