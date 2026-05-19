import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/enums.dart';
import '../models/user_model.dart';
import 'notification_repository.dart';
import 'player_repository.dart';
import 'user_repository.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    UserRepository? userRepository,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _userRepository = userRepository ?? UserRepository();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final UserRepository _userRepository;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserModel?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return _userRepository.getUser(user.uid);
  }

  Future<UserModel> signInWithGoogle({UserRole? intendedRole}) async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in cancelled');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return _ensureProfile(result.user!, intendedRole: intendedRole);
  }

  Future<void> signInWithPhone({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(FirebaseAuthException e) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: onError,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<UserModel> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
    UserRole? intendedRole,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(credential);
    return _ensureProfile(result.user!, intendedRole: intendedRole);
  }

  Future<UserModel> _ensureProfile(
    User user, {
    UserRole? intendedRole,
  }) async {
    var profile = await _userRepository.getUser(user.uid);
    if (profile == null) {
      final role = intendedRole ?? UserRole.organizer;
      profile = UserModel(
        id: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'CrickFlow User',
        phoneNumber: user.phoneNumber,
        photoUrl: user.photoURL,
        role: role,
      );
      await _userRepository.createUser(profile);
      if (role == UserRole.player) {
        await PlayerRepository().ensurePlayerProfileForUser(
          userId: user.uid,
          displayName: profile.displayName,
          photoUrl: profile.photoUrl,
          email: profile.email,
        );
      }
    }
    return profile;
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  /// Deletes Firestore profile data and the Firebase Auth account.
  /// Throws [FirebaseAuthException] with code `requires-recent-login` when re-auth is needed.
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Not signed in');
    }

    final uid = user.uid;
    await NotificationRepository().deleteAllForUser(uid);

    final player = await PlayerRepository().getPlayerByUserId(uid);
    if (player != null) {
      await PlayerRepository().deletePlayer(player.id);
    }

    await _userRepository.deleteUser(uid);
    await user.delete();
    await _googleSignIn.signOut();
  }
}
