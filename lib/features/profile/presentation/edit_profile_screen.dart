import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/player_profile_constants.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/user_model.dart';
import '../../../features/player_onboarding/presentation/widgets/onboarding_location_section.dart';
import '../../../features/player_onboarding/presentation/widgets/onboarding_widgets.dart';
import '../../../shared/providers/player_social_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'edit_profile_options.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _bioController = TextEditingController();
  final _jerseyController = TextEditingController();

  UserModel? _baseProfile;
  File? _photoFile;
  String? _photoUrl;
  var _removePhoto = false;
  var _dirty = false;
  var _saving = false;
  var _loading = true;

  LocationModel _location = const LocationModel();
  String _dialCode = '+94';
  DateTime? _dob;
  PlayerGender? _gender;
  PlayerPlayingRole? _playingRole;
  PlayerBattingStyle? _battingStyle;
  PlayerBowlingStyle? _bowlingStyle;
  PlayerStrongHand? _strongHand;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _bioController.dispose();
    _jerseyController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _loadProfile() async {
    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) {
      if (mounted) context.pop();
      return;
    }

    final repo = ref.read(profileEditRepositoryProvider);
    if (await repo.isOnline()) {
      await repo.flushPending(authUser.uid);
    }

    var profile = await ref.read(userRepositoryProvider).getUser(authUser.uid);
    profile ??=
        await ref.read(authRepositoryProvider).ensureProfileForAuthUser(authUser);

    final player =
        await ref.read(playerRepositoryProvider).getPlayerByUserId(authUser.uid);

    if (!mounted) return;

    var bowling = profile.bowlingStyle;
    if (bowling == null &&
        player != null &&
        player.bowlingStyle.isNotEmpty) {
      bowling = PlayerBowlingStyleLabels.fromStored(player.bowlingStyle);
    }

    var batting = profile.battingStyle ??
        PlayerBattingStyleLabels.fromStored(player?.battingStyle);

    var role = profile.playerRole;
    if (role == null && player != null && player.role.isNotEmpty) {
      role = enumFromName(PlayerPlayingRole.values, player.role);
      if (role == null) {
        for (final r in EditProfileOptions.playingRoles) {
          if (r.label == player.role) {
            role = r;
            break;
          }
        }
      }
    }

    setState(() {
      _baseProfile = profile;
      _loading = false;
      _photoUrl = profile!.photoUrl ?? player?.photoUrl;
      _nameController.text = profile.name.isNotEmpty
          ? profile.name
          : profile.displayName;
      _emailController.text = profile.email;
      _bioController.text = profile.bio;
      _location = profile.location;
      _syncDialCodeFromCountry(_location.country);
      final jersey = profile.jerseyNumber ?? player?.jerseyNumber;
      if (jersey != null) {
        _jerseyController.text = '$jersey';
      }
      if (profile.effectiveMobile.isNotEmpty) {
        _applyMobile(profile.effectiveMobile);
      }
      _dob = profile.dateOfBirth;
      _gender = profile.gender;
      _playingRole = role;
      _battingStyle = batting;
      _bowlingStyle = bowling;
      _strongHand = profile.strongHand;
    });
  }

  void _applyMobile(String mobile) {
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
      _mobileController.text = mobile.substring(dial.length);
    } else {
      _mobileController.text =
          mobile.replaceFirst(RegExp(r'^\+\d+\s*'), '');
    }
  }

  void _syncDialCodeFromCountry(String countryName) {
    final match = CricketCountry.byName(countryName);
    if (match != null) _dialCode = match.dialCode;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final cf = context.cf;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop photo',
          toolbarColor: cf.surface,
          toolbarWidgetColor: cf.textPrimary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Crop photo', aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null || !mounted) return;
    setState(() {
      _photoFile = File(cropped.path);
      _photoUrl = null;
      _removePhoto = false;
    });
    _markDirty();
  }

  void _removePhotoAction() {
    setState(() {
      _photoFile = null;
      _photoUrl = null;
      _removePhoto = true;
    });
    _markDirty();
  }

  void _onLocationChanged(LocationModel location) {
    setState(() => _location = location);
    _syncDialCodeFromCountry(location.country);
    _markDirty();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _dob = picked);
      _markDirty();
    }
  }

  String? _validate() {
    final name = _nameController.text.trim();
    if (name.length < 3 || name.length > 50) {
      return 'Name must be 3–50 characters';
    }
    final email = _emailController.text.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      return 'Enter a valid email address';
    }
    final mobile = _mobileController.text.trim();
    if (mobile.isNotEmpty && !RegExp(r'^[0-9]{6,14}$').hasMatch(mobile)) {
      return 'Enter a valid phone number (digits only)';
    }
    if (_bioController.text.length > 250) {
      return 'Bio must be 250 characters or less';
    }
    final jersey = _jerseyController.text.trim();
    if (jersey.isNotEmpty) {
      final n = int.tryParse(jersey);
      if (n == null || n < 0 || n > 999) {
        return 'Jersey number must be 0–999';
      }
    }
    return null;
  }

  UserModel _buildUpdatedProfile(UserModel base) {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final mobileRaw = _mobileController.text.trim();
    final mobile = mobileRaw.isEmpty ? null : '$_dialCode$mobileRaw';
    final cricketCountry = CricketCountry.byName(_location.country);
    final jersey = _jerseyController.text.trim();
    final jerseyNumber = jersey.isEmpty ? null : int.parse(jersey);

    return base.copyWith(
      name: name,
      displayName: name,
      email: email.isNotEmpty ? email : base.email,
      mobile: mobile,
      phoneNumber: mobile,
      country: _location.country.isNotEmpty ? _location.country : base.country,
      countryCode: cricketCountry?.code ?? base.countryCode,
      countryFlag: cricketCountry?.flag ?? base.countryFlag,
      location: _location,
      dateOfBirth: _dob,
      gender: _gender,
      playerRole: _playingRole,
      battingStyle: _battingStyle,
      bowlingStyle: _bowlingStyle,
      strongHand: _strongHand,
      bio: _bioController.text.trim(),
      jerseyNumber: jerseyNumber,
    );
  }

  Future<void> _save() async {
    if (_saving || _baseProfile == null) return;
    final error = _validate();
    if (error != null) {
      _showMessage(error);
      return;
    }

    setState(() => _saving = true);
    try {
      var updated = _buildUpdatedProfile(_baseProfile!);
      if (_removePhoto) {
        updated = updated.copyWith(clearPhotoUrl: true);
      }
      final result = await ref.read(profileEditRepositoryProvider).saveProfile(
            updated: updated,
            newPhotoFile: _photoFile,
            removePhoto: _removePhoto,
          );

      if (!mounted) return;

      if (!result.success) {
        _showMessage(result.errorMessage ?? 'Profile update failed');
        return;
      }

      ref.invalidate(currentUserProfileProvider);
      if (updated.playerId != null && updated.playerId!.isNotEmpty) {
        ref.invalidate(userByPlayerIdProvider(updated.playerId!));
      }

      if (result.queuedOffline) {
        _showMessage('Changes will sync when connection is restored.');
      }

      setState(() => _dirty = false);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_dirty || _saving) return true;
    final action = await showDialog<_DiscardAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved profile edits.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DiscardAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _DiscardAction.discard),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _DiscardAction.save),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (action == _DiscardAction.save) {
      await _save();
      return !_dirty;
    }
    return action == _DiscardAction.discard;
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _onWillPop();
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: cf.background,
        appBar: CfChromeAppBar(
          title: const Text('Edit Profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _saving
                ? null
                : () async {
                    if (await _onWillPop() && context.mounted) {
                      context.pop();
                    }
                  },
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: AppDimens.listPadding,
                      children: [
                        _sectionTitle(context, 'Profile photo'),
                        _photoSection(cf),
                        const SizedBox(height: AppDimens.spaceLg),
                        _sectionTitle(context, 'Basic information'),
                        _basicSection(cf),
                        const SizedBox(height: AppDimens.spaceLg),
                        _sectionTitle(context, 'Location'),
                        _locationSection(),
                        const SizedBox(height: AppDimens.spaceLg),
                        _sectionTitle(context, 'Cricket information'),
                        _cricketSection(),
                        const SizedBox(height: AppDimens.spaceLg),
                        _sectionTitle(context, 'Personal information'),
                        _personalSection(cf),
                        const SizedBox(height: AppDimens.spaceLg),
                        _sectionTitle(context, 'Private information'),
                        Text(
                          'Only visible to you',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cf.textSecondary,
                              ),
                        ),
                        const SizedBox(height: AppDimens.spaceSm),
                        _privateSection(cf),
                        const SizedBox(height: AppDimens.spaceXl),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: AppDimens.cardPadding,
                      child: CfButton(
                        label: 'Save Changes',
                        isGold: true,
                        isLoading: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.cf.textPrimary,
            ),
      ),
    );
  }

  Widget _photoSection(CfColors cf) {
    ImageProvider? image;
    if (_photoFile != null) {
      image = FileImage(_photoFile!);
    } else if (_photoUrl != null && !_removePhoto) {
      image = CachedNetworkImageProvider(_photoUrl!);
    }

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: cfCardDecoration(context),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: CfColors.primaryBlue,
            backgroundImage: image,
            child: image == null
                ? Icon(Icons.person, size: 48, color: cf.textMuted)
                : null,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Wrap(
            spacing: AppDimens.spaceSm,
            runSpacing: AppDimens.spaceSm,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Change Photo'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera'),
              ),
              if (image != null || _photoUrl != null)
                TextButton.icon(
                  onPressed: _removePhotoAction,
                  icon: Icon(Icons.delete_outline, color: cf.error),
                  label: Text('Remove', style: TextStyle(color: cf.error)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _basicSection(CfColors cf) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: cfCardDecoration(context),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full name',
              helperText: '3–50 characters',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _markDirty(),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          TextField(
            controller: _jerseyController,
            decoration: const InputDecoration(
              labelText: 'Jersey number',
              helperText: 'Optional — 0 to 999',
              hintText: 'e.g. 7, 18, 333',
              prefixIcon: Icon(Icons.numbers_outlined),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (_) => _markDirty(),
          ),
        ],
      ),
    );
  }

  Widget _locationSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: cfCardDecoration(context),
      child: Column(
        children: [
          OnboardingLocationSection(
            initialLocation: _location,
            onLocationChanged: _onLocationChanged,
            locationService: ref.read(googleMapsLocationServiceProvider),
            autoDetectOnInit: false,
          ),
        ],
      ),
    );
  }

  Widget _cricketSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: cfCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Playing role', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...EditProfileOptions.playingRoles.map(
            (PlayerPlayingRole r) => OnboardingRadioTile<PlayerPlayingRole>(
              value: r,
              groupValue: _playingRole,
              title: r.label,
              onChanged: (v) {
                setState(() => _playingRole = v);
                _markDirty();
              },
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text('Batting style', style: Theme.of(context).textTheme.titleSmall),
          ...EditProfileOptions.battingStyles.map(
            (PlayerBattingStyle s) =>
                OnboardingRadioTile<PlayerBattingStyle>(
              value: s,
              groupValue: _battingStyle,
              title: EditProfileOptions.battingLabel(s),
              onChanged: (v) {
                setState(() => _battingStyle = v);
                _markDirty();
              },
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text('Bowling style', style: Theme.of(context).textTheme.titleSmall),
          ...EditProfileOptions.bowlingStyles.map(
            (PlayerBowlingStyle s) =>
                OnboardingRadioTile<PlayerBowlingStyle>(
              value: s,
              groupValue: _bowlingStyle,
              title: EditProfileOptions.bowlingLabel(s),
              onChanged: (v) {
                setState(() => _bowlingStyle = v);
                _markDirty();
              },
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text('Dominant hand', style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: EditProfileOptions.dominantHands.map((h) {
              return OnboardingChoiceChip(
                label: EditProfileOptions.dominantHandLabel(h),
                selected: _strongHand == h,
                onSelected: () {
                  setState(() => _strongHand = h);
                  _markDirty();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _personalSection(CfColors cf) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: cfCardDecoration(context),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            children: PlayerGender.values.map((g) {
              return OnboardingChoiceChip(
                label: g.label,
                selected: _gender == g,
                onSelected: () {
                  setState(() => _gender = g);
                  _markDirty();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          InkWell(
            onTap: _pickDob,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date of birth',
                prefixIcon: Icon(Icons.calendar_today_outlined),
                suffixIcon: Icon(Icons.chevron_right),
              ),
              child: Text(
                _dob == null
                    ? 'Select date'
                    : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                style: TextStyle(
                  color: _dob == null ? cf.textMuted : cf.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          TextField(
            controller: _bioController,
            maxLength: 250,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Bio',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            onChanged: (_) => _markDirty(),
          ),
        ],
      ),
    );
  }

  Widget _privateSection(CfColors cf) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: cfCardDecoration(context),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            onChanged: (_) => _markDirty(),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 108,
                child: Builder(
                  builder: (context) {
                    final dialCodes = [...CricketCountry.phoneDialCodes];
                    if (!dialCodes.contains(_dialCode)) {
                      dialCodes.insert(0, _dialCode);
                    }
                    return DropdownButtonFormField<String>(
                      value: _dialCode,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Code'),
                      items: dialCodes
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _dialCode = v);
                          _markDirty();
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    helperText: 'Digits only',
                  ),
                  onChanged: (_) => _markDirty(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _DiscardAction { cancel, discard, save }
