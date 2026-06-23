import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../shared/widgets/cf_button.dart';

/// Confirmation bottom sheet for tournament team actions (approve, reject, remove).
Future<bool> showTournamentTeamConfirmSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final cf = ctx.cf;
      return Padding(
        padding: EdgeInsets.only(
          left: AppDimens.spaceMd,
          right: AppDimens.spaceMd,
          top: AppDimens.spaceMd,
          bottom: MediaQuery.paddingOf(ctx).bottom + AppDimens.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                decoration: BoxDecoration(
                  color: cf.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              title,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              message,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            CfButton(
              label: confirmLabel,
              isGold: !destructive,
              isDanger: destructive,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            CfButton(
              label: 'Cancel',
              isOutlined: true,
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}

/// Success / info sheet after adding a team from the organizer flow.
Future<void> showTournamentTeamAddedSheet({
  required BuildContext context,
  required String title,
  required String message,
  String sectionHint = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final cf = ctx.cf;
      return Padding(
        padding: EdgeInsets.only(
          left: AppDimens.spaceMd,
          right: AppDimens.spaceMd,
          top: AppDimens.spaceMd,
          bottom: MediaQuery.paddingOf(ctx).bottom + AppDimens.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: cf.success),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
            if (sectionHint.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                sectionHint,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                      color: cf.accent,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: AppDimens.spaceLg),
            CfButton(
              label: 'Done',
              isGold: true,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    },
  );
}
