import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/admin_collections.dart';
import '../../../core/constants/admin_query_limits.dart';
import '../models/managed_revenue.dart';
import '../models/revenue_enums.dart';
import '../models/revenue_filters.dart';

/// Revenue Center — Super Admin metadata & estimates only.
///
/// Never charges cards, never talks to Stripe/AdMob APIs from the client.
/// Reads additive ads campaign estimates when present.
class RevenueRepository {
  RevenueRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _ads =>
      _db.collection(AdminCollections.adminAdCampaigns);

  CollectionReference<Map<String, dynamic>> get _sponsored =>
      _db.collection(AdminCollections.adminSponsoredContent);

  CollectionReference<Map<String, dynamic>> get _ledger =>
      _db.collection(AdminCollections.adminRevenueLedger);

  Future<RevenueSummary> fetchSummary() async {
    final entries = await fetchEntries(limit: AdminQueryLimits.summaryScanMax);
    final ads = entries.where((e) => e.stream == RevenueStreamKind.ads);
    final sponsorship =
        entries.where((e) => e.stream == RevenueStreamKind.sponsorship);
    final subs =
        entries.where((e) => e.stream == RevenueStreamKind.subscription);

    double sum(Iterable<ManagedRevenueEntry> list) =>
        list.fold<double>(0, (s, e) => s + e.amount);

    return RevenueSummary(
      estimatedTotal: sum(entries),
      adsEstimated: sum(ads),
      sponsorshipEstimated: sum(sponsorship),
      subscriptionEstimated: sum(subs),
      transactionCount: entries.length,
      activeCampaigns: ads.length,
    );
  }

  Future<List<ManagedRevenueEntry>> fetchEntries({
    RevenueFilters filters = RevenueFilters.empty,
    int limit = 80,
  }) async {
    final fromAds = await _entriesFromAds(limit: limit);
    final fromSponsored = await _entriesFromSponsored(limit: limit);
    final fromLedger = await _entriesFromLedger(limit: limit);
    var merged = [...fromAds, ...fromSponsored, ...fromLedger];

    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      merged = merged
          .where(
            (e) =>
                e.title.toLowerCase().contains(q) ||
                e.id.toLowerCase().contains(q) ||
                e.stream.label.toLowerCase().contains(q) ||
                (e.sourceId?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    if (filters.stream != null) {
      merged = merged.where((e) => e.stream == filters.stream).toList();
    }
    if (filters.status != null) {
      merged = merged.where((e) => e.status == filters.status).toList();
    }

    merged.sort((a, b) {
      final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });

    if (merged.length > limit) {
      return merged.sublist(0, limit);
    }
    return merged;
  }

  Future<List<ManagedRevenueEntry>> _entriesFromAds({required int limit}) async {
    try {
      final snap = await _ads.limit(limit).get();
      return snap.docs.map((d) {
        final m = d.data();
        final title = (m['title'] as String?)?.trim().isNotEmpty == true
            ? m['title'] as String
            : (m['name'] as String?) ?? 'Ad campaign';
        return ManagedRevenueEntry(
          id: 'ad_${d.id}',
          title: title,
          stream: RevenueStreamKind.ads,
          amount: (m['estimatedRevenue'] as num?)?.toDouble() ?? 0,
          status: RevenueTxnStatus.estimated,
          sourceId: d.id,
          note: 'From admin ads metadata',
          createdAt: _parseDate(m['updatedAt'] ?? m['createdAt']),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ManagedRevenueEntry>> _entriesFromSponsored({
    required int limit,
  }) async {
    try {
      final snap = await _sponsored.limit(limit).get();
      return snap.docs.map((d) {
        final m = d.data();
        final title = (m['title'] as String?)?.trim().isNotEmpty == true
            ? m['title'] as String
            : 'Sponsored content';
        return ManagedRevenueEntry(
          id: 'sponsor_${d.id}',
          title: title,
          stream: RevenueStreamKind.sponsorship,
          amount: (m['estimatedRevenue'] as num?)?.toDouble() ??
              (m['budget'] as num?)?.toDouble() ??
              0,
          status: RevenueTxnStatus.estimated,
          sourceId: d.id,
          note: 'From sponsored content metadata',
          createdAt: _parseDate(m['updatedAt'] ?? m['createdAt']),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ManagedRevenueEntry>> _entriesFromLedger({
    required int limit,
  }) async {
    try {
      final snap = await _ledger
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) {
        final m = d.data();
        return ManagedRevenueEntry(
          id: d.id,
          title: m['title'] as String? ?? 'Ledger entry',
          stream: RevenueStreamKind.parse(m['stream'] as String?),
          amount: (m['amount'] as num?)?.toDouble() ?? 0,
          status: RevenueTxnStatus.parse(m['status'] as String?),
          currency: m['currency'] as String? ?? 'USD',
          sourceId: m['sourceId'] as String?,
          note: m['note'] as String? ?? '',
          createdAt: _parseDate(m['createdAt']),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  List<RevenueIntegrationCard> integrations() => const [
        RevenueIntegrationCard(
          id: 'admob',
          name: 'Google AdMob',
          description:
              'Import mediated network earnings. Configure reporting API later.',
          statusLabel: 'Architecture ready',
        ),
        RevenueIntegrationCard(
          id: 'stripe',
          name: 'Stripe',
          description:
              'Subscriptions and one-time charges. Never store card data in Firestore.',
          statusLabel: 'Architecture ready',
        ),
        RevenueIntegrationCard(
          id: 'play_billing',
          name: 'Google Play Billing',
          description: 'In-app purchases and subscriptions from Play Console.',
          statusLabel: 'Future',
        ),
        RevenueIntegrationCard(
          id: 'app_store',
          name: 'App Store Connect',
          description: 'iOS IAP / subscription reporting.',
          statusLabel: 'Future',
        ),
        RevenueIntegrationCard(
          id: 'manual_sponsorship',
          name: 'Manual sponsorship ledger',
          description:
              'Record board/sponsor contracts as metadata-only ledger rows.',
          statusLabel: 'Ledger collection ready',
          ready: true,
        ),
      ];

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }
}
