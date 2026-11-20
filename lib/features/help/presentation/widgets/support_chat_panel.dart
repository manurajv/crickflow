import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_gate.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/support_thread_provider.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../data/support_thread_models.dart';

class SupportChatPanel extends ConsumerStatefulWidget {
  const SupportChatPanel({super.key});

  @override
  ConsumerState<SupportChatPanel> createState() => _SupportChatPanelState();
}

class _SupportChatPanelState extends ConsumerState<SupportChatPanel> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  var _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final user = ref.read(currentUserProfileProvider).valueOrNull;
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || user == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(supportThreadRepositoryProvider).sendUserMessage(
            userId: uid,
            displayName: user.effectiveName,
            photoUrl: user.photoUrl,
            text: text,
          );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) {
      return Container(
        width: double.infinity,
        padding: AppDimens.cardPadding,
        decoration: cfCardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat with CrickFlow staff',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Sign in to start a conversation. A teammate will reply here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            CfButton(
              label: 'Sign in',
              isGold: true,
              onPressed: () => openLoginForGuest(
                context: context,
                prompt: SignInPrompt.supportChat,
                returnPath: '/help',
              ),
            ),
          ],
        ),
      );
    }

    final threadAsync = ref.watch(mySupportThreadProvider);
    final messagesAsync = ref.watch(mySupportMessagesProvider);

    ref.listen(mySupportThreadProvider, (prev, next) {
      final unread = next.valueOrNull?.userUnreadCount ?? 0;
      if (unread > 0) {
        ref.read(supportThreadRepositoryProvider).markUserRead(uid);
      }
    });

    return Container(
      width: double.infinity,
      padding: AppDimens.cardPadding,
      decoration: cfCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chat with CrickFlow staff',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          threadAsync.maybeWhen(
            data: (thread) {
              if (thread == null) {
                return Text(
                  'Send a message to start a conversation.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cf.textSecondary,
                      ),
                );
              }
              if (!thread.isOpen) {
                return Text(
                  'This conversation is marked resolved. Send a message to open it again.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cf.textSecondary,
                      ),
                );
              }
              return Text(
                'A CrickFlow teammate will reply here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cf.textSecondary,
                    ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          SizedBox(
            height: 280,
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(friendlyError(e))),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cf.textMuted,
                          ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _Bubble(message: messages[i], viewerId: uid),
                );
              },
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Write a message…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                tooltip: 'Send',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.viewerId});

  final SupportMessage message;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final mine = message.senderId == viewerId && !message.isStaff;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: mine ? CfColors.primaryBlue.withValues(alpha: 0.12) : cf.sectionBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              mine ? 'You' : message.senderName,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cf.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 2),
            Text(message.text, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
