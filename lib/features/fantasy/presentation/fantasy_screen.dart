import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/providers.dart';

class FantasyScreen extends ConsumerWidget {
  const FantasyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(fantasyUserEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fantasy Cricket')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showJoinDialog(context, ref),
        icon: const Icon(Icons.vpn_key),
        label: const Text('Join code'),
      ),
      body: entriesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sports_esports,
                      size: 64,
                      color: AppColors.primaryBlueLight.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    const Text(
                      'No fantasy leagues yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join with a code from a match organizer, or create a league from Match Center.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: AppDimens.spaceLg),
                    FilledButton.icon(
                      onPressed: () => _showJoinDialog(context, ref),
                      icon: const Icon(Icons.vpn_key),
                      label: const Text('Enter join code'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                    child: Text(
                      item.entry.totalPoints.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(item.league.name),
                  subtitle: Text(
                    '${item.league.matchTitle} · Code ${item.league.joinCode}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/fantasy/${item.league.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showJoinDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join fantasy league'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Join code',
            hintText: 'e.g. ABC123',
          ),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (code == null || code.trim().isEmpty || !context.mounted) return;

    final uid = ref.read(authStateProvider).value?.uid;
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (uid == null) return;

    final repo = ref.read(fantasyRepositoryProvider);
    final league = await repo.findLeagueByJoinCode(code);
    if (!context.mounted) return;

    if (league == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid join code')),
      );
      return;
    }

    await repo.joinLeague(
      league: league,
      userId: uid,
      displayName: profile?.displayName ?? 'Player',
    );

    if (!context.mounted) return;
    context.push('/fantasy/${league.id}');
  }
}
