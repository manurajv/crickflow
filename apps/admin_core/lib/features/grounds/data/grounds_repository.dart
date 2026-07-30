import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/cache/admin_cache.dart';
import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../core/constants/admin_query_limits.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/ground_enums.dart';
import '../models/ground_filters.dart';
import '../models/managed_ground.dart';

/// Ground catalog for admin panels.
///
/// Primary source: unique names from tournament `grounds[]`, with city / state /
/// country / coords taken from each tournament's `location` (not match `venue`).
/// Optional additive `grounds` docs supply admin verify / feature / soft-delete.
class GroundsRepository {
  GroundsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _grounds =>
      _db.collection(AdminCollections.grounds);

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _db.collection(AdminCollections.tournaments);

  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  static const _tournamentScanLimit =
      AdminQueryLimits.groundsTournamentScanMax;
  static const _registryScanLimit = AdminQueryLimits.groundsRegistryScanMax;

  Future<GroundPageResult> fetchPage({
    required AdminAppType appType,
    required AdminUser? actor,
    required GroundListFilters filters,
    required GroundSort sort,
    String? startAfterId,
    int limit = 25,
  }) async {
    final catalog = await _loadCatalog(appType: appType, actor: actor);
    var list = _applyClientFilters(catalog, filters);
    _sortInPlace(list, sort);

    var start = 0;
    if (startAfterId != null && startAfterId.isNotEmpty) {
      final idx = list.indexWhere((g) => g.id == startAfterId);
      start = idx < 0 ? 0 : idx + 1;
    }

    final page = list.skip(start).take(limit).toList();
    final hasMore = start + page.length < list.length;

    return GroundPageResult(
      grounds: page,
      hasMore: hasMore,
      pageCursor: page.isEmpty ? null : page.last.id,
    );
  }

  Future<GroundSummaryStats> fetchSummary({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    final list = (await _loadCatalog(appType: appType, actor: actor))
        .where((g) => !g.isSoftDeleted)
        .toList();

    return GroundSummaryStats(
      total: list.length,
      verified: list.where((g) => g.isVerified).length,
      active: list
          .where(
            (g) =>
                g.displayStatus == ManagedGroundStatus.active ||
                g.displayStatus == ManagedGroundStatus.verified,
          )
          .length,
      pendingVerification: list
          .where(
            (g) =>
                g.displayStatus == ManagedGroundStatus.pendingVerification,
          )
          .length,
      indoor:
          list.where((g) => g.groundType == ManagedGroundType.indoor).length,
      outdoor:
          list.where((g) => g.groundType == ManagedGroundType.outdoor).length,
      turf: list
          .where(
            (g) =>
                g.groundType == ManagedGroundType.turf ||
                g.pitchType == ManagedGroundPitchType.turf,
          )
          .length,
      matting: list
          .where(
            (g) =>
                g.groundType == ManagedGroundType.matting ||
                g.pitchType == ManagedGroundPitchType.matting,
          )
          .length,
    );
  }

  /// Builds unique grounds from tournaments, merged with registry metadata.
  /// Cached for 2 minutes to avoid re-scanning tournaments on every page flip.
  Future<List<ManagedGround>> _loadCatalog({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    final orgKey = appType == AdminAppType.organizationAdmin
        ? (actor?.organizationId ?? 'none')
        : 'global';
    final cacheKey = 'grounds.catalog.$orgKey';
    return AdminCache.shared.getOrLoad(cacheKey, () async {
      final fromTournaments = await _aggregateFromTournaments(
        appType: appType,
        actor: actor,
      );
      final registry = await _loadRegistry(appType: appType, actor: actor);

      // Collapse by normalized ground name (fixes city-split duplicates).
      final byName = <String, ManagedGround>{};

      void upsert(ManagedGround g) {
        final key = ManagedGround.normalizeNameKey(g.name);
        if (key.isEmpty) return;
        final existing = byName[key];
        if (existing == null) {
          byName[key] = g;
        } else {
          byName[key] = _mergeSameName(existing, g);
        }
      }

      for (final g in fromTournaments) {
        upsert(g);
      }
      for (final reg in registry) {
        if (_visibleToActor(reg, appType: appType, actor: actor)) {
          upsert(reg);
        }
      }

      return byName.values.toList();
    });
  }

  /// Prefer tournament-derived canonical id; keep richer admin / location fields.
  ManagedGround _mergeSameName(ManagedGround a, ManagedGround b) {
    final id = a.id.startsWith('tg_')
        ? a.id
        : (b.id.startsWith('tg_')
            ? b.id
            : ManagedGround.stableIdFor(name: a.name.isNotEmpty ? a.name : b.name));

    final name = a.name.length >= b.name.length ? a.name : b.name;
    final betterLoc = _locationScore(a) >= _locationScore(b) ? a : b;
    final adminDonor = _adminRichness(a) >= _adminRichness(b) ? a : b;
    final ids = {...a.tournamentIds, ...b.tournamentIds}.toList()..sort();
    final matches = a.matchesHosted > b.matchesHosted
        ? a.matchesHosted
        : b.matchesHosted;

    return ManagedGround(
      id: id,
      name: name,
      groundCode: adminDonor.groundCode ?? betterLoc.groundCode,
      description: ids.isEmpty
          ? (adminDonor.description.isNotEmpty
              ? adminDonor.description
              : betterLoc.description)
          : (ids.length == 1
              ? 'Used in 1 tournament'
              : 'Used in ${ids.length} tournaments'),
      photoUrl: adminDonor.photoUrl ?? betterLoc.photoUrl,
      galleryUrls: adminDonor.galleryUrls.isNotEmpty
          ? adminDonor.galleryUrls
          : betterLoc.galleryUrls,
      address: adminDonor.address.isNotEmpty
          ? adminDonor.address
          : betterLoc.address,
      country: betterLoc.country,
      stateProvince: betterLoc.stateProvince,
      city: betterLoc.city,
      pinCode: adminDonor.pinCode.isNotEmpty
          ? adminDonor.pinCode
          : betterLoc.pinCode,
      latitude: betterLoc.latitude,
      longitude: betterLoc.longitude,
      contactPerson: adminDonor.contactPerson.isNotEmpty
          ? adminDonor.contactPerson
          : betterLoc.contactPerson,
      contactNumber: adminDonor.contactNumber.isNotEmpty
          ? adminDonor.contactNumber
          : betterLoc.contactNumber,
      email: adminDonor.email.isNotEmpty ? adminDonor.email : betterLoc.email,
      website:
          adminDonor.website.isNotEmpty ? adminDonor.website : betterLoc.website,
      ownerId: adminDonor.ownerId ?? betterLoc.ownerId,
      ownerName: adminDonor.ownerName.isNotEmpty
          ? adminDonor.ownerName
          : betterLoc.ownerName,
      establishedYear: adminDonor.establishedYear ?? betterLoc.establishedYear,
      capacity: adminDonor.capacity ?? betterLoc.capacity,
      boundarySize: adminDonor.boundarySize ?? betterLoc.boundarySize,
      groundType: adminDonor.groundType ?? betterLoc.groundType,
      pitchType: adminDonor.pitchType ?? betterLoc.pitchType,
      ballTypes: adminDonor.ballTypes.isNotEmpty
          ? adminDonor.ballTypes
          : betterLoc.ballTypes,
      availability: adminDonor.availability,
      facilities: adminDonor.facilities.isNotEmpty
          ? adminDonor.facilities
          : betterLoc.facilities,
      floodlights: adminDonor.floodlights || betterLoc.floodlights,
      parking: adminDonor.parking || betterLoc.parking,
      matchesHosted: matches,
      rating: adminDonor.rating > 0 ? adminDonor.rating : betterLoc.rating,
      reviewCount: adminDonor.reviewCount > 0
          ? adminDonor.reviewCount
          : betterLoc.reviewCount,
      createdAt: _earlier(a.createdAt, b.createdAt),
      updatedAt: _later(a.updatedAt, b.updatedAt),
      adminFeatured: adminDonor.adminFeatured,
      adminVerified: adminDonor.adminVerified,
      adminStatus: adminDonor.adminStatus,
      recordStatus: adminDonor.recordStatus,
      organizationId: adminDonor.organizationId ?? betterLoc.organizationId,
      deletedAt: adminDonor.deletedAt,
      deletedBy: adminDonor.deletedBy,
      tournamentIds: ids,
      source: ids.isNotEmpty
          ? GroundDataSource.tournament
          : adminDonor.source,
    );
  }

  int _adminRichness(ManagedGround g) {
    var s = 0;
    if (g.adminFeatured) s += 4;
    if (g.adminVerified) s += 4;
    if (g.isSoftDeleted) s += 3;
    if (g.recordStatus != AdminGroundRecordStatus.active) s += 2;
    if (g.source == GroundDataSource.registry) s += 1;
    if (g.contactPerson.isNotEmpty) s += 1;
    return s;
  }

  int _locationScore(ManagedGround g) {
    var s = 0;
    if (g.hasCoordinates) s += 50;
    if (g.city.isNotEmpty) s += 10;
    if (g.stateProvince.isNotEmpty) s += 5;
    if (g.country.isNotEmpty) s += 5;
    return s;
  }

  DateTime? _earlier(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isBefore(b) ? a : b;
  }

  DateTime? _later(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  Future<List<ManagedGround>> _aggregateFromTournaments({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    Query<Map<String, dynamic>> query = _tournaments;

    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const [];
      query = query.where('organizationId', isEqualTo: orgId);
    }

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.limit(_tournamentScanLimit).get();
    } on FirebaseException {
      snap = await _tournaments.limit(_tournamentScanLimit).get();
    }

    // key = normalized ground name → accumulator
    final acc = <String, _GroundAcc>{};

    for (final doc in snap.docs) {
      final map = doc.data();
      if (appType == AdminAppType.organizationAdmin) {
        final orgId = actor?.organizationId;
        final docOrg = map['organizationId'] as String?;
        if (orgId != null && docOrg != null && docOrg != orgId) continue;
      }

      final soft = map['adminRecordStatus'] as String?;
      if (soft == 'deleted') continue;

      final rawGrounds = map['grounds'];
      if (rawGrounds is! List || rawGrounds.isEmpty) continue;

      final groundNames = rawGrounds
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (groundNames.isEmpty) continue;

      final location = map['location'];
      final loc =
          location is Map ? Map<String, dynamic>.from(location) : const {};
      final city = (loc['city'] as String?)?.trim() ?? '';
      final state = (loc['stateProvince'] as String?)?.trim() ??
          (loc['state'] as String?)?.trim() ??
          '';
      final country = (loc['country'] as String?)?.trim() ?? '';
      final lat = (loc['latitude'] as num?)?.toDouble();
      final lng = (loc['longitude'] as num?)?.toDouble();
      final orgId = map['organizationId'] as String?;
      final createdAt = _parseDate(map['createdAt']);
      final matchCount = (map['matchIds'] as List?)?.length ?? 0;

      final setup = map['setupMeta'];
      final setupMeta =
          setup is Map ? Map<String, dynamic>.from(setup) : const {};
      final primaryGround =
          (setupMeta['primaryGround'] as String?)?.trim() ?? '';

      final groundCount = groundNames.length;
      // Tournament.location is one shared city pin. It is reliable only when
      // the tournament lists a single ground; with multiple grounds the pin
      // usually belongs to the last-picked ground and must not split rows.
      final singleGround = groundCount == 1;

      for (final name in groundNames) {
        final nameKey = ManagedGround.normalizeNameKey(name);
        if (nameKey.isEmpty) continue;

        final id = ManagedGround.stableIdFor(name: name);
        final entry = acc.putIfAbsent(
          nameKey,
          () => _GroundAcc(id: id, name: name),
        );
        // Prefer display casing from the longest/most specific name.
        if (name.length > entry.name.length) entry.name = name;

        entry.tournamentIds.add(doc.id);
        entry.matchesHosted += matchCount;
        if (orgId != null && orgId.isNotEmpty) {
          entry.organizationId ??= orgId;
        }
        if (entry.createdAt == null ||
            (createdAt != null && createdAt.isBefore(entry.createdAt!))) {
          entry.createdAt = createdAt;
        }

        final isPrimary = primaryGround.isNotEmpty &&
            primaryGround.toLowerCase() == name.toLowerCase();
        entry.considerLocation(
          city: city,
          stateProvince: state,
          country: country,
          latitude: lat,
          longitude: lng,
          singleGroundTournament: singleGround,
          isPrimaryGround: isPrimary,
        );
      }
    }

    return acc.values.map((e) => e.toManagedGround()).toList();
  }

  Future<List<ManagedGround>> _loadRegistry({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    Query<Map<String, dynamic>> query = _grounds;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const [];
      query = query.where('organizationId', isEqualTo: orgId);
    }

    try {
      final snap = await query.limit(_registryScanLimit).get();
      return snap.docs
          .map((d) => ManagedGround.fromFirestore(id: d.id, map: d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  void _sortInPlace(List<ManagedGround> list, GroundSort sort) {
    int cmp(ManagedGround a, ManagedGround b) {
      final r = switch (sort.field) {
        GroundSortField.name =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        GroundSortField.city =>
          a.city.toLowerCase().compareTo(b.city.toLowerCase()),
        GroundSortField.matchesHosted =>
          a.matchesHosted.compareTo(b.matchesHosted),
        GroundSortField.rating => a.rating.compareTo(b.rating),
        GroundSortField.createdAt => (a.createdAt ?? DateTime(1970))
            .compareTo(b.createdAt ?? DateTime(1970)),
      };
      return sort.descending ? -r : r;
    }

    list.sort(cmp);
  }

  List<ManagedGround> _applyClientFilters(
    List<ManagedGround> list,
    GroundListFilters filters,
  ) {
    Iterable<ManagedGround> items = list;

    if (!filters.includeDeleted) {
      items = items.where((g) => !g.isSoftDeleted);
    }
    if (!filters.includeArchived) {
      items = items.where(
        (g) => g.recordStatus != AdminGroundRecordStatus.archived,
      );
    }

    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((g) {
        return g.name.toLowerCase().contains(q) ||
            g.id.toLowerCase().contains(q) ||
            (g.groundCode?.toLowerCase().contains(q) ?? false) ||
            g.ownerName.toLowerCase().contains(q) ||
            (g.ownerId?.toLowerCase().contains(q) ?? false) ||
            g.contactPerson.toLowerCase().contains(q) ||
            g.contactNumber.toLowerCase().contains(q) ||
            g.city.toLowerCase().contains(q) ||
            g.stateProvince.toLowerCase().contains(q) ||
            g.country.toLowerCase().contains(q) ||
            g.pinCode.toLowerCase().contains(q) ||
            g.address.toLowerCase().contains(q) ||
            g.tournamentIds.any((id) => id.toLowerCase().contains(q));
      });
    }

    if (filters.statuses.isNotEmpty) {
      items = items.where((g) => filters.statuses.contains(g.displayStatus));
    }
    if (filters.groundTypes.isNotEmpty) {
      items = items.where(
        (g) =>
            g.groundType != null && filters.groundTypes.contains(g.groundType),
      );
    }
    if (filters.ballTypes.isNotEmpty) {
      items = items.where(
        (g) => g.ballTypes.any(filters.ballTypes.contains),
      );
    }
    if (filters.pitchTypes.isNotEmpty) {
      items = items.where(
        (g) => g.pitchType != null && filters.pitchTypes.contains(g.pitchType),
      );
    }
    if (filters.availabilities.isNotEmpty) {
      items = items.where(
        (g) => filters.availabilities.contains(g.availability),
      );
    }
    if (filters.country?.trim().isNotEmpty == true) {
      final c = filters.country!.trim().toLowerCase();
      items = items.where((g) => g.country.toLowerCase().contains(c));
    }
    if (filters.stateProvince?.trim().isNotEmpty == true) {
      final s = filters.stateProvince!.trim().toLowerCase();
      items = items.where((g) => g.stateProvince.toLowerCase().contains(s));
    }
    if (filters.city?.trim().isNotEmpty == true) {
      final c = filters.city!.trim().toLowerCase();
      items = items.where((g) => g.city.toLowerCase().contains(c));
    }

    return items.toList();
  }

  bool _visibleToActor(
    ManagedGround g, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) {
    if (appType != AdminAppType.organizationAdmin) return true;
    final orgId = actor?.organizationId;
    if (orgId == null || orgId.isEmpty) return false;
    // Tournament-derived rows without org stay visible only to Super Admin.
    if (g.organizationId == null || g.organizationId!.isEmpty) return false;
    return g.organizationId == orgId;
  }

  Stream<ManagedGround?> watchById(
    String id, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) {
    return Stream.fromFuture(
      fetchById(id, appType: appType, actor: actor),
    );
  }

  /// One-shot detail — avoids reloading the full tournament catalog on every
  /// snapshot event (previous `.snapshots().asyncMap` cost).
  Future<ManagedGround?> fetchById(
    String id, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    final snap = await _grounds.doc(id).get();
    if (snap.exists && snap.data() != null) {
      final g = ManagedGround.fromFirestore(id: snap.id, map: snap.data()!);
      if (!_visibleToActor(g, appType: appType, actor: actor)) return null;
      return g;
    }
    final catalog = await _loadCatalog(appType: appType, actor: actor);
    try {
      return catalog.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<AdminAuditLogEntry>> fetchAuditForGround(
    String groundId, {
    int limit = 30,
  }) async {
    try {
      final snap = await _audit
          .where('targetUid', isEqualTo: groundId)
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

  Future<String> createGround({
    required ManagedGround draft,
    required AdminUser actor,
    String? reason,
  }) async {
    final ref = _grounds.doc();
    final data = draft.toCreateMap(actorUid: actor.uid);
    data['source'] = GroundDataSource.registry.wireValue;
    if (actor.organizationId != null && actor.organizationId!.isNotEmpty) {
      data['organizationId'] = actor.organizationId;
    }
    await ref.set(data);
    final created = ManagedGround.fromFirestore(id: ref.id, map: data);
    AdminCache.shared.invalidatePrefix('grounds.catalog');
    await _writeAudit(
      action: AdminAuditActions.groundCreated,
      actor: actor,
      target: created,
      reason: reason,
    );
    return ref.id;
  }

  Future<void> _ensurePersisted(ManagedGround target, AdminUser actor) async {
    final ref = _grounds.doc(target.id);
    final snap = await ref.get();
    if (snap.exists) return;
    final data = target.toCreateMap(actorUid: actor.uid);
    if (actor.organizationId != null &&
        actor.organizationId!.isNotEmpty &&
        data['organizationId'] == null) {
      data['organizationId'] = actor.organizationId;
    }
    await ref.set(data);
  }

  Future<void> setFeatured({
    required ManagedGround target,
    required bool featured,
    required AdminUser actor,
    String? reason,
  }) async {
    await _ensurePersisted(target, actor);
    await _grounds.doc(target.id).set({
      'adminFeatured': featured,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    AdminCache.shared.invalidatePrefix('grounds.catalog');
    await _writeAudit(
      action: featured
          ? AdminAuditActions.groundFeatured
          : AdminAuditActions.groundUnfeatured,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> setVerified({
    required ManagedGround target,
    required bool verified,
    required AdminUser actor,
    String? reason,
  }) async {
    await _ensurePersisted(target, actor);
    await _grounds.doc(target.id).set({
      'adminVerified': verified,
      'adminStatus': verified
          ? ManagedGroundStatus.verified.wireValue
          : ManagedGroundStatus.active.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: verified
          ? AdminAuditActions.groundVerified
          : AdminAuditActions.groundUnverified,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> setStatus({
    required ManagedGround target,
    required ManagedGroundStatus status,
    required AdminUser actor,
    String? reason,
  }) async {
    await _ensurePersisted(target, actor);
    await _grounds.doc(target.id).set({
      'adminStatus': status.wireValue,
      if (status == ManagedGroundStatus.verified) 'adminVerified': true,
      if (status == ManagedGroundStatus.active) 'adminVerified': false,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    final action = switch (status) {
      ManagedGroundStatus.suspended => AdminAuditActions.groundSuspended,
      ManagedGroundStatus.active => AdminAuditActions.groundUnsuspended,
      ManagedGroundStatus.verified => AdminAuditActions.groundVerified,
      _ => AdminAuditActions.groundEdited,
    };
    await _writeAudit(
      action: action,
      actor: actor,
      target: target,
      reason: reason,
      metadata: {'status': status.wireValue},
    );
  }

  Future<void> softDelete({
    required ManagedGround target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _ensurePersisted(target, actor);
    final now = DateTime.now().toIso8601String();
    await _grounds.doc(target.id).set({
      'adminRecordStatus': AdminGroundRecordStatus.deleted.wireValue,
      'adminDeletedAt': now,
      'adminDeletedBy': actor.uid,
      'updatedAt': now,
    }, SetOptions(merge: true));
    AdminCache.shared.invalidatePrefix('grounds.catalog');
    await _writeAudit(
      action: AdminAuditActions.groundSoftDeleted,
      actor: actor,
      target: target,
      reason: reason,
      metadata: {'softDelete': true},
    );
  }

  Future<void> restore({
    required ManagedGround target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _ensurePersisted(target, actor);
    await _grounds.doc(target.id).set({
      'adminRecordStatus': AdminGroundRecordStatus.active.wireValue,
      'adminDeletedAt': FieldValue.delete(),
      'adminDeletedBy': FieldValue.delete(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    AdminCache.shared.invalidatePrefix('grounds.catalog');
    await _writeAudit(
      action: AdminAuditActions.groundRestored,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> archive({
    required ManagedGround target,
    required AdminUser actor,
    String? reason,
  }) async {
    await _ensurePersisted(target, actor);
    await _grounds.doc(target.id).set({
      'adminRecordStatus': AdminGroundRecordStatus.archived.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.groundArchived,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> updateBasicInfo({
    required ManagedGround target,
    required AdminUser actor,
    String? name,
    String? description,
    String? address,
    String? city,
    String? stateProvince,
    String? country,
    String? pinCode,
    String? contactPerson,
    String? contactNumber,
    String? email,
    ManagedGroundType? groundType,
    ManagedGroundPitchType? pitchType,
    ManagedGroundAvailability? availability,
    String? reason,
  }) async {
    await _ensurePersisted(target, actor);
    await _grounds.doc(target.id).set({
      'name': ?name,
      'description': ?description,
      'address': ?address,
      'city': ?city,
      'stateProvince': ?stateProvince,
      'country': ?country,
      'pinCode': ?pinCode,
      'contactPerson': ?contactPerson,
      'contactNumber': ?contactNumber,
      'email': ?email,
      'groundType': ?groundType?.wireValue,
      'pitchType': ?pitchType?.wireValue,
      'availability': ?availability?.wireValue,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.groundEdited,
      actor: actor,
      target: target,
      reason: reason,
    );
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    required ManagedGround target,
    String? reason,
    Map<String, dynamic> metadata = const {},
  }) async {
    final entry = AdminAuditLogEntry(
      id: '',
      action: action,
      actorUid: actor.uid,
      actorEmail: actor.email,
      targetUid: target.id,
      targetEmail: target.name,
      timestamp: DateTime.now(),
      reason: reason,
      metadata: {
        ...metadata,
        'entity': 'ground',
        'groundCode': target.groundCode,
        'tournamentIds': target.tournamentIds,
      },
    );
    await _audit.add(entry.toMap());
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        raw > 9999999999 ? raw : raw * 1000,
      );
    }
    return null;
  }
}

class _GroundAcc {
  _GroundAcc({
    required this.id,
    required this.name,
  });

  final String id;
  String name;
  String city = '';
  String stateProvince = '';
  String country = '';
  double? latitude;
  double? longitude;
  String? organizationId;
  DateTime? createdAt;
  final Set<String> tournamentIds = {};
  int matchesHosted = 0;
  int _locationScore = -1;

  /// Prefer location from single-ground tournaments (shared tournament.location
  /// is trustworthy). Multi-ground tournaments only fill gaps weakly.
  void considerLocation({
    required String city,
    required String stateProvince,
    required String country,
    required double? latitude,
    required double? longitude,
    required bool singleGroundTournament,
    required bool isPrimaryGround,
  }) {
    var score = 0;
    if (singleGroundTournament) {
      score += 100;
    } else if (isPrimaryGround) {
      score += 25;
    } else {
      // Multi-ground: tournament pin is usually the last-added ground — ignore
      // unless we have no location at all (handled by score 0 still applying
      // only when nothing better exists).
      score += 0;
    }
    final hasCoords = latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite;
    if (hasCoords) score += 50;
    if (city.isNotEmpty) score += 10;
    if (stateProvince.isNotEmpty) score += 5;
    if (country.isNotEmpty) score += 5;

    // Multi-ground non-primary with no coords: do not overwrite a good city.
    if (!singleGroundTournament && !isPrimaryGround && !hasCoords) {
      if (_locationScore >= 0) return;
      // First weak fill only if completely empty.
      if (this.city.isEmpty && city.isNotEmpty) {
        this.city = city;
        this.stateProvince = stateProvince;
        this.country = country;
        _locationScore = 0;
      }
      return;
    }

    if (score < _locationScore) return;
    if (score == _locationScore && this.city.isNotEmpty) return;

    if (city.isNotEmpty) this.city = city;
    if (stateProvince.isNotEmpty) this.stateProvince = stateProvince;
    if (country.isNotEmpty) this.country = country;
    if (hasCoords) {
      this.latitude = latitude;
      this.longitude = longitude;
    }
    _locationScore = score;
  }

  ManagedGround toManagedGround() {
    final n = tournamentIds.length;
    return ManagedGround(
      id: id,
      name: name,
      description: n == 1
          ? 'Used in 1 tournament'
          : 'Used in $n tournaments',
      country: country,
      stateProvince: stateProvince,
      city: city,
      latitude: latitude,
      longitude: longitude,
      matchesHosted: matchesHosted,
      createdAt: createdAt,
      updatedAt: createdAt,
      organizationId: organizationId,
      tournamentIds: tournamentIds.toList()..sort(),
      source: GroundDataSource.tournament,
      adminStatus: ManagedGroundStatus.active,
    );
  }
}
