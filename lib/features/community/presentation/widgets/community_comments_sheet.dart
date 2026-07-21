import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_gate.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/community_comment_model.dart';
import '../../../../shared/providers/community_provider.dart';
import '../../../../shared/providers/providers.dart';

Future<void> showCommunityCommentsSheet(
  BuildContext context, {
  required String postId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => CommunityCommentsSheet(postId: postId),
  );
}

class CommunityCommentsSheet extends ConsumerStatefulWidget {
  const CommunityCommentsSheet({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<CommunityCommentsSheet> createState() =>
      _CommunityCommentsSheetState();
}

class _CommunityCommentsSheetState
    extends ConsumerState<CommunityCommentsSheet> {
  final _controller = TextEditingController();
  String? _replyToId;
  String? _replyToName;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    requireAuthVoid(
      context: context,
      ref: ref,
      action: () async {
        final user = ref.read(authStateProvider).valueOrNull;
        final profile = ref.read(currentUserProfileProvider).valueOrNull;
        if (user == null || profile == null) return;

        setState(() => _sending = true);
        try {
          await ref.read(communityRepositoryProvider).addComment(
                postId: widget.postId,
                authorId: user.uid,
                authorName: profile.effectiveName,
                authorPhotoUrl: profile.photoUrl,
                text: text,
                parentId: _replyToId,
              );
          _controller.clear();
          setState(() {
            _replyToId = null;
            _replyToName = null;
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not comment: $e')),
            );
          }
        } finally {
          if (mounted) setState(() => _sending = false);
        }
      },
    );
  }

  Future<void> _reportComment(CommunityCommentModel comment) async {
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report comment'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Spam, harassment…',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (ok != true || reason.isEmpty || !mounted) return;

    requireAuthVoid(
      context: context,
      ref: ref,
      action: () async {
        final uid = ref.read(authStateProvider).valueOrNull?.uid;
        if (uid == null) return;
        await ref.read(communityRepositoryProvider).reportPost(
              postId: widget.postId,
              reporterUserId: uid,
              reason: reason,
              authorId: comment.authorId,
              commentId: comment.id,
            );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Comment reported')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final commentsAsync = ref.watch(communityCommentsProvider(widget.postId));
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Comments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Expanded(
              child: commentsAsync.when(
                data: (comments) {
                  if (comments.isEmpty) {
                    return Center(
                      child: Text(
                        'No comments yet — start the conversation.',
                        style: TextStyle(color: cf.textMuted),
                      ),
                    );
                  }
                  final roots =
                      comments.where((c) => c.parentId == null).toList();
                  final replies = <String, List<CommunityCommentModel>>{};
                  for (final c in comments) {
                    if (c.parentId == null) continue;
                    replies.putIfAbsent(c.parentId!, () => []).add(c);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                    ),
                    itemCount: roots.length,
                    itemBuilder: (context, i) {
                      final root = roots[i];
                      final kids = replies[root.id] ?? const [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CommentTile(
                            postId: widget.postId,
                            comment: root,
                            isOwner: uid == root.authorId,
                            currentUserId: uid,
                            onReply: () => setState(() {
                              _replyToId = root.id;
                              _replyToName = root.authorName;
                            }),
                            onDelete: () => ref
                                .read(communityRepositoryProvider)
                                .deleteComment(
                                  postId: widget.postId,
                                  commentId: root.id,
                                ),
                            onCopy: () async {
                              await Clipboard.setData(
                                ClipboardData(text: root.text),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Comment copied'),
                                  ),
                                );
                              }
                            },
                            onReport: () => _reportComment(root),
                          ),
                          ...kids.map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: _CommentTile(
                                postId: widget.postId,
                                comment: r,
                                isOwner: uid == r.authorId,
                                currentUserId: uid,
                                isReply: true,
                                onReply: () => setState(() {
                                  _replyToId = root.id;
                                  _replyToName = r.authorName;
                                }),
                                onDelete: () => ref
                                    .read(communityRepositoryProvider)
                                    .deleteComment(
                                      postId: widget.postId,
                                      commentId: r.id,
                                    ),
                                onCopy: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: r.text),
                                  );
                                },
                                onReport: () => _reportComment(r),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
              ),
            ),
            if (_replyToName != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to $_replyToName',
                        style: TextStyle(color: cf.textMuted, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _replyToId = null;
                        _replyToName = null;
                      }),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({
    required this.postId,
    required this.comment,
    required this.isOwner,
    required this.onReply,
    required this.onDelete,
    required this.onCopy,
    required this.onReport,
    this.currentUserId,
    this.isReply = false,
  });

  final String postId;
  final CommunityCommentModel comment;
  final bool isOwner;
  final String? currentUserId;
  final bool isReply;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final uid = currentUserId;
    final liked = uid == null
        ? false
        : (ref
                .watch(
                  communityCommentLikedProvider((
                    postId: postId,
                    commentId: comment.id,
                    userId: uid,
                  )),
                )
                .valueOrNull ??
            false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 12 : 16,
            backgroundColor: cf.sectionBackground,
            backgroundImage: comment.authorPhotoUrl != null
                ? CachedNetworkImageProvider(comment.authorPhotoUrl!)
                : null,
            child: comment.authorPhotoUrl == null
                ? Text(
                    comment.authorName.isNotEmpty
                        ? comment.authorName[0].toUpperCase()
                        : '?',
                    style: TextStyle(fontSize: isReply ? 10 : 12),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName,
                        style: theme.textTheme.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (comment.createdAt != null)
                      Text(
                        AppDateUtils.timeAgo(comment.createdAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cf.textMuted,
                        ),
                      ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      onSelected: (v) {
                        if (v == 'reply') onReply();
                        if (v == 'copy') onCopy();
                        if (v == 'delete') onDelete();
                        if (v == 'report') onReport();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'reply',
                          child: Text('Reply'),
                        ),
                        const PopupMenuItem(
                          value: 'copy',
                          child: Text('Copy'),
                        ),
                        if (!isOwner)
                          const PopupMenuItem(
                            value: 'report',
                            child: Text('Report'),
                          ),
                        if (isOwner)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                      ],
                    ),
                  ],
                ),
                Text(comment.text, style: theme.textTheme.bodyMedium),
                Row(
                  children: [
                    TextButton(
                      onPressed: onReply,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Reply'),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => requireAuthVoid(
                        context: context,
                        ref: ref,
                        action: () async {
                          final id =
                              ref.read(authStateProvider).valueOrNull?.uid;
                          if (id == null) return;
                          await ref
                              .read(communityRepositoryProvider)
                              .toggleCommentLike(
                                postId: postId,
                                commentId: comment.id,
                                userId: id,
                              );
                        },
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              liked ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: liked ? cf.error : cf.textMuted,
                            ),
                            if (comment.likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${comment.likeCount}',
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
