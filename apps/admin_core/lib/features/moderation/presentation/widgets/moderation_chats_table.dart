import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_moderation.dart';

class ModerationChatsTable extends StatefulWidget {
  const ModerationChatsTable({
    super.key,
    required this.chats,
    required this.isLoading,
  });

  final List<ManagedChatThread> chats;
  final bool isLoading;

  @override
  State<ModerationChatsTable> createState() => _ModerationChatsTableState();
}

class _ModerationChatsTableState extends State<ModerationChatsTable> {
  final _horizontalScroll = ScrollController();
  static const _tableWidth = 1200.0;

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final items = widget.chats;

    if (widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading chat metadata…'),
        ),
      );
    }

    if (!widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.chat_outlined,
            title: 'No chats found',
            message: 'Chat threads will appear here for metadata review.',
          ),
        ),
      );
    }

    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.info.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.privacy_tip_outlined, size: 18, color: colors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Private message content is never shown — metadata only.',
                    style: TextStyle(
                      color: colors.info,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Scrollbar(
                controller: _horizontalScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScroll,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: SizedBox(
                      width: _tableWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Header(),
                          Divider(height: 1, color: colors.border),
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: colors.border),
                            _ChatRow(thread: items[i]),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Divider(height: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '${items.length} conversation(s)',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const _FlexCol('Conversation ID', flex: 2),
          const _FlexCol('Participants', flex: 3),
          const _FlexCol('Created', flex: 2),
          const _FlexCol('Last message', flex: 2),
          const _FlexCol('Preview', flex: 2),
          const _FlexCol('Reported', flex: 1),
          const _FlexCol('Status', flex: 1),
        ],
      ),
    );
  }
}

class _FlexCol extends StatelessWidget {
  const _FlexCol(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ChatRow extends StatefulWidget {
  const _ChatRow({required this.thread});

  final ManagedChatThread thread;

  @override
  State<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends State<_ChatRow> {
  bool _hover = false;

  String _shortId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 12)}…';
  }

  String get _participantsLabel {
    final names = widget.thread.participantNames;
    if (names.isNotEmpty) return names.join(', ');
    final ids = widget.thread.participantIds;
    if (ids.isEmpty) return '—';
    return ids.map(_shortId).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final t = widget.thread;
    final bg = _hover ? colors.background : colors.card;
    final dateFmt = DateFormat('MMM d HH:mm');

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: bg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  _shortId(t.id),
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _participantsLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  t.createdAt == null ? '—' : dateFmt.format(t.createdAt!),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  t.lastMessageAt == null
                      ? '—'
                      : dateFmt.format(t.lastMessageAt!),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Hidden (privacy)',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Icon(
                  t.reported ? Icons.flag : Icons.flag_outlined,
                  size: 18,
                  color: t.reported ? colors.error : colors.textMuted,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  t.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
