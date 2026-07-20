import 'package:flutter/material.dart';

import '../../../config/admob_config.dart';
import '../../../core/theme/app_dimens.dart';
import 'cf_banner_ad.dart';

/// Banner sized for [Scaffold.bottomNavigationBar] — shrink-wraps so it does
/// not expand and hide the body (unlike [Center] / unbounded flex children).
class CfStickyBannerAd extends StatelessWidget {
  const CfStickyBannerAd({
    super.key,
    this.placement = AdPlacement.home,
  });

  final AdPlacement placement;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CfBannerAd(
            placement: placement,
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceXs,
              AppDimens.spaceMd,
              AppDimens.spaceXs,
            ),
          ),
        ],
      ),
    );
  }
}
