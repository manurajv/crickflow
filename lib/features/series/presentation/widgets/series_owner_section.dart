import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/series/series.dart';
import '../../../../domain/services/series/series_owner_actions.dart';
import '../../../../shared/providers/series_providers.dart';
import 'series_status_banner.dart';
import 'series_user_name.dart';

/// Owner-only: transfer ownership and archive / reactivate the org.
class SeriesOwnerSection extends ConsumerStatefulWidget {
  const SeriesOwnerSection({super.key, required this.series});
  final SeriesModel series;

  @override
  ConsumerState<SeriesOwnerSection> createState() => _SeriesOwnerSectionState();
}

class _SeriesOwnerSectionState extends ConsumerState<SeriesOwnerSection> {
  bool _busy = false;

  static const _actions = SeriesOwnerActions();

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runLifecycle(SeriesLifecycleAction action) async {
    final reason = await _askReason(
      title: action.label,
      message: action == SeriesLifecycleAction.archive
          ? 'Archiving hides the organization from listings and pauses new '
              'requests. Clubs, players, results and history are kept. You '
              'can reactivate it later.'
          : 'Reactivating makes the organization visible again and reopens '
              'requests.',
      confirmLabel: action == SeriesLifecycleAction.archive
          ? 'Archive'
          : 'Reactivate',
      destructive: action == SeriesLifecycleAction.archive,
    );
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(seriesFunctionsServiceProvider).setSeriesLifecycle(
            seriesId: widget.series.id,
            action: action.name,
            reason: reason,
          );
      _snack(
        action == SeriesLifecycleAction.archive
            ? 'Organization archived'
            : 'Organization reactivated',
      );
    } catch (e) {
      _snack('Could not update: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transfer(List<SeriesAdminModel> candidates) async {
    if (candidates.isEmpty) {
      _snack('Add the new owner as an admin first.');
      return;
    }
    final picked = await showModalBottomSheet<SeriesAdminModel>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceLg,
                0,
                AppDimens.spaceLg,
                AppDimens.spaceSm,
              ),
              child: Text(
                'Choose the new owner',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final a in candidates)
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: a.displayName.trim().isNotEmpty
                    ? Text(a.displayName.trim())
                    : SeriesUserName(a.userId),
                subtitle: const Text('Admin'),
                onTap: () => Navigator.pop(ctx, a),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final name = picked.displayName.trim().isNotEmpty
        ? picked.displayName.trim()
        : 'this admin';
    final reason = await _askReason(
      title: 'Transfer ownership?',
      message: 'You will hand ${widget.series.name} to $name. They get full '
          'control, including settings and admins. You stay on as an admin. '
          'Only the new owner can transfer it back.',
      confirmLabel: 'Transfer',
      destructive: true,
    );
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(seriesFunctionsServiceProvider).transferSeriesOwnership(
            seriesId: widget.series.id,
            newOwnerUserId: picked.userId,
            reason: reason,
          );
      _snack('Ownership transferred');
    } catch (e) {
      _snack('Could not transfer: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askReason({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final cf = ctx.cf;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: AppDimens.spaceMd),
              TextField(
                controller: controller,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  helperText: 'Saved in the activity log',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: cf.error)
                  : null,
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final series = widget.series;
    final admins =
        ref.watch(seriesAdminsListProvider(series.id)).valueOrNull ?? const [];
    final candidates =
        _actions.transferCandidates(series: series, admins: admins);
    final lifecycle = _actions.lifecycleActions(series);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ownership & status', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppDimens.spaceSm),
        SeriesStatusBanner(series: series, showWhenActive: true),
        const SizedBox(height: AppDimens.spaceSm),
        ListTile(
          tileColor: cf.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
          leading: Icon(Icons.swap_horiz, color: cf.accent),
          title: const Text('Transfer ownership'),
          subtitle: Text(
            candidates.isEmpty
                ? 'Add the new owner as an admin first'
                : 'Hand this organization to another admin',
          ),
          trailing: const Icon(Icons.chevron_right),
          enabled: !_busy && !series.platformHold,
          onTap: () => _transfer(candidates),
        ),
        for (final action in lifecycle) ...[
          const SizedBox(height: AppDimens.spaceSm),
          ListTile(
            tileColor: cf.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            leading: Icon(
              action == SeriesLifecycleAction.archive
                  ? Icons.inventory_2_outlined
                  : Icons.restart_alt,
              color: action == SeriesLifecycleAction.archive
                  ? cf.error
                  : cf.success,
            ),
            title: Text(action.label),
            trailing: const Icon(Icons.chevron_right),
            enabled: !_busy,
            onTap: () => _runLifecycle(action),
          ),
        ],
      ],
    );
  }
}
