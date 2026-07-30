import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../models/managed_support.dart';
import '../../models/support_enums.dart';
import '../../providers/support_providers.dart';
import 'support_badges.dart';

class SupportTicketDetailPanel extends ConsumerStatefulWidget {
  const SupportTicketDetailPanel({
    super.key,
    required this.ticket,
    required this.messages,
  });

  final ManagedSupportTicket ticket;
  final List<SupportMessage> messages;

  @override
  ConsumerState<SupportTicketDetailPanel> createState() =>
      _SupportTicketDetailPanelState();
}

class _SupportTicketDetailPanelState
    extends ConsumerState<SupportTicketDetailPanel> {
  final _reply = TextEditingController();
  bool _internal = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final colors = context.adminColors;
    final fmt = DateFormat.yMMMd().add_jm();
    final live = ref.watch(supportMessagesStreamProvider(t.id));
    final messages = live.valueOrNull ?? widget.messages;
    final actor = ref.watch(adminSessionProvider).adminUser;
    final controller = ref.read(supportHubControllerProvider.notifier);

    return CfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.ticketNumber,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Close panel',
                onPressed: () => controller.selectTicket(null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(t.subject, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SupportStatusBadge(status: t.status),
              SupportPriorityBadge(priority: t.priority),
              Chip(label: Text(t.category.label)),
              Chip(label: Text(t.kind.label)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t.description.isEmpty ? 'No description' : t.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _MetaGrid(ticket: t, fmt: fmt),
          if (t.kind == SupportTicketKind.bug) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'Bug details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Severity: ${t.severity.label}'),
                  const SizedBox(height: 6),
                  Text('Steps:\n${t.stepsToReproduce.isEmpty ? '—' : t.stepsToReproduce}'),
                  const SizedBox(height: 6),
                  Text('Logs:\n${t.logs.isEmpty ? '—' : t.logs}'),
                ],
              ),
            ),
          ],
          if (t.kind == SupportTicketKind.feature) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'Feature request',
              child: Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('${t.votes} votes')),
                  Chip(label: Text(t.featureStatus.label)),
                  for (final s in FeatureRequestStatus.values)
                    if (s != t.featureStatus)
                      TextButton(
                        onPressed: () => controller.setFeatureStatus(s),
                        child: Text('Mark ${s.label}'),
                      ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Section(
            title: 'Assignment & actions',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CfButton(
                  label: 'Assign to me',
                  onPressed: actor == null
                      ? null
                      : () => controller.assignSelected(
                            uid: actor.uid,
                            email: actor.email,
                            name: actor.displayName ?? actor.email,
                          ),
                ),
                OutlinedButton(
                  onPressed: actor == null
                      ? null
                      : () => controller.assignSelected(
                            uid: actor.uid,
                            email: actor.email,
                            name: actor.displayName ?? actor.email,
                            transfer: true,
                          ),
                  child: const Text('Reassign / Transfer'),
                ),
                OutlinedButton(
                  onPressed: actor == null
                      ? null
                      : () => controller.assignSelected(
                            uid: actor.uid,
                            email: actor.email,
                            name: actor.displayName ?? actor.email,
                            escalate: true,
                          ),
                  child: const Text('Escalate'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      controller.setSelectedStatus(SupportTicketStatus.resolved),
                  child: const Text('Resolve'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      controller.setSelectedStatus(SupportTicketStatus.closed),
                  child: const Text('Close'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      controller.setSelectedStatus(SupportTicketStatus.open),
                  child: const Text('Reopen'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Conversation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            'Support thread only — never private user chats',
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: messages.isEmpty
                ? const CfEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No messages yet',
                    message: 'Reply to start the conversation timeline.',
                  )
                : ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final isAgent =
                          m.authorType == SupportMessageAuthorType.agent;
                      return Align(
                        alignment: isAgent
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 420),
                          decoration: BoxDecoration(
                            color: m.isInternal
                                ? colors.warning.withValues(alpha: 0.12)
                                : isAgent
                                    ? AdminColors.primaryBlue
                                        .withValues(alpha: 0.12)
                                    : colors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: m.isInternal
                                  ? colors.warning
                                  : colors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    m.isInternal
                                        ? 'Internal note'
                                        : (m.authorName.isEmpty
                                            ? m.authorEmail
                                            : m.authorName),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (m.readByUser || m.readByAgent)
                                    Icon(
                                      Icons.done_all,
                                      size: 14,
                                      color: colors.textMuted,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(m.body),
                              if (m.createdAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  fmt.format(m.createdAt!),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilterChip(
                label: const Text('Internal note'),
                selected: _internal,
                onSelected: (v) => setState(() => _internal = v),
              ),
              const SizedBox(width: 8),
              Text(
                _internal
                    ? 'Never visible to end users'
                    : 'Visible on support thread',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _reply,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: _internal
                        ? 'Add internal note…'
                        : 'Reply to customer…',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CfButton(
                label: 'Send',
                onPressed: () async {
                  final text = _reply.text;
                  _reply.clear();
                  await controller.postReply(text, internal: _internal);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaGrid extends StatelessWidget {
  const _MetaGrid({required this.ticket, required this.fmt});
  final ManagedSupportTicket ticket;
  final DateFormat fmt;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Created by', ticket.createdByEmail),
      ('Assigned', ticket.assignedToName ?? 'Unassigned'),
      ('Device', ticket.deviceInfo.isEmpty ? '—' : ticket.deviceInfo),
      ('App version', ticket.appVersion.isEmpty ? '—' : ticket.appVersion),
      ('OS', ticket.os.isEmpty ? '—' : ticket.os),
      ('Platform', ticket.platform.isEmpty ? '—' : ticket.platform),
      ('Country', ticket.country.isEmpty ? '—' : ticket.country),
      ('State', ticket.stateProvince.isEmpty ? '—' : ticket.stateProvince),
      ('City', ticket.city.isEmpty ? '—' : ticket.city),
      (
        'Created',
        ticket.createdAt == null ? '—' : fmt.format(ticket.createdAt!),
      ),
      (
        'Updated',
        ticket.updatedAt == null ? '—' : fmt.format(ticket.updatedAt!),
      ),
      (
        'SLA',
        ticket.isOverdue
            ? 'Overdue'
            : (ticket.slaDueAt == null ? '—' : fmt.format(ticket.slaDueAt!)),
      ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final i in items)
          SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i.$1,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.adminColors.textMuted,
                  ),
                ),
                Text(i.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        if (ticket.attachments.isNotEmpty)
          Text('Attachments: ${ticket.attachments.length}'),
        if (ticket.screenshots.isNotEmpty)
          Text('Screenshots: ${ticket.screenshots.length}'),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
