import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/home_promotion_model.dart';
import '../../../../data/repositories/home_promotion_repository.dart';

final homePromotionRepositoryProvider = Provider(
  (ref) => HomePromotionRepository(),
);

final homePromotionsProvider =
    StreamProvider.autoDispose<List<HomePromotionModel>>((ref) {
  final link = ref.keepAlive();
  Future<void>.delayed(const Duration(minutes: 10), link.close);
  return ref.watch(homePromotionRepositoryProvider).watchActivePromotions();
});

/// Admin ads / announcements carousel (no AdMob native slot — banners stay sticky).
class HomePromotionsCarousel extends ConsumerStatefulWidget {
  const HomePromotionsCarousel({super.key});

  @override
  ConsumerState<HomePromotionsCarousel> createState() =>
      _HomePromotionsCarouselState();
}

class _HomePromotionsCarouselState
    extends ConsumerState<HomePromotionsCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(homePromotionsProvider);

    return async.when(
      loading: () => const _PromoSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (promos) {
        if (promos.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
                AppDimens.spaceXs,
              ),
              child: Text(
                'For you',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            SizedBox(
              height: 156,
              child: PageView.builder(
                controller: _controller,
                itemCount: promos.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _PromotionSlide(promo: promos[i]),
              ),
            ),
            if (promos.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(promos.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: active ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: active
                            ? context.cf.accent
                            : context.cf.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PromotionSlide extends StatelessWidget {
  const _PromotionSlide({required this.promo});

  final HomePromotionModel promo;

  Future<void> _open(BuildContext context) async {
    final action = promo.redirectAction.toLowerCase();
    final target = promo.redirectUrl.trim();
    if (target.isEmpty || action == 'none') return;
    if (action == 'route' || target.startsWith('/')) {
      context.push(target.startsWith('/') ? target : '/$target');
      return;
    }
    final uri = Uri.tryParse(target);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final isAnnouncement = promo.isAnnouncement;
    final accent = isAnnouncement ? cf.info : cf.accent;

    return Padding(
      padding: const EdgeInsets.only(right: AppDimens.spaceSm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(context),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAnnouncement
                    ? cf.info.withValues(alpha: 0.45)
                    : cf.border,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isAnnouncement
                    ? [
                        cf.info.withValues(alpha: 0.18),
                        cf.card,
                      ]
                    : [
                        accent.withValues(alpha: 0.12),
                        cf.card,
                      ],
              ),
            ),
            child: Row(
              children: [
                if (promo.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: promo.imageUrl,
                      width: 110,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const SizedBox(width: 110),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isAnnouncement ? 'Announcement' : 'Sponsored',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          promo.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (promo.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            promo.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cf.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const Spacer(),
                        if (promo.buttonText.isNotEmpty)
                          Text(
                            promo.buttonText,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromoSkeleton extends StatelessWidget {
  const _PromoSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Container(
        height: 148,
        decoration: BoxDecoration(
          color: context.cf.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cf.border),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
