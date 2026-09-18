import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/providers.dart';

/// Resolves a Firebase uid to a display name for Orgs UI (never shows raw ids).
class SeriesUserName extends ConsumerWidget {
  const SeriesUserName(
    this.userId, {
    super.key,
    this.fallback = 'Member',
    this.style,
  });

  final String userId;
  final String fallback;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) {
      return Text(fallback, style: style);
    }
    final async = ref.watch(userProfileByIdProvider(userId));
    final name = async.when(
      data: (user) {
        if (user == null) return fallback;
        if (user.displayName.trim().isNotEmpty) return user.displayName.trim();
        if (user.name.trim().isNotEmpty) return user.name.trim();
        return fallback;
      },
      loading: () => fallback,
      error: (_, _) => fallback,
    );
    return Text(name, style: style);
  }
}

String seriesPersonLabel({
  required String? displayName,
  required String? userId,
  String fallback = 'Member',
}) {
  final name = displayName?.trim() ?? '';
  if (name.isNotEmpty) return name;
  return fallback;
}

String seriesAdminStatusLabel(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'active':
      return 'Active';
    case 'removed':
      return 'Removed';
    case 'pending':
      return 'Pending';
    case 'suspended':
      return 'Suspended';
    default:
      return status == null || status.isEmpty ? 'Active' : status;
  }
}

String seriesClubReviewLabel(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'approved':
      return 'Cleared by club admin';
    case 'rejected':
      return 'Declined by club admin';
    case 'pending':
      return 'Waiting for club admin';
    default:
      return 'Waiting for club admin';
  }
}

String seriesAuditActionLabel(String action) {
  switch (action) {
    case 'SERIES_CREATED':
      return 'Organization created';
    case 'SERIES_ADMIN_ADDED':
      return 'Admin added';
    case 'SERIES_ADMIN_REMOVED':
      return 'Admin removed';
    case 'SERIES_SETTINGS_UPDATED':
      return 'Settings updated';
    case 'SERIES_CLUB_CREATED':
      return 'Club submitted';
    case 'SERIES_CLUB_APPROVED':
      return 'Club approved';
    case 'SERIES_CLUB_REJECTED':
      return 'Club rejected';
    case 'SERIES_CLUB_ADMIN_ADDED':
      return 'Club admin added';
    case 'SERIES_CLUB_ADMIN_REMOVED':
      return 'Club admin removed';
    case 'SERIES_APPROVAL_APPROVED':
      return 'Request approved';
    case 'SERIES_APPROVAL_REJECTED':
      return 'Request rejected';
    case 'SERIES_REGISTRATION_SUBMITTED':
      return 'Registration submitted';
    case 'SERIES_PLAYER_JOIN_REQUESTED':
      return 'Join requested';
    case 'SERIES_CLUB_JOIN_CLEARED':
      return 'Join cleared by club';
    case 'SERIES_MATCH_PROPOSED':
      return 'Match proposed';
    case 'SERIES_TOURNAMENT_PROPOSED':
      return 'Tournament proposed';
    case 'SERIES_SUSPENDED':
      return 'Organization suspended';
    default:
      return action
          .replaceAll('_', ' ')
          .toLowerCase()
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
  }
}

String seriesIdentityFieldLabel(String key) {
  switch (key) {
    case 'fullName':
      return 'Full name';
    case 'crickFlowPlayerId':
      return 'CrickFlow Player ID';
    case 'dateOfBirth':
      return 'Date of birth';
    case 'nationalId':
      return 'National ID';
    case 'nationalIdDocUrl':
      return 'National ID document';
    case 'passport':
    case 'passportNumber':
      return 'Passport';
    case 'passportDocUrl':
      return 'Passport document';
    case 'phoneNumber':
      return 'Phone';
    case 'address':
      return 'Address';
    case 'profilePhotoUrl':
      return 'Profile photo';
    case 'email':
      return 'Email';
    default:
      return key
          .replaceAllMapped(
            RegExp(r'([A-Z])'),
            (m) => ' ${m.group(0)!.toLowerCase()}',
          )
          .trim()
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
  }
}

String seriesShortDate(DateTime? dt) {
  if (dt == null) return '';
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
