import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/lineup_player.dart';
import 'scoring_ui_kit.dart';

/// Searchable fielder picker from the bowling squad.
class FielderPickerSheet extends StatefulWidget {
  const FielderPickerSheet({
    super.key,
    required this.title,
    required this.players,
    required this.scrollController,
    this.excludeIds = const {},
  });

  final String title;
  final List<LineupPlayer> players;
  final ScrollController scrollController;
  final Set<String> excludeIds;

  static Future<LineupPlayer?> show(
    BuildContext context, {
    required String title,
    required List<LineupPlayer> players,
    Set<String> excludeIds = const {},
    double initialChildSize = 0.6,
  }) {
    return ScoringUiKit.showDraggableSheet<LineupPlayer>(
      context,
      initialChildSize: initialChildSize,
      maxChildSize: 0.92,
      builder: (ctx, controller) => FielderPickerSheet(
        title: title,
        players: players,
        scrollController: controller,
        excludeIds: excludeIds,
      ),
    );
  }

  @override
  State<FielderPickerSheet> createState() => _FielderPickerSheetState();
}

class _FielderPickerSheetState extends State<FielderPickerSheet> {
  String _query = '';

  List<LineupPlayer> get _eligible => widget.players
      .where((p) => !widget.excludeIds.contains(p.id))
      .where((p) {
        if (_query.trim().isEmpty) return true;
        return p.name.toLowerCase().contains(_query.trim().toLowerCase());
      })
      .toList();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Column(
        children: [
          ScoringSheetHeader(
            title: widget.title,
            trailing: ScoringUiKit.sheetCloseButton(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              0,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search players',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _eligible.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppDimens.spaceMd),
                      child: Text(
                        'No players found',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                    itemCount: _eligible.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) {
                      final p = _eligible[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceElevated,
                          child: Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                        title: Text(p.name),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
