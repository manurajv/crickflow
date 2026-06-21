import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/constants/player_profile_constants.dart';
import '../models/user_model.dart';
import '../services/profile_update_queue_service.dart';
import '../services/storage_service.dart';
import '../services/user_profile_cache_service.dart';
import 'player_repository.dart';
import 'user_repository.dart';

class ProfileSaveResult {
  const ProfileSaveResult({
    required this.success,
    this.queuedOffline = false,
    this.errorMessage,
    this.savedUser,
  });

  final bool success;
  final bool queuedOffline;
  final String? errorMessage;
  final UserModel? savedUser;
}

class ProfileEditRepository {
  ProfileEditRepository({
    UserRepository? userRepository,
    PlayerRepository? playerRepository,
    StorageService? storageService,
    ProfileUpdateQueueService? queueService,
    UserProfileCacheService? cacheService,
    Connectivity? connectivity,
  })  : _users = userRepository ?? UserRepository(),
        _players = playerRepository ?? PlayerRepository(),
        _storage = storageService ?? StorageService(),
        _queue = queueService ?? ProfileUpdateQueueService(),
        _cache = cacheService ?? UserProfileCacheService(),
        _connectivity = connectivity ?? Connectivity();

  final UserRepository _users;
  final PlayerRepository _players;
  final StorageService _storage;
  final ProfileUpdateQueueService _queue;
  final UserProfileCacheService _cache;
  final Connectivity _connectivity;

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<ProfileSaveResult> saveProfile({
    required UserModel updated,
    File? newPhotoFile,
    bool removePhoto = false,
  }) async {
    try {
      final online = await isOnline();
      if (!online) {
        await _queue.enqueue(
          userId: updated.id,
          userMap: updated.toMap(),
          localPhotoPath: newPhotoFile?.path,
          removePhoto: removePhoto,
        );
        await _cache.cacheProfile(updated);
        return ProfileSaveResult(
          success: true,
          queuedOffline: true,
          savedUser: updated,
        );
      }

      var profile = updated;
      if (removePhoto) {
        profile = profile.copyWith(photoUrl: null);
      } else if (newPhotoFile != null) {
        final url = await _storage.uploadUserProfilePhoto(
          updated.id,
          newPhotoFile,
        );
        profile = profile.copyWith(photoUrl: url);
      }

      await _users.updateUser(profile);
      await _syncPlayerDoc(profile);
      await _cache.cacheProfile(profile);
      await _queue.clear(profile.id);

      return ProfileSaveResult(success: true, savedUser: profile);
    } catch (e) {
      return ProfileSaveResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<ProfileSaveResult?> flushPending(String userId) async {
    final pending = await _queue.dequeue(userId);
    if (pending == null) return null;

    try {
      var profile = UserModel.fromMap(userId, pending.userMap);
      if (pending.removePhoto) {
        profile = profile.copyWith(photoUrl: null);
      } else if (pending.localPhotoPath != null &&
          pending.localPhotoPath!.isNotEmpty) {
        final file = File(pending.localPhotoPath!);
        if (file.existsSync()) {
          final url = await _storage.uploadUserProfilePhoto(userId, file);
          profile = profile.copyWith(photoUrl: url);
        }
      }

      await _users.updateUser(profile);
      await _syncPlayerDoc(profile);
      await _cache.cacheProfile(profile);
      return ProfileSaveResult(success: true, savedUser: profile);
    } catch (e) {
      await _queue.enqueue(
        userId: userId,
        userMap: pending.userMap,
        localPhotoPath: pending.localPhotoPath,
        removePhoto: pending.removePhoto,
      );
      return ProfileSaveResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _syncPlayerDoc(UserModel profile) async {
    final player = await _players.getPlayerByUserId(profile.id);
    if (player == null) {
      await _players.ensurePlayerProfileForUser(
        userId: profile.id,
        displayName: profile.displayName,
        fullName: profile.name,
        photoUrl: profile.photoUrl,
        email: profile.email,
        playerId: profile.playerId,
      );
      return;
    }

    final batting = profile.battingStyle != null
        ? _battingLabel(profile.battingStyle!)
        : player.battingStyle;
    final bowling =
        profile.bowlingStyle?.label ?? player.bowlingStyle;

    await _players.updatePlayer(
      player.copyWith(
        name: profile.displayName.isNotEmpty ? profile.displayName : profile.name,
        fullName: profile.name,
        photoUrl: profile.photoUrl,
        role: profile.playerRole?.label ?? player.role,
        battingStyle: batting,
        bowlingStyle: bowling,
        location: profile.location,
        playerId: profile.playerId,
        jerseyNumber: profile.jerseyNumber,
      ),
    );
  }

  static String _battingLabel(PlayerBattingStyle style) => switch (style) {
        PlayerBattingStyle.rightHandBatsman => 'Right Hand Bat',
        PlayerBattingStyle.leftHandBatsman => 'Left Hand Bat',
      };
}
