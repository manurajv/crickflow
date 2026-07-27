import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/auth/auth_gate.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/deep_link_utils.dart';
import '../../../../data/models/opportunity_post_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/chat_provider.dart';
import '../../../../shared/providers/opportunity_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/report_reason_dialog.dart';
import '../../../../shared/widgets/venue_location_sheet.dart';
import '../../domain/opportunity_category.dart';
import '../create_opportunity_flow.dart';
import 'opportunity_author_sheet.dart';

/// Compact marketplace card for an opportunity listing.
class OpportunityPostCard extends ConsumerWidget {
  const OpportunityPostCard({
    super.key,
    required this.post,
    this.onAuthorTap,
    this.onTap,
    this.highlighted = false,
    this.previewMode = false,
  });

  final OpportunityPostModel post;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onTap;
  final bool highlighted;
  final bool previewMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final isOwner = uid != null && uid == post.authorId;
    final isAdmin = ref.watch(isPlatformAdminProvider);
    final category = post.category;
    final chips = post.cardChips;
    final eventDateLabel = post.eventDateLabel;
    final location = post.locationLabel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: previewMode ? null : onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Container(
          decoration: cfCardDecoration(
            context,
            borderColor: highlighted
                ? cf.accent.withValues(alpha: 0.7)
                : (post.isFeatured
                    ? cf.accent.withValues(alpha: 0.35)
                    : null),
            borderWidth: highlighted || post.isFeatured ? 1.5 : 1,
          ),
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _CategoryBadge(category: category),
                        if (post.isPinned)
                          _SubtleFlag(
                            icon: Icons.push_pin,
                            label: 'Pinned',
                            color: cf.textMuted,
                          ),
                        if (post.isFeatured)
                          _SubtleFlag(
                            icon: Icons.star_outline,
                            label: 'Featured',
                            color: cf.accent,
                          ),
                      ],
                    ),
                  ),
                  if (!previewMode)
                    _OverflowMenu(
                      post: post,
                      isOwner: isOwner,
                      isAdmin: isAdmin,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              _AuthorRow(
                post: post,
                onAuthorTap: previewMode
                    ? null
                    : (onAuthorTap ??
                        () {
                          if (post.authorId.isEmpty) return;
                          showOpportunityAuthorSheet(context, post.authorId);
                        }),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                post.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 4),
                TappableVenueLocation(
                  label: location,
                  location: post.location,
                  maxLines: 2,
                  underline: false,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cf.textSecondary,
                  ),
                ),
              ],
              if (eventDateLabel != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 13, color: cf.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      eventDateLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cf.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              if (post.portfolioUrl != null) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: previewMode
                      ? null
                      : () => launchUrl(
                            Uri.parse(post.portfolioUrl!),
                            mode: LaunchMode.externalApplication,
                          ),
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 14, color: cf.accent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Portfolio reference',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cf.accent,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceSm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: chips
                      .map(
                        (c) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cf.sectionBackground,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusSm),
                            border: Border.all(
                              color: cf.border.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Text(
                            c,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cf.textSecondary,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (post.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceSm),
                _MediaSlideshow(urls: post.mediaUrls),
              ],
              if (post.description.trim().isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceSm),
                _ExpandableDescription(
                  text: post.description.trim(),
                  previewMode: previewMode,
                  onReadMore: onTap,
                ),
              ],
              if (post.brandingOfferText != null) ...[
                const SizedBox(height: AppDimens.spaceSm),
                _ExpandableDescription(
                  text: post.brandingOfferText!,
                  previewMode: previewMode,
                  onReadMore: onTap,
                  bold: true,
                ),
              ],
              if (!previewMode) ...[
                const SizedBox(height: AppDimens.spaceSm),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: cf.border.withValues(alpha: 0.55),
                ),
                _Footer(post: post),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 16:9 ground photo gallery — swipe when more than one image.
class _MediaSlideshow extends StatefulWidget {
  const _MediaSlideshow({required this.urls});

  final List<String> urls;

  @override
  State<_MediaSlideshow> createState() => _MediaSlideshowState();
}

class _MediaSlideshowState extends State<_MediaSlideshow> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final urls = widget.urls;
    final multi = urls.length > 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              physics: multi
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                return CachedNetworkImage(
                  imageUrl: urls[i],
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: cf.sectionBackground),
                  errorWidget: (_, _, _) => Container(
                    color: cf.sectionBackground,
                    alignment: Alignment.center,
                    child: Icon(Icons.broken_image_outlined,
                        color: cf.textMuted),
                  ),
                );
              },
            ),
            if (multi) ...[
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_index + 1}/${urls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(urls.length, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 14 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final OpportunityCategory category;

  @override
  Widget build(BuildContext context) {
    final color = category.badgeColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        category.badgeLabel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

class _SubtleFlag extends StatelessWidget {
  const _SubtleFlag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.post, this.onAuthorTap});

  final OpportunityPostModel post;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final photo = post.authorPhotoUrl?.trim() ?? '';
    final hasPhoto = photo.isNotEmpty;
    final time = post.createdAt != null
        ? AppDateUtils.timeAgo(post.createdAt!)
        : '';

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onAuthorTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: cf.sectionBackground,
                  backgroundImage:
                      hasPhoto ? CachedNetworkImageProvider(photo) : null,
                  child: hasPhoto
                      ? null
                      : Text(
                          post.authorName.isNotEmpty
                              ? post.authorName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 12),
                        ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.authorName.isNotEmpty
                              ? post.authorName
                              : 'Cricketer',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (post.authorVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified, size: 14, color: cf.accent),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.visibility_outlined, size: 13, color: cf.textMuted),
        const SizedBox(width: 3),
        Text(
          '${post.viewCount}',
          style: theme.textTheme.labelSmall?.copyWith(color: cf.textMuted),
        ),
        if (time.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              '·',
              style: theme.textTheme.labelSmall?.copyWith(color: cf.textMuted),
            ),
          ),
          Text(
            time,
            style: theme.textTheme.labelSmall?.copyWith(color: cf.textMuted),
          ),
        ],
      ],
    );
  }
}

class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({
    required this.text,
    required this.previewMode,
    this.onReadMore,
    this.bold = false,
  });

  final String text;
  final bool previewMode;
  final VoidCallback? onReadMore;
  final bool bold;

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: widget.bold ? cf.textPrimary : cf.textSecondary,
            fontWeight: widget.bold ? FontWeight.w700 : FontWeight.w400,
            height: 1.35,
          ),
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (!_expanded && widget.text.length > 120) ...[
          const SizedBox(height: 2),
          GestureDetector(
            onTap: widget.previewMode
                ? null
                : () {
                    if (widget.onReadMore != null) {
                      widget.onReadMore!();
                    } else {
                      setState(() => _expanded = true);
                    }
                  },
            child: Text(
              'Read more',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cf.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ] else if (_expanded) ...[
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () => setState(() => _expanded = false),
            child: Text(
              'Show less',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cf.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.post});

  final OpportunityPostModel post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showChat =
        post.contactMethods.contains(OpportunityContactMethod.chat);
    final showPhone =
        post.contactMethods.contains(OpportunityContactMethod.phone) &&
            post.contactPhone.trim().isNotEmpty;
    final showWa =
        post.contactMethods.contains(OpportunityContactMethod.whatsapp) &&
            post.contactWhatsApp.trim().isNotEmpty;
    final hasContact = showChat || showPhone || showWa;

    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: hasContact
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (showPhone)
                        _ContactButton(
                          icon: Icons.phone_outlined,
                          label: 'Call',
                          onTap: () => launchUrl(
                            Uri(scheme: 'tel', path: post.contactPhone.trim()),
                          ),
                        ),
                      if (showWa)
                        _ContactButton(
                          icon: Icons.chat_outlined,
                          label: 'WhatsApp',
                          onTap: () {
                            final phone = post.contactWhatsApp
                                .replaceAll(RegExp(r'\D'), '');
                            launchUrl(
                              Uri.parse('https://wa.me/$phone'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                        ),
                      if (showChat)
                        OutlinedButton(
                          onPressed: () => _openChat(context, ref),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            minimumSize: const Size(0, 34),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Chat'),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          _FooterAction(
            icon: Icons.share_outlined,
            label: post.shareCount > 0 ? '${post.shareCount}' : '',
            onTap: () => _share(ref),
          ),
        ],
      ),
    );
  }

  Future<void> _share(WidgetRef ref) async {
    final url = DeepLinkUtils.hostedOpportunityPostUri(post.id).toString();
    final buf = StringBuffer(post.title);
    if (post.locationLabel.isNotEmpty) {
      buf.writeln();
      buf.write(post.locationLabel);
    }
    buf.writeln();
    buf.write(post.category.chipLabel);
    buf.writeln();
    buf.write(url);
    final result = await Share.share(buf.toString().trim());
    // Only count completed shares (sent to another app or copied).
    if (result.status != ShareResultStatus.success) return;
    try {
      await ref
          .read(opportunityRepositoryProvider)
          .incrementShareCount(post.id);
    } catch (_) {}
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    requireAuthVoid(
      context: context,
      ref: ref,
      action: () async {
        final me = ref.read(currentUserProfileProvider).valueOrNull;
        if (me == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign in to message')),
            );
          }
          return;
        }
        if (me.id == post.authorId) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This is your post')),
            );
          }
          return;
        }

        UserModel other = UserModel(
          id: post.authorId,
          email: '',
          name: post.authorName,
          photoUrl: post.authorPhotoUrl,
          playerId: post.authorPlayerId,
        );
        try {
          final fetched = await ref
              .read(userRepositoryProvider)
              .getUser(post.authorId);
          if (fetched != null) other = fetched;
        } catch (_) {}

        try {
          final chatId =
              await ref.read(chatRepositoryProvider).openOrCreateChat(
                    me: me,
                    other: other,
                  );
          if (context.mounted) {
            context.push('/community/chats/$chatId');
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$e')),
            );
          }
        }
      },
    );
  }
}

/// Community-style labeled icon action (share / counts).
class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.onTap,
    this.label = '',
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu({
    required this.post,
    required this.isOwner,
    required this.isAdmin,
  });

  final OpportunityPostModel post;
  final bool isOwner;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    return PopupMenuButton<String>(
      tooltip: 'Post options',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      iconSize: 20,
      onSelected: (v) => _onSelected(context, ref, v),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'report',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.flag_outlined),
            title: Text('Report'),
          ),
        ),
        if (isAdmin) ...[
          PopupMenuItem(
            value: 'pin',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                post.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(post.isPinned ? 'Unpin' : 'Pin'),
            ),
          ),
          PopupMenuItem(
            value: 'feature',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                post.isFeatured ? Icons.star : Icons.star_outline,
              ),
              title: Text(post.isFeatured ? 'Unfeature' : 'Feature'),
            ),
          ),
          PopupMenuItem(
            value: 'remove',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_forever_outlined, color: cf.error),
              title: Text('Remove', style: TextStyle(color: cf.error)),
            ),
          ),
          PopupMenuItem(
            value: 'block',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person_off_outlined, color: cf.error),
              title: Text('Block user', style: TextStyle(color: cf.error)),
            ),
          ),
        ],
        if (isOwner) ...[
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit'),
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: cf.error),
              title: Text('Delete', style: TextStyle(color: cf.error)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final repo = ref.read(opportunityRepositoryProvider);
    switch (value) {
      case 'report':
        await _report(context, ref);
      case 'edit':
        await requireAuthVoid(
          context: context,
          ref: ref,
          action: () => showEditOpportunityFlow(context, post),
        );
      case 'pin':
        await requireAuthVoid(
          context: context,
          ref: ref,
          action: () => repo.setPinned(
            postId: post.id,
            pinned: !post.isPinned,
          ),
        );
      case 'feature':
        await requireAuthVoid(
          context: context,
          ref: ref,
          action: () => repo.setFeatured(
            postId: post.id,
            featured: !post.isFeatured,
          ),
        );
      case 'remove':
        final ok = await _confirm(
          context,
          title: 'Remove post?',
          body: 'This listing will be removed from Discover.',
        );
        if (ok != true || !context.mounted) return;
        await requireAuthVoid(
          context: context,
          ref: ref,
          action: () async {
            await repo.softRemovePost(post.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post removed')),
              );
            }
          },
        );
      case 'block':
        final ok = await _confirm(
          context,
          title: 'Block ${post.authorName}?',
          body: 'They will not be able to message you.',
        );
        if (ok != true || !context.mounted) return;
        await requireAuthVoid(
          context: context,
          ref: ref,
          action: () async {
            final uid = ref.read(authStateProvider).valueOrNull?.uid;
            if (uid == null) return;
            await ref.read(chatRepositoryProvider).blockUser(
                  blockerId: uid,
                  blockedId: post.authorId,
                );
            await repo.softRemovePost(post.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User blocked')),
              );
            }
          },
        );
      case 'delete':
        final ok = await _confirm(
          context,
          title: 'Delete post?',
          body: 'This cannot be undone.',
        );
        if (ok != true || !context.mounted) return;
        await requireAuthVoid(
          context: context,
          ref: ref,
          action: () async {
            await repo.deletePost(post.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post deleted')),
              );
            }
          },
        );
    }
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Report opportunity'),
        children: [
          for (final r in OpportunityReportReason.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r.label),
              child: Text(r.label),
            ),
        ],
      ),
    );
    if (!context.mounted || reason == null) return;

    String details = '';
    if (reason == OpportunityReportReason.other.label) {
      final typed = await showReportReasonDialog(
        context,
        title: 'Describe the issue',
        hint: 'Tell us what is wrong…',
      );
      if (!context.mounted || typed == null) return;
      details = typed;
    }

    await requireAuthVoid(
      context: context,
      ref: ref,
      action: () async {
        final uid = ref.read(authStateProvider).valueOrNull?.uid;
        if (uid == null) return;
        try {
          await ref.read(opportunityRepositoryProvider).reportPost(
                postId: post.id,
                reporterUserId: uid,
                reason: reason,
                authorId: post.authorId,
                details: details,
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report submitted')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not report: $e')),
            );
          }
        }
      },
    );
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
