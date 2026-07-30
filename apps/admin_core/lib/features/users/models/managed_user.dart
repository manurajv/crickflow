import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../../models/admin_role.dart';
import 'user_account_status.dart';

/// Admin-facing view of a CrickFlow `users/{uid}` document.
///
/// Reads existing mobile fields and additive admin metadata
/// (`accountStatus`, `adminVerified`, `organizationId`, `lastLoginAt`, …).
class ManagedUser extends Equatable {
  const ManagedUser({
    required this.id,
    required this.email,
    this.name = '',
    this.displayName = '',
    this.username = '',
    this.phoneNumber,
    this.photoUrl,
    this.coverUrl,
    this.playerId,
    this.bio = '',
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.gender,
    this.dateOfBirth,
    this.mobileRole = '',
    this.accountStatus = UserAccountStatus.active,
    this.adminVerified = false,
    this.organizationId,
    this.currentTeamId,
    this.currentTeamName,
    this.followers = 0,
    this.following = 0,
    this.badgeIds = const [],
    this.achievementIds = const [],
    this.matchesPlayed = 0,
    this.matchesScored = 0,
    this.tournamentsOrganized = 0,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.deletedAt,
    this.deletedBy,
    this.adminRole,
    this.onboardingCompleted = false,
  });

  final String id;
  final String email;
  final String name;
  final String displayName;

  /// Prefer displayName; fall back to name local-part.
  final String username;
  final String? phoneNumber;
  final String? photoUrl;
  final String? coverUrl;
  final String? playerId;
  final String bio;
  final String country;
  final String stateProvince;
  final String city;
  final String? gender;
  final DateTime? dateOfBirth;

  /// Mobile cricket role (player/scorer/organizer/viewer/…).
  final String mobileRole;

  final UserAccountStatus accountStatus;
  final bool adminVerified;
  final String? organizationId;
  final String? currentTeamId;
  final String? currentTeamName;
  final int followers;
  final int following;
  final List<String> badgeIds;
  final List<String> achievementIds;
  final int matchesPlayed;
  final int matchesScored;
  final int tournamentsOrganized;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  /// Soft-delete metadata (set only when [accountStatus] is [UserAccountStatus.deleted]).
  final DateTime? deletedAt;
  final String? deletedBy;

  /// From additive `admin_users` if present.
  final AdminRole? adminRole;

  final bool onboardingCompleted;

  bool get isSoftDeleted => accountStatus.isSoftDeleted;

  String get effectiveName {
    if (name.trim().isNotEmpty) return name.trim();
    if (displayName.trim().isNotEmpty) return displayName.trim();
    if (username.trim().isNotEmpty) return username.trim();
    if (email.contains('@')) return email.split('@').first;
    return 'Unknown user';
  }

  String get initials {
    final parts =
        effectiveName.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get roleLabel {
    if (adminRole != null) return adminRole!.label;
    if (mobileRole.isNotEmpty) {
      return mobileRole[0].toUpperCase() + mobileRole.substring(1);
    }
    return 'User';
  }

  bool get isPlatformStaff => adminRole != null;

  factory ManagedUser.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
    AdminRole? adminRole,
    String? currentTeamName,
  }) {
    final location = map['location'];
    final loc = location is Map ? Map<String, dynamic>.from(location) : const {};
    final stats = map['stats'];
    final statsMap = stats is Map ? Map<String, dynamic>.from(stats) : const {};
    final social = map['socialStats'];
    final socialMap =
        social is Map ? Map<String, dynamic>.from(social) : const {};

    final displayName = (map['displayName'] as String?)?.trim() ?? '';
    final name = (map['name'] as String?)?.trim() ?? '';
    final username = (map['username'] as String?)?.trim().isNotEmpty == true
        ? (map['username'] as String).trim()
        : (displayName.isNotEmpty
            ? displayName
            : (name.isNotEmpty ? name : (map['email'] as String? ?? '')));

    return ManagedUser(
      id: id,
      email: (map['email'] as String?) ?? '',
      name: name,
      displayName: displayName,
      username: username,
      phoneNumber: (map['mobile'] as String?) ?? (map['phoneNumber'] as String?),
      photoUrl: map['photoUrl'] as String?,
      coverUrl: (map['coverUrl'] as String?) ?? (map['coverPhotoUrl'] as String?),
      playerId: (map['playerId'] as String?) ?? (map['cfPlayerId'] as String?),
      bio: (map['bio'] as String?) ?? '',
      country: (map['country'] as String?)?.isNotEmpty == true
          ? map['country'] as String
          : (loc['country'] as String?) ?? '',
      stateProvince: (loc['stateProvince'] as String?) ??
          (loc['state'] as String?) ??
          '',
      city: (loc['city'] as String?) ?? '',
      gender: map['gender'] as String?,
      dateOfBirth: _parseDate(map['dob'] ?? map['dateOfBirth']),
      mobileRole: (map['role'] as String?) ?? '',
      accountStatus: UserAccountStatus.parse(
        (map['accountStatus'] as String?) ?? (map['status'] as String?),
      ),
      adminVerified: map['adminVerified'] as bool? ?? false,
      organizationId: map['organizationId'] as String?,
      currentTeamId: map['teamId'] as String? ?? map['currentTeamId'] as String?,
      currentTeamName: currentTeamName,
      followers: (socialMap['followers'] as num?)?.toInt() ??
          (socialMap['followerCount'] as num?)?.toInt() ??
          0,
      following: (socialMap['following'] as num?)?.toInt() ??
          (socialMap['followingCount'] as num?)?.toInt() ??
          0,
      badgeIds: List<String>.from(map['badgeIds'] as List? ?? const []),
      achievementIds:
          List<String>.from(map['achievementIds'] as List? ?? const []),
      matchesPlayed: (statsMap['matchesPlayed'] as num?)?.toInt() ?? 0,
      matchesScored: (statsMap['matchesScored'] as num?)?.toInt() ?? 0,
      tournamentsOrganized:
          (statsMap['tournamentsOrganized'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      lastLoginAt: _parseDate(map['lastLoginAt']),
      deletedAt: _parseDate(map['deletedAt']),
      deletedBy: map['deletedBy'] as String?,
      adminRole: adminRole,
      onboardingCompleted: map['onboardingCompleted'] as bool? ??
          ((map['playerId'] as String?)?.isNotEmpty ?? false),
    );
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

  @override
  List<Object?> get props => [id, email, accountStatus, adminRole, updatedAt];
}

class UserPageResult {
  const UserPageResult({
    required this.users,
    required this.hasMore,
    this.cursor,
  });

  final List<ManagedUser> users;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}

class UserSummaryStats {
  const UserSummaryStats({
    this.total = 0,
    this.verified = 0,
    this.online = 0,
    this.newToday = 0,
    this.suspended = 0,
    this.admins = 0,
  });

  final int total;
  final int verified;
  final int online;
  final int newToday;
  final int suspended;
  final int admins;
}
