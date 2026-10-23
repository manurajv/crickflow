import '../../../data/models/series/series.dart';

/// Owner lifecycle actions (mirrors `setSeriesLifecycle` in Cloud Functions).
enum SeriesLifecycleAction {
  archive,
  reactivate;

  String get label => switch (this) {
        SeriesLifecycleAction.archive => 'Archive organization',
        SeriesLifecycleAction.reactivate => 'Reactivate organization',
      };
}

/// Client-side helpers for owner-only org management. The server re-checks
/// every rule; these only decide what the UI offers.
class SeriesOwnerActions {
  const SeriesOwnerActions();

  /// Actions the owner may take right now. Empty while CrickFlow staff have
  /// the org on platform hold.
  List<SeriesLifecycleAction> lifecycleActions(SeriesModel series) {
    if (series.platformHold) return const [];
    return switch (series.status) {
      SeriesStatus.archived => const [SeriesLifecycleAction.reactivate],
      SeriesStatus.suspended => const [
          SeriesLifecycleAction.reactivate,
          SeriesLifecycleAction.archive,
        ],
      SeriesStatus.active ||
      SeriesStatus.draft =>
        const [SeriesLifecycleAction.archive],
    };
  }

  /// Active admins who can receive ownership (everyone except the owner).
  List<SeriesAdminModel> transferCandidates({
    required SeriesModel series,
    required List<SeriesAdminModel> admins,
  }) {
    final owner = ownerUid(series);
    final seen = <String>{};
    return admins
        .where(
          (a) =>
              a.status == 'active' &&
              a.userId.isNotEmpty &&
              a.userId != owner &&
              seen.add(a.userId),
        )
        .toList();
  }

  String ownerUid(SeriesModel series) {
    final superId = series.superAdminUserId ?? '';
    return superId.isNotEmpty ? superId : (series.createdBy ?? '');
  }

  /// Short status line for owners and admins.
  String statusMessage(SeriesModel series) {
    if (series.platformHold) {
      return series.status == SeriesStatus.archived
          ? 'Archived by CrickFlow. Contact support to restore it.'
          : 'Suspended by CrickFlow. Contact support to restore it.';
    }
    return switch (series.status) {
      SeriesStatus.active => 'Active and visible to everyone.',
      SeriesStatus.draft => 'Draft. Not listed yet.',
      SeriesStatus.suspended =>
        'Suspended. New requests and announcements are paused.',
      SeriesStatus.archived =>
        'Archived. Hidden from listings; history is kept.',
    };
  }
}
