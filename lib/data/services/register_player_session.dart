import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../config/firebase_options.dart';
import '../models/player_model.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/player_repository.dart';
import '../repositories/user_repository.dart';
import 'isolated_user_profile_cache.dart';
import 'storage_service.dart';

/// Isolated Firebase Auth/Firestore/Storage for registering another player.
///
/// SMS OTP is requested via default [FirebaseAuth] (reliable reCAPTCHA /
/// Play Integrity). The phone credential is signed in only on this named
/// app so [FirebaseAuth.instance] (the registrar) is never replaced.
class RegisterPlayerSession {
  RegisterPlayerSession._({
    required this.app,
    required this.auth,
    required this.firestore,
    required this.storage,
    required this.userRepository,
    required this.playerRepository,
    required this.storageService,
    required this.authRepository,
    required this.registrarUid,
    required this.phoneE164,
  });

  static const appName = 'registerPlayer';

  final FirebaseApp app;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final UserRepository userRepository;
  final PlayerRepository playerRepository;
  final StorageService storageService;
  final AuthRepository authRepository;
  final String registrarUid;
  final String phoneE164;

  String? verificationId;
  int? resendToken;
  UserModel? createdUser;
  PlayerModel? createdPlayer;

  static Future<RegisterPlayerSession> start({
    required String registrarUid,
    required String phoneE164,
  }) async {
    FirebaseApp app;
    try {
      app = Firebase.app(appName);
    } on FirebaseException {
      app = await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final auth = FirebaseAuth.instanceFor(app: app);
    if (auth.currentUser != null) {
      await auth.signOut();
    }

    final firestore = FirebaseFirestore.instanceFor(app: app);
    final storage = FirebaseStorage.instanceFor(app: app);
    final users = UserRepository(
      firestore: firestore,
      profileCache: IsolatedUserProfileCache(),
    );
    final players = PlayerRepository(firestore: firestore);
    final storageService = StorageService(storage: storage);
    final authRepository = AuthRepository(auth: auth, userRepository: users);

    final session = RegisterPlayerSession._(
      app: app,
      auth: auth,
      firestore: firestore,
      storage: storage,
      userRepository: users,
      playerRepository: players,
      storageService: storageService,
      authRepository: authRepository,
      registrarUid: registrarUid,
      phoneE164: phoneE164,
    );
    session.assertRegistrarUnchanged();
    return session;
  }

  void assertRegistrarUnchanged() {
    final primary = FirebaseAuth.instance.currentUser?.uid;
    if (primary != registrarUid) {
      throw StateError(
        'Registrar session changed unexpectedly. Aborting to protect your login.',
      );
    }
    final secondary = auth.currentUser?.uid;
    if (secondary != null && secondary == registrarUid) {
      throw StateError(
        'New player session collided with your account. Aborting.',
      );
    }
  }

  /// Client-owned flag only. Registrar identity is stamped by the callable.
  Future<void> writeClientRegistrationSource() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    final payload = {
      'registrationSource': 'registered_by_another_user',
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await firestore.collection('users').doc(uid).set(
          payload,
          SetOptions(merge: true),
        );
    await firestore.collection('players').doc(uid).set(
          payload,
          SetOptions(merge: true),
        );
  }

  Future<void> dispose() async {
    try {
      if (auth.currentUser != null) {
        await auth.signOut();
      }
    } catch (_) {}
    try {
      await app.delete();
    } catch (_) {}
  }
}
