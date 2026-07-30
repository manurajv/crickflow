import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/platform_settings.dart';
import '../../providers/settings_providers.dart';
import 'settings_chrome.dart';

class SettingsSectionBody extends ConsumerWidget {
  const SettingsSectionBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsHubControllerProvider);
    final snap = state.snapshot;
    final canWrite = state.canWrite;

    return switch (state.section) {
      SettingsHubSection.dashboard => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsDashboardCards(dashboard: snap.dashboard),
            const SizedBox(height: 20),
            SettingsSectionCard(
              title: 'Quick overview',
              subtitle:
                  'Platform control center — versions, flags, maintenance, and CMS.',
              child: Text(
                'Use the section chips above to manage general settings, '
                'feature flags, remote configuration, maintenance mode, '
                'CMS content, and legal page copy. '
                'Existing Privacy Policy and Terms URLs are never modified.',
                style: TextStyle(
                  color: context.adminColors.textMuted,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      SettingsHubSection.general => _GeneralPanel(
          general: snap.settings.general,
          canWrite: canWrite,
        ),
      SettingsHubSection.branding => _BrandingPanel(
          branding: snap.settings.branding,
          canWrite: canWrite,
        ),
      SettingsHubSection.remoteConfig => _RemoteConfigPanel(
          entries: snap.remoteConfig,
          canWrite: canWrite,
        ),
      SettingsHubSection.featureFlags => _FeatureFlagsPanel(
          flags: snap.featureFlags,
          canWrite: canWrite,
        ),
      SettingsHubSection.appVersions => _AppVersionsPanel(
          versions: snap.versions,
          canWrite: canWrite,
        ),
      SettingsHubSection.maintenance => _MaintenancePanel(
          config: snap.maintenance,
          canWrite: canWrite,
        ),
      SettingsHubSection.cms => _CmsPagesPanel(
          pages: snap.cmsPages,
          canWrite: canWrite,
        ),
      SettingsHubSection.legal => _LegalPagesPanel(
          pages: snap.legalPages,
          canWrite: canWrite,
        ),
      SettingsHubSection.contact => _ContactPanel(
          contact: snap.settings.contact,
          canWrite: canWrite,
        ),
      SettingsHubSection.social => _SocialPanel(
          social: snap.settings.social,
          canWrite: canWrite,
        ),
      SettingsHubSection.apiConfig => _ApiConfigPanel(
          statuses: snap.apiStatuses,
        ),
      SettingsHubSection.firebaseConfig => _FirebaseStatusPanel(
          statuses: snap.firebaseStatuses,
        ),
      SettingsHubSection.backup => const _BackupPanel(),
      SettingsHubSection.systemPrefs => _SystemPrefsPanel(
          prefs: snap.settings.systemPrefs,
          canWrite: canWrite,
        ),
      SettingsHubSection.auditLog => const _SettingsAuditPanel(),
    };
  }
}

// ─── General ──────────────────────────────────────────────────────────────────

class _GeneralPanel extends ConsumerStatefulWidget {
  const _GeneralPanel({required this.general, required this.canWrite});

  final PlatformGeneralSettings general;
  final bool canWrite;

  @override
  ConsumerState<_GeneralPanel> createState() => _GeneralPanelState();
}

class _GeneralPanelState extends ConsumerState<_GeneralPanel> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final g = widget.general;
    _c = {
      'appName': TextEditingController(text: g.appName),
      'appShortName': TextEditingController(text: g.appShortName),
      'companyName': TextEditingController(text: g.companyName),
      'supportEmail': TextEditingController(text: g.supportEmail),
      'supportPhone': TextEditingController(text: g.supportPhone),
      'website': TextEditingController(text: g.website),
      'copyright': TextEditingController(text: g.copyright),
      'timezone': TextEditingController(text: g.timezone),
      'defaultLanguage': TextEditingController(text: g.defaultLanguage),
      'country': TextEditingController(text: g.country),
      'currency': TextEditingController(text: g.currency),
      'dateFormat': TextEditingController(text: g.dateFormat),
      'timeFormat': TextEditingController(text: g.timeFormat),
      'logoUrl': TextEditingController(text: g.logoUrl),
      'appIconUrl': TextEditingController(text: g.appIconUrl),
      'splashLogoUrl': TextEditingController(text: g.splashLogoUrl),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final draft = PlatformGeneralSettings(
      appName: _c['appName']!.text,
      appShortName: _c['appShortName']!.text,
      companyName: _c['companyName']!.text,
      supportEmail: _c['supportEmail']!.text,
      supportPhone: _c['supportPhone']!.text,
      website: _c['website']!.text,
      copyright: _c['copyright']!.text,
      timezone: _c['timezone']!.text,
      defaultLanguage: _c['defaultLanguage']!.text,
      country: _c['country']!.text,
      currency: _c['currency']!.text,
      dateFormat: _c['dateFormat']!.text,
      timeFormat: _c['timeFormat']!.text,
      logoUrl: _c['logoUrl']!.text,
      appIconUrl: _c['appIconUrl']!.text,
      splashLogoUrl: _c['splashLogoUrl']!.text,
    );
    try {
      await ref
          .read(settingsHubControllerProvider.notifier)
          .saveGeneral(draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('General settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'General Settings',
      subtitle: 'Application identity, support contacts, and regional defaults.',
      trailing: widget.canWrite
          ? CfButton(label: 'Save', icon: Icons.save_outlined, onPressed: _save)
          : null,
      child: Column(
        children: [
          if (!widget.canWrite) ...[
            const SettingsReadOnlyBanner(),
            const SizedBox(height: 12),
          ],
          _grid([
            _field('Application Name', _c['appName']!, enabled: widget.canWrite),
            _field('Short Name', _c['appShortName']!, enabled: widget.canWrite),
            _field('Company Name', _c['companyName']!, enabled: widget.canWrite),
            _field('Support Email', _c['supportEmail']!, enabled: widget.canWrite),
            _field('Support Phone', _c['supportPhone']!, enabled: widget.canWrite),
            _field('Website', _c['website']!, enabled: widget.canWrite),
            _field('Copyright', _c['copyright']!, enabled: widget.canWrite),
            _field('Timezone', _c['timezone']!, enabled: widget.canWrite),
            _field('Default Language', _c['defaultLanguage']!, enabled: widget.canWrite),
            _field('Country', _c['country']!, enabled: widget.canWrite),
            _field('Currency', _c['currency']!, enabled: widget.canWrite),
            _field('Date Format', _c['dateFormat']!, enabled: widget.canWrite),
            _field('Time Format', _c['timeFormat']!, enabled: widget.canWrite),
            _field('Logo URL', _c['logoUrl']!, enabled: widget.canWrite),
            _field('App Icon URL', _c['appIconUrl']!, enabled: widget.canWrite),
            _field('Splash Logo URL', _c['splashLogoUrl']!, enabled: widget.canWrite),
          ]),
        ],
      ),
    );
  }
}

// ─── Branding ─────────────────────────────────────────────────────────────────

class _BrandingPanel extends ConsumerStatefulWidget {
  const _BrandingPanel({required this.branding, required this.canWrite});

  final PlatformBrandingSettings branding;
  final bool canWrite;

  @override
  ConsumerState<_BrandingPanel> createState() => _BrandingPanelState();
}

class _BrandingPanelState extends ConsumerState<_BrandingPanel> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final b = widget.branding;
    _c = {
      'primaryColor': TextEditingController(text: b.primaryColor),
      'secondaryColor': TextEditingController(text: b.secondaryColor),
      'accentColor': TextEditingController(text: b.accentColor),
      'darkPrimary': TextEditingController(text: b.darkPrimary),
      'darkSecondary': TextEditingController(text: b.darkSecondary),
      'darkAccent': TextEditingController(text: b.darkAccent),
      'lightPrimary': TextEditingController(text: b.lightPrimary),
      'lightSecondary': TextEditingController(text: b.lightSecondary),
      'lightAccent': TextEditingController(text: b.lightAccent),
      'placeholderImageUrl':
          TextEditingController(text: b.placeholderImageUrl),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final draft = PlatformBrandingSettings(
      primaryColor: _c['primaryColor']!.text,
      secondaryColor: _c['secondaryColor']!.text,
      accentColor: _c['accentColor']!.text,
      darkPrimary: _c['darkPrimary']!.text,
      darkSecondary: _c['darkSecondary']!.text,
      darkAccent: _c['darkAccent']!.text,
      lightPrimary: _c['lightPrimary']!.text,
      lightSecondary: _c['lightSecondary']!.text,
      lightAccent: _c['lightAccent']!.text,
      placeholderImageUrl: _c['placeholderImageUrl']!.text,
    );
    try {
      await ref
          .read(settingsHubControllerProvider.notifier)
          .saveBranding(draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branding saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Branding',
      subtitle:
          'Configurable theme colors and asset URLs only — does not change mobile hard-coded themes.',
      trailing: widget.canWrite
          ? CfButton(label: 'Save', icon: Icons.save_outlined, onPressed: _save)
          : null,
      child: Column(
        children: [
          if (!widget.canWrite) ...[
            const SettingsReadOnlyBanner(),
            const SizedBox(height: 12),
          ],
          _grid([
            _field('Primary Color', _c['primaryColor']!, enabled: widget.canWrite),
            _field('Secondary Color', _c['secondaryColor']!, enabled: widget.canWrite),
            _field('Accent Color', _c['accentColor']!, enabled: widget.canWrite),
            _field('Dark Primary', _c['darkPrimary']!, enabled: widget.canWrite),
            _field('Dark Secondary', _c['darkSecondary']!, enabled: widget.canWrite),
            _field('Dark Accent', _c['darkAccent']!, enabled: widget.canWrite),
            _field('Light Primary', _c['lightPrimary']!, enabled: widget.canWrite),
            _field('Light Secondary', _c['lightSecondary']!, enabled: widget.canWrite),
            _field('Light Accent', _c['lightAccent']!, enabled: widget.canWrite),
            _field(
              'Placeholder Image URL',
              _c['placeholderImageUrl']!,
              enabled: widget.canWrite,
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Feature flags ────────────────────────────────────────────────────────────

class _FeatureFlagsPanel extends ConsumerWidget {
  const _FeatureFlagsPanel({required this.flags, required this.canWrite});

  final List<ManagedFeatureFlag> flags;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSectionCard(
      title: 'Feature Flags',
      subtitle: 'Toggle platform features. New modules only need a new flag.',
      child: Column(
        children: [
          if (!canWrite) ...[
            const SettingsReadOnlyBanner(),
            const SizedBox(height: 12),
          ],
          for (final f in flags)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(f.label.isEmpty ? f.key : f.label),
              subtitle: Text(
                f.description,
                style: TextStyle(
                  fontSize: 12,
                  color: context.adminColors.textMuted,
                ),
              ),
              value: f.enabled,
              onChanged: !canWrite
                  ? null
                  : (v) async {
                      final key = FeatureFlagKey.values.firstWhere(
                        (k) => k.wireValue == f.key,
                        orElse: () => FeatureFlagKey.analytics,
                      );
                      try {
                        await ref
                            .read(settingsHubControllerProvider.notifier)
                            .setFeatureFlag(key, v);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
            ),
        ],
      ),
    );
  }
}

// ─── Remote config ────────────────────────────────────────────────────────────

class _RemoteConfigPanel extends ConsumerWidget {
  const _RemoteConfigPanel({required this.entries, required this.canWrite});

  final List<ManagedRemoteConfigEntry> entries;
  final bool canWrite;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    ManagedRemoteConfigEntry? existing,
  }) async {
    final keyCtrl = TextEditingController(text: existing?.key ?? '');
    final valueCtrl = TextEditingController(text: existing?.value ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    var type = existing?.valueType ?? RemoteConfigValueType.string;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Create Config' : 'Update Config'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyCtrl,
                  enabled: existing == null,
                  decoration: const InputDecoration(labelText: 'Key'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueCtrl,
                  decoration: const InputDecoration(labelText: 'Value'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<RemoteConfigValueType>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in RemoteConfigValueType.values)
                      DropdownMenuItem(value: t, child: Text(t.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => type = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final entry = ManagedRemoteConfigEntry(
      id: existing?.id ?? keyCtrl.text.trim(),
      key: keyCtrl.text.trim(),
      value: valueCtrl.text,
      description: descCtrl.text,
      valueType: type,
      enabled: existing?.enabled ?? true,
    );
    try {
      await ref
          .read(settingsHubControllerProvider.notifier)
          .upsertRemoteConfig(entry);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    return SettingsSectionCard(
      title: 'Remote Configuration',
      subtitle:
          'Admin mirror of remote config keys. Apply via Firebase Remote Config where appropriate.',
      trailing: canWrite
          ? CfButton(
              label: 'Create',
              icon: Icons.add,
              onPressed: () => _edit(context, ref),
            )
          : null,
      child: Column(
        children: [
          if (!canWrite) ...[
            const SettingsReadOnlyBanner(),
            const SizedBox(height: 12),
          ],
          if (entries.isEmpty)
            const CfEmptyState(
              icon: Icons.tune,
              title: 'No config entries',
              message: 'Create remote configuration keys to get started.',
            )
          else
            for (final e in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${e.description.isEmpty ? e.valueType.name : e.description} · ${e.value}',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: e.enabled,
                      onChanged: !canWrite
                          ? null
                          : (v) => ref
                              .read(settingsHubControllerProvider.notifier)
                              .setRemoteConfigEnabled(e.id, v),
                    ),
                    if (canWrite)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(context, ref, existing: e),
                      ),
                    if (canWrite)
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: colors.error),
                        onPressed: () async {
                          try {
                            await ref
                                .read(settingsHubControllerProvider.notifier)
                                .deleteRemoteConfig(e.id);
                          } catch (err) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$err')),
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ─── App versions ─────────────────────────────────────────────────────────────

class _AppVersionsPanel extends ConsumerWidget {
  const _AppVersionsPanel({required this.versions, required this.canWrite});

  final List<ManagedAppVersion> versions;
  final bool canWrite;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final latest = TextEditingController();
    final minimum = TextEditingController();
    final notes = TextEditingController();
    var platform = AppPlatform.both;
    var updateType = VersionUpdateType.soft;
    var isCurrent = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Publish Version'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AppPlatform>(
                  value: platform,
                  decoration: const InputDecoration(labelText: 'Platform'),
                  items: [
                    for (final p in AppPlatform.values)
                      DropdownMenuItem(value: p, child: Text(p.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => platform = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: latest,
                  decoration: const InputDecoration(labelText: 'Latest Version'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: minimum,
                  decoration:
                      const InputDecoration(labelText: 'Minimum Version'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<VersionUpdateType>(
                  value: updateType,
                  decoration: const InputDecoration(labelText: 'Update Type'),
                  items: [
                    for (final t in VersionUpdateType.values)
                      DropdownMenuItem(value: t, child: Text(t.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => updateType = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Release Notes'),
                  maxLines: 3,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mark as current'),
                  value: isCurrent,
                  onChanged: (v) => setLocal(() => isCurrent = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(settingsHubControllerProvider.notifier).createAppVersion(
            ManagedAppVersion(
              id: '',
              platform: platform,
              latestVersion: latest.text.trim(),
              minimumVersion: minimum.text.trim(),
              releaseNotes: notes.text.trim(),
              updateType: updateType,
              isCurrent: isCurrent,
              releaseDate: DateTime.now(),
            ),
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    final df = DateFormat.yMMMd();
    return SettingsSectionCard(
      title: 'App Version Management',
      subtitle: 'Soft update, force update, and release history.',
      trailing: canWrite
          ? CfButton(
              label: 'Publish',
              icon: Icons.system_update,
              onPressed: () => _create(context, ref),
            )
          : null,
      child: Column(
        children: [
          if (!canWrite) ...[
            const SettingsReadOnlyBanner(),
            const SizedBox(height: 12),
          ],
          if (versions.isEmpty)
            const CfEmptyState(
              icon: Icons.system_update_alt,
              title: 'No versions published',
              message: 'Publish Android / iOS version requirements here.',
            )
          else
            for (final v in versions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  v.platform == AppPlatform.ios
                      ? Icons.phone_iphone
                      : Icons.android,
                  color: AdminColors.primaryBlue,
                ),
                title: Text(
                  '${v.latestVersion}  ·  min ${v.minimumVersion}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${v.platform.name} · ${v.updateType.name}'
                  '${v.isCurrent ? ' · current' : ''}'
                  '${v.releaseDate != null ? ' · ${df.format(v.releaseDate!)}' : ''}',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
                trailing: v.releaseNotes.isEmpty
                    ? null
                    : Tooltip(
                        message: v.releaseNotes,
                        child: const Icon(Icons.notes_outlined),
                      ),
              ),
        ],
      ),
    );
  }
}

// ─── Maintenance ──────────────────────────────────────────────────────────────

class _MaintenancePanel extends ConsumerStatefulWidget {
  const _MaintenancePanel({required this.config, required this.canWrite});

  final MaintenanceConfig config;
  final bool canWrite;

  @override
  ConsumerState<_MaintenancePanel> createState() => _MaintenancePanelState();
}

class _MaintenancePanelState extends ConsumerState<_MaintenancePanel> {
  late bool _enabled;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late Set<MaintenanceBypassRole> _bypass;
  DateTime? _eta;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    _enabled = c.enabled;
    _title = TextEditingController(text: c.title);
    _description = TextEditingController(text: c.description);
    _bypass = {...c.bypassRoles};
    _eta = c.estimatedCompletion;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await ref.read(settingsHubControllerProvider.notifier).saveMaintenance(
            MaintenanceConfig(
              enabled: _enabled,
              title: _title.text,
              description: _description.text,
              estimatedCompletion: _eta,
              bypassRoles: _bypass,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maintenance settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Maintenance Mode',
      subtitle:
          'When enabled, non-bypass roles see the maintenance screen. Super Admin always bypasses.',
      trailing: widget.canWrite
          ? CfButton(label: 'Save', icon: Icons.save_outlined, onPressed: _save)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.canWrite) ...[
            const SettingsReadOnlyBanner(),
            const SizedBox(height: 12),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable maintenance mode'),
            value: _enabled,
            onChanged: !widget.canWrite
                ? null
                : (v) => setState(() => _enabled = v),
          ),
          TextField(
            controller: _title,
            enabled: widget.canWrite,
            decoration: const InputDecoration(labelText: 'Maintenance Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            enabled: widget.canWrite,
            decoration:
                const InputDecoration(labelText: 'Maintenance Description'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: !widget.canWrite
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _eta ?? DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _eta = picked);
                  },
            icon: const Icon(Icons.schedule),
            label: Text(
              _eta == null
                  ? 'Set estimated completion'
                  : 'ETA: ${DateFormat.yMMMd().add_jm().format(_eta!)}',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bypass roles',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.adminColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final role in MaintenanceBypassRole.values)
                FilterChip(
                  label: Text(role.name),
                  selected: _bypass.contains(role),
                  onSelected: !widget.canWrite
                      ? null
                      : (v) => setState(() {
                            if (v) {
                              _bypass.add(role);
                            } else {
                              _bypass.remove(role);
                            }
                          }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── CMS ──────────────────────────────────────────────────────────────────────

class _CmsPagesPanel extends ConsumerWidget {
  const _CmsPagesPanel({required this.pages, required this.canWrite});

  final List<ManagedCmsPage> pages;
  final bool canWrite;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ManagedCmsPage page,
  ) async {
    final title = TextEditingController(text: page.title);
    final body = TextEditingController(text: page.body);
    var published = page.published;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(page.kind.label),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: body,
                  decoration: const InputDecoration(labelText: 'Content'),
                  maxLines: 8,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Published'),
                  value: published,
                  onChanged: (v) => setLocal(() => published = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(settingsHubControllerProvider.notifier).saveCmsPage(
            ManagedCmsPage(
              id: page.id,
              kind: page.kind,
              title: title.text,
              body: body.text,
              published: published,
            ),
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    return SettingsSectionCard(
      title: 'CMS Pages',
      subtitle: 'Home, onboarding, FAQ, help center, and support content.',
      child: Column(
        children: [
          if (!canWrite) ...[
            const SettingsReadOnlyBanner(),
            const SizedBox(height: 12),
          ],
          for (final p in pages)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.kind.label),
              subtitle: Text(
                p.title.isEmpty ? 'No title' : p.title,
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(p.published ? 'Published' : 'Draft'),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (canWrite)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(context, ref, p),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Legal ────────────────────────────────────────────────────────────────────

class _LegalPagesPanel extends ConsumerWidget {
  const _LegalPagesPanel({required this.pages, required this.canWrite});

  final List<ManagedLegalPage> pages;
  final bool canWrite;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ManagedLegalPage page,
  ) async {
    final title = TextEditingController(text: page.title);
    final body = TextEditingController(text: page.body);
    var published = page.published;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(page.kind.label),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (page.kind.urlLocked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Existing public URL is locked and will never be changed by this editor. '
                      'Edit page content only.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                    ),
                  ),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: body,
                  decoration: const InputDecoration(labelText: 'Page Content'),
                  maxLines: 10,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Published'),
                  value: published,
                  onChanged: (v) => setLocal(() => published = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Content'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(settingsHubControllerProvider.notifier).saveLegalPage(
            ManagedLegalPage(
              id: page.id,
              kind: page.kind,
              title: title.text,
              body: body.text,
              existingUrlNote: page.existingUrlNote,
              published: published,
            ),
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    return SettingsSectionCard(
      title: 'Legal Pages',
      subtitle:
          'Edit page content only. Privacy Policy and Terms & Conditions URLs are never modified.',
      child: Column(
        children: [
          if (!canWrite) ...[
            const SettingsReadOnlyBanner(),
            const SizedBox(height: 12),
          ],
          for (final p in pages)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Flexible(child: Text(p.kind.label)),
                  if (p.kind.urlLocked) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.lock_outline, size: 14, color: colors.warning),
                  ],
                ],
              ),
              subtitle: Text(
                p.existingUrlNote.isNotEmpty
                    ? p.existingUrlNote
                    : (p.title.isEmpty ? 'No content yet' : p.title),
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
              trailing: canWrite
                  ? IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(context, ref, p),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

// ─── Contact / Social / System ────────────────────────────────────────────────

class _ContactPanel extends ConsumerStatefulWidget {
  const _ContactPanel({required this.contact, required this.canWrite});

  final PlatformContactSettings contact;
  final bool canWrite;

  @override
  ConsumerState<_ContactPanel> createState() => _ContactPanelState();
}

class _ContactPanelState extends ConsumerState<_ContactPanel> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _c = {
      'email': TextEditingController(text: c.email),
      'phone': TextEditingController(text: c.phone),
      'whatsapp': TextEditingController(text: c.whatsapp),
      'address': TextEditingController(text: c.address),
      'website': TextEditingController(text: c.website),
      'supportHours': TextEditingController(text: c.supportHours),
      'emergencyContact': TextEditingController(text: c.emergencyContact),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await ref.read(settingsHubControllerProvider.notifier).saveContact(
            PlatformContactSettings(
              email: _c['email']!.text,
              phone: _c['phone']!.text,
              whatsapp: _c['whatsapp']!.text,
              address: _c['address']!.text,
              website: _c['website']!.text,
              supportHours: _c['supportHours']!.text,
              emergencyContact: _c['emergencyContact']!.text,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact information saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Contact Information',
      trailing: widget.canWrite
          ? CfButton(label: 'Save', icon: Icons.save_outlined, onPressed: _save)
          : null,
      child: Column(
        children: [
          if (!widget.canWrite) ...[
            const SettingsReadOnlyBanner(),
            const SizedBox(height: 12),
          ],
          _grid([
            _field('Email', _c['email']!, enabled: widget.canWrite),
            _field('Phone', _c['phone']!, enabled: widget.canWrite),
            _field('WhatsApp', _c['whatsapp']!, enabled: widget.canWrite),
            _field('Address', _c['address']!, enabled: widget.canWrite),
            _field('Website', _c['website']!, enabled: widget.canWrite),
            _field('Support Hours', _c['supportHours']!, enabled: widget.canWrite),
            _field(
              'Emergency Contact',
              _c['emergencyContact']!,
              enabled: widget.canWrite,
            ),
          ]),
        ],
      ),
    );
  }
}

class _SocialPanel extends ConsumerStatefulWidget {
  const _SocialPanel({required this.social, required this.canWrite});

  final PlatformSocialSettings social;
  final bool canWrite;

  @override
  ConsumerState<_SocialPanel> createState() => _SocialPanelState();
}

class _SocialPanelState extends ConsumerState<_SocialPanel> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final s = widget.social;
    _c = {
      'facebook': TextEditingController(text: s.facebook),
      'instagram': TextEditingController(text: s.instagram),
      'youtube': TextEditingController(text: s.youtube),
      'linkedin': TextEditingController(text: s.linkedin),
      'x': TextEditingController(text: s.x),
      'tiktok': TextEditingController(text: s.tiktok),
      'website': TextEditingController(text: s.website),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await ref.read(settingsHubControllerProvider.notifier).saveSocial(
            PlatformSocialSettings(
              facebook: _c['facebook']!.text,
              instagram: _c['instagram']!.text,
              youtube: _c['youtube']!.text,
              linkedin: _c['linkedin']!.text,
              x: _c['x']!.text,
              tiktok: _c['tiktok']!.text,
              website: _c['website']!.text,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Social links saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Social Media',
      subtitle: 'Public profile links. Future platforms are easy to add.',
      trailing: widget.canWrite
          ? CfButton(label: 'Save', icon: Icons.save_outlined, onPressed: _save)
          : null,
      child: Column(
        children: [
          if (!widget.canWrite) ...[
            const SettingsReadOnlyBanner(),
            const SizedBox(height: 12),
          ],
          _grid([
            _field('Facebook', _c['facebook']!, enabled: widget.canWrite),
            _field('Instagram', _c['instagram']!, enabled: widget.canWrite),
            _field('YouTube', _c['youtube']!, enabled: widget.canWrite),
            _field('LinkedIn', _c['linkedin']!, enabled: widget.canWrite),
            _field('X', _c['x']!, enabled: widget.canWrite),
            _field('TikTok', _c['tiktok']!, enabled: widget.canWrite),
            _field('Website', _c['website']!, enabled: widget.canWrite),
          ]),
        ],
      ),
    );
  }
}

class _SystemPrefsPanel extends ConsumerStatefulWidget {
  const _SystemPrefsPanel({required this.prefs, required this.canWrite});

  final PlatformSystemPrefs prefs;
  final bool canWrite;

  @override
  ConsumerState<_SystemPrefsPanel> createState() => _SystemPrefsPanelState();
}

class _SystemPrefsPanelState extends ConsumerState<_SystemPrefsPanel> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final p = widget.prefs;
    _c = {
      'timezone': TextEditingController(text: p.timezone),
      'dateFormat': TextEditingController(text: p.dateFormat),
      'numberFormat': TextEditingController(text: p.numberFormat),
      'language': TextEditingController(text: p.language),
      'country': TextEditingController(text: p.country),
      'currency': TextEditingController(text: p.currency),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await ref.read(settingsHubControllerProvider.notifier).saveSystemPrefs(
            PlatformSystemPrefs(
              timezone: _c['timezone']!.text,
              dateFormat: _c['dateFormat']!.text,
              numberFormat: _c['numberFormat']!.text,
              language: _c['language']!.text,
              country: _c['country']!.text,
              currency: _c['currency']!.text,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('System preferences saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'System Preferences',
      subtitle: 'Regional defaults for timezone, formats, language, and currency.',
      trailing: widget.canWrite
          ? CfButton(label: 'Save', icon: Icons.save_outlined, onPressed: _save)
          : null,
      child: Column(
        children: [
          if (!widget.canWrite) ...[
            const SettingsReadOnlyBanner(),
            const SizedBox(height: 12),
          ],
          _grid([
            _field('Timezone', _c['timezone']!, enabled: widget.canWrite),
            _field('Date Format', _c['dateFormat']!, enabled: widget.canWrite),
            _field('Number Format', _c['numberFormat']!, enabled: widget.canWrite),
            _field('Language', _c['language']!, enabled: widget.canWrite),
            _field('Country', _c['country']!, enabled: widget.canWrite),
            _field('Currency', _c['currency']!, enabled: widget.canWrite),
          ]),
        ],
      ),
    );
  }
}

// ─── API / Firebase / Backup / Audit ──────────────────────────────────────────

class _ApiConfigPanel extends StatelessWidget {
  const _ApiConfigPanel({required this.statuses});

  final List<ApiServiceStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return SettingsSectionCard(
      title: 'API Configuration',
      subtitle:
          'Status only. API keys, OAuth secrets, tokens, and client secrets are never shown.',
      child: Column(
        children: [
          for (final s in statuses)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_statusIcon(s.status), color: _statusColor(s.status, colors)),
              title: Text(s.kind.label),
              subtitle: Text(
                'Key: ${s.maskedKey} · ${s.note}',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
              trailing: Chip(
                label: Text(s.status.name),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _FirebaseStatusPanel extends StatelessWidget {
  const _FirebaseStatusPanel({required this.statuses});

  final List<FirebaseServiceStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return SettingsSectionCard(
      title: 'Firebase Configuration',
      subtitle:
          'Read-only status dashboard. Existing Firebase project configuration is never modified.',
      child: Column(
        children: [
          for (final s in statuses)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_statusIcon(s.status), color: _statusColor(s.status, colors)),
              title: Text(s.kind.label),
              subtitle: Text(
                s.note,
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
              trailing: Chip(
                label: Text(s.status.name),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _BackupPanel extends StatelessWidget {
  const _BackupPanel();

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'Backup & Restore',
      subtitle: 'Future-ready export formats — no implementation required yet.',
      child: Column(
        children: [
          for (final item in [
            ('Settings Backup', Icons.backup_outlined),
            ('JSON Export', Icons.data_object),
            ('CSV Export', Icons.table_chart_outlined),
            ('PDF Export', Icons.picture_as_pdf_outlined),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(item.$2),
              title: Text(item.$1),
              trailing: const Chip(
                label: Text('Coming soon'),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsAuditPanel extends ConsumerWidget {
  const _SettingsAuditPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(settingsAuditProvider);
    final colors = context.adminColors;
    final df = DateFormat.yMMMd().add_jm();

    return SettingsSectionCard(
      title: 'Configuration Audit Log',
      subtitle: 'Every settings change with actor, timestamp, old/new values, and reason.',
      child: async.when(
        loading: () => const CfLoadingState(message: 'Loading audit…'),
        error: (e, _) => Text('$e'),
        data: (entries) {
          if (entries.isEmpty) {
            return const CfEmptyState(
              icon: Icons.history,
              title: 'No settings audit entries',
              message: 'Configuration changes will appear here.',
            );
          }
          return Column(
            children: [
              for (final e in entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    e.action,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${e.actorEmail} · ${df.format(e.timestamp)}'
                    '${e.reason?.isNotEmpty == true ? ' · ${e.reason}' : ''}'
                    '${e.metadata['oldValue'] != null ? '\n${e.metadata['oldValue']} → ${e.metadata['newValue']}' : ''}',
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

Widget _field(
  String label,
  TextEditingController controller, {
  bool enabled = true,
}) {
  return TextField(
    controller: controller,
    enabled: enabled,
    decoration: InputDecoration(labelText: label),
  );
}

Widget _grid(List<Widget> fields) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final twoCol = constraints.maxWidth >= 700;
      if (!twoCol) {
        return Column(
          children: [
            for (var i = 0; i < fields.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              fields[i],
            ],
          ],
        );
      }
      final rows = <Widget>[];
      for (var i = 0; i < fields.length; i += 2) {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fields[i]),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < fields.length ? fields[i + 1] : const SizedBox(),
              ),
            ],
          ),
        );
        rows.add(const SizedBox(height: 12));
      }
      return Column(children: rows);
    },
  );
}

IconData _statusIcon(ServiceHealthStatus status) => switch (status) {
      ServiceHealthStatus.healthy || ServiceHealthStatus.enabled =>
        Icons.check_circle_outline,
      ServiceHealthStatus.disabled => Icons.pause_circle_outline,
      ServiceHealthStatus.error => Icons.error_outline,
      ServiceHealthStatus.unknown => Icons.help_outline,
    };

Color _statusColor(ServiceHealthStatus status, dynamic colors) => switch (status) {
      ServiceHealthStatus.healthy || ServiceHealthStatus.enabled =>
        colors.success as Color,
      ServiceHealthStatus.disabled => colors.textMuted as Color,
      ServiceHealthStatus.error => colors.error as Color,
      ServiceHealthStatus.unknown => colors.warning as Color,
    };
