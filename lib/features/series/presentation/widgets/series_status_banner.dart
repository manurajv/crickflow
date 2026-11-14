import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/series/series.dart';
import '../../../../domain/services/series/series_owner_actions.dart';

/// Status strip for an org that is not simply active (or always, when
/// [showWhenActive] is true, e.g. on the dashboard).
class SeriesStatusBanner extends StatelessWidget {
  const SeriesStatusBanner({
    super.key,
    required this.series,
    this.showWhenActive = false,
  });

  final SeriesModel series;
  final bool showWhenActive;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    if (series.status == SeriesStatus.active &&
        !series.platformHold &&
        !showWhenActive) {
      return const SizedBox.shrink();
    }
    final (IconData icon, Color tone, String label) = switch (series.status) {
      _ when series.platformHold => (Icons.gpp_maybe_outlined, cf.error, 'On hold'),
      SeriesStatus.active => (Icons.check_circle_outline, cf.success, 'Active'),
      SeriesStatus.draft => (Icons.edit_note_outlined, cf.info, 'Draft'),
      SeriesStatus.suspended => (Icons.pause_circle_outline, cf.error, 'Suspended'),
      SeriesStatus.archived => (Icons.inventory_2_outlined, cf.textSecondary, 'Archived'),
    };
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: cf.isLight ? 0.08 : 0.14),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: tone, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  const SeriesOwnerActions().statusMessage(series),
                  style: TextStyle(color: cf.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
