import 'audit_enums.dart';

class AuditListFilters {
  const AuditListFilters({
    this.query = '',
    this.modules = const {},
    this.severities = const {},
    this.statuses = const {},
    this.action,
    this.actorUid,
    this.actorEmail,
    this.role,
    this.organizationId,
    this.country,
    this.stateProvince,
    this.city,
    this.platform,
    this.device,
    this.browser,
    this.from,
    this.to,
  });

  final String query;
  final Set<AuditModule> modules;
  final Set<AuditSeverity> severities;
  final Set<AuditStatus> statuses;
  final String? action;
  final String? actorUid;
  final String? actorEmail;
  final String? role;
  final String? organizationId;
  final String? country;
  final String? stateProvince;
  final String? city;
  final String? platform;
  final String? device;
  final String? browser;
  final DateTime? from;
  final DateTime? to;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      modules.isNotEmpty ||
      severities.isNotEmpty ||
      statuses.isNotEmpty ||
      (action?.isNotEmpty ?? false) ||
      (actorUid?.isNotEmpty ?? false) ||
      (actorEmail?.isNotEmpty ?? false) ||
      (role?.isNotEmpty ?? false) ||
      (organizationId?.isNotEmpty ?? false) ||
      (country?.isNotEmpty ?? false) ||
      (stateProvince?.isNotEmpty ?? false) ||
      (city?.isNotEmpty ?? false) ||
      (platform?.isNotEmpty ?? false) ||
      (device?.isNotEmpty ?? false) ||
      (browser?.isNotEmpty ?? false) ||
      from != null ||
      to != null;

  AuditListFilters copyWith({
    String? query,
    Set<AuditModule>? modules,
    Set<AuditSeverity>? severities,
    Set<AuditStatus>? statuses,
    String? action,
    String? actorUid,
    String? actorEmail,
    String? role,
    String? organizationId,
    String? country,
    String? stateProvince,
    String? city,
    String? platform,
    String? device,
    String? browser,
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return AuditListFilters(
      query: query ?? this.query,
      modules: modules ?? this.modules,
      severities: severities ?? this.severities,
      statuses: statuses ?? this.statuses,
      action: action ?? this.action,
      actorUid: actorUid ?? this.actorUid,
      actorEmail: actorEmail ?? this.actorEmail,
      role: role ?? this.role,
      organizationId: organizationId ?? this.organizationId,
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      city: city ?? this.city,
      platform: platform ?? this.platform,
      device: device ?? this.device,
      browser: browser ?? this.browser,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }

  static const empty = AuditListFilters();
}
