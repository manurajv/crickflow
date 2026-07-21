import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_gate.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/chat_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/chat_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_chrome_app_bar.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchController = TextEditingController();
  List<UserModel> _searchResults = const [];
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearch(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() {
        _searchResults = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final results =
          await ref.read(userRepositoryProvider).searchUsersByName(q);
      final me = ref.read(authStateProvider).valueOrNull?.uid;
      if (!mounted) return;
      setState(() {
        _searchResults = results.where((u) => u.id != me).take(20).toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openChatWith(UserModel other) async {
    requireAuthVoid(
      context: context,
      ref: ref,
      action: () async {
        final me = ref.read(currentUserProfileProvider).valueOrNull;
        if (me == null) return;
        try {
          final chatId = await ref.read(chatRepositoryProvider).openOrCreateChat(
                me: me,
                other: other,
              );
          if (mounted) context.push('/community/chats/$chatId');
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$e')),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final chatsAsync = ref.watch(chatListProvider);
    final requestCount =
        ref.watch(messageRequestCountProvider).valueOrNull ?? 0;
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: CfChromeAppBar(
        title: const Text('Chats'),
        actions: [
          Badge(
            isLabelVisible: requestCount > 0,
            label: Text('$requestCount'),
            child: IconButton(
              tooltip: 'Message requests',
              icon: const Icon(Icons.mark_email_unread_outlined),
              onPressed: () => context.push('/community/chats/requests'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onSearch,
            ),
          ),
          if (_searchController.text.trim().length >= 2)
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            'No users found',
                            style: TextStyle(color: cf.textMuted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, i) {
                            final u = _searchResults[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: u.photoUrl != null
                                    ? CachedNetworkImageProvider(u.photoUrl!)
                                    : null,
                                child: u.photoUrl == null
                                    ? Text(
                                        u.effectiveName.isNotEmpty
                                            ? u.effectiveName[0].toUpperCase()
                                            : '?',
                                      )
                                    : null,
                              ),
                              title: Text(u.effectiveName),
                              subtitle: u.playerId != null
                                  ? Text(u.playerId!)
                                  : null,
                              onTap: () => _openChatWith(u),
                            );
                          },
                        ),
            )
          else
            Expanded(
              child: chatsAsync.when(
                data: (chats) {
                  if (chats.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: AppDimens.listPadding,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 48, color: cf.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'No chats yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Search for a player above or open Message from a profile.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cf.textMuted),
                            ),
                            if (requestCount > 0) ...[
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () =>
                                    context.push('/community/chats/requests'),
                                child: Text(
                                  'View $requestCount message request${requestCount == 1 ? '' : 's'}',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: chats.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final chat = chats[i];
                      return _ChatTile(
                        chat: chat,
                        myId: uid ?? '',
                        onOpen: () =>
                            context.push('/community/chats/${chat.id}'),
                        onArchive: () => ref
                            .read(chatRepositoryProvider)
                            .archiveChat(chatId: chat.id, userId: uid!),
                        onDelete: () => ref
                            .read(chatRepositoryProvider)
                            .deleteChatForUser(
                              chatId: chat.id,
                              userId: uid!,
                            ),
                        onMute: () => ref
                            .read(chatRepositoryProvider)
                            .toggleMute(chatId: chat.id, userId: uid!),
                        onPin: () => ref
                            .read(chatRepositoryProvider)
                            .togglePin(chatId: chat.id, userId: uid!),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.myId,
    required this.onOpen,
    required this.onArchive,
    required this.onDelete,
    required this.onMute,
    required this.onPin,
  });

  final ChatModel chat;
  final String myId;
  final VoidCallback onOpen;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onMute;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final other = chat.otherParticipant(myId);
    final unread = chat.unreadFor(myId);
    final pending = chat.status == ChatStatus.request;

    return Dismissible(
      key: ValueKey(chat.id),
      background: Container(
        color: cf.accent.withValues(alpha: 0.2),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(Icons.archive_outlined, color: cf.accent),
      ),
      secondaryBackground: Container(
        color: cf.error.withValues(alpha: 0.2),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: cf.error),
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          onArchive();
          return true;
        }
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove chat?'),
            content: const Text(
              'This hides the conversation for you. The other person keeps their copy.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (ok == true) onDelete();
        return ok == true;
      },
      child: ListTile(
        onTap: onOpen,
        onLongPress: () => _showActions(context),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: cf.sectionBackground,
              backgroundImage: other?.photoUrl != null
                  ? CachedNetworkImageProvider(other!.photoUrl!)
                  : null,
              child: other?.photoUrl == null
                  ? Text(
                      (other?.name.isNotEmpty == true)
                          ? other!.name[0].toUpperCase()
                          : '?',
                    )
                  : null,
            ),
            if (chat.isPinnedBy(myId))
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: cf.card,
                  child: Icon(Icons.push_pin, size: 10, color: cf.accent),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                other?.name.isNotEmpty == true ? other!.name : 'CrickFlow user',
                style: TextStyle(
                  fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (chat.lastMessageAt != null)
              Text(
                AppDateUtils.timeAgo(chat.lastMessageAt!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cf.textMuted,
                    ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            if (pending)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  'Pending',
                  style: TextStyle(
                    color: cf.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (chat.isMutedBy(myId))
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.volume_off, size: 14, color: cf.textMuted),
              ),
            Expanded(
              child: Text(
                chat.lastMessage.isEmpty ? 'Say hello…' : chat.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unread > 0 ? cf.textSecondary : cf.textMuted,
                  fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (unread > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cf.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: TextStyle(
                    color: cf.onAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                chat.isPinnedBy(myId)
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
              ),
              title: Text(chat.isPinnedBy(myId) ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(ctx);
                onPin();
              },
            ),
            ListTile(
              leading: Icon(
                chat.isMutedBy(myId)
                    ? Icons.volume_up_outlined
                    : Icons.volume_off_outlined,
              ),
              title: Text(chat.isMutedBy(myId) ? 'Unmute' : 'Mute'),
              onTap: () {
                Navigator.pop(ctx);
                onMute();
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              onTap: () {
                Navigator.pop(ctx);
                onArchive();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove'),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
