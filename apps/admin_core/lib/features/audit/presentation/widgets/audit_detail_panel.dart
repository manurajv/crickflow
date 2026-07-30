import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../models/audit_log_view.dart';
import 'audit_chrome.dart';

class AuditDetailPanel extends StatelessWidget {
  const AuditDetailPanel({
    super.key,
    required this.log,
    required this.onClose,
  });

  final AuditLogView log;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final df = DateFormat.yMMMd().add_jm();

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 440,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Audit Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy ID',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: log.id));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Log ID copied')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(
                    log.actionLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AuditModuleBadge(module: log.module),
                      AuditSeverityBadge(severity: log.severity),
                      AuditStatusBadge(status: log.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    log.description,
                    style: TextStyle(color: colors.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  _row('Performed by', log.actorEmail.isEmpty
                      ? log.actorUid
                      : '${log.actorEmail}\n${log.actorUid}'),
                  _row('Role', log.role.isEmpty ? '—' : log.role),
                  _row('Target', log.targetLabel),
                  _row('Target ID', log.targetUid.isEmpty ? '—' : log.targetUid),
                  _row('Timestamp', df.format(log.timestamp)),
                  _row('Session ID', log.sessionId.isEmpty ? '—' : log.sessionId),
                  if (log.reason?.isNotEmpty == true)
                    _row('Reason', log.reason!),
                  const SizedBox(height: 12),
                  Text(
                    'Values',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _row('Old value', log.oldValue ?? '—'),
                  _row('New value', log.newValue ?? '—'),
                  const SizedBox(height: 12),
                  Text(
                    'Client context',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _row('IP Address', log.ipAddress.isEmpty ? '—' : log.ipAddress),
                  _row('Location', log.locationLabel),
                  _row('Browser', log.browser.isEmpty ? '—' : log.browser),
                  _row(
                    'Operating System',
                    log.operatingSystem.isEmpty ? '—' : log.operatingSystem,
                  ),
                  _row('Device', log.device.isEmpty ? '—' : log.device),
                  _row('Platform', log.platform.isEmpty ? '—' : log.platform),
                  _row(
                    'User Agent',
                    log.userAgent.isEmpty ? '—' : log.userAgent,
                  ),
                  if (log.organizationId != null) ...[
                    const SizedBox(height: 12),
                    _row('Organization', log.organizationId!),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      'Audit logs are immutable. Administrators cannot edit '
                      'or delete entries from this panel.',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
