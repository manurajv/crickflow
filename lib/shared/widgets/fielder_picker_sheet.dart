import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/lineup_player.dart';

/// Searchable fielder picker from the bowling squad.
class FielderPickerSheet extends StatefulWidget {
  const FielderPickerSheet({
    super.key,
    required this.title,
    required this.players,
    this.excludeIds = const {},
  });

  final String title;
  final List<LineupPlayer> players;
  final Set<String> excludeIds;

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
      builder: (ctx) => FielderPickerSheet(
        title: title,
        players: players,
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
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) {
        return Material(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            children: [
              AppBar(
                title: Text(widget.title),
                backgroundColor: AppColors.surface,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
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
                        controller: controller,
                        itemCount: _eligible.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = _eligible[i];
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
                            onTap: () => Navigator.pop(context, p),
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
