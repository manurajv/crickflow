import 'monitoring_enums.dart';

class MonitoringFilters {
  const MonitoringFilters({
    this.query = '',
    this.severities = const {},
    this.services = const {},
    this.module,
    this.environment,
    this.platform,
    this.from,
    this.to,
  });

  final String query;
  final Set<MonitoringSeverity> severities;
  final Set<FirebaseServiceId> services;
  final String? module;
  final MonitoringEnvironment? environment;
  final String? platform;
  final DateTime? from;
  final DateTime? to;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      severities.isNotEmpty ||
      services.isNotEmpty ||
      (module?.isNotEmpty ?? false) ||
      environment != null ||
      (platform?.isNotEmpty ?? false) ||
      from != null ||
      to != null;

  MonitoringFilters copyWith({
    String? query,
    Set<MonitoringSeverity>? severities,
    Set<FirebaseServiceId>? services,
    String? module,
    MonitoringEnvironment? environment,
    String? platform,
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return MonitoringFilters(
      query: query ?? this.query,
      severities: severities ?? this.severities,
      services: services ?? this.services,
      module: module ?? this.module,
      environment: environment ?? this.environment,
      platform: platform ?? this.platform,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }

  static const empty = MonitoringFilters();
}
