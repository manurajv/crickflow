import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/location_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_underlined_field.dart';
import 'team_logo_picker.dart';

/// Reference-style create team form inside the Add tab.
class CreateTeamForm extends ConsumerStatefulWidget {
  const CreateTeamForm({super.key, this.onCreated});

  final void Function(String teamId)? onCreated;

  @override
  ConsumerState<CreateTeamForm> createState() => _CreateTeamFormState();
}

class _CreateTeamFormState extends ConsumerState<CreateTeamForm> {
  final _teamId = const Uuid().v4();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _captainNameController = TextEditingController();
  var _addSelf = true;
  var _saving = false;
  String? _logoUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _captainNameController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final url = await ref
          .read(storageServiceProvider)
          .pickAndUploadTeamLogo(_teamId);
      if (url == null) return;
      if (mounted) setState(() => _logoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logo upload failed: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();
    if (name.isEmpty || city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team name and city are required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      final team = TeamModel(
        id: _teamId,
        name: name,
        logoUrl: _logoUrl,
        coachName: _captainNameController.text.trim().isEmpty
            ? null
            : _captainNameController.text.trim(),
        location: LocationModel(
          country: AppConstants.defaultCountry,
          city: city,
        ),
        createdBy: uid,
      );
      await ref.read(teamRepositoryProvider).createTeam(team);

      if (_addSelf && uid != null) {
        final profile = ref.read(currentUserProfileProvider).valueOrNull;
        final player = await ref
            .read(playerRepositoryProvider)
            .ensurePlayerProfileForUser(
              userId: uid,
              displayName: profile?.displayName ?? name,
              photoUrl: profile?.photoUrl,
              email: profile?.email,
            );
        await ref.read(playerRepositoryProvider).assignPlayerToTeam(
              playerId: player.id,
              teamId: _teamId,
            );
        await ref.read(teamRepositoryProvider).updateTeam(
              TeamModel(
                id: _teamId,
                name: name,
                logoUrl: _logoUrl,
                captainId: player.id,
                coachName: team.coachName,
                playerIds: [player.id],
                location: team.location,
                createdBy: uid,
              ),
            );
      }

      if (!mounted) return;
      widget.onCreated?.call(_teamId);
      context.push('/teams/$_teamId');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${team.name} created')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create team: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(myPlayerProvider);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceLg,
            ),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: TeamLogoPicker(
                        logoUrl: _logoUrl,
                        teamName: _nameController.text,
                        onTap: _pickLogo,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceXl),
                    CfFormFieldGroup(
                      children: [
                        CfUnderlinedField(
                          controller: _nameController,
                          label: 'Team name',
                          required: true,
                          textInputAction: TextInputAction.next,
                        ),
                        CfUnderlinedField(
                          controller: _cityController,
                          label: 'City / town',
                          required: true,
                          hint: 'e.g. Colombo',
                          textInputAction: TextInputAction.next,
                        ),
                        CfUnderlinedField(
                          controller: _phoneController,
                          label: 'Team captain / coordinator number',
                          hint: 'Optional',
                          keyboardType: TextInputType.phone,
                          suffix: IconButton(
                            icon: const Icon(Icons.contacts_outlined),
                            color: AppColors.primaryBlueLight,
                            onPressed: () {},
                            tooltip: 'Pick from contacts (coming soon)',
                          ),
                        ),
                        CfUnderlinedField(
                          controller: _captainNameController,
                          label: 'Team captain name',
                          hint: 'Optional',
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
          ),
          child: CheckboxListTile(
            value: _addSelf,
            onChanged: (v) => setState(() => _addSelf = v ?? false),
            title: const Text('Add yourself in the team'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              0,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add team'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
