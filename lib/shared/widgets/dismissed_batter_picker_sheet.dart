import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Run-out only: pick which batter was dismissed (striker or non-striker).
Future<String?> showDismissedBatterPickerSheet(
  BuildContext context, {
  required String? strikerId,
  required String strikerName,
  required String? nonStrikerId,
  required String nonStrikerName,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Who got out?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              if (strikerId != null)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceElevated,
                    child: Icon(Icons.sports_cricket, color: AppColors.gold),
                  ),
                  title: Text(strikerName.isNotEmpty ? strikerName : 'Striker'),
                  subtitle: const Text('Current striker'),
                  onTap: () => Navigator.pop(ctx, strikerId),
                ),
              if (nonStrikerId != null)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceElevated,
                    child: Icon(Icons.person_outline, color: AppColors.gold),
                  ),
                  title:
                      Text(nonStrikerName.isNotEmpty ? nonStrikerName : 'Non-striker'),
                  subtitle: const Text('Current non-striker'),
                  onTap: () => Navigator.pop(ctx, nonStrikerId),
                ),
            ],
          ),
        ),
      );
    },
  );
}
