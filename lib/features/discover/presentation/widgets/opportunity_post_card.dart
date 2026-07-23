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
import '../../domain/opportunity_category.dart';
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
    final saved =
        ref.watch(opportunityPostSavedProvider(post.id)).valueOrNull ?? false;
    final category = post.category;
    final chips = post.cardChips.take(4).toList();
    final eventDate = post.eventDate;
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
              const SizedBox(height: AppDimens.spaceSm),
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
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: cf.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cf.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (eventDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 13, color: cf.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      AppDateUtils.formatShort(eventDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cf.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceSm),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: chips
                      .map(
                        (c) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cf.sectionBackground,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusSm),
                            border: Border.all(
                              color: cf.border.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Text(
                            c,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cf.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (post.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceSm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: post.mediaUrls.first,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: cf.sectionBackground,
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: cf.sectionBackground,
                        alignment: Alignment.center,
                        child: Icon(Icons.broken_image_outlined,
                            color: cf.textMuted),
                      ),
                    ),
                  ),
                ),
              ],
              if (post.description.trim().isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceSm),
                _ExpandableDescription(
                  text: post.description.trim(),
                  previewMode: previewMode,
                  onReadMore: onTap,
                ),
              ],
              const SizedBox(height: AppDimens.spaceSm),
              _Footer(
                post: post,
                saved: saved,
                previewMode: previewMode,
              ),
            ],
          ),
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

    return InkWell(
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
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    post.authorName.isNotEmpty ? post.authorName : 'Cricketer',
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
    );
  }
}

class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({
    required this.text,
    required this.previewMode,
    this.onReadMore,
  });

  final String text;
  final bool previewMode;
  final VoidCallback? onReadMore;

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
            color: cf.textSecondary,
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
  const _Footer({
    required this.post,
    required this.saved,
    required this.previewMode,
  });

  final OpportunityPostModel post;
  final bool saved;
  final bool previewMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final time = post.createdAt != null
        ? AppDateUtils.timeAgo(post.createdAt!)
        : '';
    final showChat =
        post.contactMethods.contains(OpportunityContactMethod.chat);
    final showPhone =
        post.contactMethods.contains(OpportunityContactMethod.phone) &&
            post.contactPhone.trim().isNotEmpty;
    final showWa =
        post.contactMethods.contains(OpportunityContactMethod.whatsapp) &&
            post.contactWhatsApp.trim().isNotEmpty;

    return Row(
      children: [
        Icon(Icons.visibility_outlined, size: 14, color: cf.textMuted),
        const SizedBox(width: 3),
        Text(
          '${post.viewCount}',
          style: theme.textTheme.labelSmall?.copyWith(color: cf.textMuted),
        ),
        if (time.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            time,
            style: theme.textTheme.labelSmall?.copyWith(color: cf.textMuted),
          ),
        ],
        const Spacer(),
        if (!previewMode) ...[
          if (showPhone)
            _IconAction(
              icon: Icons.call_outlined,
              tooltip: 'Call',
              onTap: () => launchUrl(
                Uri(scheme: 'tel', path: post.contactPhone.trim()),
              ),
            ),
          if (showWa)
            _IconAction(
              icon: Icons.message_outlined,
              tooltip: 'WhatsApp',
              onTap: () {
                final phone =
                    post.contactWhatsApp.replaceAll(RegExp(r'\D'), '');
                launchUrl(
                  Uri.parse('https://wa.me/$phone'),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          _IconAction(
            icon: Icons.share_outlined,
            tooltip: 'Share',
            onTap: () => _share(ref),
          ),
          if (showChat)
            _IconAction(
              icon: Icons.chat_bubble_outline,
              tooltip: 'Chat',
              onTap: () => _openChat(context, ref),
            ),
          _IconAction(
            icon: saved ? Icons.bookmark : Icons.bookmark_border,
            tooltip: saved ? 'Saved' : 'Save',
            color: saved ? cf.accent : null,
            onTap: () => requireAuthVoid(
              context: context,
              ref: ref,
              action: () async {
                final uid = ref.read(authStateProvider).valueOrNull?.uid;
                if (uid == null) return;
                try {
                  await ref.read(opportunityRepositoryProvider).toggleSave(
                        postId: post.id,
                        userId: uid,
                      );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not save: $e')),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ],
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
    await Share.share(buf.toString().trim());
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

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(icon, size: AppDimens.iconSm, color: color ?? cf.textMuted),
      onPressed: onTap,
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
        if (isOwner)
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
