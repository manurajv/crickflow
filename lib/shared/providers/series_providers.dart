import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/series/series.dart';
import '../../data/repositories/series_approval_repository.dart';
import '../../data/repositories/series_audit_repository.dart';
import '../../data/repositories/series_club_repository.dart';
import '../../data/repositories/series_competition_repository.dart';
import '../../data/repositories/series_membership_repository.dart';
import '../../data/repositories/series_ranking_repository.dart';
import '../../data/repositories/series_registration_repository.dart';
import '../../data/repositories/series_repository.dart';
import '../../data/services/series_functions_service.dart';
import '../../domain/services/series/series_permission_service.dart';

final seriesFunctionsServiceProvider = Provider(
  (ref) => SeriesFunctionsService(),
);

final seriesRepositoryProvider = Provider(
  (ref) =>
      SeriesRepository(functions: ref.watch(seriesFunctionsServiceProvider)),
);
final seriesClubRepositoryProvider = Provider((ref) => SeriesClubRepository());
final seriesApprovalRepositoryProvider = Provider(
  (ref) => SeriesApprovalRepository(
    functions: ref.watch(seriesFunctionsServiceProvider),
  ),
);
final seriesMembershipRepositoryProvider = Provider(
  (ref) => SeriesMembershipRepository(),
);
final seriesRegistrationRepositoryProvider = Provider(
  (ref) => SeriesRegistrationRepository(
    functions: ref.watch(seriesFunctionsServiceProvider),
  ),
);
final seriesCompetitionRepositoryProvider = Provider(
  (ref) => SeriesCompetitionRepository(),
);
final seriesRankingRepositoryProvider = Provider(
  (ref) => SeriesRankingRepository(),
);
final seriesAuditRepositoryProvider = Provider(
  (ref) => SeriesAuditRepository(),
);

final seriesByIdProvider = StreamProvider.family<SeriesModel?, String>((
  ref,
  seriesId,
) {
  if (seriesId.isEmpty) return Stream.value(null);
  return ref.watch(seriesRepositoryProvider).watchSeriesById(seriesId);
});

final listActiveSeriesProvider = StreamProvider<List<SeriesModel>>((ref) {
  return ref.watch(seriesRepositoryProvider).listActiveSeries();
});

final seriesClubByIdProvider = FutureProvider.family<SeriesClubModel?, String>((
  ref,
  clubId,
) async {
  if (clubId.isEmpty) return null;
  return ref.watch(seriesClubRepositoryProvider).getClub(clubId);
});

final pendingSeriesApprovalsProvider =
    StreamProvider.family<List<SeriesApprovalModel>, String>((ref, seriesId) {
      if (seriesId.isEmpty) return Stream.value(const []);
      return ref
          .watch(seriesApprovalRepositoryProvider)
          .watchPendingApprovals(seriesId);
    });

final seriesClubAdminsProvider =
    StreamProvider.family<
      List<SeriesClubAdminModel>,
      ({String seriesId, String clubId})
    >((ref, params) {
      return ref
          .watch(seriesClubRepositoryProvider)
          .watchClubAdmins(seriesId: params.seriesId, clubId: params.clubId);
    });

/// Pending player-join requests for a club awaiting Club Admin first-pass.
final pendingClubJoinApprovalsProvider =
    Provider.family<
      AsyncValue<List<SeriesApprovalModel>>,
      ({String seriesId, String clubId})
    >((ref, params) {
      return ref.watch(pendingSeriesApprovalsProvider(params.seriesId)).whenData(
        (items) => items
            .where(
              (a) =>
                  a.targetType == SeriesApprovalTargetType.playerJoin &&
                  a.clubId == params.clubId &&
                  a.metadata['clubReviewStatus'] != 'approved',
            )
            .toList(),
      );
    });

final seriesClubRankingsProvider =
    StreamProvider.family<List<SeriesClubRankingModel>, String>((
      ref,
      seriesId,
    ) {
      if (seriesId.isEmpty) return Stream.value(const []);
      return ref
          .watch(seriesRankingRepositoryProvider)
          .watchClubRankings(seriesId);
    });

final seriesPlayerRankingsProvider =
    StreamProvider.family<List<SeriesPlayerRankingModel>, String>((
      ref,
      seriesId,
    ) {
      if (seriesId.isEmpty) return Stream.value(const []);
      return ref
          .watch(seriesRankingRepositoryProvider)
          .watchPlayerRankings(seriesId);
    });

final seriesClubSquadProvider =
    StreamProvider.family<
      List<SeriesMembershipModel>,
      ({String seriesId, String clubId})
    >((ref, params) {
      if (params.seriesId.isEmpty || params.clubId.isEmpty) {
        return Stream.value(const []);
      }
      return ref
          .watch(seriesMembershipRepositoryProvider)
          .watchMembershipsForClub(
            seriesId: params.seriesId,
            clubId: params.clubId,
          );
    });

final clubsForSeriesProvider =
    StreamProvider.family<List<SeriesClubModel>, String>((ref, seriesId) {
      if (seriesId.isEmpty) return Stream.value(const []);
      return ref
          .watch(seriesClubRepositoryProvider)
          .watchClubsForSeries(seriesId);
    });

final seriesAdminsListProvider =
    StreamProvider.family<List<SeriesAdminModel>, String>((ref, seriesId) {
      if (seriesId.isEmpty) return Stream.value(const []);
      return ref.watch(seriesRepositoryProvider).watchSeriesAdmins(seriesId);
    });

final seriesCompetitionsProvider =
    StreamProvider.family<List<SeriesCompetitionModel>, String>((
      ref,
      seriesId,
    ) {
      if (seriesId.isEmpty) return Stream.value(const []);
      return ref
          .watch(seriesCompetitionRepositoryProvider)
          .watchCompetitions(seriesId);
    });

final seriesAuditLogsProvider =
    StreamProvider.family<List<SeriesAuditLogModel>, String>((ref, seriesId) {
      if (seriesId.isEmpty) return Stream.value(const []);
      return ref.watch(seriesAuditRepositoryProvider).watchAuditLogs(seriesId);
    });

final _seriesAdminsProvider = seriesAdminsListProvider;

final _clubAdminsProvider =
    StreamProvider.family<List<SeriesClubAdminModel>, String>((ref, seriesId) {
      return ref
          .watch(seriesClubRepositoryProvider)
          .watchClubAdmins(seriesId: seriesId);
    });

final _mySeriesMembershipsProvider =
    StreamProvider.family<
      List<SeriesMembershipModel>,
      ({String seriesId, String userId})
    >((ref, params) {
      return ref
          .watch(seriesMembershipRepositoryProvider)
          .watchMembershipsForUser(params.userId, seriesId: params.seriesId);
    });

final _seriesAuthProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Highest current role for the signed-in user in a Series.
final mySeriesRoleProvider = Provider.family<SeriesRole, String>((
  ref,
  seriesId,
) {
  final userId = ref.watch(_seriesAuthProvider).valueOrNull?.uid;
  final series = ref.watch(seriesByIdProvider(seriesId)).valueOrNull;
  if (userId == null || series == null) return SeriesRole.viewer;

  final admins =
      ref.watch(_seriesAdminsProvider(seriesId)).valueOrNull ?? const [];
  final clubAdmins =
      ref.watch(_clubAdminsProvider(seriesId)).valueOrNull ?? const [];
  final memberships =
      ref
          .watch(
            _mySeriesMembershipsProvider((seriesId: seriesId, userId: userId)),
          )
          .valueOrNull ??
      const [];

  return const SeriesPermissionService().highestRole(
    series: series,
    userId: userId,
    admins: admins,
    clubAdmins: clubAdmins,
    memberships: memberships,
  );
});
