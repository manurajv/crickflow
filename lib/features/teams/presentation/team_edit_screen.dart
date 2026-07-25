import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/player_profile_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_underlined_field.dart';
import '../../discover/presentation/widgets/opportunity_location_field.dart';
import '../../player_onboarding/presentation/widgets/onboarding_location_section.dart';
import 'utils/team_image_upload.dart';
import 'utils/team_location_parts.dart';
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
  final _phoneController = TextEditingController();
  File? _profileFile;
  File? _coverFile;
  String? _profileUrl;
  String? _coverUrl;
  LocationModel _teamLocation = const LocationModel();
  LocationModel _homeGround = const LocationModel();
  String _dialCode = '+94';
  var _bound = false;
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _bindTeam(TeamModel team) {
    if (_bound) return;
    _bound = true;
    _nameController.text = team.name;
    _profileUrl = team.profileImageUrl;
    _coverUrl = team.coverImageUrl;
    final parts = TeamLocationParts.fromStored(team.location);
    _teamLocation = parts.teamLocation;
    _homeGround = parts.homeGround;
    _syncDialCodeFromCountry(_teamLocation.country);
    _applyContactNumber(team.contactNumber);
  }

  void _applyContactNumber(String? raw) {
    final mobile = raw?.trim() ?? '';
    if (mobile.isEmpty) {
      _phoneController.clear();
      return;
    }
    final dial = CricketCountry.all
        .map((c) => c.dialCode)
        .where(mobile.startsWith)
        .fold<String?>(
          null,
          (prev, code) =>
              prev == null || code.length > prev.length ? code : prev,
        );
    if (dial != null) {
      _dialCode = dial;
      _phoneController.text = mobile.substring(dial.length);
    } else {
      _phoneController.text = mobile.replaceFirst(RegExp(r'^\+\d+\s*'), '');
    }
  }

  void _syncDialCodeFromCountry(String countryName) {
    final match = CricketCountry.byName(countryName);
    if (match != null) {
      _dialCode = match.dialCode;
    }
  }

  void _onTeamLocationChanged(LocationModel location) {
    setState(() {
      _teamLocation = location.copyWith(clearPlaceName: true);
      _syncDialCodeFromCountry(location.country);
    });
  }

  void _onHomeGroundChanged(LocationModel ground) {
    setState(() => _homeGround = ground);
  }

  String get _phoneNumberHint {
    return switch (_dialCode) {
      '+94' => '771234567',
      '+91' => '9876543210',
      '+92' => '3001234567',
      '+880' => '1712345678',
      '+44' => '7911123456',
      '+61' => '412345678',
      '+64' => '211234567',
      '+27' => '821234567',
      '+1' => '2025551234',
      '+971' => '501234567',
      _ => '771234567',
    };
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
    if (_teamLocation.city.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'City is required — search or enter your team location',
          ),
        ),
      );
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

      final phoneRaw = _phoneController.text.trim();
      final contactNumber = phoneRaw.isEmpty ? '' : '$_dialCode$phoneRaw';
      final location = TeamLocationParts(
        teamLocation: _teamLocation,
        homeGround: _homeGround,
      ).merge();

      final updated = team.copyWith(
        name: name,
        teamProfileImageUrl: profileUrl,
        teamCoverImageUrl: coverUrl,
        logoUrl: profileUrl,
        location: location,
        contactNumber: contactNumber,
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
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                'Home ground',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              OpportunityLocationField(
                location: _homeGround,
                onLocationChanged: _onHomeGroundChanged,
                helperText:
                    'Search Google Places or pin your home ground on the map',
                hintText: 'Home ground / venue',
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                'Team location',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                'City / region for the team (separate from home ground)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              OnboardingLocationSection(
                key: ValueKey('edit-loc-${team.id}'),
                initialLocation: _teamLocation,
                onLocationChanged: _onTeamLocationChanged,
                autoDetectOnInit: false,
                locationService: ref.read(googleMapsLocationServiceProvider),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                'Contact number',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 108,
                    child: Builder(
                      builder: (context) {
                        final dialCodes = [
                          ...CricketCountry.phoneDialCodes,
                        ];
                        if (!dialCodes.contains(_dialCode)) {
                          dialCodes.insert(0, _dialCode);
                        }
                        return DropdownButtonFormField<String>(
                          key: ValueKey(_dialCode),
                          initialValue: _dialCode,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Code',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                          ),
                          items: dialCodes
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (v) {
                                  if (v != null) {
                                    setState(() => _dialCode = v);
                                  }
                                },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Contact number',
                        hintText: _phoneNumberHint,
                        helperText: 'Optional — digits only',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceXl),
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
