import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_loading_state.dart';
import '../../shell/providers/shell_providers.dart';
import '../providers/settings_providers.dart';
import 'widgets/settings_chrome.dart';
import 'widgets/settings_section_body.dart';

/// Platform Settings hub — Super Admin writes; Org Admin read-only.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    this.initialSection = SettingsHubSection.dashboard,
    this.cmsMode = false,
  });

  final SettingsHubSection initialSection;

  /// When true, shows CMS-focused sections and uses CMS permission.
  final bool cmsMode;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(breadcrumbProvider.notifier).state = widget.cmsMode
          ? ['Platform', 'CMS']
          : ['Settings', 'Platform Settings'];
      ref.read(settingsHubControllerProvider.notifier).ensureBootstrapped(
            initialSection: widget.initialSection,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsHubControllerProvider);
    final controller = ref.read(settingsHubControllerProvider.notifier);
    final sections = widget.cmsMode
        ? SettingsHubSection.cmsFocused
        : SettingsHubSection.values;

    return PermissionGate(
      permission: widget.cmsMode
          ? AdminPermission.canManageCms
          : AdminPermission.canManageSettings,
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.cmsMode
                            ? 'Content Management'
                            : 'Platform Settings',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.cmsMode
                            ? 'Manage CMS pages, legal content, contact and social links'
                            : 'Central control panel for CrickFlow platform configuration',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                CfButton(
                  label: 'Refresh',
                  icon: Icons.refresh,
                  variant: CfButtonVariant.secondary,
                  onPressed: state.isLoading ? null : controller.refresh,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!state.canWrite) ...[
              const SettingsReadOnlyBanner(),
              const SizedBox(height: 12),
            ],
            SettingsSectionChips(
              section: state.section,
              sections: sections,
              onSelect: controller.setSection,
            ),
            const SizedBox(height: 16),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(child: Text(state.error!)),
                        CfButton(
                          label: 'Retry',
                          onPressed: controller.refresh,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (state.isLoading && !state.bootstrapped)
              const SizedBox(
                height: 240,
                child: CfLoadingState(message: 'Loading settings…'),
              )
            else if (state.isLoading)
              Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  const SettingsSectionBody(),
                ],
              )
            else
              const SettingsSectionBody(),
          ],
        ),
      ),
    );
  }
}

/// Dedicated CMS route (`/cms`) — Super Admin only in nav.
class CmsScreen extends StatelessWidget {
  const CmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen(
      cmsMode: true,
      initialSection: SettingsHubSection.cms,
    );
  }
}
