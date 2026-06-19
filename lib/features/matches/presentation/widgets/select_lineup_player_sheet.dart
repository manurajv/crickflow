import 'package:flutter/material.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/lineup_player.dart';
import '../../../../shared/widgets/lineup_player_avatar.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';
import '../../../../core/theme/cf_colors.dart';

/// Pick one player from a squad list (start innings / replace).
class SelectLineupPlayerSheet extends StatelessWidget {
  const SelectLineupPlayerSheet({
    super.key,
    required this.title,
    required this.players,
    required this.scrollController,
    this.excludeIds = const {},
    this.disabledIds = const {},
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<LineupPlayer> players;
  final ScrollController scrollController;
  final Set<String> excludeIds;
  /// Player id → reason shown when the row is disabled (e.g. wicketkeeper).
  final Map<String, String> disabledIds;

  static Future<LineupPlayer?> show(
    BuildContext context, {
    required String title,
    required List<LineupPlayer> players,
    Set<String> excludeIds = const {},
    Map<String, String> disabledIds = const {},
    String? subtitle,
    double initialChildSize = 0.55,
  }) {
    return ScoringUiKit.showDraggableSheet<LineupPlayer>(
      context,
      initialChildSize: initialChildSize,
      maxChildSize: 0.9,
      builder: (ctx, controller) => SelectLineupPlayerSheet(
        title: title,
        subtitle: subtitle,
        players: players,
        scrollController: controller,
        excludeIds: excludeIds,
        disabledIds: disabledIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final visible =
        players.where((p) => !excludeIds.contains(p.id)).toList();

    return Material(
      color: cf.surface,
      child: Column(
        children: [
          ScoringSheetHeader(
            title: title,
            trailing: ScoringUiKit.sheetCloseButton(context),
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  color: cf.textSecondary,
                ),
              ),
            ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceMd),
                      child: Text(
                        'No players available',
                        style: TextStyle(color: cf.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: cf.border,
                    ),
                    itemBuilder: (_, i) {
                      final p = visible[i];
                      final disabledReason = disabledIds[p.id];
                      final disabled = disabledReason != null;
                      return ListTile(
                        enabled: !disabled,
                        leading: LineupPlayerAvatar(
                          name: p.name,
                          photoUrl: p.photoUrl,
                          radius: 24,
                          backgroundColor: disabled
                              ? cf.surface
                              : cf.sectionBackground,
                          foregroundColor: disabled
                              ? cf.textMuted
                              : cf.accent,
                        ),
                        title: Text(
                          p.name,
                          style: TextStyle(
                            color: disabled ? cf.textMuted : null,
                          ),
                        ),
                        subtitle: disabledReason != null
                            ? Text(
                                disabledReason,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cf.textMuted,
                                ),
                              )
                            : null,
                        onTap: disabled
                            ? null
                            : () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
