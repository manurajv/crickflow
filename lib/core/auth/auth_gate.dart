import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/user_model.dart';
import '../../shared/providers/providers.dart';
import 'sign_in_prompts.dart';
import 'sign_in_required_sheet.dart';

export 'sign_in_prompts.dart';

/// Runs after successful login when the user tapped a gated action.
typedef PendingAuthCallback = Future<void> Function();

/// Stores a one-shot callback to resume the user's intended action after login.
class PendingAuthAction {
  PendingAuthAction._();

  static PendingAuthCallback? _callback;
  static String? returnPath;
  static SignInPrompt? _prompt;

  static void register({
    PendingAuthCallback? callback,
    String? path,
    SignInPrompt? prompt,
    @Deprecated('Use prompt:') String? message,
  }) {
    _callback = callback;
    returnPath = path;
    if (prompt != null) {
      _prompt = prompt;
    } else if (message != null && message.isNotEmpty) {
      _prompt = SignInPrompt.custom(message);
    } else {
      _prompt = SignInPrompt.general;
    }
  }

  static bool get hasPending =>
      _callback != null || (returnPath != null && returnPath!.isNotEmpty);

  static SignInPrompt get prompt => _prompt ?? SignInPrompt.general;

  static String get promptMessage => prompt.message;

  static Future<void> runIfAny(WidgetRef ref, BuildContext context) async {
    final callback = _callback;
    _callback = null;
    final path = returnPath;
    returnPath = null;
    _prompt = null;

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
    _prompt = null;
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
  SignInPrompt prompt = SignInPrompt.general,
  @Deprecated('Use prompt:') String? message,
}) => showSignInRequiredSheet(
  context,
  prompt: message != null ? SignInPrompt.custom(message) : prompt,
);

Future<T?> requireAuth<T>({
  required BuildContext context,
  required WidgetRef ref,
  required Future<T?> Function() action,
  String? returnPath,
  PendingAuthCallback? onAuthenticated,
  SignInPrompt prompt = SignInPrompt.general,
  @Deprecated('Use prompt:') String? message,
  bool showDialog = true,
}) async {
  final effective = message != null ? SignInPrompt.custom(message) : prompt;
  final uid = ref.read(authStateProvider).value?.uid;
  if (uid != null) {
    final profile =
        ref.read(currentUserProfileProvider).valueOrNull ??
        await ref.read(currentUserProfileProvider.future);
    if (profile != null && profile.needsPlayerOnboarding) {
      PendingAuthAction.register(
        callback: () async {
          await action();
        },
        path: returnPath,
        prompt: effective,
      );
      if (context.mounted) context.go('/player-onboarding');
      return null;
    }
    return action();
  }

  if (showDialog) {
    final login = await showSignInRequiredSheet(context, prompt: effective);
    if (!login || !context.mounted) return null;
  } else if (!context.mounted) {
    return null;
  }

  PendingAuthAction.register(
    callback:
        onAuthenticated ??
        () async {
          await action();
        },
    path: returnPath,
    prompt: effective,
  );
  context.push('/login');
  return null;
}

Future<void> requireAuthVoid({
  required BuildContext context,
  required WidgetRef ref,
  required Future<void> Function() action,
  String? returnPath,
  SignInPrompt prompt = SignInPrompt.general,
  @Deprecated('Use prompt:') String? message,
  bool showDialog = true,
}) async {
  await requireAuth<void>(
    context: context,
    ref: ref,
    returnPath: returnPath,
    prompt: message != null ? SignInPrompt.custom(message) : prompt,
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
  SignInPrompt prompt = SignInPrompt.general,
  @Deprecated('Use prompt:') String? message,
}) => requireAuthVoid(
  context: context,
  ref: ref,
  action: action,
  returnPath: returnPath,
  showDialog: showDialog,
  prompt: message != null ? SignInPrompt.custom(message) : prompt,
);

Future<void> openLoginForGuest({
  required BuildContext context,
  String? returnPath,
  SignInPrompt prompt = SignInPrompt.general,
  @Deprecated('Use prompt:') String? message,
}) async {
  PendingAuthAction.register(
    path: returnPath,
    prompt: message != null ? SignInPrompt.custom(message) : prompt,
  );
  if (context.mounted) context.push('/login');
}
