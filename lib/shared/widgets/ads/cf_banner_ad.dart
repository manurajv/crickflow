import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../config/admob_config.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/services/admob_service.dart';

/// Non-intrusive banner ad for discovery surfaces only.
class CfBannerAd extends StatefulWidget {
  const CfBannerAd({
    super.key,
    this.placement = AdPlacement.home,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppDimens.spaceMd,
      vertical: AppDimens.spaceSm,
    ),
  });

  final AdPlacement placement;
  final EdgeInsetsGeometry padding;

  @override
  State<CfBannerAd> createState() => _CfBannerAdState();
}

class _CfBannerAdState extends State<CfBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AdMobService.isInitialized) {
      await AdMobService.initialize();
    }
    if (!mounted) return;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AdMobConfig.bannerAdUnitId(isAndroid: isAndroid),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad as BannerAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed (${widget.placement.name}): $error');
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    );
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: widget.padding,
      child: SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
