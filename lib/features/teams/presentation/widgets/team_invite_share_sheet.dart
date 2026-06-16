import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/team_model.dart';
import 'team_invite_share_card.dart';

/// Bottom sheet with team QR, link, and share actions.
Future<void> showTeamInviteShareSheet(BuildContext context, TeamModel team) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(ctx).bottom + AppDimens.spaceMd,
      ),
      child: SingleChildScrollView(child: TeamInviteShareCard(team: team)),
    ),
  );
}
