import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/cf_colors.dart';
import 'auth_gate.dart';

/// Single shared guest gate UI — use via [showSignInRequiredSheet] / [requireAuth].
Future<bool> showSignInRequiredSheet(
  BuildContext context, {
  String message = kSignInToUseThisMessage,
  String title = 'Sign in required',
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SignInRequiredSheet(title: title, message: message),
  );
  return result == true;
}

class _SignInRequiredSheet extends StatelessWidget {
  const _SignInRequiredSheet({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceSm,
        AppDimens.spaceLg,
        AppDimens.spaceLg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cf.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline_rounded, size: 32, color: cf.accent),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: cf.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cf.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXl),
          SizedBox(
            width: double.infinity,
            height: AppDimens.buttonHeight,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: cf.accent,
                foregroundColor: cf.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Sign in'),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          SizedBox(
            width: double.infinity,
            height: AppDimens.buttonHeight,
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Not now',
                style: TextStyle(
                  color: cf.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
