import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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
}
