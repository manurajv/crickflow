import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/user_model.dart';
import '../../shared/providers/providers.dart';

/// Shown on the login screen and the login-required dialog when a guest
/// tries an account-only action. Keep this exact string — product copy.
const String kLoginToUseThisMessage = 'Login to use this';

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
    message = prompt ?? kLoginToUseThisMessage;
  }

  /// True when the user was sent to login from a gated action.
  static bool get hasPending =>
      _callback != null || (returnPath != null && returnPath!.isNotEmpty);

  static String get promptMessage => message ?? kLoginToUseThisMessage;

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

/// Whether the signed-in user may create or modify cricket data.
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

Future<bool> showLoginRequiredDialog(
  BuildContext context, {
  String message = kLoginToUseThisMessage,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign in required'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Login'),
        ),
      ],
    ),
  );
  return result == true;
}

/// Prompts login when needed; runs [action] when authenticated and onboarded.
///
/// Prefer this (or [requireLogin] / [requireAuthVoid]) over a bare
/// `context.push('/login')` so guests always see [kLoginToUseThisMessage]
/// and can return to where they were.
Future<T?> requireAuth<T>({
  required BuildContext context,
  required WidgetRef ref,
  required Future<T?> Function() action,
  String? returnPath,
  PendingAuthCallback? onAuthenticated,
  String message = kLoginToUseThisMessage,
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
    final login = await showLoginRequiredDialog(context, message: message);
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

/// Same as [requireAuth] but for void actions (navigation, dialogs).
Future<void> requireAuthVoid({
  required BuildContext context,
  required WidgetRef ref,
  required Future<void> Function() action,
  String? returnPath,
  String message = kLoginToUseThisMessage,
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

/// Alias used at call sites: gate an action behind login with the standard
/// "Login to use this" message.
Future<void> requireLogin({
  required BuildContext context,
  required WidgetRef ref,
  required Future<void> Function() action,
  String? returnPath,
  bool showDialog = true,
}) =>
    requireAuthVoid(
      context: context,
      ref: ref,
      action: action,
      returnPath: returnPath,
      showDialog: showDialog,
    );

/// Opens the login screen for a guest without a dialog (e.g. a Sign-in button
/// that already conveys intent). Still shows [kLoginToUseThisMessage] on the
/// login screen and restores [returnPath] after success.
Future<void> openLoginForGuest({
  required BuildContext context,
  String? returnPath,
  String message = kLoginToUseThisMessage,
}) async {
  PendingAuthAction.register(path: returnPath, prompt: message);
  if (context.mounted) context.push('/login');
}
