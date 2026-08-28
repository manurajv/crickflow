import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/utils/phone_auth_utils.dart';
import '../models/register_player_models.dart';
import '../models/user_model.dart';
import '../repositories/player_repository.dart';
import '../repositories/user_repository.dart';
import '../services/register_player_session.dart';

class RegisterPlayerRepository {
  RegisterPlayerRepository({
    FirebaseFunctions? functions,
    UserRepository? userRepository,
    PlayerRepository? playerRepository,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _users = userRepository ?? UserRepository(),
        _players = playerRepository ?? PlayerRepository();

  final FirebaseFunctions _functions;
  final UserRepository _users;
  final PlayerRepository _players;

  Future<ExistingPlayerMatch?> lookupByPhone(String phoneE164) async {
    try {
      final callable = _functions.httpsCallable('lookupPlayerByPhone');
      final result = await callable.call({'phoneNumber': phoneE164});
      final raw = result.data;
      if (raw is! Map) return _clientLookup(phoneE164);
      final data = Map<String, dynamic>.from(raw);
      if (data['exists'] != true) return null;
      return ExistingPlayerMatch.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unimplemented') {
        return _clientLookup(phoneE164);
      }
      rethrow;
    } catch (_) {
      return _clientLookup(phoneE164);
    }
  }

  Future<ExistingPlayerMatch?> _clientLookup(String phoneE164) async {
    final hits = await _users.searchScorers(phoneE164);
    if (hits.isEmpty) return null;
    final user = hits.first;
    final player = await _players.getPlayerByUserId(user.id);
    return ExistingPlayerMatch(
      uid: user.id,
      playerDocId: player?.id ?? user.id,
      playerId: user.playerId ?? player?.playerId,
      displayName: player?.name ?? user.effectiveName,
      photoUrl: player?.photoUrl ?? user.photoUrl,
      onboardingCompleted: user.onboardingCompleted,
    );
  }

  /// Sends SMS via the **default** [FirebaseAuth] (Play Integrity / reCAPTCHA
  /// work reliably there). The resulting credential is applied only to
  /// [RegisterPlayerSession.auth] so the registrar stays signed in.
  Future<void> sendOtp({
    required RegisterPlayerSession session,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException e) onError,
    required Future<void> Function() onAutoVerified,
  }) async {
    session.assertRegistrarUnchanged();

    // Secondary-app verifyPhoneNumber often fails reCAPTCHA init and burns
    // SMS attempts → Firebase device block (17010). Use default Auth to send.
    final smsAuth = FirebaseAuth.instance;
    await smsAuth.setLanguageCode('en');
    await smsAuth.verifyPhoneNumber(
      phoneNumber: session.phoneE164,
      forceResendingToken: session.resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Never sign in on default Auth — that would replace the registrar.
        await session.auth.signInWithCredential(credential);
        session.assertRegistrarUnchanged();
        await onAutoVerified();
      },
      verificationFailed: onError,
      codeSent: (verificationId, resendToken) {
        session.verificationId = verificationId;
        session.resendToken = resendToken;
        onCodeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        session.verificationId ??= verificationId;
      },
    );
    session.assertRegistrarUnchanged();
  }

  Future<UserModel> verifyOtp({
    required RegisterPlayerSession session,
    required String smsCode,
  }) async {
    session.assertRegistrarUnchanged();
    final verificationId = session.verificationId;
    if (verificationId == null) {
      throw FirebaseAuthException(
        code: 'missing-verification-id',
        message: PhoneAuthUtils.friendlyAuthError('session-expired'),
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    await session.auth.signInWithCredential(credential);
    session.assertRegistrarUnchanged();
    final user = session.auth.currentUser;
    if (user == null) {
      throw StateError('Could not create the player account.');
    }
    return session.authRepository.ensureProfileForAuthUser(user);
  }

  Future<PlayerInviteCreated> createInvite({
    String? phoneE164,
    String? displayName,
    PlayerInviteType inviteType = PlayerInviteType.either,
  }) async {
    try {
      final callable = _functions.httpsCallable('createPlayerInvite');
      final result = await callable.call({
        if (phoneE164 != null && phoneE164.trim().isNotEmpty)
          'phoneNumber': phoneE164.trim(),
        if (displayName != null && displayName.trim().isNotEmpty)
          'displayName': displayName.trim(),
        'inviteType': inviteType.apiValue,
      });
      final raw = result.data;
      if (raw is! Map) {
        throw StateError('Could not create the invite');
      }
      final data = Map<String, dynamic>.from(raw);
      if (data['exists'] == true) {
        throw FirebaseFunctionsException(
          code: 'already-exists',
          message: 'This number already has a CrickFlow account',
        );
      }
      final url = data['url'] as String?;
      final inviteId = data['inviteId'] as String?;
      if (url == null || inviteId == null) {
        throw StateError('Could not create the invite');
      }
      return PlayerInviteCreated(
        inviteId: inviteId,
        url: url,
        expiresAt: data['expiresAt'] as String? ?? '',
        reused: data['reused'] == true,
        inviteType: PlayerInviteType.fromApi(data['inviteType'] as String?),
      );
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseFunctionsException(
        code: e.code,
        message: _friendlyFunctionsMessage(e),
      );
    }
  }

  Future<PlayerInvitePreview?> getInvite(String inviteId) async {
    final snap = await FirebaseFirestore.instance
        .collection('player_invites')
        .doc(inviteId)
        .get();
    if (!snap.exists) return null;
    return PlayerInvitePreview.fromMap(
      snap.id,
      Map<String, dynamic>.from(snap.data() ?? {}),
    );
  }

  Future<void> acceptInvite(String inviteId) async {
    try {
      final callable = _functions.httpsCallable('acceptPlayerInvite');
      await callable.call({'inviteId': inviteId});
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseFunctionsException(
        code: e.code,
        message: _friendlyFunctionsMessage(e),
      );
    }
  }

  String _friendlyFunctionsMessage(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'already-exists':
        return 'This number already has a CrickFlow account';
      case 'resource-exhausted':
        return e.message ??
            'You have too many pending invites. Wait for some to be accepted.';
      case 'permission-denied':
        return e.message ??
            'Sign in with Google or the invited mobile number to accept this invite';
      case 'failed-precondition':
        return e.message ?? 'This invite is no longer active';
      case 'not-found':
        return 'This invite link is not valid';
      case 'unauthenticated':
        return 'Sign in required';
      default:
        return e.message ?? 'Something went wrong. Try again.';
    }
  }

  Future<void> stampAudit({
    required String newUserId,
    required String phoneE164,
  }) async {
    try {
      final callable = _functions.httpsCallable('stampProxyPlayerRegistration');
      await callable.call({
        'newUserId': newUserId,
        'phoneNumber': phoneE164,
      });
    } catch (_) {
      // Profile is already owned by the new player; audit stamp is best-effort.
    }
  }
}
