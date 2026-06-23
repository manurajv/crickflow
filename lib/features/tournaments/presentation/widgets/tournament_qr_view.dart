import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/deep_link_utils.dart';
import '../../../../data/models/tournament_model.dart';

class TournamentQrView extends StatelessWidget {
  const TournamentQrView({
    super.key,
    required this.tournament,
    this.size = 180,
    this.showCode = true,
  });

  final TournamentModel tournament;
  final double size;
  final bool showCode;

  String get _payload =>
      DeepLinkUtils.hostedTournamentJoinUri(tournament.id).toString();

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
          child: QrImageView(
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
        if (showCode &&
            tournament.tournamentCode != null &&
            tournament.tournamentCode!.trim().isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            tournament.tournamentCode!,
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
