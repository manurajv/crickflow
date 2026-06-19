import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/team_model.dart';
import 'team_invite_share_card.dart';

/// Bottom sheet with team QR, link, and share actions.
Future<void> showTeamInviteShareSheet(BuildContext context, TeamModel team) {
  final cf = context.cf;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: cf.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: AppDimens.spaceMd,
        right: AppDimens.spaceMd,
        bottom: MediaQuery.paddingOf(ctx).bottom + AppDimens.spaceMd,
      ),
      child: SingleChildScrollView(child: TeamInviteShareCard(team: team)),
    ),
  );
}
