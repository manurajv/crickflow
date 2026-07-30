import 'security_enums.dart';

class SecurityFilters {
  const SecurityFilters({
    this.query = '',
    this.severities = const {},
    this.roleId,
    this.organizationId,
    this.country,
    this.device,
    this.browser,
    this.alertStatuses = const {},
    this.from,
    this.to,
  });

  final String query;
  final Set<SocSeverity> severities;
  final String? roleId;
  final String? organizationId;
  final String? country;
  final String? device;
  final String? browser;
  final Set<SocAlertStatus> alertStatuses;
  final DateTime? from;
  final DateTime? to;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      severities.isNotEmpty ||
      (roleId?.isNotEmpty ?? false) ||
      (organizationId?.isNotEmpty ?? false) ||
      (country?.isNotEmpty ?? false) ||
      (device?.isNotEmpty ?? false) ||
      (browser?.isNotEmpty ?? false) ||
      alertStatuses.isNotEmpty ||
      from != null ||
      to != null;

  SecurityFilters copyWith({
    String? query,
    Set<SocSeverity>? severities,
    String? roleId,
    String? organizationId,
    String? country,
    String? device,
    String? browser,
    Set<SocAlertStatus>? alertStatuses,
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return SecurityFilters(
      query: query ?? this.query,
      severities: severities ?? this.severities,
      roleId: roleId ?? this.roleId,
      organizationId: organizationId ?? this.organizationId,
      country: country ?? this.country,
      device: device ?? this.device,
      browser: browser ?? this.browser,
      alertStatuses: alertStatuses ?? this.alertStatuses,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }

  static const empty = SecurityFilters();
}
