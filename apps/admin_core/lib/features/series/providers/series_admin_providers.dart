import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/series_admin_repository.dart';
import '../models/managed_series.dart';

final seriesAdminRepositoryProvider = Provider(
  (ref) => SeriesAdminRepository(),
);

final managedSeriesListProvider =
    FutureProvider.autoDispose<List<ManagedSeries>>((ref) {
      return ref.watch(seriesAdminRepositoryProvider).listSeries();
    });

final seriesInvestigationProvider = FutureProvider.autoDispose
    .family<SeriesInvestigation?, String>((ref, id) {
      return ref.watch(seriesAdminRepositoryProvider).investigate(id);
    });

/// Pure filter used by the Orgs & Series screen (unit-tested).
List<ManagedSeries> filterOrgs(
  List<ManagedSeries> all, {
  OrgFamily? family,
  String status = '',
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  return all
      .where((s) {
        if (family != null && s.family != family) return false;
        if (status.isNotEmpty && s.status != status) return false;
        if (q.isEmpty) return true;
        return s.name.toLowerCase().contains(q) ||
            s.id.toLowerCase().contains(q) ||
            s.ownerUid.toLowerCase().contains(q) ||
            s.region.toLowerCase().contains(q);
      })
      .toList(growable: false);
}
