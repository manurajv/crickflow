import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/match_media_naming.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  final _picker = ImagePicker();

  Future<String?> pickAndUploadTeamLogo(String teamId) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return uploadTeamLogo(teamId, File(picked.path));
  }

  Future<String> uploadTeamLogo(String teamId, File file) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final ref = _storage.ref().child('teams/$teamId/logo_$uid.jpg');
    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<String?> pickAndUploadPlayerPhoto(String playerId) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return uploadPlayerPhoto(playerId, File(picked.path));
  }

  Future<String> uploadPlayerPhoto(String playerId, File file) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final ref = _storage.ref().child('players/$playerId/photo_$uid.jpg');
    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<String> uploadUserProfilePhoto(String userId, File file) async {
    final ref = _storage.ref().child('users/$userId/profile.jpg');
    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  /// Team invite QR — `teams/{teamId}/invite_qr.png`
  Future<String> uploadTeamQr(String teamId, Uint8List pngBytes) async {
    final ref = _storage.ref().child('teams/$teamId/invite_qr.png');
    await ref.putData(
      pngBytes,
      SettableMetadata(contentType: 'image/png'),
    );
    return ref.getDownloadURL();
  }

  /// Picks image or video for match setup; [mediaCode] must be CM1, CM2, …
  Future<({File file, bool isVideo})?> pickMatchMedia({
    ImageSource source = ImageSource.gallery,
    bool preferVideo = false,
  }) async {
    if (preferVideo) {
      final video = await _picker.pickVideo(source: source);
      if (video == null) return null;
      return (file: File(video.path), isVideo: true);
    }
    final image = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 88,
    );
    if (image == null) return null;
    return (file: File(image.path), isVideo: false);
  }

  /// Uploads to `matches/{matchId}/media/CM{n}.jpg` (or .mp4).
  Future<String> uploadMatchMedia({
    required String matchId,
    required String mediaCode,
    required File file,
    bool isVideo = false,
  }) async {
    if (!mediaCode.startsWith(MatchMediaNaming.prefix)) {
      throw ArgumentError('Media code must be CM1, CM2, … got $mediaCode');
    }
    final ext = isVideo ? 'mp4' : 'jpg';
    final contentType = isVideo ? 'video/mp4' : 'image/jpeg';
    final ref = _storage.ref().child('matches/$matchId/media/$mediaCode.$ext');
    await ref.putFile(
      file,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'mediaCode': mediaCode,
          'originalName': '$mediaCode.$ext',
        },
      ),
    );
    return ref.getDownloadURL();
  }
}
