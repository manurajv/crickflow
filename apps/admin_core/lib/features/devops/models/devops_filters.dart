import 'devops_enums.dart';

class DevOpsFilters {
  const DevOpsFilters({
    this.query = '',
    this.environment,
    this.status,
    this.releaseType,
    this.version,
    this.from,
    this.to,
  });

  final String query;
  final DevOpsEnvironment? environment;
  final String? status;
  final DevOpsReleaseType? releaseType;
  final String? version;
  final DateTime? from;
  final DateTime? to;

  static const empty = DevOpsFilters();

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      environment != null ||
      status != null ||
      releaseType != null ||
      (version != null && version!.isNotEmpty) ||
      from != null ||
      to != null;

  DevOpsFilters copyWith({
    String? query,
    DevOpsEnvironment? environment,
    bool clearEnvironment = false,
    String? status,
    bool clearStatus = false,
    DevOpsReleaseType? releaseType,
    bool clearReleaseType = false,
    String? version,
    bool clearVersion = false,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
  }) {
    return DevOpsFilters(
      query: query ?? this.query,
      environment: clearEnvironment ? null : (environment ?? this.environment),
      status: clearStatus ? null : (status ?? this.status),
      releaseType: clearReleaseType ? null : (releaseType ?? this.releaseType),
      version: clearVersion ? null : (version ?? this.version),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
    );
  }
}
