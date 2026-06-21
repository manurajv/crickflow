import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/auth/auth_gate.dart';
import '../../../../core/constants/player_profile_constants.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/cf_team_id_format.dart';
import '../../../../data/models/location_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../player_onboarding/presentation/widgets/onboarding_location_section.dart';
import 'team_logo_picker.dart';

/// Create team form inside the Teams → Add tab.
class CreateTeamForm extends ConsumerStatefulWidget {
  const CreateTeamForm({super.key, this.onCreated});

  final void Function(String teamId)? onCreated;

  @override
  ConsumerState<CreateTeamForm> createState() => _CreateTeamFormState();
}

class _CreateTeamFormState extends ConsumerState<CreateTeamForm> {
  final _teamId = const Uuid().v4();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  var _addSelf = true;
  var _saving = false;
  var _locationReady = false;

  File? _logoFile;
  String? _logoUrl;
  String _dialCode = '+94';
  LocationModel _location = const LocationModel();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
  }

  Future<void> _prefillFromProfile() async {
    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) {
      if (mounted) setState(() => _locationReady = true);
      return;
    }

    final profile =
        await ref.read(userRepositoryProvider).getUser(authUser.uid) ??
        await ref
            .read(authRepositoryProvider)
            .ensureProfileForAuthUser(authUser);
    if (!mounted) return;

    setState(() {
      _location = profile.location;
      _syncDialCodeFromCountry(_location.country);
      if (profile.effectiveMobile.isNotEmpty) {
        final mobile = profile.effectiveMobile;
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
      _locationReady = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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

  void _syncDialCodeFromCountry(String countryName) {
    final match = CricketCountry.byName(countryName);
    if (match != null) {
      _dialCode = match.dialCode;
    }
  }

  void _onLocationChanged(LocationModel location) {
    setState(() => _location = location);
    _syncDialCodeFromCountry(location.country);
  }

  Future<void> _pickLogo(ImageSource source) async {
    await requireAuthVoid(
      context: context,
      ref: ref,
      action: () async {
        final cf = context.cf;
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: source, imageQuality: 92);
        if (picked == null) return;

        final cropped = await ImageCropper().cropImage(
          sourcePath: picked.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop logo',
              toolbarColor: cf.surface,
              toolbarWidgetColor: cf.textPrimary,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(title: 'Crop logo', aspectRatioLockEnabled: true),
          ],
        );
        if (cropped == null || !mounted) return;
        setState(() {
          _logoFile = File(cropped.path);
          _logoUrl = null;
        });
      },
    );
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _submit() async {
    await requireAuthVoid(
      context: context,
      ref: ref,
      returnPath: '/teams',
      action: () async => _submitTeam(),
    );
  }

  Future<void> _submitTeam() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showValidationError('Team name is required');
      return;
    }
    if (_location.city.trim().isEmpty) {
      _showValidationError(
        'City is required — search or enter your team location',
      );
      return;
    }

    final phoneRaw = _phoneController.text.trim();
    if (phoneRaw.isNotEmpty && !RegExp(r'^[0-9]{6,14}$').hasMatch(phoneRaw)) {
      _showValidationError('Enter a valid contact number (digits only)');
      return;
    }
    final contactNumber = phoneRaw.isEmpty ? null : '$_dialCode$phoneRaw';

    setState(() => _saving = true);
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      final draft = TeamModel(
        id: _teamId,
        name: name,
        contactNumber: contactNumber,
        location: _location,
        createdBy: uid,
      );
      var saved = await ref.read(teamRepositoryProvider).createTeam(draft);

      var logoUrl = _logoUrl;
      if (_logoFile != null) {
        logoUrl = await ref
            .read(storageServiceProvider)
            .uploadTeamLogo(_teamId, _logoFile!);
        saved = saved.copyWith(teamProfileImageUrl: logoUrl, logoUrl: logoUrl);
        await ref.read(teamRepositoryProvider).updateTeam(saved);
      }

      if (_addSelf && uid != null) {
        final profile = ref.read(currentUserProfileProvider).valueOrNull;
        final player = await ref
            .read(playerRepositoryProvider)
            .ensurePlayerProfileForUser(
              userId: uid,
              displayName: profile?.displayName ?? name,
              fullName: profile?.name,
              photoUrl: profile?.photoUrl,
              email: profile?.email,
            );
        await ref.read(playerRepositoryProvider).assignPlayerToTeam(
              playerId: player.id,
              teamId: _teamId,
              addedByUserId: uid,
            );
        await ref
            .read(teamRepositoryProvider)
            .updateTeam(
              saved.copyWith(
                name: name,
                teamProfileImageUrl: logoUrl,
                logoUrl: logoUrl,
                captainId: player.id,
                contactNumber: contactNumber,
                playerIds: [player.id],
                createdBy: uid,
              ),
            );
      }

      if (!mounted) return;
      widget.onCreated?.call(_teamId);
      context.push('/teams/$_teamId');
      final codeLabel = CfTeamIdFormat.displayLabel(saved.teamCode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${saved.name} created · Team ID $codeLabel')),
      );
    } catch (e) {
      if (mounted) {
        _showValidationError('Could not create team: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(myPlayerProvider);
    final cf = context.cf;

    if (!_locationReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppDimens.listPadding,
            children: [
              Text(
                'Create your team',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cf.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your team logo, location, and contact details. Team ID (e.g. TM00001) and QR are created when you save.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cf.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Card(
                elevation: 0,
                color: cf.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: cf.border.withValues(alpha: 0.8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: Column(
                    children: [
                      TeamLogoPicker(
                        logoUrl: _logoUrl,
                        localFile: _logoFile,
                        teamName: _nameController.text,
                        size: 128,
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _saving
                                  ? null
                                  : () => _pickLogo(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Camera'),
                            ),
                          ),
                          const SizedBox(width: AppDimens.spaceSm),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _saving
                                  ? null
                                  : () => _pickLogo(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Gallery'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Card(
                elevation: 0,
                color: cf.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: cf.border.withValues(alpha: 0.8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Team name *',
                          prefixIcon: Icon(Icons.groups_outlined),
                        ),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      OnboardingLocationSection(
                        initialLocation: _location,
                        onLocationChanged: _onLocationChanged,
                        locationService: ref.read(
                          googleMapsLocationServiceProvider,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
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
                                  value: _dialCode,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Code',
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            0,
          ),
          child: CheckboxListTile(
            value: _addSelf,
            onChanged: _saving
                ? null
                : (v) => setState(() => _addSelf = v ?? false),
            title: const Text('Add yourself to the team'),
            subtitle: const Text('You will be set as team captain'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: AppDimens.cardPadding,
            child: CfButton(
              label: 'Create team',
              isGold: true,
              isLoading: _saving,
              onPressed: _saving ? null : _submit,
            ),
          ),
        ),
      ],
    );
  }
}
