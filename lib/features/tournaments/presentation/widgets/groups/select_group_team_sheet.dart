import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../data/models/tournament_model.dart';

/// Bottom sheet to pick a tournament team to assign to a group.
Future<String?> showSelectGroupTeamSheet({
  required BuildContext context,
  required TournamentModel tournament,
  required List<String> teamIds,
  String title = 'Select team',
}) {
  if (teamIds.isEmpty) return Future.value(null);
  if (teamIds.length == 1) return Future.value(teamIds.first);

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      String teamName(String id) {
        return tournament.pointsTable
                .where((e) => e.teamId == id)
                .firstOrNull
                ?.teamName ??
            id;
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: AppDimens.screenPadding,
              child: Text(
                title,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: teamIds.length,
                itemBuilder: (_, i) {
                  final id = teamIds[i];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.groups_outlined, size: 20),
                    ),
                    title: Text(teamName(id)),
                    onTap: () => Navigator.pop(ctx, id),
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
