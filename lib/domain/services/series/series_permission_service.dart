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

  bool isSeriesAdmin({
    required SeriesModel series,
    required String userId,
    required List<SeriesAdminModel> admins,
  }) {
    if (isSuperAdmin(series: series, userId: userId)) return true;
    return admins.any(
      (a) =>
          a.userId == userId &&
          a.seriesId == series.id &&
          a.status == 'active',
    );
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
  }) =>
      isSuperAdmin(series: series, userId: userId);

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
    if (isSeriesAdmin(series: series, userId: userId, admins: admins)) {
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
    if (admins.any((a) => a.userId == userId && a.status == 'active')) {
      return SeriesRole.seriesAdmin;
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
