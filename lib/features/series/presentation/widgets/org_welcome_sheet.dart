import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import 'org_welcome_prefs.dart';

/// Professional welcome tip for org owners/admins after create (and first open).
Future<void> showOrgWelcomeSheet(
  BuildContext context, {
  required String seriesId,
  required String uid,
  required String orgLabel,
}) async {
  final prefs = OrgWelcomePrefs(await SharedPreferences.getInstance());
  if (!context.mounted) return;

  final neverAsk = ValueNotifier<bool>(false);
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final cf = ctx.cf;
      final theme = Theme.of(ctx);
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimens.spaceLg,
              AppDimens.spaceSm,
              AppDimens.spaceLg,
              AppDimens.spaceLg + MediaQuery.paddingOf(ctx).bottom,
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
                  child: Icon(
                    Icons.celebration_outlined,
                    size: 32,
                    color: cf.accent,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  'Welcome to your $orgLabel',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cf.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Set who can start or propose matches and tournaments, '
                  'whether requests need approval, and walk-in players — '
                  'all in Settings › Permissions.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cf.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: neverAsk.value,
                  onChanged: (v) => setState(() => neverAsk.value = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    "Don't show this again",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cf.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                SizedBox(
                  width: double.infinity,
                  height: AppDimens.buttonHeight,
                  child: FilledButton(
                    key: const Key('org_welcome_go_settings'),
                    onPressed: () => Navigator.pop(ctx, 'settings'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cf.accent,
                      foregroundColor: cf.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Go to settings'),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                SizedBox(
                  width: double.infinity,
                  height: AppDimens.buttonHeight,
                  child: TextButton(
                    key: const Key('org_welcome_later'),
                    onPressed: () => Navigator.pop(ctx, 'later'),
                    child: Text(
                      'Later',
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
        },
      );
    },
  );

  final skip = neverAsk.value;
  neverAsk.dispose();
  await prefs.dismiss(uid: uid, seriesId: seriesId, neverAskAgain: skip);

  if (!context.mounted) return;
  if (result == 'settings') {
    context.push('/series/$seriesId/settings');
  }
}

/// Decide and show the welcome tip when appropriate. Safe to call repeatedly.
Future<void> maybeShowOrgWelcome(
  BuildContext context, {
  required String seriesId,
  required String uid,
  required String orgLabel,
  bool forceFromCreate = false,
}) async {
  if (uid.isEmpty) return;
  final prefs = OrgWelcomePrefs(await SharedPreferences.getInstance());
  if (!prefs.shouldShow(
    uid: uid,
    seriesId: seriesId,
    forceFromCreate: forceFromCreate,
  )) {
    return;
  }
  if (!context.mounted) return;
  await showOrgWelcomeSheet(
    context,
    seriesId: seriesId,
    uid: uid,
    orgLabel: orgLabel,
  );
}
