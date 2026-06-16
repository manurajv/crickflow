import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/user_model.dart';
import '../../shared/providers/providers.dart';

/// Runs after successful login when the user tapped a gated action.
typedef PendingAuthCallback = Future<void> Function();

/// Stores a one-shot callback to resume the user's intended action after login.
class PendingAuthAction {
  PendingAuthAction._();

  static PendingAuthCallback? _callback;
  static String? returnPath;

  static void register({
    PendingAuthCallback? callback,
    String? path,
  }) {
    _callback = callback;
    returnPath = path;
  }

  static Future<void> runIfAny(WidgetRef ref, BuildContext context) async {
    final callback = _callback;
    _callback = null;
    final path = returnPath;
    returnPath = null;

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
  }
}

/// Whether the signed-in user may create or modify cricket data.
bool canPerformWriteActions(UserModel? profile) {
  if (profile == null) return false;
  return profile.onboardingCompleted;
}

Future<bool> _ensureOnboardingComplete(WidgetRef ref, BuildContext context) async {
  final profile = await ref.read(currentUserProfileProvider.future);
  if (profile == null) return false;
  if (profile.onboardingCompleted) return true;
  if (context.mounted) {
    context.go('/player-onboarding');
  }
  return false;
}

Future<bool> showLoginRequiredDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign in required'),
      content: const Text('Please log in to continue'),
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
Future<T?> requireAuth<T>({
  required BuildContext context,
  required WidgetRef ref,
  required Future<T?> Function() action,
  String? returnPath,
  PendingAuthCallback? onAuthenticated,
}) async {
  final uid = ref.read(authStateProvider).value?.uid;
  if (uid != null) {
    final profile = ref.read(currentUserProfileProvider).valueOrNull ??
        await ref.read(currentUserProfileProvider.future);
    if (profile != null && !profile.onboardingCompleted) {
      PendingAuthAction.register(callback: () async {
        await action();
      }, path: returnPath);
      if (context.mounted) context.go('/player-onboarding');
      return null;
    }
    return action();
  }

  final login = await showLoginRequiredDialog(context);
  if (!login || !context.mounted) return null;

  PendingAuthAction.register(
    callback: onAuthenticated ?? () async {
      await action();
    },
    path: returnPath,
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
}) async {
  await requireAuth<void>(
    context: context,
    ref: ref,
    returnPath: returnPath,
    action: () async {
      await action();
    },
  );
}
