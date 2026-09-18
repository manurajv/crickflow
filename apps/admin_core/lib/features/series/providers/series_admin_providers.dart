import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/series_admin_repository.dart';
import '../models/managed_series.dart';

final seriesAdminRepositoryProvider = Provider(
  (ref) => SeriesAdminRepository(),
);

final seriesSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final managedSeriesListProvider =
    FutureProvider.autoDispose<List<ManagedSeries>>((ref) {
      return ref
          .watch(seriesAdminRepositoryProvider)
          .listSeries(queryText: ref.watch(seriesSearchProvider));
    });

final seriesInvestigationProvider = FutureProvider.autoDispose
    .family<SeriesInvestigation?, String>((ref, id) {
      return ref.watch(seriesAdminRepositoryProvider).investigate(id);
    });
