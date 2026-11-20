import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/cf_loading_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../data/user_support_thread_models.dart';
import '../../providers/user_support_providers.dart';

class SupportInboxPanel extends ConsumerStatefulWidget {
  const SupportInboxPanel({super.key});

  @override
  ConsumerState<SupportInboxPanel> createState() => _SupportInboxPanelState();
}

class _SupportInboxPanelState extends ConsumerState<SupportInboxPanel> {
  String? _selectedId;
  final _composer = TextEditingController();
  var _sending = false;
  var _statusBusy = false;

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  String get _staffName {
    final admin = ref.read(adminUserProvider).valueOrNull;
    final display = admin?.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final email = admin?.email.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'CrickFlow staff';
  }

  String? get _staffUid => ref.read(authStateProvider).value?.uid;

  Future<void> _markRead(String threadId) async {
    try {
      await ref.read(userSupportThreadRepositoryProvider).markStaffRead(threadId);
    } catch (_) {}
  }

  Future<void> _send(UserSupportThread thread) async {
    final text = _composer.text.trim();
    final uid = _staffUid;
    if (text.isEmpty || uid == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(userSupportThreadRepositoryProvider).sendStaffMessage(
            threadId: thread.id,
            staffUserId: uid,
            staffName: _staffName,
            text: text,
          );
      _composer.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send that reply.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _setStatus(UserSupportThread thread, String status) async {
    if (_statusBusy) return;
    setState(() => _statusBusy = true);
    try {
      await ref.read(userSupportThreadRepositoryProvider).setStatus(
            threadId: thread.id,
            status: status,
            resolvedByUid: _staffUid,
            resolvedByName: _staffName,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the conversation.')),
        );
      }
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(userSupportInboxProvider);
    final wide = MediaQuery.sizeOf(context).width >= 960;
    return inbox.when(
      loading: () => const SizedBox(
        height: 280,
        child: CfLoadingState(message: 'Loading inbox…'),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('Could not load help conversations.'),
      ),
      data: (threads) {
        if (threads.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text('No help conversations yet.'),
          );
        }
        final selected = threads.cast<UserSupportThread?>().firstWhere(
              (t) => t!.id == _selectedId,
              orElse: () => null,
            ) ??
            (wide ? threads.first : null);
        final list = _ThreadList(
          threads: threads,
          selectedId: selected?.id,
          onSelect: (thread) {
            setState(() => _selectedId = thread.id);
            if (thread.staffUnreadCount > 0) {
              _markRead(thread.id);
            }
          },
        );
        final detail = selected == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('Select a conversation to reply.'),
              )
            : _ThreadDetail(
                thread: selected,
                composer: _composer,
                sending: _sending,
                statusBusy: _statusBusy,
                onSend: () => _send(selected),
                onResolve: () => _setStatus(selected, 'resolved'),
                onReopen: () => _setStatus(selected, 'open'),
              );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              list,
              const SizedBox(height: 16),
              detail,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: list),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: detail),
          ],
        );
      },
    );
  }
}

class _ThreadList extends StatelessWidget {
  const _ThreadList({
    required this.threads,
    required this.selectedId,
    required this.onSelect,
  });

  final List<UserSupportThread> threads;
  final String? selectedId;
  final ValueChanged<UserSupportThread> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (final thread in threads)
            ListTile(
              selected: thread.id == selectedId,
              title: Text(thread.userDisplayName),
              subtitle: Text(
                thread.lastMessageText.isEmpty
                    ? 'No messages yet'
                    : thread.lastMessageText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    thread.isOpen ? 'Open' : 'Resolved',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (thread.staffUnreadCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: CircleAvatar(
                        radius: 10,
                        child: Text(
                          '${thread.staffUnreadCount}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
              onTap: () => onSelect(thread),
            ),
        ],
      ),
    );
  }
}

class _ThreadDetail extends ConsumerWidget {
  const _ThreadDetail({
    required this.thread,
    required this.composer,
    required this.sending,
    required this.statusBusy,
    required this.onSend,
    required this.onResolve,
    required this.onReopen,
  });

  final UserSupportThread thread;
  final TextEditingController composer;
  final bool sending;
  final bool statusBusy;
  final VoidCallback onSend;
  final VoidCallback onResolve;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(userSupportMessagesProvider(thread.id));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    thread.userDisplayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: statusBusy
                      ? null
                      : (thread.isOpen ? onResolve : onReopen),
                  child: Text(thread.isOpen ? 'Mark resolved' : 'Reopen'),
                ),
              ],
            ),
            Text(
              thread.isOpen ? 'Open conversation' : 'Resolved',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: messages.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Center(
                  child: Text('Could not load messages.'),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(child: Text('No messages yet.'));
                  }
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final m = items[i];
                      final staff = m.isStaff;
                      return Align(
                        alignment: staff
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          constraints: const BoxConstraints(maxWidth: 360),
                          decoration: BoxDecoration(
                            color: staff
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.12)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: staff
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                staff ? m.senderName : thread.userDisplayName,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(m.text),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: composer,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Write a reply…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: sending ? null : onSend,
                  child: Text(sending ? 'Sending…' : 'Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
