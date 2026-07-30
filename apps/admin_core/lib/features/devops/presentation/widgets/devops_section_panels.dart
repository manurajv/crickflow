import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../models/devops_enums.dart';
import '../../models/managed_devops.dart';
import 'devops_chrome.dart';

class DevOpsReleasesPanel extends StatelessWidget {
  const DevOpsReleasesPanel({
    super.key,
    required this.releases,
    required this.canManage,
    required this.onCreate,
    required this.onDuplicate,
    required this.onStatus,
    required this.onSelect,
    this.selectedId,
    this.showNotes = false,
  });

  final List<ManagedRelease> releases;
  final bool canManage;
  final VoidCallback onCreate;
  final ValueChanged<ManagedRelease> onDuplicate;
  final void Function(ManagedRelease, DevOpsReleaseStatus) onStatus;
  final ValueChanged<String> onSelect;
  final String? selectedId;
  final bool showNotes;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: CfButton(
              label: 'Create Release',
              icon: Icons.add,
              onPressed: onCreate,
            ),
          ),
        const SizedBox(height: 12),
        if (releases.isEmpty)
          const CfEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No releases yet',
            message:
                'Create draft releases here. Publishing is metadata only — '
                'CI/CD integrations deploy later.',
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            variant: CfCardVariant.list,
            child: Column(
              children: [
                for (final r in releases)
                  ListTile(
                    selected: selectedId == r.id,
                    onTap: () => onSelect(r.id),
                    title: Text('${r.version} · ${r.title}'),
                    subtitle: Text(
                      showNotes
                          ? r.summary
                          : '${r.environment.label} · ${r.releaseType.label}'
                              '${r.releaseDate != null ? ' · ${df.format(r.releaseDate!)}' : ''}'
                              '${r.authorEmail.isNotEmpty ? ' · ${r.authorEmail}' : ''}',
                      maxLines: showNotes ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DevOpsStatusChip(label: r.status.label),
                        if (canManage)
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              switch (v) {
                                case 'dup':
                                  onDuplicate(r);
                                case 'publish':
                                  onStatus(r, DevOpsReleaseStatus.published);
                                case 'schedule':
                                  onStatus(r, DevOpsReleaseStatus.scheduled);
                                case 'cancel':
                                  onStatus(r, DevOpsReleaseStatus.cancelled);
                                case 'archive':
                                  onStatus(r, DevOpsReleaseStatus.archived);
                                case 'draft':
                                  onStatus(r, DevOpsReleaseStatus.draft);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'dup', child: Text('Duplicate')),
                              PopupMenuItem(
                                value: 'publish',
                                child: Text('Mark published'),
                              ),
                              PopupMenuItem(
                                value: 'schedule',
                                child: Text('Schedule'),
                              ),
                              PopupMenuItem(
                                value: 'draft',
                                child: Text('Back to draft'),
                              ),
                              PopupMenuItem(
                                value: 'cancel',
                                child: Text('Cancel'),
                              ),
                              PopupMenuItem(
                                value: 'archive',
                                child: Text('Archive'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (showNotes && selectedId != null) ...[
          const SizedBox(height: 16),
          _ReleaseNotesCard(
            release: () {
              for (final r in releases) {
                if (r.id == selectedId) return r;
              }
              return null;
            }(),
          ),
        ],
      ],
    );
  }
}

class _ReleaseNotesCard extends StatelessWidget {
  const _ReleaseNotesCard({required this.release});

  final ManagedRelease? release;

  @override
  Widget build(BuildContext context) {
    final r = release;
    if (r == null) return const SizedBox.shrink();
    Widget block(String title, List<String> lines) {
      if (lines.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final l in lines) Text('• $l'),
          ],
        ),
      );
    }

    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Release notes — ${r.version}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(r.summary),
          const SizedBox(height: 12),
          block('New features', r.newFeatures),
          block('Bug fixes', r.bugFixes),
          block('Breaking changes', r.breakingChanges),
          block('Known issues', r.knownIssues),
        ],
      ),
    );
  }
}

class DevOpsBuildsPanel extends StatelessWidget {
  const DevOpsBuildsPanel({super.key, required this.builds});

  final List<ManagedBuild> builds;

  @override
  Widget build(BuildContext context) {
    if (builds.isEmpty) {
      return const CfEmptyState(
        icon: Icons.handyman_outlined,
        title: 'No builds yet',
        message:
            'Build Monitor is ready for GitHub Actions / Cloud Build webhooks.',
      );
    }
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final b in builds)
            ListTile(
              title: Text(b.label),
              subtitle: Text(
                '${b.environment.label} · ${b.provider} · ${b.durationLabel}',
              ),
              trailing: DevOpsStatusChip(label: b.status.label),
            ),
        ],
      ),
    );
  }
}

class DevOpsDeploymentsPanel extends StatelessWidget {
  const DevOpsDeploymentsPanel({super.key, required this.logs});

  final List<ManagedDeploymentLog> logs;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();
    if (logs.isEmpty) {
      return const CfEmptyState(
        icon: Icons.rocket_launch_outlined,
        title: 'No deployment logs',
        message:
            'Logs appear when CI/CD posts deployment events. '
            'This panel never deploys automatically.',
      );
    }
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final d in logs)
            ListTile(
              title: Text('${d.label} · ${d.version}'),
              subtitle: Text(
                '${d.environment.label} · ${d.triggeredBy}'
                '${d.startedAt != null ? ' · ${df.format(d.startedAt!)}' : ''}'
                ' · ${d.durationLabel}',
              ),
              trailing: DevOpsStatusChip(label: d.status.label),
            ),
        ],
      ),
    );
  }
}

class DevOpsRolloutsPanel extends StatelessWidget {
  const DevOpsRolloutsPanel({
    super.key,
    required this.rollouts,
    required this.canManage,
    required this.onAdd,
    required this.onPause,
    required this.onPercent,
  });

  final List<ManagedRollout> rollouts;
  final bool canManage;
  final VoidCallback onAdd;
  final ValueChanged<ManagedRollout> onPause;
  final void Function(ManagedRollout, DevOpsRolloutPercent) onPercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Gradual rollout plans — Remote Config integration later. '
          'No automatic traffic shifting.',
          style: TextStyle(color: context.adminColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: CfButton(
              label: 'New rollout plan',
              icon: Icons.add,
              onPressed: onAdd,
            ),
          ),
        const SizedBox(height: 12),
        if (rollouts.isEmpty)
          const CfEmptyState(
            icon: Icons.tune,
            title: 'No rollouts',
            message: 'Plan Internal → 5% → … → 100% here for future RC.',
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final r in rollouts)
                  ListTile(
                    title: Text(r.title),
                    subtitle: Text(
                      '${r.featureKey} · ${r.environment.label} · ${r.percent.label}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DevOpsStatusChip(label: r.status.label),
                        if (canManage)
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'pause') {
                                onPause(r);
                              } else {
                                onPercent(
                                  r,
                                  DevOpsRolloutPercent.parse(v),
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'pause',
                                child: Text('Pause'),
                              ),
                              for (final p in DevOpsRolloutPercent.values)
                                PopupMenuItem(
                                  value: p.wireValue,
                                  child: Text('Set ${p.label}'),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class DevOpsRollbackPanel extends StatelessWidget {
  const DevOpsRollbackPanel({
    super.key,
    required this.plans,
    required this.canManage,
    required this.onPrepare,
  });

  final List<ManagedRollbackPlan> plans;
  final bool canManage;
  final VoidCallback onPrepare;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Rollback Center prepares targets only — never executes automatic rollback.',
          style: TextStyle(color: context.adminColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: CfButton(
              label: 'Prepare rollback',
              icon: Icons.undo,
              variant: CfButtonVariant.secondary,
              onPressed: onPrepare,
            ),
          ),
        const SizedBox(height: 12),
        if (plans.isEmpty)
          const CfEmptyState(
            icon: Icons.history,
            title: 'No rollback plans',
            message: 'Prepare a target version and reason for audit trail.',
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final p in plans)
                  ListTile(
                    title: Text('${p.fromVersion} → ${p.targetVersion}'),
                    subtitle: Text(
                      '${p.environment.label} · ${p.status} · ${p.reason}',
                    ),
                    trailing: DevOpsStatusChip(label: p.status),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class DevOpsDomainsPanel extends StatelessWidget {
  const DevOpsDomainsPanel({super.key, required this.domains});

  final List<ManagedDomain> domains;

  @override
  Widget build(BuildContext context) {
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final d in domains)
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: Text(d.host),
              subtitle: Text(
                'SSL: ${d.ssl} · DNS: ${d.dns}'
                '${d.note.isNotEmpty ? ' · ${d.note}' : ''}',
              ),
              trailing: DevOpsStatusChip(label: d.status.label),
            ),
        ],
      ),
    );
  }
}

class DevOpsEnvVarsPanel extends StatelessWidget {
  const DevOpsEnvVarsPanel({
    super.key,
    required this.vars,
    required this.canManage,
    required this.onAdd,
  });

  final List<ManagedEnvVar> vars;
  final bool canManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Keys and configuration status only. Secrets and credentials are never stored or shown.',
          style: TextStyle(color: context.adminColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: CfButton(
              label: 'Register key metadata',
              icon: Icons.vpn_key_outlined,
              variant: CfButtonVariant.secondary,
              onPressed: onAdd,
            ),
          ),
        const SizedBox(height: 12),
        if (vars.isEmpty)
          const CfEmptyState(
            icon: Icons.password_outlined,
            title: 'No env var metadata',
            message: 'Register key names per environment for validation tracking.',
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final v in vars)
                  ListTile(
                    title: Text(v.key),
                    subtitle: Text(
                      '${v.environment.label} · ${v.validation}',
                    ),
                    trailing: Text(
                      v.maskedValue,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class DevOpsTimelinePanel extends StatelessWidget {
  const DevOpsTimelinePanel({super.key, required this.events});

  final List<ManagedTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();
    if (events.isEmpty) {
      return const CfEmptyState(
        icon: Icons.timeline,
        title: 'No timeline events',
        message: 'Release and environment actions appear here.',
      );
    }
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final e in events)
            ListTile(
              leading: const Icon(Icons.circle, size: 10),
              title: Text(e.title),
              subtitle: Text(
                '${e.kind.label} · ${e.environment.label}'
                '${e.actorEmail.isNotEmpty ? ' · ${e.actorEmail}' : ''}'
                '${e.at != null ? ' · ${df.format(e.at!)}' : ''}',
              ),
            ),
        ],
      ),
    );
  }
}

class DevOpsEnvironmentsPanel extends StatefulWidget {
  const DevOpsEnvironmentsPanel({
    super.key,
    required this.settings,
    required this.canEdit,
    required this.onSave,
  });

  final DevOpsPlatformSettings settings;
  final bool canEdit;
  final ValueChanged<DevOpsPlatformSettings> onSave;

  @override
  State<DevOpsEnvironmentsPanel> createState() =>
      _DevOpsEnvironmentsPanelState();
}

class _DevOpsEnvironmentsPanelState extends State<DevOpsEnvironmentsPanel> {
  late DevOpsEnvironment _active;
  late final TextEditingController _current;
  late final TextEditingController _latest;

  @override
  void initState() {
    super.initState();
    _active = widget.settings.activeEnvironment;
    _current = TextEditingController(text: widget.settings.currentVersion);
    _latest = TextEditingController(text: widget.settings.latestVersion);
  }

  @override
  void dispose() {
    _current.dispose();
    _latest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final canEdit = widget.canEdit;
    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Environments must stay isolated — never mix production and development settings.',
            style: TextStyle(color: context.adminColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in DevOpsEnvironment.values)
                FilterChip(
                  label: Text(e.label),
                  selected: _active == e,
                  onSelected: canEdit
                      ? (_) => setState(() => _active = e)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _current,
            enabled: canEdit,
            decoration: const InputDecoration(labelText: 'Current version'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _latest,
            enabled: canEdit,
            decoration: const InputDecoration(labelText: 'Latest version'),
          ),
          const SizedBox(height: 12),
          Text('Firebase project: ${settings.firebaseProjectId}'),
          Text(settings.hostingNote),
          if (canEdit) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: CfButton(
                label: 'Save environment metadata',
                onPressed: () => widget.onSave(
                  DevOpsPlatformSettings(
                    activeEnvironment: _active,
                    currentVersion: _current.text.trim().isEmpty
                        ? settings.currentVersion
                        : _current.text.trim(),
                    latestVersion: _latest.text.trim().isEmpty
                        ? settings.latestVersion
                        : _latest.text.trim(),
                    firebaseProjectId: settings.firebaseProjectId,
                    hostingNote: settings.hostingNote,
                    qualityGates: settings.qualityGates,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DevOpsQualityGatesPanel extends StatelessWidget {
  const DevOpsQualityGatesPanel({
    super.key,
    required this.settings,
    required this.canEdit,
    required this.onToggle,
  });

  final DevOpsPlatformSettings settings;
  final bool canEdit;
  final void Function(QualityGateItem gate, bool passed) onToggle;

  @override
  Widget build(BuildContext context) {
    final gates = settings.qualityGates.isEmpty
        ? DevOpsPlatformSettings.defaultQualityGates
        : settings.qualityGates;
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Pre-production checklist — manual verification only. '
              'Does not deploy or mutate Firebase automatically.',
              style: TextStyle(color: context.adminColors.textSecondary),
            ),
          ),
          for (final g in gates)
            CheckboxListTile(
              value: g.passed,
              onChanged: canEdit ? (v) => onToggle(g, v ?? false) : null,
              title: Text(g.label),
              subtitle: g.note.isEmpty ? null : Text(g.note),
            ),
        ],
      ),
    );
  }
}
