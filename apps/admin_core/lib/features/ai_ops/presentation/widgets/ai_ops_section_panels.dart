import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../models/ai_ops_enums.dart';
import '../../models/managed_ai_ops.dart';
import 'ai_ops_summary_cards.dart';

class AiInsightsGrid extends StatelessWidget {
  const AiInsightsGrid({super.key, required this.insights});

  final List<AiInsightCard> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 200,
          child: CfEmptyState(
            icon: Icons.insights_outlined,
            title: 'No insights yet',
            message: 'Future AI will generate growth, inactivity, and trend cards.',
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100
            ? 3
            : c.maxWidth >= 700
                ? 2
                : 1;
        const spacing = 12.0;
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final i in insights)
              SizedBox(
                width: w,
                child: CfCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.adminColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        i.value,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (i.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          i.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.adminColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AiJobsPanel extends StatelessWidget {
  const AiJobsPanel({super.key, required this.jobs});

  final List<AiJob> jobs;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 200,
          child: CfEmptyState(
            icon: Icons.schedule,
            title: 'No AI jobs',
            message: 'Schedule or run a manual scan to queue batch work.',
          ),
        ),
      );
    }
    final fmt = DateFormat.yMMMd().add_jm();
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final j in jobs)
            Material(
              child: ListTile(
                leading: Icon(switch (j.status) {
                  AiJobStatus.running => Icons.play_circle_outline,
                  AiJobStatus.completed => Icons.check_circle_outline,
                  AiJobStatus.failed => Icons.error_outline,
                  AiJobStatus.cancelled => Icons.cancel_outlined,
                  AiJobStatus.scheduled => Icons.schedule,
                }),
                title: Text(j.kind.label),
                subtitle: Text(
                  '${j.status.label}\n${j.note}'
                  '${j.scheduledAt == null ? '' : '\n${fmt.format(j.scheduledAt!)}'}',
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }
}

class AiModelsPanel extends StatelessWidget {
  const AiModelsPanel({super.key, required this.models});

  final List<AiModelRegistryEntry> models;

  @override
  Widget build(BuildContext context) {
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Provider registry — credentials never stored in the admin client. '
              'Wire Cloud Functions / Secret Manager later.',
              style: TextStyle(
                fontSize: 12,
                color: context.adminColors.textMuted,
              ),
            ),
          ),
          for (final m in models)
            Material(
              child: ListTile(
                title: Text(m.name),
                subtitle: Text(
                  '${m.provider.label} · v${m.version}\n'
                  '${m.capabilities.join(', ')}\n${m.note}',
                ),
                isThreeLine: true,
                trailing: Text(
                  m.status.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AiLogsPanel extends StatelessWidget {
  const AiLogsPanel({super.key, required this.logs});

  final List<AiOpsLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 200,
          child: CfEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No AI logs yet',
            message: 'Approvals, rules, and jobs appear here.',
          ),
        ),
      );
    }
    final fmt = DateFormat.yMMMd().add_jm();
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final l in logs)
            Material(
              child: ListTile(
                title: Text(l.action.label),
                subtitle: Text(
                  '${l.recommendation}\n'
                  '${l.actorEmail.isEmpty ? '—' : l.actorEmail}'
                  '${l.timestamp == null ? '' : ' · ${fmt.format(l.timestamp!)}'}'
                  '${l.detail.isEmpty ? '' : '\n${l.detail}'}',
                ),
                isThreeLine: true,
                trailing: AiStatusBadge(status: l.status),
              ),
            ),
        ],
      ),
    );
  }
}

class AiSettingsPanel extends StatelessWidget {
  const AiSettingsPanel({
    super.key,
    required this.settings,
    required this.canEdit,
    required this.onChanged,
    required this.onSave,
  });

  final AiOpsSettings settings;
  final bool canEdit;
  final ValueChanged<AiOpsSettings> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'AI feature flags',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            canEdit
                ? 'Super Admin only — mirrors admin_feature_flags'
                : 'Read-only for organization admins',
            style: TextStyle(fontSize: 12, color: context.adminColors.textMuted),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Enable AI'),
            value: settings.enableAi,
            onChanged: canEdit
                ? (v) => onChanged(settings.copyWith(enableAi: v))
                : null,
          ),
          SwitchListTile(
            title: const Text('Enable Automation'),
            value: settings.enableAutomation,
            onChanged: canEdit
                ? (v) => onChanged(settings.copyWith(enableAutomation: v))
                : null,
          ),
          SwitchListTile(
            title: const Text('Enable Smart Reports'),
            value: settings.enableSmartReports,
            onChanged: canEdit
                ? (v) => onChanged(settings.copyWith(enableSmartReports: v))
                : null,
          ),
          SwitchListTile(
            title: const Text('Enable Spam Detection'),
            value: settings.enableSpamDetection,
            onChanged: canEdit
                ? (v) => onChanged(settings.copyWith(enableSpamDetection: v))
                : null,
          ),
          SwitchListTile(
            title: const Text('Enable Recommendations'),
            value: settings.enableRecommendations,
            onChanged: canEdit
                ? (v) => onChanged(settings.copyWith(enableRecommendations: v))
                : null,
          ),
          SwitchListTile(
            title: const Text('Enable Duplicate Detection'),
            value: settings.enableDuplicateDetection,
            onChanged: canEdit
                ? (v) =>
                    onChanged(settings.copyWith(enableDuplicateDetection: v))
                : null,
          ),
          SwitchListTile(
            title: const Text('Enable Fraud Detection'),
            value: settings.enableFraudDetection,
            onChanged: canEdit
                ? (v) => onChanged(settings.copyWith(enableFraudDetection: v))
                : null,
          ),
          DropdownButtonFormField<AiProviderId>(
            // ignore: deprecated_member_use
            value: settings.preferredProvider,
            decoration: const InputDecoration(labelText: 'Preferred provider'),
            items: [
              for (final p in AiProviderId.values)
                DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: canEdit
                ? (v) => onChanged(
                      settings.copyWith(preferredProvider: v),
                    )
                : null,
          ),
          const SizedBox(height: 12),
          if (canEdit) CfButton(label: 'Save settings', onPressed: onSave),
        ],
      ),
    );
  }
}
