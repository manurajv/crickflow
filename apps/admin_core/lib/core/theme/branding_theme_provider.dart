import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/models/platform_settings.dart';
import '../constants/admin_collections.dart';
export 'branding_colors.dart';

/// Live branding from `admin_platform_settings/global`. Null when unset.
final platformBrandingProvider =
    StreamProvider<PlatformBrandingSettings?>((ref) {
  return FirebaseFirestore.instance
      .collection(AdminCollections.adminPlatformSettings)
      .doc('global')
      .snapshots()
      .map((snap) {
    if (!snap.exists) return null;
    final raw = snap.data()?['branding'];
    if (raw is! Map) return null;
    return PlatformBrandingSettings.fromMap(Map<String, dynamic>.from(raw));
  });
});
