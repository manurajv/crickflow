import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'organization_enums.dart';

/// Admin view of Firestore `organizations/{id}` (admin-native collection).
///
/// Additive — never overwrites mobile-owned collections.
/// Designed as the root entity for future billing, white-label, and
/// multi-tenant architecture.
class ManagedOrganization extends Equatable {
  const ManagedOrganization({
    required this.id,
    required this.name,
    this.slug = '',
    this.type = ManagedOrganizationType.other,
    this.status = ManagedOrganizationStatus.active,
    this.recordStatus = AdminOrganizationRecordStatus.active,
    // Contact
    this.email = '',
    this.phone = '',
    this.website = '',
    // Location
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.address = '',
    // Profile
    this.logoUrl,
    this.bannerUrl,
    this.description = '',
    this.establishedYear,
    this.registrationNumber = '',
    // Admin
    this.primaryAdminUid,
    this.primaryAdminEmail,
    this.adminCount = 0,
    this.featured = false,
    // Timestamps & audit
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.deletedAt,
    this.deletedBy,
    this.approvedAt,
    this.approvedBy,
    this.verifiedAt,
    this.verifiedBy,
  });

  final String id;
  final String name;
  final String slug;
  final ManagedOrganizationType type;
  final ManagedOrganizationStatus status;
  final AdminOrganizationRecordStatus recordStatus;
  // Contact
  final String email;
  final String phone;
  final String website;
  // Location
  final String country;
  final String stateProvince;
  final String city;
  final String address;
  // Profile
  final String? logoUrl;
  final String? bannerUrl;
  final String description;
  final int? establishedYear;
  final String registrationNumber;
  // Admin
  final String? primaryAdminUid;
  final String? primaryAdminEmail;
  final int adminCount;
  final bool featured;
  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final DateTime? deletedAt;
  final String? deletedBy;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? verifiedAt;
  final String? verifiedBy;

  bool get isSoftDeleted => recordStatus.isSoftDeleted;
  bool get isArchived => recordStatus.isArchived;

  bool get hasPrimaryAdmin =>
      primaryAdminUid != null && primaryAdminUid!.isNotEmpty;

  bool get isPending => status == ManagedOrganizationStatus.pending;
  bool get isVerified => status == ManagedOrganizationStatus.verified;
  bool get isApproved => status.isApproved;

  ManagedOrganizationStatus get displayStatus =>
      ManagedOrganizationStatus.derive(
        recordStatus: recordStatus,
        status: status.wireValue,
      );

  String get locationLabel {
    final parts = [
      if (city.isNotEmpty) city,
      if (stateProvince.isNotEmpty) stateProvince,
      if (country.isNotEmpty) country,
    ];
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  String get shortLabel {
    final parts = <String>[type.shortLabel];
    if (slug.isNotEmpty) parts.add(slug);
    return parts.join(' · ');
  }

  static String slugify(String name) {
    final cleaned = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? 'org' : cleaned;
  }

  factory ManagedOrganization.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final recordStatus = AdminOrganizationRecordStatus.parse(
      map['recordStatus'] as String?,
    );

    return ManagedOrganization(
      id: id,
      name: (map['name'] as String?)?.trim() ?? '',
      slug: (map['slug'] as String?)?.trim() ?? '',
      type: ManagedOrganizationType.parse(map['type'] as String?),
      status: ManagedOrganizationStatus.parse(map['status'] as String?),
      recordStatus: recordStatus,
      email: (map['email'] as String?)?.trim() ?? '',
      phone: (map['phone'] as String?)?.trim() ?? '',
      website: (map['website'] as String?)?.trim() ?? '',
      country: (map['country'] as String?)?.trim() ?? '',
      stateProvince: (map['stateProvince'] as String?)?.trim() ?? '',
      city: (map['city'] as String?)?.trim() ?? '',
      address: (map['address'] as String?)?.trim() ?? '',
      logoUrl: (map['logoUrl'] as String?)?.trim(),
      bannerUrl: (map['bannerUrl'] as String?)?.trim(),
      description: (map['description'] as String?)?.trim() ?? '',
      establishedYear: (map['establishedYear'] as num?)?.toInt(),
      registrationNumber:
          (map['registrationNumber'] as String?)?.trim() ?? '',
      primaryAdminUid: (map['primaryAdminUid'] as String?)?.trim(),
      primaryAdminEmail: (map['primaryAdminEmail'] as String?)?.trim(),
      adminCount: (map['adminCount'] as num?)?.toInt() ?? 0,
      featured: (map['featured'] as bool?) ?? false,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      createdBy: map['createdBy'] as String?,
      deletedAt: _parseDate(map['deletedAt']),
      deletedBy: map['deletedBy'] as String?,
      approvedAt: _parseDate(map['approvedAt']),
      approvedBy: map['approvedBy'] as String?,
      verifiedAt: _parseDate(map['verifiedAt']),
      verifiedBy: map['verifiedBy'] as String?,
    );
  }

  Map<String, dynamic> toCreateMap({required String createdBy}) {
    final now = DateTime.now().toIso8601String();
    return {
      'name': name.trim(),
      'slug': slug.trim().isEmpty ? slugify(name) : slug.trim(),
      'type': type.wireValue,
      'status': (status == ManagedOrganizationStatus.deleted ||
              status == ManagedOrganizationStatus.archived)
          ? ManagedOrganizationStatus.pending.wireValue
          : status.wireValue,
      'recordStatus': AdminOrganizationRecordStatus.active.wireValue,
      'email': email.trim(),
      'phone': phone.trim(),
      'website': website.trim(),
      'country': country.trim(),
      'stateProvince': stateProvince.trim(),
      'city': city.trim(),
      'address': address.trim(),
      'logoUrl': logoUrl?.trim(),
      'bannerUrl': bannerUrl?.trim(),
      'description': description.trim(),
      'establishedYear': establishedYear,
      'registrationNumber': registrationNumber.trim(),
      'primaryAdminUid': primaryAdminUid,
      'primaryAdminEmail': primaryAdminEmail,
      'adminCount': 0,
      'featured': false,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': createdBy,
    };
  }

  ManagedOrganization copyWith({
    String? name,
    String? slug,
    ManagedOrganizationType? type,
    ManagedOrganizationStatus? status,
    AdminOrganizationRecordStatus? recordStatus,
    String? email,
    String? phone,
    String? website,
    String? country,
    String? stateProvince,
    String? city,
    String? address,
    String? logoUrl,
    String? bannerUrl,
    String? description,
    int? establishedYear,
    String? registrationNumber,
    String? primaryAdminUid,
    String? primaryAdminEmail,
    int? adminCount,
    bool? featured,
  }) {
    return ManagedOrganization(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      type: type ?? this.type,
      status: status ?? this.status,
      recordStatus: recordStatus ?? this.recordStatus,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      country: country ?? this.country,
      stateProvince: stateProvince ?? this.stateProvince,
      city: city ?? this.city,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      description: description ?? this.description,
      establishedYear: establishedYear ?? this.establishedYear,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      primaryAdminUid: primaryAdminUid ?? this.primaryAdminUid,
      primaryAdminEmail: primaryAdminEmail ?? this.primaryAdminEmail,
      adminCount: adminCount ?? this.adminCount,
      featured: featured ?? this.featured,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      deletedAt: deletedAt,
      deletedBy: deletedBy,
      approvedAt: approvedAt,
      approvedBy: approvedBy,
      verifiedAt: verifiedAt,
      verifiedBy: verifiedBy,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props =>
      [id, name, status, recordStatus, adminCount, featured, updatedAt];
}

// ─── Result / stats ──────────────────────────────────────────────────────────

class OrganizationPageResult {
  const OrganizationPageResult({
    required this.organizations,
    required this.hasMore,
    this.cursor,
  });

  final List<ManagedOrganization> organizations;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}

class OrganizationSummaryStats {
  const OrganizationSummaryStats({
    this.total = 0,
    this.active = 0,
    this.pending = 0,
    this.verified = 0,
    this.inactive = 0,
    this.suspended = 0,
    this.archived = 0,
    this.boards = 0,
    this.clubs = 0,
    this.academies = 0,
    this.withAdmin = 0,
  });

  final int total;
  final int active;
  final int pending;
  final int verified;
  final int inactive;
  final int suspended;
  final int archived;
  final int boards;
  final int clubs;
  final int academies;
  final int withAdmin;
}

/// Counts of resources scoped to an organization.
class OrganizationRelatedCounts {
  const OrganizationRelatedCounts({
    this.users = 0,
    this.teams = 0,
    this.tournaments = 0,
    this.matches = 0,
    this.grounds = 0,
    this.liveMatches = 0,
    this.liveStreams = 0,
    this.communityPosts = 0,
  });

  final int users;
  final int teams;
  final int tournaments;
  final int matches;
  final int grounds;
  final int liveMatches;
  final int liveStreams;
  final int communityPosts;
}
