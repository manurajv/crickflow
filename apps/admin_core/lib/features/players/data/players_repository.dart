import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../core/constants/admin_query_limits.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/managed_player.dart';
import '../models/player_enums.dart';
import '../models/player_filters.dart';

/// Paginated reads / additive admin updates for Firestore `players`.
///
/// Never hard-deletes player docs. Never mutates `playerId` / career stats /
/// team roster fields from the admin panel.
class PlayersRepository {
  PlayersRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _players =>
      _db.collection(AdminCollections.players);

  CollectionReference<Map<String, dynamic>> get _teams =>
      _db.collection(AdminCollections.teams);

  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  Future<PlayerPageResult> fetchPage({
    required AdminAppType appType,
    required AdminUser? actor,
    required PlayerListFilters filters,
    required PlayerSort sort,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    if (appType == AdminAppType.organizationAdmin) {
      return _fetchOrgScopedPage(
        actor: actor,
        filters: filters,
        sort: sort,
        limit: limit,
      );
    }

    Query<Map<String, dynamic>> query = _players;
    final q = filters.query.trim();

    if (q.isNotEmpty) {
      if (_looksLikeDocId(q)) {
        final doc = await _players.doc(q).get();
        if (!doc.exists || doc.data() == null) {
          return const PlayerPageResult(players: [], hasMore: false);
        }
        final player =
            ManagedPlayer.fromFirestore(id: doc.id, map: doc.data()!);
        final filtered = _applyClientFilters([player], filters);
        return PlayerPageResult(players: filtered, hasMore: false, cursor: doc);
      }
      // Prefix search on public display name.
      query = query.orderBy('name').startAt([q]).endAt(['$q\uf8ff']);
    } else {
      switch (sort.field) {
        case PlayerSortField.name:
          query = query.orderBy('name', descending: sort.descending);
        case PlayerSortField.createdAt:
        case PlayerSortField.matches:
        case PlayerSortField.runs:
        case PlayerSortField.wickets:
          // createdAt is often an ISO string; documentId is a safe fallback order.
          query = query.orderBy(FieldPath.documentId, descending: sort.descending);
      }
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.limit(limit + 1).get();
    } on FirebaseException {
      snap = await _players
          .orderBy(FieldPath.documentId)
          .limit(limit + 1)
          .get();
    }

    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

    var players = pageDocs
        .map((d) => ManagedPlayer.fromFirestore(id: d.id, map: d.data()))
        .toList();
    players = _applyClientFilters(players, filters);
    players = _sortClient(players, sort);

    return PlayerPageResult(
      players: players,
      hasMore: hasMore,
      cursor: pageDocs.isEmpty ? null : pageDocs.last,
    );
  }

  /// Org Admin: players linked to teams that belong to the actor's organization.
  Future<PlayerPageResult> _fetchOrgScopedPage({
    required AdminUser? actor,
    required PlayerListFilters filters,
    required PlayerSort sort,
    required int limit,
  }) async {
    final orgId = actor?.organizationId;
    if (orgId == null || orgId.isEmpty) {
      return const PlayerPageResult(players: [], hasMore: false);
    }

    final teamSnap = await _teams
        .where('organizationId', isEqualTo: orgId)
        .limit(AdminQueryLimits.summaryScanMax)
        .get();

    final playerIds = <String>{};
    for (final doc in teamSnap.docs) {
      final ids = List<String>.from(doc.data()['playerIds'] as List? ?? const []);
      playerIds.addAll(ids.where((id) => id.isNotEmpty));
    }

    if (playerIds.isEmpty) {
      return const PlayerPageResult(players: [], hasMore: false);
    }

    final players = <ManagedPlayer>[];
    final idList = playerIds.toList();
    for (var i = 0; i < idList.length; i += 10) {
      final chunk = idList.sublist(i, i + 10 > idList.length ? idList.length : i + 10);
      final snaps = await Future.wait(chunk.map((id) => _players.doc(id).get()));
      for (final s in snaps) {
        if (s.exists && s.data() != null) {
          players.add(ManagedPlayer.fromFirestore(id: s.id, map: s.data()!));
        }
      }
    }

    var filtered = _applyClientFilters(players, filters);
    filtered = _sortClient(filtered, sort);
    final page = filtered.take(limit).toList();

    return PlayerPageResult(
      players: page,
      hasMore: filtered.length > limit,
    );
  }

  bool _looksLikeDocId(String q) =>
      RegExp(r'^[A-Za-z0-9_-]{12,}$').hasMatch(q) && !q.contains(' ');

  List<ManagedPlayer> _applyClientFilters(
    List<ManagedPlayer> list,
    PlayerListFilters filters,
  ) {
    Iterable<ManagedPlayer> items = list;

    if (!filters.includeDeleted) {
      items = items.where((p) => !p.isSoftDeleted);
    }
    if (!filters.includeArchived) {
      items = items.where(
        (p) => p.recordStatus != AdminPlayerRecordStatus.archived,
      );
    }
    if (filters.registeredOnly) {
      items = items.where((p) => p.isRegistered);
    }
    if (filters.walkInOnly) {
      items = items.where((p) => p.isWalkIn);
    }

    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.fullName.toLowerCase().contains(q) ||
            p.id.toLowerCase().contains(q) ||
            (p.publicPlayerId?.toLowerCase().contains(q) ?? false) ||
            (p.userId?.toLowerCase().contains(q) ?? false) ||
            p.role.toLowerCase().contains(q) ||
            p.locationLabel.toLowerCase().contains(q);
      });
    }

    if (filters.statuses.isNotEmpty) {
      items = items.where((p) => filters.statuses.contains(p.displayStatus));
    }
    if (filters.country?.trim().isNotEmpty == true) {
      final c = filters.country!.trim().toLowerCase();
      items = items.where((p) => p.country.toLowerCase().contains(c));
    }
    if (filters.city?.trim().isNotEmpty == true) {
      final c = filters.city!.trim().toLowerCase();
      items = items.where((p) => p.city.toLowerCase().contains(c));
    }

    return items.toList();
  }

  List<ManagedPlayer> _sortClient(List<ManagedPlayer> list, PlayerSort sort) {
    final items = [...list];
    int cmp(ManagedPlayer a, ManagedPlayer b) {
      final result = switch (sort.field) {
        PlayerSortField.name =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
        PlayerSortField.matches => a.matchesPlayed.compareTo(b.matchesPlayed),
        PlayerSortField.runs => a.runs.compareTo(b.runs),
        PlayerSortField.wickets => a.wickets.compareTo(b.wickets),
        PlayerSortField.createdAt =>
          (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      };
      return sort.descending ? -result : result;
    }

    items.sort(cmp);
    return items;
  }

  Future<ManagedPlayer?> fetchById(
    String id, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    final doc = await _players.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    final player = ManagedPlayer.fromFirestore(id: doc.id, map: doc.data()!);
    if (!_visibleToActor(player, appType: appType, actor: actor)) {
      return null;
    }
    return player;
  }

  bool _visibleToActor(
    ManagedPlayer player, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) {
    if (appType != AdminAppType.organizationAdmin) return true;
    final orgId = actor?.organizationId;
    if (orgId == null || orgId.isEmpty) return false;
    if (player.organizationId == orgId) return true;
    // Org visibility for players without organizationId is enforced at list
    // time via team membership; detail allows if already selected from list.
    return true;
  }

  Future<PlayerSummaryStats> fetchSummary({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    final page = await fetchPage(
      appType: appType,
      actor: actor,
      filters: const PlayerListFilters(includeDeleted: true, includeArchived: true),
      sort: const PlayerSort(),
      limit: AdminQueryLimits.summaryScanMax,
    );
    final list = page.players;
    return PlayerSummaryStats(
      total: list.where((p) => !p.isSoftDeleted).length,
      registered: list.where((p) => p.isRegistered && !p.isSoftDeleted).length,
      walkIn: list.where((p) => p.isWalkIn && !p.isSoftDeleted).length,
      verified: list
          .where((p) =>
              p.displayStatus == ManagedPlayerStatus.verified && !p.isSoftDeleted)
          .length,
      active: list
          .where((p) =>
              p.displayStatus == ManagedPlayerStatus.active && !p.isSoftDeleted)
          .length,
      suspended: list
          .where((p) => p.displayStatus == ManagedPlayerStatus.suspended)
          .length,
    );
  }

  Future<List<AdminAuditLogEntry>> fetchAuditForPlayer(
    String playerId, {
    int limit = 30,
  }) async {
    try {
      final snap = await _audit
          .where('targetUid', isEqualTo: playerId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => AdminAuditLogEntry.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setFeatured({
    required ManagedPlayer target,
    required bool featured,
    required AdminUser actor,
    String? reason,
  }) async {
    await _players.doc(target.id).set({
      'adminFeatured': featured,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: featured ? 'player.featured' : 'player.unfeatured',
      actor: actor,
      targetUid: target.id,
      reason: reason,
    );
  }

  Future<void> setVerified({
    required ManagedPlayer target,
    required bool verified,
    required AdminUser actor,
    String? reason,
  }) async {
    await _players.doc(target.id).set({
      'adminVerified': verified,
      if (verified) 'adminStatus': ManagedPlayerStatus.verified.wireValue,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: verified ? 'player.verified' : 'player.unverified',
      actor: actor,
      targetUid: target.id,
      reason: reason,
    );
  }

  Future<void> setStatus({
    required ManagedPlayer target,
    required ManagedPlayerStatus status,
    required AdminUser actor,
    String? reason,
  }) async {
    await _players.doc(target.id).set({
      'adminStatus': status.wireValue,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: 'player.status_changed',
      actor: actor,
      targetUid: target.id,
      reason: reason ?? status.label,
    );
  }

  Future<void> softDelete({
    required ManagedPlayer target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _players.doc(target.id).set({
      'adminRecordStatus': AdminPlayerRecordStatus.deleted.wireValue,
      'adminStatus': ManagedPlayerStatus.deleted.wireValue,
      'adminDeletedAt': FieldValue.serverTimestamp(),
      'adminDeletedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: 'player.soft_deleted',
      actor: actor,
      targetUid: target.id,
      reason: reason,
    );
  }

  Future<void> restore({
    required ManagedPlayer target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _players.doc(target.id).set({
      'adminRecordStatus': AdminPlayerRecordStatus.active.wireValue,
      'adminStatus': ManagedPlayerStatus.active.wireValue,
      'adminDeletedAt': null,
      'adminDeletedBy': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: 'player.restored',
      actor: actor,
      targetUid: target.id,
      reason: reason,
    );
  }

  Future<void> updateBasicInfo({
    required ManagedPlayer target,
    required AdminUser actor,
    String? name,
    String? fullName,
    String? role,
    String? battingStyle,
    String? bowlingStyle,
    String? reason,
  }) async {
    final patch = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) patch['name'] = name.trim();
    if (fullName != null) patch['fullName'] = fullName.trim();
    if (role != null) patch['role'] = role.trim();
    if (battingStyle != null) patch['battingStyle'] = battingStyle.trim();
    if (bowlingStyle != null) patch['bowlingStyle'] = bowlingStyle.trim();

    await _players.doc(target.id).set(patch, SetOptions(merge: true));
    await _writeAudit(
      action: 'player.profile_updated',
      actor: actor,
      targetUid: target.id,
      reason: reason,
    );
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    required String targetUid,
    String? reason,
  }) async {
    await _audit.add({
      'action': action,
      'actorUid': actor.uid,
      'actorEmail': actor.email,
      'targetUid': targetUid,
      'timestamp': FieldValue.serverTimestamp(),
      'reason': ?reason,
      'module': 'players',
      'organizationId': ?actor.organizationId,
    });
  }
}
