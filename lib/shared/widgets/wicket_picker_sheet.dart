import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';

/// Bottom sheet to pick dismissal type before recording a wicket.
Future<WicketType?> showWicketPickerSheet(BuildContext context) {
  return showModalBottomSheet<WicketType>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(AppDimens.spaceMd),
            child: Text(
              'Wicket type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          ...WicketType.values.map((type) {
            return ListTile(
              leading: const Icon(Icons.sports_cricket, color: AppColors.accentRed),
              title: Text(_label(type)),
              onTap: () => Navigator.pop(ctx, type),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

String _label(WicketType type) {
  switch (type) {
    case WicketType.bowled:
      return 'Bowled';
    case WicketType.caught:
      return 'Caught';
    case WicketType.lbw:
      return 'LBW';
    case WicketType.runOut:
      return 'Run out';
    case WicketType.stumped:
      return 'Stumped';
    case WicketType.hitWicket:
      return 'Hit wicket';
    case WicketType.retired:
      return 'Retired';
    case WicketType.other:
      return 'Other';
  }
}
