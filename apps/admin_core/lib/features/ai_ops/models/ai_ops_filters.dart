import 'ai_ops_enums.dart';

class AiOpsFilters {
  const AiOpsFilters({
    this.query = '',
    this.categories = const {},
    this.statuses = const {},
    this.confidenceBands = const {},
    this.organizationId,
    this.country,
    this.stateProvince,
    this.from,
    this.to,
  });

  final String query;
  final Set<AiRecommendationCategory> categories;
  final Set<AiRecommendationStatus> statuses;
  final Set<AiConfidenceBand> confidenceBands;
  final String? organizationId;
  final String? country;
  final String? stateProvince;
  final DateTime? from;
  final DateTime? to;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      categories.isNotEmpty ||
      statuses.isNotEmpty ||
      confidenceBands.isNotEmpty ||
      (organizationId?.isNotEmpty ?? false) ||
      (country?.isNotEmpty ?? false) ||
      (stateProvince?.isNotEmpty ?? false) ||
      from != null ||
      to != null;

  AiOpsFilters copyWith({
    String? query,
    Set<AiRecommendationCategory>? categories,
    Set<AiRecommendationStatus>? statuses,
    Set<AiConfidenceBand>? confidenceBands,
    String? organizationId,
    String? country,
    String? stateProvince,
    DateTime? from,
    DateTime? to,
    bool clearOrg = false,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return AiOpsFilters(
      query: query ?? this.query,
      categories: categories ?? this.categories,
      statuses: statuses ?? this.statuses,
      confidenceBands: confidenceBands ?? this.confidenceBands,
      organizationId:
          clearOrg ? null : (organizationId ?? this.organizationId),
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }

  static const empty = AiOpsFilters();
}
