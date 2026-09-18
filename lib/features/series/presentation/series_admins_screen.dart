import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/player_discovery_repository.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_ui.dart';
import 'widgets/series_user_name.dart';

class SeriesAdminsScreen extends ConsumerStatefulWidget {
  const SeriesAdminsScreen({super.key, required this.seriesId});
  final String seriesId;

  @override
  ConsumerState<SeriesAdminsScreen> createState() => _SeriesAdminsScreenState();
}

class _SeriesAdminsScreenState extends ConsumerState<SeriesAdminsScreen> {
  bool _busy = false;

  Future<void> _addAdmin() async {
    final selected = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _AdminSearchSheet(),
    );
    if (selected == null) return;
    setState(() => _busy = true);
    try {
      final name = selected.displayName.trim().isNotEmpty
          ? selected.displayName.trim()
          : selected.name.trim();
      await ref.read(seriesFunctionsServiceProvider).addSeriesAdmin(
            seriesId: widget.seriesId,
            userId: selected.id,
            displayName: name,
            permissions: const [],
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name added as admin')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add admin')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAdmin(SeriesAdminModel admin) async {
    final name = seriesPersonLabel(
      displayName: admin.displayName,
      userId: admin.userId,
      fallback: 'this admin',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove admin?'),
        content: Text('Remove $name from organization admins?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(seriesFunctionsServiceProvider).removeSeriesAdmin(
            seriesId: widget.seriesId,
            userId: admin.userId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin removed')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove admin')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final role = ref.watch(mySeriesRoleProvider(widget.seriesId));
    final series = ref.watch(seriesByIdProvider(widget.seriesId)).valueOrNull;
    final admins = ref.watch(seriesAdminsListProvider(widget.seriesId));
    final isSuper = role == SeriesRole.superAdmin;

    return Scaffold(
      backgroundColor: cf.background,
      appBar: CfChromeAppBar(
        title: const Text('Admins'),
        actions: [
          if (isSuper)
            IconButton(
              tooltip: 'Add admin',
              onPressed: _busy ? null : _addAdmin,
              icon: const Icon(Icons.person_add_alt_1),
            ),
        ],
      ),
      body: !isSuper && role != SeriesRole.seriesAdmin
          ? const Center(child: Text('Admin access required'))
          : admins.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) {
                final active =
                    items.where((a) => a.status == 'active').toList();
                if (active.isEmpty) {
                  return const SeriesEmptyState(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'No admins yet',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  itemCount: active.length,
                  separatorBuilder: (_, _) => Divider(color: cf.border),
                  itemBuilder: (_, i) {
                    final a = active[i];
                    final isOwner =
                        series?.superAdminUserId == a.userId;
                    final title = seriesPersonLabel(
                      displayName: a.displayName,
                      userId: a.userId,
                    );
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cf.accent
                            .withValues(alpha: cf.isLight ? 0.1 : 0.15),
                        child: Icon(
                          isOwner
                              ? Icons.star_outlined
                              : Icons.badge_outlined,
                          color: cf.accent,
                        ),
                      ),
                      title: title == 'Member'
                          ? SeriesUserName(a.userId)
                          : Text(title),
                      subtitle: Text(
                        isOwner ? 'Owner' : 'Admin',
                      ),
                      trailing: isSuper && !isOwner
                          ? IconButton(
                              tooltip: 'Remove',
                              onPressed:
                                  _busy ? null : () => _removeAdmin(a),
                              icon: const Icon(Icons.remove_circle_outline),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _AdminSearchSheet extends StatefulWidget {
  const _AdminSearchSheet();

  @override
  State<_AdminSearchSheet> createState() => _AdminSearchSheetState();
}

class _AdminSearchSheetState extends State<_AdminSearchSheet> {
  final _query = TextEditingController();
  final _repo = PlayerDiscoveryRepository();
  List<UserModel> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await _repo.searchPlayers(
        query: q,
        currentUserId: FirebaseAuth.instance.currentUser?.uid,
      );
      if (mounted) setState(() => _results = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd + bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          children: [
            Text(
              'Add admin',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search by name or CrickFlow Player ID',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        'Type a name to find people',
                        style: TextStyle(color: cf.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final u = _results[i];
                        final name = u.displayName.isNotEmpty
                            ? u.displayName
                            : u.name;
                        final subtitle = (u.playerId != null &&
                                u.playerId!.trim().isNotEmpty)
                            ? u.playerId!
                            : (u.location.displayLabel.isNotEmpty
                                ? u.location.displayLabel
                                : null);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: u.photoUrl == null
                                ? null
                                : NetworkImage(u.photoUrl!),
                            child: u.photoUrl == null
                                ? const Icon(Icons.person_outline)
                                : null,
                          ),
                          title: Text(name),
                          subtitle:
                              subtitle == null ? null : Text(subtitle),
                          onTap: () => Navigator.pop(context, u),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
