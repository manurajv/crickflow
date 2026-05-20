import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/lineup_player.dart';

/// Pick one player from a squad list (start innings / replace).
class SelectLineupPlayerSheet extends StatelessWidget {
  const SelectLineupPlayerSheet({
    super.key,
    required this.title,
    required this.players,
    required this.onSelected,
    this.excludeIds = const {},
  });

  final String title;
  final List<LineupPlayer> players;
  final Set<String> excludeIds;
  final void Function(LineupPlayer player) onSelected;

  static Future<LineupPlayer?> show(
    BuildContext context, {
    required String title,
    required List<LineupPlayer> players,
    Set<String> excludeIds = const {},
  }) {
    return showModalBottomSheet<LineupPlayer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SelectLineupPlayerSheet(
        title: title,
        players: players,
        excludeIds: excludeIds,
        onSelected: (p) => Navigator.pop(ctx, p),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eligible =
        players.where((p) => !excludeIds.contains(p.id)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) {
        return Material(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            children: [
              AppBar(
                title: Text(title),
                backgroundColor: AppColors.surface,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: eligible.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppDimens.spaceMd),
                          child: Text(
                            'No players available',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        itemCount: eligible.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = eligible[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.surfaceElevated,
                              child: Text(
                                p.name.isNotEmpty
                                    ? p.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                            title: Text(p.name),
                            onTap: () => onSelected(p),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
