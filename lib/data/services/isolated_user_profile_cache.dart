import '../models/user_model.dart';
import 'user_profile_cache_service.dart';

/// Does not touch the signed-in registrar's local profile cache.
class IsolatedUserProfileCache extends UserProfileCacheService {
  IsolatedUserProfileCache();

  @override
  Future<void> cacheProfile(UserModel user) async {}

  @override
  Future<UserModel?> readCachedProfile(String uid) async => null;

  @override
  Future<String?> readCachedPlayerId(String uid) async => null;

  @override
  Future<void> clear() async {}
}
