import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/location_fields.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not signed in'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primaryBlue,
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 32),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                user.email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(user.role.name.toUpperCase()),
                backgroundColor: AppColors.gold.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 24),
              const Text('Location',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              LocationFields(
                location: user.location,
                onChanged: (loc) async {
                  await ref
                      .read(userRepositoryProvider)
                      .updateUser(user.copyWith(location: loc));
                  ref.invalidate(currentUserProfileProvider);
                },
              ),
              const SizedBox(height: 24),
              const Text('Stats',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              ListTile(
                title: const Text('Matches Played'),
                trailing: Text('${user.stats.matchesPlayed}'),
              ),
              ListTile(
                title: const Text('Matches Scored'),
                trailing: Text('${user.stats.matchesScored}'),
              ),
              ListTile(
                title: const Text('Badges'),
                trailing: Text('${user.badgeIds.length}'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: user.role == UserRole.viewer
                    ? UserRole.viewer
                    : UserRole.organizer,
                decoration: const InputDecoration(
                  labelText: 'App mode',
                  helperText:
                      'Member: score, stream, and join squads. Viewer: browse only.',
                ),
                items: const [
                  DropdownMenuItem(
                    value: UserRole.organizer,
                    child: Text('Member (score & play)'),
                  ),
                  DropdownMenuItem(
                    value: UserRole.viewer,
                    child: Text('Viewer (browse only)'),
                  ),
                ],
                onChanged: (role) async {
                  if (role == null) return;
                  await ref
                      .read(userRepositoryProvider)
                      .updateUser(user.copyWith(role: role));
                  if (role == UserRole.organizer) {
                    await ref
                        .read(playerRepositoryProvider)
                        .ensurePlayerProfileForUser(
                          userId: user.id,
                          displayName: user.displayName,
                          photoUrl: user.photoUrl,
                          email: user.email,
                        );
                  }
                  ref.invalidate(currentUserProfileProvider);
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
