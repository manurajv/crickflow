import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../core/utils/cf_player_id_format.dart';
import '../../../core/utils/deep_link_utils.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';

class PlayerQrScreen extends StatelessWidget {
  const PlayerQrScreen({
    super.key,
    required this.playerId,
    this.playerName,
  });

  final String playerId;
  final String? playerName;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final normalized = CfPlayerIdFormat.normalize(playerId);

    return Scaffold(
      appBar: const CfChromeAppBar(title: Text('Profile QR Code')),
      body: Center(
        child: Padding(
          padding: AppDimens.listPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (playerName != null && playerName!.isNotEmpty) ...[
                Text(
                  playerName!,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cf.textPrimary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimens.spaceSm),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cf.border),
                ),
                child: QrImageView(
                  data: normalized,
                  version: QrVersions.auto,
                  size: 220,
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
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                CfPlayerIdFormat.displayLabel(normalized),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: cf.textPrimary,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                'Scan to open this player profile in CrickFlow',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cf.textSecondary,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceXl),
              OutlinedButton.icon(
                onPressed: () => Share.share(
                  'Connect with ${playerName ?? normalized} on CrickFlow\n'
                  '${DeepLinkUtils.playerUri(normalized)}\n'
                  '${DeepLinkUtils.hostedPlayerUri(normalized)}',
                ),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
