import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/chat_model.dart';
import '../../../../shared/providers/chat_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_chrome_app_bar.dart';

class ChatConversationScreen extends ConsumerStatefulWidget {
  const ChatConversationScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState
    extends ConsumerState<ChatConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  var _markedRead = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            chatId: widget.chatId,
            senderId: uid,
            text: text,
          );
      _controller.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final chatAsync = ref.watch(chatProvider(widget.chatId));
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));

    ref.listen(chatProvider(widget.chatId), (prev, next) {
      final chat = next.valueOrNull;
      if (chat == null || uid.isEmpty || _markedRead) return;
      if (chat.unreadFor(uid) > 0) {
        _markedRead = true;
        ref.read(chatRepositoryProvider).markRead(
              chatId: widget.chatId,
              userId: uid,
            );
      }
    });

    final chat = chatAsync.valueOrNull;
    final other = chat?.otherParticipant(uid);
    final isIncomingRequest = chat?.status == ChatStatus.request &&
        chat?.requestFrom != null &&
        chat!.requestFrom != uid;
    final isDeclined = chat?.status == ChatStatus.declined;

    return Scaffold(
      appBar: CfChromeAppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: cf.sectionBackground,
              backgroundImage: other?.photoUrl != null
                  ? CachedNetworkImageProvider(other!.photoUrl!)
                  : null,
              child: other?.photoUrl == null
                  ? Text(
                      (other?.name.isNotEmpty == true)
                          ? other!.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    other?.name.isNotEmpty == true
                        ? other!.name
                        : 'Chat',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (other?.playerId != null && other!.playerId!.isNotEmpty)
                    Text(
                      other.playerId!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cf.textMuted,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (other?.playerId != null && other!.playerId!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.push('/player/${other.playerId}'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (isIncomingRequest)
            Material(
              color: cf.accent.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Message request',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Accept to move this conversation into your chats.',
                      style: TextStyle(color: cf.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => ref
                                .read(chatRepositoryProvider)
                                .acceptRequest(
                                  chatId: widget.chatId,
                                  userId: uid,
                                ),
                            child: const Text('Accept'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await ref
                                  .read(chatRepositoryProvider)
                                  .declineRequest(
                                    chatId: widget.chatId,
                                    userId: uid,
                                  );
                              if (context.mounted) context.pop();
                            },
                            child: const Text('Decline'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (chat?.status == ChatStatus.request &&
              chat?.requestFrom == uid)
            Material(
              color: cf.sectionBackground,
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceSm),
                child: Text(
                  'Waiting for them to accept your message request.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cf.textMuted, fontSize: 13),
                ),
              ),
            ),
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(color: cf.textMuted),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final mine = msg.senderId == uid;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? cf.accent.withValues(alpha: 0.2)
                              : cf.sectionBackground,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(mine ? 14 : 4),
                            bottomRight: Radius.circular(mine ? 4 : 14),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: mine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(msg.text),
                            if (msg.createdAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                AppDateUtils.timeAgo(msg.createdAt!),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cf.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
          if (!isDeclined && !isIncomingRequest)
            SafeArea(
              top: false,
              child: Padding(
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
                          hintText: 'Message…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _send(),
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
            ),
          if (isIncomingRequest)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                child: Text(
                  'Accept the request to reply.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cf.textMuted),
                ),
              ),
            ),
          if (isDeclined)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                child: Text(
                  'This conversation is closed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cf.textMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
