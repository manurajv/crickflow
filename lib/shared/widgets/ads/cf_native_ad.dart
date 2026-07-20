import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../config/admob_config.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/services/admob_service.dart';

/// Native ad slot for home / list carousels. Fails silently if unavailable.
class CfNativeAdCard extends StatefulWidget {
  const CfNativeAdCard({
    super.key,
    this.height = 140,
    this.width = 280,
  });

  final double height;
  final double width;

  @override
  State<CfNativeAdCard> createState() => _CfNativeAdCardState();
}

class _CfNativeAdCardState extends State<CfNativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({int attempt = 0}) async {
    await AdMobService.initialize();
    if (!mounted || AdMobService.isUnavailable) return;
    if (!AdMobService.isInitialized) return;

    if (attempt == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
    }

    final bg = Theme.of(context).colorScheme.surface;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    try {
      final ad = NativeAd(
        adUnitId: AdMobConfig.nativeAdUnitId(isAndroid: isAndroid),
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            setState(() {
              _ad = ad as NativeAd;
              _loaded = true;
            });
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('Native ad failed: $error');
            ad.dispose();
            final jsEngine = error.message.contains('JavascriptEngine');
            if (jsEngine && attempt < 2 && mounted) {
              Future<void>.delayed(
                const Duration(seconds: 1),
                () => _load(attempt: attempt + 1),
              );
            }
          },
        ),
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
          mainBackgroundColor: bg,
          cornerRadius: 12,
        ),
      );
      await ad.load();
    } on MissingPluginException catch (e) {
      debugPrint('Native ad skipped (plugin not linked): $e');
    } catch (e) {
      debugPrint('Native ad load error: $e');
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    if (!_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: widget.width,
      height: widget.height,
      margin: const EdgeInsets.only(right: AppDimens.spaceSm),
      decoration: BoxDecoration(
        color: cf.surface,
        borderRadius: AppDimens.cardRadius,
        border: Border.all(color: cf.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: AdWidget(ad: _ad!),
    );
  }
}
