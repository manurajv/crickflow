import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/cf_team_id_format.dart';
import '../../../../core/utils/deep_link_utils.dart';
import '../../../../data/models/team_model.dart';

/// Displays a team invite QR (from Firestore/Storage or rendered locally).
class TeamQrView extends StatelessWidget {
  const TeamQrView({
    super.key,
    required this.team,
    this.size = 220,
    this.showTeamCode = true,
  });

  final TeamModel team;
  final double size;
  final bool showTeamCode;

  String get _payload {
    final base = DeepLinkUtils.httpsTeamUri(team.id);
    if (team.teamCode == null || team.teamCode!.isEmpty) {
      return base.toString();
    }
    return base
        .replace(
          queryParameters: {'code': CfTeamIdFormat.normalize(team.teamCode!)},
        )
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cf.border),
          ),
          child: team.qrUrl != null && team.qrUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: team.qrUrl!,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  ),
                )
              : QrImageView(
                  data: _payload,
                  version: QrVersions.auto,
                  size: size,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: cf.accent,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: cf.accent,
                  ),
                ),
        ),
        if (showTeamCode &&
            team.teamCode != null &&
            team.teamCode!.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            CfTeamIdFormat.displayLabel(team.teamCode),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cf.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
          ),
        ],
      ],
    );
  }
}
