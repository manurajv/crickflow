import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/user_model.dart';
import '../../shared/providers/providers.dart';
import 'sign_in_required_sheet.dart';

/// Shown on the login screen banner and the shared sign-in sheet body.
const String kSignInToUseThisMessage = 'Sign in to use this';

/// Friendly sheet/dialog body when a slightly longer line fits better.
const String kPleaseSignInToContinue = 'Please sign in to continue';

/// Runs after successful login when the user tapped a gated action.
typedef PendingAuthCallback = Future<void> Function();

/// Stores a one-shot callback to resume the user's intended action after login.
class PendingAuthAction {
  PendingAuthAction._();

  static PendingAuthCallback? _callback;
  static String? returnPath;
  static String? message;

  static void register({
    PendingAuthCallback? callback,
    String? path,
    String? prompt,
  }) {
    _callback = callback;
    returnPath = path;
    message = prompt ?? kSignInToUseThisMessage;
  }

  static bool get hasPending =>
      _callback != null || (returnPath != null && returnPath!.isNotEmpty);

  static String get promptMessage => message ?? kSignInToUseThisMessage;

  static Future<void> runIfAny(WidgetRef ref, BuildContext context) async {
    final callback = _callback;
    _callback = null;
    final path = returnPath;
    returnPath = null;
    message = null;

    if (!await _ensureOnboardingComplete(ref, context)) return;

    if (callback != null) {
      await callback();
      return;
    }
    if (path != null && path.isNotEmpty && context.mounted) {
      context.go(path);
    }
  }

  static void clear() {
    _callback = null;
    returnPath = null;
    message = null;
  }
}

bool canPerformWriteActions(UserModel? profile) {
  if (profile == null) return false;
  return !profile.needsPlayerOnboarding;
}

Future<bool> _ensureOnboardingComplete(
  WidgetRef ref,
  BuildContext context,
) async {
  final profile = await ref.read(currentUserProfileProvider.future);
  if (profile == null) return false;
  if (!profile.needsPlayerOnboarding) return true;
  if (context.mounted) {
    context.go('/player-onboarding');
  }
  return false;
}

/// Opens the shared professional sign-in sheet. Returns true if the user
/// chose Sign in.
Future<bool> showLoginRequiredDialog(
  BuildContext context, {
  String message = kSignInToUseThisMessage,
}) =>
    showSignInRequiredSheet(context, message: message);

Future<T?> requireAuth<T>({
  required BuildContext context,
  required WidgetRef ref,
  required Future<T?> Function() action,
  String? returnPath,
  PendingAuthCallback? onAuthenticated,
  String message = kSignInToUseThisMessage,
  bool showDialog = true,
}) async {
  final uid = ref.read(authStateProvider).value?.uid;
  if (uid != null) {
    final profile = ref.read(currentUserProfileProvider).valueOrNull ??
        await ref.read(currentUserProfileProvider.future);
    if (profile != null && profile.needsPlayerOnboarding) {
      PendingAuthAction.register(
        callback: () async {
          await action();
        },
        path: returnPath,
        prompt: message,
      );
      if (context.mounted) context.go('/player-onboarding');
      return null;
    }
    return action();
  }

  if (showDialog) {
    final login = await showSignInRequiredSheet(context, message: message);
    if (!login || !context.mounted) return null;
  } else if (!context.mounted) {
    return null;
  }

  PendingAuthAction.register(
    callback: onAuthenticated ??
        () async {
          await action();
        },
    path: returnPath,
    prompt: message,
  );
  context.push('/login');
  return null;
}

Future<void> requireAuthVoid({
  required BuildContext context,
  required WidgetRef ref,
  required Future<void> Function() action,
  String? returnPath,
  String message = kSignInToUseThisMessage,
  bool showDialog = true,
}) async {
  await requireAuth<void>(
    context: context,
    ref: ref,
    returnPath: returnPath,
    message: message,
    showDialog: showDialog,
    action: () async {
      await action();
    },
  );
}

Future<void> requireLogin({
  required BuildContext context,
  required WidgetRef ref,
  required Future<void> Function() action,
  String? returnPath,
  bool showDialog = true,
  String message = kSignInToUseThisMessage,
}) =>
    requireAuthVoid(
      context: context,
      ref: ref,
      action: action,
      returnPath: returnPath,
      showDialog: showDialog,
      message: message,
    );

Future<void> openLoginForGuest({
  required BuildContext context,
  String? returnPath,
  String message = kSignInToUseThisMessage,
}) async {
  PendingAuthAction.register(path: returnPath, prompt: message);
  if (context.mounted) context.push('/login');
}
