import '../../../models/admin_role.dart';
import 'user_account_status.dart';

class UserListFilters {
  const UserListFilters({
    this.query = '',
    this.statuses = const {},
    this.adminRoles = const {},
    this.verified,
    this.country,
    this.stateProvince,
    this.city,
    this.gender,
    this.joinedFrom,
    this.joinedTo,
    this.lastLoginFrom,
    this.lastLoginTo,
  });

  final String query;
  final Set<UserAccountStatus> statuses;
  final Set<AdminRole> adminRoles;
  final bool? verified;
  final String? country;
  final String? stateProvince;
  final String? city;
  final String? gender;
  final DateTime? joinedFrom;
  final DateTime? joinedTo;
  final DateTime? lastLoginFrom;
  final DateTime? lastLoginTo;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      adminRoles.isNotEmpty ||
      verified != null ||
      (country?.isNotEmpty ?? false) ||
      (stateProvince?.isNotEmpty ?? false) ||
      (city?.isNotEmpty ?? false) ||
      (gender?.isNotEmpty ?? false) ||
      joinedFrom != null ||
      joinedTo != null ||
      lastLoginFrom != null ||
      lastLoginTo != null;

  UserListFilters copyWith({
    String? query,
    Set<UserAccountStatus>? statuses,
    Set<AdminRole>? adminRoles,
    bool? verified,
    bool clearVerified = false,
    String? country,
    String? stateProvince,
    String? city,
    String? gender,
    DateTime? joinedFrom,
    DateTime? joinedTo,
    DateTime? lastLoginFrom,
    DateTime? lastLoginTo,
    bool clearJoined = false,
    bool clearLastLogin = false,
  }) {
    return UserListFilters(
      query: query ?? this.query,
      statuses: statuses ?? this.statuses,
      adminRoles: adminRoles ?? this.adminRoles,
      verified: clearVerified ? null : (verified ?? this.verified),
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      city: city ?? this.city,
      gender: gender ?? this.gender,
      joinedFrom: clearJoined ? null : (joinedFrom ?? this.joinedFrom),
      joinedTo: clearJoined ? null : (joinedTo ?? this.joinedTo),
      lastLoginFrom:
          clearLastLogin ? null : (lastLoginFrom ?? this.lastLoginFrom),
      lastLoginTo: clearLastLogin ? null : (lastLoginTo ?? this.lastLoginTo),
    );
  }

  static const empty = UserListFilters();
}

enum UserSortField {
  joinedAt,
  name,
  email,
  lastLoginAt,
  country,
}

class UserSort {
  const UserSort({
    this.field = UserSortField.joinedAt,
    this.descending = true,
  });

  final UserSortField field;
  final bool descending;

  UserSort toggle(UserSortField next) {
    if (field == next) {
      return UserSort(field: next, descending: !descending);
    }
    return UserSort(field: next, descending: true);
  }
}
