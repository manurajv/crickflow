import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';
import '../../data/models/lineup_player.dart';
import 'lineup_player_avatar.dart';
import 'scoring_ui_kit.dart';

/// Searchable fielder picker from the bowling squad.
class FielderPickerSheet extends StatefulWidget {
  const FielderPickerSheet({
    super.key,
    required this.title,
    required this.players,
    required this.scrollController,
    this.excludeIds = const {},
    this.currentWicketKeeperId,
  });

  final String title;
  final List<LineupPlayer> players;
  final ScrollController scrollController;
  final Set<String> excludeIds;
  /// When set, this player shows a gloves badge (current keeper).
  final String? currentWicketKeeperId;

  static Future<LineupPlayer?> show(
    BuildContext context, {
    required String title,
    required List<LineupPlayer> players,
    Set<String> excludeIds = const {},
    String? currentWicketKeeperId,
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
        currentWicketKeeperId: currentWicketKeeperId,
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
    final cf = context.cf;
    return Material(
      color: cf.card,
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
              style: TextStyle(color: cf.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search players',
                hintStyle: TextStyle(color: cf.textHint),
                prefixIcon: Icon(Icons.search, color: cf.textSecondary),
                filled: true,
                fillColor: cf.sectionBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cf.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cf.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cf.accent, width: 1.5),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _eligible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceMd),
                      child: Text(
                        'No players found',
                        style: TextStyle(color: cf.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                    itemCount: _eligible.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: cf.border,
                    ),
                    itemBuilder: (_, i) {
                      final p = _eligible[i];
                      final isCurrentKeeper =
                          widget.currentWicketKeeperId != null &&
                              widget.currentWicketKeeperId!.isNotEmpty &&
                              p.id == widget.currentWicketKeeperId;
                      return ListTile(
                        leading: LineupPlayerAvatar(
                          name: p.name,
                          photoUrl: p.photoUrl,
                          radius: 22,
                        ),
                        title: Text(
                          p.name,
                          style: TextStyle(color: cf.textPrimary),
                        ),
                        subtitle: isCurrentKeeper
                            ? Text(
                                'Current wicketkeeper',
                                style: TextStyle(
                                  color: cf.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                        trailing: isCurrentKeeper
                            ? Icon(
                                Icons.sports_handball_outlined,
                                color: cf.accent,
                              )
                            : null,
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
