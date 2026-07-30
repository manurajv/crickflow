import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../models/admin_permission.dart';
import '../../../../models/admin_role.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../models/ground_enums.dart';
import '../../models/managed_ground.dart';
import '../../providers/grounds_providers.dart';
import 'ground_status_badge.dart';

class GroundDetailPanel extends ConsumerWidget {
  const GroundDetailPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedManagedGroundProvider);
    final colors = context.adminColors;
    final canManage = ref
        .watch(permissionCheckerProvider)
        .can(AdminPermission.canManageGrounds);

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 440,
        child: async.when(
          loading: () => const CfLoadingState(message: 'Loading ground…'),
          error: (e, _) => Center(child: Text('$e')),
          data: (ground) {
            if (ground == null) {
              return const Center(child: Text('Select a ground'));
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ground details',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
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
                      _Hero(ground: ground),
                      const SizedBox(height: 12),
                      _Overview(ground: ground),
                      const SizedBox(height: 16),
                      _Facilities(ground: ground),
                      const SizedBox(height: 16),
                      if (canManage) ...[
                        _Actions(ground: ground),
                        const SizedBox(height: 16),
                      ],
                      _AuditSection(),
                      const SizedBox(height: 16),
                      const _SectionTitle('Related (placeholders)'),
                      const SizedBox(height: 8),
                      const _PlaceholderList(
                        items: [
                          'Matches hosted',
                          'Bookings',
                          'Photo gallery',
                          'Reviews & ratings',
                          'Reports',
                          'Nearby grounds / clustering map',
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.ground});

  final ManagedGround ground;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final photo = ground.photoUrl;
    return Column(
      children: [
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colors.background,
            border: Border.all(color: colors.border),
            image: photo != null && photo.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(photo),
                    fit: BoxFit.cover,
                    onError: (_, _) {},
                  )
                : null,
          ),
          child: photo == null || photo.isEmpty
              ? Icon(Icons.stadium_outlined, color: colors.textMuted, size: 40)
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          ground.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(ground.shortLabel, style: TextStyle(color: colors.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            GroundStatusBadge(status: ground.displayStatus),
            GroundVerifiedBadge(verified: ground.isVerified),
            GroundFeaturedBadge(featured: ground.adminFeatured),
            if (ground.groundType != null)
              Chip(
                label: Text(ground.groundType!.label),
                visualDensity: VisualDensity.compact,
              ),
            Chip(
              label: Text(ground.availability.label),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.ground});

  final ManagedGround ground;

  @override
  Widget build(BuildContext context) {
    final g = ground;
    final rows = <MapEntry<String, String>>[
      MapEntry('Address', g.address.isEmpty ? '—' : g.address),
      MapEntry('Location', g.locationLabel),
      MapEntry(
        'Tournaments',
        g.tournamentIds.isEmpty
            ? '—'
            : '${g.tournamentIds.length}',
      ),
      MapEntry('PIN', g.pinCode.isEmpty ? '—' : g.pinCode),
      MapEntry(
        'Coordinates',
        g.hasCoordinates
            ? '${g.latitude!.toStringAsFixed(5)}, ${g.longitude!.toStringAsFixed(5)}'
            : '—',
      ),
      MapEntry(
        'Contact person',
        g.contactPerson.isEmpty ? '—' : g.contactPerson,
      ),
      MapEntry(
        'Contact',
        g.contactNumber.isEmpty ? '—' : g.contactNumber,
      ),
      MapEntry('Email', g.email.isEmpty ? '—' : g.email),
      MapEntry('Website', g.website.isEmpty ? '—' : g.website),
      MapEntry(
        'Owner',
        g.ownerName.isEmpty ? (g.ownerId ?? '—') : g.ownerName,
      ),
      MapEntry(
        'Established',
        g.establishedYear?.toString() ?? '—',
      ),
      MapEntry('Capacity', g.capacity?.toString() ?? '—'),
      MapEntry('Boundary', g.boundarySize ?? '—'),
      MapEntry('Pitch', g.pitchType?.label ?? '—'),
      MapEntry(
        'Ball types',
        g.ballTypes.isEmpty
            ? '—'
            : g.ballTypes.map((e) => e.label).join(', '),
      ),
      MapEntry('Floodlights', g.floodlights ? 'Yes' : 'No'),
      MapEntry('Parking', g.parking ? 'Yes' : 'No'),
      MapEntry('Matches hosted', '${g.matchesHosted}'),
      MapEntry(
        'Rating',
        g.rating <= 0
            ? '—'
            : '${g.rating.toStringAsFixed(1)} (${g.reviewCount})',
      ),
      if (g.isSoftDeleted)
        MapEntry(
          'Deleted at',
          g.deletedAt == null
              ? '—'
              : DateFormat('yyyy-MM-dd HH:mm').format(g.deletedAt!),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Overview'),
        const SizedBox(height: 8),
        if (g.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(g.description),
          ),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    row.key,
                    style: TextStyle(
                      color: context.adminColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Text(row.value)),
              ],
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () async {
            await launchUrl(
              Uri.parse(g.mapsUrl),
              mode: LaunchMode.externalApplication,
            );
          },
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Open in Google Maps'),
        ),
      ],
    );
  }
}

class _Facilities extends StatelessWidget {
  const _Facilities({required this.ground});

  final ManagedGround ground;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final facilities = ground.facilities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Facilities'),
        const SizedBox(height: 8),
        if (facilities.isEmpty)
          Text('No facilities listed', style: TextStyle(color: colors.textMuted))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in GroundFacilityKeys.all)
                if (facilities.contains(key))
                  Chip(
                    label: Text(GroundFacilityKeys.label(key)),
                    visualDensity: VisualDensity.compact,
                  ),
              for (final key in facilities)
                if (!GroundFacilityKeys.all.contains(key))
                  Chip(
                    label: Text(key),
                    visualDensity: VisualDensity.compact,
                  ),
            ],
          ),
      ],
    );
  }
}

class _AuditSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedGroundAuditProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Audit Log'),
        const SizedBox(height: 8),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (items) => items.isEmpty
              ? Text(
                  'No admin actions yet',
                  style: TextStyle(color: context.adminColors.textMuted),
                )
              : Column(
                  children: [
                    for (final item in items.take(20))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.action),
                        subtitle: Text(item.reason ?? item.actorEmail),
                        trailing: Text(
                          DateFormat('MMM d HH:mm').format(item.timestamp),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.ground});

  final ManagedGround ground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(groundsListControllerProvider.notifier);
    final isSuper =
        AdminRole.tryParse(ref.watch(adminSessionProvider).adminUser?.roleId) ==
            AdminRole.superAdmin;

    Future<void> confirmAction({
      required String title,
      required String message,
      required Future<void> Function(String? reason) run,
      bool danger = false,
    }) async {
      final reasonController = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                ),
              ),
            ],
          ),
          actions: [
            CfButton(
              label: 'Cancel',
              variant: CfButtonVariant.ghost,
              onPressed: () => Navigator.pop(context, false),
            ),
            CfButton(
              label: 'Confirm',
              variant:
                  danger ? CfButtonVariant.danger : CfButtonVariant.primary,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (ok == true) {
        await run(
          reasonController.text.trim().isEmpty
              ? null
              : reasonController.text.trim(),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title completed')),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Actions'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _editBasicInfo(context, ref, ground),
              child: const Text('Edit Basic Info'),
            ),
            if (isSuper) ...[
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: ground.isVerified
                      ? 'Remove Verification'
                      : 'Verify Ground',
                  message: ground.isVerified
                      ? 'Remove platform verification?'
                      : 'Mark this ground as verified?',
                  run: (r) => controller.setVerified(
                    ground,
                    !ground.isVerified,
                    reason: r,
                  ),
                ),
                child: Text(ground.isVerified ? 'Unverify' : 'Verify'),
              ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: ground.displayStatus == ManagedGroundStatus.suspended
                      ? 'Unsuspend Ground'
                      : 'Suspend Ground',
                  message:
                      ground.displayStatus == ManagedGroundStatus.suspended
                          ? 'Restore ground to active status?'
                          : 'Suspend this ground?',
                  danger:
                      ground.displayStatus != ManagedGroundStatus.suspended,
                  run: (r) => controller.setStatus(
                    ground,
                    ground.displayStatus == ManagedGroundStatus.suspended
                        ? ManagedGroundStatus.active
                        : ManagedGroundStatus.suspended,
                    reason: r,
                  ),
                ),
                child: Text(
                  ground.displayStatus == ManagedGroundStatus.suspended
                      ? 'Unsuspend'
                      : 'Suspend',
                ),
              ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: ground.adminFeatured
                      ? 'Remove Feature'
                      : 'Feature Ground',
                  message: ground.adminFeatured
                      ? 'Remove ground feature?'
                      : 'Feature this ground?',
                  run: (r) => controller.setFeatured(
                    ground,
                    !ground.adminFeatured,
                    reason: r,
                  ),
                ),
                child: Text(ground.adminFeatured ? 'Unfeature' : 'Feature'),
              ),
              if (!ground.isSoftDeleted)
                OutlinedButton(
                  onPressed: () => confirmAction(
                    title: 'Soft-delete Ground',
                    message:
                        'Soft-delete this ground? History and references stay intact.',
                    danger: true,
                    run: (r) => controller.softDelete(ground, reason: r),
                  ),
                  child: const Text('Delete'),
                )
              else
                OutlinedButton(
                  onPressed: () => confirmAction(
                    title: 'Restore Ground',
                    message: 'Restore this ground?',
                    run: (r) => controller.restore(ground, reason: r),
                  ),
                  child: const Text('Restore'),
                ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Archive Ground',
                  message: 'Archive this ground?',
                  run: (r) => controller.archive(ground, reason: r),
                ),
                child: const Text('Archive'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _editBasicInfo(
    BuildContext context,
    WidgetRef ref,
    ManagedGround ground,
  ) async {
    final name = TextEditingController(text: ground.name);
    final description = TextEditingController(text: ground.description);
    final address = TextEditingController(text: ground.address);
    final city = TextEditingController(text: ground.city);
    final state = TextEditingController(text: ground.stateProvince);
    final country = TextEditingController(text: ground.country);
    final pin = TextEditingController(text: ground.pinCode);
    final contactPerson = TextEditingController(text: ground.contactPerson);
    final contact = TextEditingController(text: ground.contactNumber);
    final email = TextEditingController(text: ground.email);
    ManagedGroundType? groundType = ground.groundType;
    ManagedGroundPitchType? pitchType = ground.pitchType;
    ManagedGroundAvailability availability = ground.availability;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Edit Ground Information'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      TextField(
                        controller: description,
                        maxLines: 2,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                      ),
                      TextField(
                        controller: address,
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                      TextField(
                        controller: city,
                        decoration: const InputDecoration(labelText: 'City'),
                      ),
                      TextField(
                        controller: state,
                        decoration:
                            const InputDecoration(labelText: 'State / Province'),
                      ),
                      TextField(
                        controller: country,
                        decoration: const InputDecoration(labelText: 'Country'),
                      ),
                      TextField(
                        controller: pin,
                        decoration: const InputDecoration(labelText: 'PIN'),
                      ),
                      TextField(
                        controller: contactPerson,
                        decoration:
                            const InputDecoration(labelText: 'Contact person'),
                      ),
                      TextField(
                        controller: contact,
                        decoration:
                            const InputDecoration(labelText: 'Contact number'),
                      ),
                      TextField(
                        controller: email,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ManagedGroundType?>(
                        initialValue: groundType,
                        decoration:
                            const InputDecoration(labelText: 'Ground type'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None'),
                          ),
                          for (final t in ManagedGroundType.values)
                            DropdownMenuItem(value: t, child: Text(t.label)),
                        ],
                        onChanged: (v) => setLocal(() => groundType = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ManagedGroundPitchType?>(
                        initialValue: pitchType,
                        decoration:
                            const InputDecoration(labelText: 'Pitch type'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None'),
                          ),
                          for (final p in ManagedGroundPitchType.values)
                            DropdownMenuItem(value: p, child: Text(p.label)),
                        ],
                        onChanged: (v) => setLocal(() => pitchType = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ManagedGroundAvailability>(
                        initialValue: availability,
                        decoration:
                            const InputDecoration(labelText: 'Availability'),
                        items: [
                          for (final a in ManagedGroundAvailability.values)
                            DropdownMenuItem(value: a, child: Text(a.label)),
                        ],
                        onChanged: (v) =>
                            setLocal(() => availability = v ?? availability),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                CfButton(
                  label: 'Cancel',
                  variant: CfButtonVariant.ghost,
                  onPressed: () => Navigator.pop(context, false),
                ),
                CfButton(
                  label: 'Save',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) {
      await ref.read(groundsListControllerProvider.notifier).saveBasicInfo(
            ground,
            name: name.text.trim(),
            description: description.text.trim(),
            address: address.text.trim(),
            city: city.text.trim(),
            stateProvince: state.text.trim(),
            country: country.text.trim(),
            pinCode: pin.text.trim(),
            contactPerson: contactPerson.text.trim(),
            contactNumber: contact.text.trim(),
            email: email.text.trim(),
            groundType: groundType,
            pitchType: pitchType,
            availability: availability,
          );
    }
  }
}

class _PlaceholderList extends StatelessWidget {
  const _PlaceholderList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Column(
      children: [
        for (final item in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(item),
            subtitle: Text(
              'Coming soon',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            trailing: Icon(
              Icons.lock_outline,
              size: 16,
              color: colors.textMuted,
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}
