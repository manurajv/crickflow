import 'continuity_enums.dart';

class ContinuityFilters {
  const ContinuityFilters({
    this.query = '',
    this.environment,
    this.status,
    this.backupType,
    this.createdBy,
  });

  static const empty = ContinuityFilters();

  final String query;
  final String? environment;
  final ContinuityJobStatus? status;
  final ContinuityBackupType? backupType;
  final String? createdBy;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      (environment?.isNotEmpty ?? false) ||
      status != null ||
      backupType != null ||
      (createdBy?.isNotEmpty ?? false);

  ContinuityFilters copyWith({
    String? query,
    String? environment,
    bool clearEnvironment = false,
    ContinuityJobStatus? status,
    bool clearStatus = false,
    ContinuityBackupType? backupType,
    bool clearBackupType = false,
    String? createdBy,
    bool clearCreatedBy = false,
  }) {
    return ContinuityFilters(
      query: query ?? this.query,
      environment:
          clearEnvironment ? null : (environment ?? this.environment),
      status: clearStatus ? null : (status ?? this.status),
      backupType: clearBackupType ? null : (backupType ?? this.backupType),
      createdBy: clearCreatedBy ? null : (createdBy ?? this.createdBy),
    );
  }
}
