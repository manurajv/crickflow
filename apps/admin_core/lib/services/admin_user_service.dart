import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/admin_collections.dart';
import '../models/admin_user.dart';

/// Reads additive `admin_users` docs. Does not write to mobile `users`.
class AdminUserService {
  AdminUserService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(AdminCollections.adminUsers).doc(uid);

  Future<AdminUser?> fetchByUid(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    try {
      return AdminUser.fromMap(uid, snap.data()!);
    } catch (_) {
      return null;
    }
  }

  Stream<AdminUser?> watchByUid(String uid) {
    return _doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      try {
        return AdminUser.fromMap(uid, snap.data()!);
      } catch (_) {
        return null;
      }
    });
  }
}
