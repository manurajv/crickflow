import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/chat_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../shared/providers/chat_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_chrome_app_bar.dart';

class MessageRequestsScreen extends ConsumerWidget {
  const MessageRequestsScreen({super.key});

  List<String> _mutualTeamNames({
    required String myId,
    required String otherId,
    required List<TeamModel> teams,
  }) {
    if (myId.isEmpty || otherId.isEmpty) return const [];
    final names = <String>[];
    for (final t in teams) {
      if (t.playerIds.contains(myId) && t.playerIds.contains(otherId)) {
        if (t.name.isNotEmpty) names.add(t.name);
      }
    }
    return names.take(3).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final requestsAsync = ref.watch(messageRequestsProvider);
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final teams = ref.watch(allTeamsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: const CfChromeAppBar(title: Text('Message requests')),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: AppDimens.listPadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 48, color: cf.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      'No message requests',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'When someone new messages you, it will appear here until you accept.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cf.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: AppDimens.listPadding,
            itemCount: requests.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppDimens.spaceSm),
            itemBuilder: (context, i) {
              final chat = requests[i];
              final other = chat.otherParticipant(uid ?? '');
              final mutual = _mutualTeamNames(
                myId: uid ?? '',
                otherId: other?.userId ?? '',
                teams: teams,
              );
              return _RequestCard(
                chat: chat,
                other: other,
                mutualTeams: mutual,
                onOpen: () => context.push('/community/chats/${chat.id}'),
                onAccept: () async {
                  if (uid == null) return;
                  await ref.read(chatRepositoryProvider).acceptRequest(
                        chatId: chat.id,
                        userId: uid,
                      );
                  if (context.mounted) {
                    context.push('/community/chats/${chat.id}');
                  }
                },
                onDecline: () async {
                  if (uid == null) return;
                  await ref.read(chatRepositoryProvider).declineRequest(
                        chatId: chat.id,
                        userId: uid,
                      );
                },
                onBlock: () async {
                  if (uid == null || other == null) return;
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Block user?'),
                      content: Text(
                        'Block ${other.name}? They will not be able to message you again.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Block'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await ref.read(chatRepositoryProvider).blockUser(
                        blockerId: uid,
                        blockedId: other.userId,
                      );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.chat,
    required this.other,
    required this.mutualTeams,
    required this.onOpen,
    required this.onAccept,
    required this.onDecline,
    required this.onBlock,
  });

  final ChatModel chat;
  final ChatParticipant? other;
  final List<String> mutualTeams;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);

    return Container(
      padding: AppDimens.cardPadding,
      decoration: BoxDecoration(
        color: cf.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cf.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpen,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        other?.name.isNotEmpty == true
                            ? other!.name
                            : 'CrickFlow user',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (other?.playerId != null &&
                          other!.playerId!.isNotEmpty)
                        Text(
                          other!.playerId!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cf.textMuted,
                          ),
                        ),
                      if (chat.lastMessageAt != null)
                        Text(
                          AppDateUtils.timeAgo(chat.lastMessageAt!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cf.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (mutualTeams.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Mutual teams: ${mutualTeams.join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(color: cf.accent),
            ),
          ],
          if (chat.lastMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              chat.lastMessage,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Block',
                onPressed: onBlock,
                icon: Icon(Icons.block, color: cf.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
