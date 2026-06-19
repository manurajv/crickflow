import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/match_local_store.dart';
import '../../data/local/pending_sync_action.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/offline_sync_service.dart';

final matchLocalStoreProvider = Provider<MatchLocalStore>((ref) {
  return MatchLocalStore();
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final service = OfflineSyncService(
    localStore: ref.watch(matchLocalStoreProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final offlineSyncStatusProvider = StreamProvider<ConnectivityStatus>((ref) {
  return ref.watch(offlineSyncServiceProvider).onSyncStatusChanged;
});

final matchSyncMetaProvider =
    StreamProvider.family<MatchSyncMeta, String>((ref, matchId) {
  final local = ref.watch(matchLocalStoreProvider);
  final sync = ref.watch(offlineSyncServiceProvider);

  MatchSyncMeta buildMeta() => MatchSyncMeta(
        matchId: matchId,
        pendingCount: local.pendingCountForMatch(matchId),
        lastSyncAt: local.lastSyncAt(matchId),
        status: sync.currentStatus,
      );

  return Stream.multi((multi) {
    multi.add(buildMeta());
    final localSub = local.watchSyncMeta(matchId).listen((_) {
      multi.add(buildMeta());
    });
    final statusSub = sync.onSyncStatusChanged.listen((_) {
      multi.add(buildMeta());
    });
    multi.onCancel = () {
      localSub.cancel();
      statusSub.cancel();
    };
  });
});
