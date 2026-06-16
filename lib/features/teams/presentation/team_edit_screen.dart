import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_underlined_field.dart';
import 'utils/team_image_upload.dart';
import 'utils/team_squad_utils.dart';
import 'widgets/team_detail_banner.dart';

class TeamEditScreen extends ConsumerStatefulWidget {
  const TeamEditScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamEditScreen> createState() => _TeamEditScreenState();
}

class _TeamEditScreenState extends ConsumerState<TeamEditScreen> {
  final _nameController = TextEditingController();
  File? _profileFile;
  File? _coverFile;
  String? _profileUrl;
  String? _coverUrl;
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _bindTeam(TeamModel team) {
    if (_nameController.text.isEmpty) {
      _nameController.text = team.name;
      _profileUrl = team.profileImageUrl;
      _coverUrl = team.coverImageUrl;
    }
  }

  Future<void> _pickImage(TeamImageKind kind) async {
    await showTeamImageSourceSheet(
      context,
      onSelected: (source) async {
        final file = await pickAndCropTeamImage(
          context,
          kind: kind,
          source: source,
        );
        if (file == null || !mounted) return;
        setState(() {
          if (kind == TeamImageKind.profile) {
            _profileFile = file;
            _profileUrl = null;
          } else {
            _coverFile = file;
            _coverUrl = null;
          }
        });
      },
    );
  }

  Future<void> _save(TeamModel team) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team name is required')));
      return;
    }

    setState(() => _saving = true);
    try {
      var profileUrl = _profileUrl ?? team.profileImageUrl;
      var coverUrl = _coverUrl ?? team.coverImageUrl;
      final storage = ref.read(storageServiceProvider);

      if (_profileFile != null) {
        profileUrl = await storage.uploadTeamProfileImage(
          team.id,
          _profileFile!,
        );
      }
      if (_coverFile != null) {
        coverUrl = await storage.uploadTeamCoverImage(team.id, _coverFile!);
      }

      final updated = team.copyWith(
        name: name,
        teamProfileImageUrl: profileUrl,
        teamCoverImageUrl: coverUrl,
        logoUrl: profileUrl,
      );
      await ref.read(teamRepositoryProvider).updateTeam(updated);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Team updated')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(_teamEditProvider(widget.teamId));
    final uid = ref.watch(authStateProvider).value?.uid;

    return teamAsync.when(
      data: (team) {
        if (team == null) {
          return const Scaffold(body: Center(child: Text('Team not found')));
        }
        _bindTeam(team);

        if (!TeamSquadUtils.isTeamOwner(uid, team)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit team')),
            body: const Center(
              child: Text('Only the team owner can edit team details.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit team'),
            actions: [
              TextButton(
                onPressed: _saving ? null : () => _save(team),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            children: [
              Text(
                'Cover picture',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              GestureDetector(
                onTap: () => _pickImage(TeamImageKind.cover),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: TeamDetailBanner.height * 0.85,
                    width: double.infinity,
                    child: _coverFile != null
                        ? Image.file(_coverFile!, fit: BoxFit.cover)
                        : _coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _coverUrl!,
                            fit: BoxFit.cover,
                          )
                        : const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppColors.heroGradient,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                'Profile picture',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Center(
                child: GestureDetector(
                  onTap: () => _pickImage(TeamImageKind.profile),
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: AppColors.surfaceElevated,
                    backgroundImage: _profileFile != null
                        ? FileImage(_profileFile!)
                        : _profileUrl != null
                        ? CachedNetworkImageProvider(_profileUrl!)
                        : null,
                    child: _profileFile == null && _profileUrl == null
                        ? const Icon(Icons.add_a_photo_outlined, size: 32)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              CfUnderlinedField(
                controller: _nameController,
                label: 'Team name',
                required: true,
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }
}

final _teamEditProvider = StreamProvider.family<TeamModel?, String>((
  ref,
  teamId,
) {
  return ref.watch(teamRepositoryProvider).watchTeam(teamId);
});
