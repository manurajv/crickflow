import '../../../data/models/series/series.dart';

/// Scoped Series RBAC helpers (client UX + pre-checks; server enforces).
class SeriesPermissionService {
  const SeriesPermissionService();

  bool isSuperAdmin({
    required SeriesModel series,
    required String userId,
    SeriesAdminModel? adminDoc,
  }) {
    if (series.superAdminUserId == userId) return true;
    if (series.createdBy == userId && series.superAdminUserId == null) {
      return true;
    }
    return false;
  }

  SeriesAdminModel? _activeAdminDoc({
    required SeriesModel series,
    required String userId,
    required List<SeriesAdminModel> admins,
  }) {
    for (final a in admins) {
      if (a.userId == userId &&
          a.seriesId == series.id &&
          a.status == 'active') {
        return a;
      }
    }
    return null;
  }

  /// Owner or full admin tier (legacy `seriesAdmin` / missing role included).
  bool isSeriesAdmin({
    required SeriesModel series,
    required String userId,
    required List<SeriesAdminModel> admins,
  }) {
    if (isSuperAdmin(series: series, userId: userId)) return true;
    final doc = _activeAdminDoc(series: series, userId: userId, admins: admins);
    return doc != null && doc.tier == SeriesAdminTier.admin;
  }

  bool isSeriesStaff({
    required SeriesModel series,
    required String userId,
    required List<SeriesAdminModel> admins,
  }) {
    if (isSuperAdmin(series: series, userId: userId)) return true;
    return _activeAdminDoc(series: series, userId: userId, admins: admins) !=
        null;
  }

  bool isSeriesScorer({
    required SeriesModel series,
    required String userId,
    required List<SeriesAdminModel> admins,
  }) {
    if (isSuperAdmin(series: series, userId: userId)) return true;
    final doc = _activeAdminDoc(series: series, userId: userId, admins: admins);
    return doc != null &&
        (doc.tier == SeriesAdminTier.admin ||
            doc.tier == SeriesAdminTier.scorer);
  }

  bool isClubAdmin({
    required String userId,
    required String clubId,
    required List<SeriesClubAdminModel> clubAdmins,
  }) {
    return clubAdmins.any(
      (a) =>
          a.userId == userId &&
          a.clubId == clubId &&
          a.status == 'active',
    );
  }

  /// Super Admin can do everything in the Series.
  bool canManageSeriesSettings({
    required SeriesModel series,
    required String userId,
    List<SeriesAdminModel> admins = const [],
  }) =>
      isSeriesAdmin(series: series, userId: userId, admins: admins);

  bool canApprove({
    required SeriesModel series,
    required String userId,
    required List<SeriesAdminModel> admins,
    bool requiresSuperAdmin = true,
  }) {
    if (requiresSuperAdmin) {
      return isSuperAdmin(series: series, userId: userId);
    }
    return isSeriesAdmin(series: series, userId: userId, admins: admins);
  }

  bool canProposeMatch({
    required SeriesModel series,
    required String userId,
    required String clubId,
    required List<SeriesAdminModel> admins,
    required List<SeriesClubAdminModel> clubAdmins,
  }) {
    if (isSeriesScorer(series: series, userId: userId, admins: admins)) {
      return true;
    }
    return isClubAdmin(
      userId: userId,
      clubId: clubId,
      clubAdmins: clubAdmins,
    );
  }

  bool canViewSensitiveRegistration({
    required SeriesModel series,
    required String userId,
    required List<SeriesAdminModel> admins,
  }) =>
      isSeriesAdmin(series: series, userId: userId, admins: admins);

  SeriesRole highestRole({
    required SeriesModel series,
    required String userId,
    required List<SeriesAdminModel> admins,
    required List<SeriesClubAdminModel> clubAdmins,
    required List<SeriesMembershipModel> memberships,
  }) {
    if (isSuperAdmin(series: series, userId: userId)) {
      return SeriesRole.superAdmin;
    }
    final adminDoc = _activeAdminDoc(
      series: series,
      userId: userId,
      admins: admins,
    );
    if (adminDoc != null) {
      return switch (adminDoc.tier) {
        SeriesAdminTier.admin => SeriesRole.seriesAdmin,
        SeriesAdminTier.scorer => SeriesRole.scorer,
        SeriesAdminTier.viewer => SeriesRole.staffViewer,
      };
    }
    if (clubAdmins.any((a) => a.userId == userId && a.status == 'active')) {
      return SeriesRole.clubAdmin;
    }
    if (memberships.any(
      (m) => m.userId == userId && m.status == SeriesMembershipStatus.active,
    )) {
      return SeriesRole.seriesPlayer;
    }
    return SeriesRole.viewer;
  }
}
