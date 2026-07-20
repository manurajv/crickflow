import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/enums.dart';
import '../models/user_model.dart';
import 'match_follower_repository.dart';
import 'notification_repository.dart';
import 'player_follow_repository.dart';
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
    try {
      var profile = await _userRepository.getUser(user.uid);
      profile ??= await ensureProfileForAuthUser(user);
      return profile;
    } catch (_) {
      return null;
    }
  }

  /// Creates the Firestore user doc when missing (e.g. fresh Firebase reset).
  Future<UserModel> ensureProfileForAuthUser(User user) async {
    return _ensureProfile(user);
  }

  Future<UserModel> signInWithGoogle() async {
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
    return _ensureProfile(result.user!);
  }

  Future<void> signInWithPhone({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(FirebaseAuthException e) onError,
  }) async {
    await _auth.setLanguageCode('en');
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
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(credential);
    return _ensureProfile(result.user!);
  }

  Future<UserModel> _ensureProfile(User user) async {
    var profile = await _userRepository.getUser(user.uid);
    final display = user.displayName?.trim() ?? '';

    if (profile == null) {
      profile = UserModel(
        id: user.uid,
        email: user.email ?? '',
        name: display,
        displayName: display.isNotEmpty ? display : 'CrickFlow User',
        phoneNumber: user.phoneNumber,
        mobile: user.phoneNumber,
        photoUrl: user.photoURL,
        role: UserRole.organizer,
        onboardingCompleted: false,
      );
    } else if (profile.needsPlayerOnboarding) {
      profile = profile.copyWith(
        email: profile.email.isNotEmpty ? profile.email : (user.email ?? ''),
        name: profile.name.isNotEmpty ? profile.name : display,
        displayName: profile.displayName.isNotEmpty
            ? profile.displayName
            : (display.isNotEmpty ? display : 'CrickFlow User'),
        phoneNumber: profile.phoneNumber ?? user.phoneNumber,
        mobile: profile.mobile ?? user.phoneNumber,
        photoUrl: profile.photoUrl ?? user.photoURL,
        onboardingCompleted: false,
      );
    }

    if (profile.needsPlayerOnboarding) {
      try {
        await _userRepository.upsertUser(profile);
      } catch (_) {
        // Offline — profile will sync when connectivity returns.
      }
    }
    return profile;
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    await _userRepository.clearLocalCache();
  }

  /// Deletes Firestore profile data and the Firebase Auth account.
  /// Throws [FirebaseAuthException] with code `requires-recent-login` when re-auth is needed.
  ///
  /// Checks recent login **before** deleting Firestore data so a failed Auth
  /// delete does not leave a signed-in user without a profile.
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Not signed in');
    }

    // Sensitive Auth ops require a recent sign-in; fail early before data wipe.
    final token = await user.getIdTokenResult(true);
    final authTime = token.authTime;
    if (authTime != null &&
        DateTime.now().toUtc().difference(authTime.toUtc()) >
            const Duration(minutes: 5)) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message:
            'For security, sign out, sign in again, then retry delete.',
      );
    }

    final uid = user.uid;
    await NotificationRepository().deleteAllForUser(uid);
    await MatchFollowerRepository().deleteAllForUser(uid);
    await PlayerFollowRepository().deleteAllFollowsByUser(uid);
    await NotificationPreferencesRepository().deleteTeamPrefsForUser(uid);

    final player = await PlayerRepository().getPlayerByUserId(uid);
    if (player != null) {
      await PlayerRepository().deletePlayer(player.id);
    }

    await _userRepository.deleteUser(uid);
    await user.delete();
    await _googleSignIn.signOut();
    await _userRepository.clearLocalCache();
  }
}
