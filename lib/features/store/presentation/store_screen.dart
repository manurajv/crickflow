import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';

/// CrickFlow PRO / monetization — roadmap screen (no IAP wired yet).
class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  static const _proFeatures = [
    ('Ad-free match viewing', Icons.block),
    ('Multi-camera PiP', Icons.picture_in_picture),
    ('Advanced analytics export', Icons.analytics),
    ('Tournament white-label scorecard', Icons.branding_watermark),
    ('Priority stream ingest', Icons.speed),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CfChromeAppBar(title: Text('CrickFlow PRO')),
      body: ListView(
        padding: AppDimens.listPadding,
        children: [
          Container(
            padding: AppDimens.cardPadding,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: AppDimens.cardRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRO for organizers',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                const Text(
                  'Premium tools for clubs, schools, and streamers. '
                  'In-app purchases will be enabled in a future update.',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Text('Included in PRO', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimens.spaceSm),
          ..._proFeatures.map(
            (f) => Card(
              margin: const EdgeInsets.only(bottom: AppDimens.spaceXs),
              child: ListTile(
                leading: Icon(f.$2, color: AppColors.gold),
                title: Text(f.$1),
                trailing: const Icon(Icons.lock_outline, size: 18),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'PRO subscriptions coming soon. Contact support@mavixas.com for early access.',
                  ),
                ),
              );
            },
            child: const Text('Notify me when available'),
          ),
        ],
      ),
    );
  }
}
