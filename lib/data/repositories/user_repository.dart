import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.usersCollection);

  Future<UserModel?> getUser(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> createUser(UserModel user) async {
    await _col.doc(user.id).set(user.toMap());
  }

  Future<void> updateUser(UserModel user) async {
    await _col.doc(user.id).update(user.toMap());
  }

  Future<void> deleteUser(String id) async {
    await _col.doc(id).delete();
  }

  Stream<UserModel?> watchUser(String id) {
    return _col.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.id, doc.data()!);
    });
  }

  /// Search by exact email or phone (mobile).
  Future<List<UserModel>> searchByEmailOrPhone(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final results = <UserModel>[];
    final seen = <String>{};

    Future<void> addFrom(Query<Map<String, dynamic>> q) async {
      final snap = await q.limit(5).get();
      for (final doc in snap.docs) {
        if (seen.add(doc.id)) {
          results.add(UserModel.fromMap(doc.id, doc.data()));
        }
      }
    }

    if (trimmed.contains('@')) {
      await addFrom(_col.where('email', isEqualTo: trimmed.toLowerCase()));
      if (results.isEmpty) {
        await addFrom(_col.where('email', isEqualTo: trimmed));
      }
    } else {
      final digits = trimmed.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        await addFrom(_col.where('phoneNumber', isEqualTo: digits));
        if (results.isEmpty && digits != trimmed) {
          await addFrom(_col.where('phoneNumber', isEqualTo: trimmed));
        }
      }
    }

    return results;
  }
}
